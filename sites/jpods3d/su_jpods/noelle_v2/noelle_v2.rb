# ── Noelle v2 — Network Builder ───────────────────────────────────────────────
#
# Noelle validates the network and generates network.json from:
#   - Template lines.computed.json (per-station geometry)
#   - Model entity positions (station transforms, connection CPs)
#   - lines.json topology (successor graph, chains)
#
# Noelle does NOT extract geometry from SketchUp edges. She reads
# what Compute wrote and transforms it to world coordinates.
#
# ── su-real ──────────────────────────────────────────────────────────────────
# network.json is the single source of truth for the deployed network.
# Physical Natalie reads it (or its mapSM.json derivative) for routing.
# Physical Noelle reads it for ezone definitions and station registry.
#
# SU simplifications vs physical:
#   - SU routing_graph is unweighted BFS; physical should weight edges by
#     line length + current congestion for Dijkstra/A* path selection
#   - SU connections have beam_path pts at structural Z; physical needs
#     vehicle-path Z (beam_top minus hanger depth). Natalie.load_network
#     handles this subtraction — physical map converter must do the same.
#   - SU formation_registry maps sid→template; physical maps sid→station
#     hardware config (Pi IP, sensor suite, slot count, door type)
#
# What network.json must carry for physical deployment:
#   - Per-connection: length_mm, curve_radius, max_speed_ms (from lateral G)
#   - Per-station: capacity, slot_spacing_mm, platform_track length
#   - Per-ezone: inPoint/outPoint with distFrom/distTo for each track
#   - Per-diverge: servo setting per chain (which branch = which servo angle)
#
# The formation_registry is critical: it tells physical Noelle which
# station template each SID uses, so she knows the ezone layout,
# chain topology, and CP configuration without re-scanning hardware.
#
# SU-generated IDs are the authority. network.json carries the canonical
# naming (seg_s001_1_s003_1, s001.gw_platform, etc.) and physical
# systems adopt these directly — no separate numbering scheme. The SU
# model IS the design document; physical deployment reads from it.
# ─────────────────────────────────────────────────────────────────────────────

require 'json'

module JPods
  module NoelleV2

    # Generate network.json for the active network model.
    # Reads each station's lines.computed.json + lines.json, applies
    # station instance transform, writes world-coordinate network.json.
    def self.generate_network(model)
      model_dir  = File.dirname(model.path)
      model_base = File.basename(model.path, '.skp')
      plugin_dir = File.dirname(File.dirname(__FILE__))

      puts ""
      puts "═══ Noelle v2 — Build #{model_base} ═══"
      puts ""

      # ── Scan stations ───────────────────────────────────────────────────
      stations = []
      formation_registry = {}

      model.entities.each do |e|
        next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
        sid = e.get_attribute('JPods', 'structure_id', '').to_s.strip
        next if sid.empty?

        # Determine template from definition name
        defn_name = e.is_a?(Sketchup::ComponentInstance) ? e.definition.name.to_s : ''
        template = defn_name.sub(/\AJPods Formation:\s*/i, '').sub(/\AJPods_/i, '').sub(/__stale\z/i, '').strip
        template = template.downcase unless template.empty?

        # Skip cpb barriers — they are not stations
        next if template == 'cpb' || defn_name.downcase.include?('cpb')

        formation_registry[sid.downcase] = template

        # Find inner formation transform (gw_* child scan)
        child_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        inner_xf = Geom::Transformation.new
        child_ents.each do |child|
          next unless child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
          sub = child.is_a?(Sketchup::Group) ? child.entities : child.definition.entities
          has_gw = sub.any? { |c| c.respond_to?(:layer) && c.layer.name.to_s.start_with?('gw_') rescue false }
          if has_gw
            inner_xf = child.transformation
            break
          end
        end

        stations << {
          id: sid.downcase,
          template: template,
          entity: e,
          station_name: (e.get_attribute('JPods', 'station_name', '') rescue '').to_s,
          world_xf: e.transformation,
          inner_xf: inner_xf,
          eff_xf: e.transformation * inner_xf
        }
      end

      puts "[Noelle v2] #{stations.size} station(s) found"

      # ── Build station tracks in world coordinates ──────────────────────
      all_stations = []
      routing_graph = {}

      stations.each do |st|
        sid = st[:id]
        template = st[:template]
        eff_xf = st[:eff_xf]

        # Read lines.computed.json
        computed_path = File.join(plugin_dir, 'templates', 'track_formations',
                                  template, 'lines.computed.json')
        unless File.exist?(computed_path)
          puts "[Noelle v2] ⚠ #{sid}: lines.computed.json not found for #{template}"
          next
        end

        computed = JSON.parse(File.read(computed_path, encoding: 'utf-8'))
        geo_tracks = computed.dig('geometry', 'tracks') || {}

        # Read lines.json for topology
        lj_path = File.join(plugin_dir, 'templates', 'track_formations',
                            template, 'lines.json')
        lj = File.exist?(lj_path) ? JSON.parse(File.read(lj_path, encoding: 'utf-8')) : {}
        nat = lj['natalie'] || computed['natalie'] || {}

        # Transform tracks to world coordinates
        in_per_mm = 1.0 / 25.4
        tracks_out = {}

        geo_tracks.each do |role, tdata|
          pts_mm = tdata['pts_mm']
          next unless pts_mm.is_a?(Array) && pts_mm.size >= 2

          pts = pts_mm.map { |p|
            lp = Geom::Point3d.new(p[0].to_f * in_per_mm,
                                   p[1].to_f * in_per_mm,
                                   p[2].to_f * in_per_mm)
            wp = lp.transform(eff_xf)
            # Store as mm hash for network.json
            { 'x' => (wp.x * 25.4).round(1),
              'y' => (wp.y * 25.4).round(1),
              'z' => (wp.z * 25.4).round(1) }
          }

          # Direction vector — read from lines.computed.json (Compute owns the math).
          # Transform to world coordinates using the same effective transform as the points.
          dir_raw = tdata['direction']
          dir = nil
          if dir_raw.is_a?(Hash) && pts.size >= 2
            # Recompute from world-space pts (already transformed above)
            p0 = pts[0]; p1 = pts[1]
            dx = p1['x'] - p0['x']; dy = p1['y'] - p0['y']; dz = p1['z'] - p0['z']
            mag = Math.sqrt(dx*dx + dy*dy + dz*dz)
            dir = mag > 0.001 ? { 'x' => (dx/mag).round(6), 'y' => (dy/mag).round(6), 'z' => (dz/mag).round(6) } : nil
          end

          tracks_out[role] = {
            'pts' => pts,
            'length_mm' => tdata['length_mm'],
            'direction' => dir,
          }
        end

        # Build routing graph from natalie chains + designer successors
        _add_chains_to_graph(routing_graph, sid, nat)
        _add_successors_to_graph(routing_graph, sid, (lj['designer'] || {})['tracks'])

        fn = st[:station_name].to_s
        has_platform = tracks_out.key?('gw_platform')
        all_stations << {
          'id' => sid,
          'template' => template,
          'has_platform' => has_platform,
          'friendly_name' => fn.empty? ? nil : fn,
          'tracks' => tracks_out
        }

        puts "[Noelle v2] #{sid} (#{template}): #{tracks_out.size} tracks, platform=#{has_platform}"
      end

      # ── Build connections ─────────────────────────────────────────────
      # Source 1: guideway group entities with beam_path attribute (old Build)
      # Source 2: Connect tool's connection records in existing network.json
      # Both produce the same output format.
      connections = []

      # Source 1: model entities
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::Group)
        cid = e.get_attribute('JPods', 'connection_id', '').to_s.strip.downcase
        next if cid.empty?

        norm_cid = cid.sub(/\Acp_/, 'seg_')
        if norm_cid.match?(/\A[a-z]\d+\.\d+_[a-z]\d+\.\d+\z/)
          norm_cid = "seg_#{norm_cid.tr('.', '_')}"
        end
        norm_cid = "seg_#{norm_cid}" unless norm_cid.start_with?('seg_')
        norm_cid = norm_cid.gsub(/_cp(\d)/, '_\1')

        raw = e.get_attribute('JPods', 'beam_path')
        next unless raw

        pts = JSON.parse(raw).map { |a|
          { 'x' => (a[0].to_f * 25.4).round(1),
            'y' => (a[1].to_f * 25.4).round(1),
            'z' => (a[2].to_f * 25.4).round(1) }
        }
        next unless pts.size >= 2

        m = norm_cid.match(/\Aseg_([a-z]\d+)_(\d+)_([a-z]\d+)_(\d+)\z/)
        next unless m

        connections << {
          'id' => norm_cid,
          'from' => { 'station' => m[1], 'cp_index' => m[2].to_i },
          'to' => { 'station' => m[3], 'cp_index' => m[4].to_i },
          'pts' => pts,
          'length_mm' => pts.each_cons(2).sum { |a, b|
            Math.sqrt((b['x']-a['x'])**2 + (b['y']-a['y'])**2 + (b['z']-a['z'])**2)
          }.round(1),
          'source' => 'entity'
        }
      end

      # Source 2: Connect tool's records in existing network.json
      # The Connect tool writes connection records keyed by "sid.stub_sid.stub"
      # with nested seg_ entries containing from/to structure_id + stub.
      existing_nj_path = File.join(model_dir, "#{model_base}.network.json")
      if File.exist?(existing_nj_path)
        begin
          existing = JSON.parse(File.read(existing_nj_path, encoding: 'utf-8'))
          (existing['connections'] || {}).each do |conn_key, conn_data|
            next unless conn_data.is_a?(Hash)
            conn_data.each do |seg_id, seg_data|
              next if seg_id == 'via_markers'
              next unless seg_data.is_a?(Hash) && seg_data['from'].is_a?(Hash)

              from_sid  = seg_data.dig('from', 'structure_id').to_s.downcase
              from_stub = seg_data.dig('from', 'stub').to_i
              to_sid    = seg_data.dig('to', 'structure_id').to_s.downcase
              to_stub   = seg_data.dig('to', 'stub').to_i
              next if from_sid.empty? || to_sid.empty?

              norm_cid = "seg_#{from_sid}_#{from_stub}_#{to_sid}_#{to_stub}"

              # Skip if already found from entity
              next if connections.any? { |c| c['id'] == norm_cid }

              # Build pts from CP positions (connect tool records from/to CPs)
              from_cp_key = "#{from_sid}.gw_cp_out_#{from_stub}"
              to_cp_key   = "#{to_sid}.gw_cp_in_#{to_stub}"

              # Get CP world positions from station tracks
              from_st = all_stations.find { |s| s['id'] == from_sid }
              to_st   = all_stations.find { |s| s['id'] == to_sid }

              from_track = from_st && from_st['tracks']["gw_cp_out_#{from_stub}"]
              to_track   = to_st && to_st['tracks']["gw_cp_in_#{to_stub}"]

              if from_track && to_track
                from_pts = from_track['pts']
                to_pts   = to_track['pts']
                if from_pts && to_pts && from_pts.size >= 1 && to_pts.size >= 1
                  # Straight line from CP out endpoint to CP in startpoint
                  fp = from_pts.last   # exit end of gw_cp_out
                  tp = to_pts.first    # entry end of gw_cp_in
                  pts = [fp, tp]
                  len = Math.sqrt((tp['x']-fp['x'])**2 + (tp['y']-fp['y'])**2 + (tp['z']-fp['z'])**2).round(1)

                  connections << {
                    'id' => norm_cid,
                    'from' => { 'station' => from_sid, 'cp_index' => from_stub },
                    'to' => { 'station' => to_sid, 'cp_index' => to_stub },
                    'pts' => pts,
                    'length_mm' => len,
                    'source' => 'connect_tool'
                  }
                  puts "[Noelle v2] connection from Connect tool: #{norm_cid} (#{len.round(0)}mm)"
                end
              else
                puts "[Noelle v2] ⚠ connection #{norm_cid}: missing CP tracks (from=#{from_cp_key} to=#{to_cp_key})"
              end
            end
          end
        rescue => ex
          puts "[Noelle v2] existing network.json read error: #{ex.message}"
        end
      end

      # Add connections to routing graph
      connections.each do |conn|
        from_key = "#{conn.dig('from','station')}.gw_cp_out_#{conn.dig('from','cp_index')}"
        to_key = "#{conn.dig('to','station')}.gw_cp_in_#{conn.dig('to','cp_index')}"
        cid = conn['id']
        routing_graph[from_key] = (Array(routing_graph[from_key]) + [cid]).uniq
        routing_graph[cid] = (Array(routing_graph[cid]) + [to_key]).uniq
      end

      # Deduplicate connections by from/to pair — keep the one with most pts
      seen = {}
      connections.each do |c|
        key = "#{c.dig('from','station')}_#{c.dig('from','cp_index')}→#{c.dig('to','station')}_#{c.dig('to','cp_index')}"
        if !seen[key] || c['pts'].size > seen[key]['pts'].size
          seen[key] = c
        end
      end
      connections = seen.values

      puts "[Noelle v2] #{connections.size} connection(s)"

      # ── Write network.json — preserve Connect tool's raw records ──────
      # The Connect tool writes a 'connections' key at top level with its
      # own format. Preserve it so future Builds can read it.
      connect_tool_records = {}
      if File.exist?(existing_nj_path)
        begin
          prev = JSON.parse(File.read(existing_nj_path, encoding: 'utf-8'))
          connect_tool_records = prev['connections'] if prev['connections'].is_a?(Hash)
        rescue; end
      end

      # Build station_names from entity attributes (source of truth)
      entity_station_names = {}
      all_stations.each do |s|
        fn = s['friendly_name'].to_s
        entity_station_names[s['id']] = fn unless fn.empty?
      end

      output = {
        'schema' => 'jpods-network-v2',
        'generated_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'generated_by' => 'Noelle v2',
        'station_names' => entity_station_names,
        'connections' => connect_tool_records,  # preserved from Connect tool
        'noelle' => {
          'formation_registry' => formation_registry,
        },
        'natalie' => {
          'routing_graph' => routing_graph,
        },
        'designer' => {
          'stations' => all_stations,
          'connections' => connections,
        },
      }

      # ── Orphan track and blocked CP validation ─────────────────────
      # Every track must appear in at least one chain (landing, exit,
      # originating, pass, or successor). A track not in any chain is
      # unreachable — no centerline path passes through it.
      # CP tracks that have chains leading to them but no centerline
      # connecting to another station are blocked — Natalie cannot route.
      orphan_defects = []
      blocked_cps = []

      # Build set of connected CP stubs from centerline connections.
      # Connection pair keys follow the pattern "s010.1_s005.3" — extract stubs directly.
      connected_stubs = {}
      conn_source = connect_tool_records.is_a?(Hash) ? connect_tool_records : {}
      conn_source.each_key do |pair_key|
        # pair_key format: "s010.1_s005.3"
        if pair_key.match?(/\A[a-z]\d+\.\d+_[a-z]\d+\.\d+\z/i)
          parts = pair_key.split('_')
          parts.each do |part|
            sid, stub = part.split('.')
            connected_stubs["#{sid.downcase}.#{stub}"] = true
          end
        end
      end
      puts "[Noelle v2] connected stubs: #{connected_stubs.keys.sort.join(', ')}"

      # Build set of all tracks that appear in the routing chain structure
      routed_tracks = Set.new
      routing_graph.each do |key, succs|
        routed_tracks.add(key)
        succs.each { |s| routed_tracks.add(s) }
      end

      all_stations.each do |st_data|
        sid = st_data['id']
        tracks = st_data['tracks'] || {}
        tracks.each_key do |track_name|
          full_key = "#{sid}.#{track_name}"

          unless routed_tracks.include?(full_key)
            # Track is not in any chain — orphan
            orphan_defects << {
              station: sid, track: track_name,
              severity: 'orphan', message: "track #{track_name} not in any chain"
            }
            puts "[Noelle] 🔴 ORPHAN: #{sid}.#{track_name} — not in any chain"
            next
          end

          # Flag both gw_cp_out_N and gw_cp_in_N when disconnected.
          # Software could theoretically drive CW, and physical designers
          # need to know where to put barriers to block access.
          cp_match = track_name.match(/\Agw_cp_(out|in)_(\d+)\z/)
          if cp_match
            cp_idx = cp_match[2].to_i
            unless connected_stubs["#{sid}.#{cp_idx}"]
              # Check if designer placed a barrier (acknowledged)
              # Detect cpb barrier components placed by the designer.
              # A cpb is a structure whose definition contains cp_marker_b.
              # It is placed near a CP like any other structure.
              has_barrier = model.entities.any? { |e|
                next false unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
                defn = e.is_a?(Sketchup::ComponentInstance) ? e.definition : nil
                next false unless defn
                is_cpb = defn.name.downcase.include?('cpb') ||
                         defn.entities.any? { |c|
                           c.is_a?(Sketchup::ComponentInstance) &&
                           c.definition.name.to_s.downcase.include?('cp_marker_b')
                         }
                next false unless is_cpb
                # Check proximity to this CP — barrier must be near the CP location
                barrier_pos = e.transformation.origin
                tracks = st_data['tracks'] || {}
                cp_tracks = tracks.select { |tn, _| tn.match?(/\Agw_cp_(out|in)_#{cp_idx}\z/) }
                cp_tracks.any? { |_tn, td|
                  pt = (td['pts'] || []).first
                  next false unless pt
                  cp_pt = Geom::Point3d.new(pt['x'] / 25.4, pt['y'] / 25.4, pt['z'] / 25.4)
                  barrier_pos.distance(cp_pt) < 20.m  # within 20m of the CP
                }
              }
              blocked_cps << { station: sid, track: track_name, cp: cp_idx, barrier: has_barrier }
              if has_barrier
                puts "[Noelle] ◦ #{sid}.#{track_name} (CP #{cp_idx}) — disconnected, barrier in place"
              else
                puts "[Noelle] ⚠ UNRESOLVED: #{sid}.#{track_name} (CP #{cp_idx}) — disconnected, no barrier"
              end
            end
          end
        end
      end

      if orphan_defects.any?
        puts ""
        puts "┌── Orphan Track Report ────────────────────────────"
        puts "│ 🔴 #{orphan_defects.size} track(s) not in any chain"
        orphan_defects.each { |d| puts "│    #{d[:station]}.#{d[:track]}" }
        puts "│ Designer must add these tracks to lines.json chains"
        puts "│ or remove them from the template"
        puts "└──────────────────────────────────────────────────"
        puts ""
      end

      if blocked_cps.any?
        barriered   = blocked_cps.select { |d| d[:barrier] }
        unresolved  = blocked_cps.reject { |d| d[:barrier] }
        puts ""
        puts "┌── Disconnected CP Report ─────────────────────────"
        puts "│ #{blocked_cps.size} CP(s) disconnected"
        barriered.each  { |d| puts "│  ◦ #{d[:station]}.#{d[:track]} (CP #{d[:cp]}) — barrier in place" }
        unresolved.each { |d| puts "│  ⚠ #{d[:station]}.#{d[:track]} (CP #{d[:cp]}) — needs cpb barrier placed" }
        puts "└──────────────────────────────────────────────────"
        puts ""
      end

      # ── Track gap validation — RED FLAGS ─────────────────────────────
      # Check every chain connection for gaps. Classify and report.
      # Defects are stored in network.json for Crew Health to display.
      gap_defects = []
      all_stations.each do |st_data|
        sid = st_data['id']
        tracks = st_data['tracks'] || {}
        template = st_data['template']

        lj_path = File.join(plugin_dir, 'templates', 'track_formations', template, 'lines.json')
        next unless File.exist?(lj_path)
        lj = JSON.parse(File.read(lj_path, encoding: 'utf-8')) rescue next
        nat = lj['natalie'] || {}

        %w[landing_chains exit_chains originating_chains].each do |section|
          (nat[section] || {}).each do |chain_name, chain|
            next if chain_name == 'note'
            next unless chain.is_a?(Hash)
            chain_tracks = Array(chain['tracks'])
            chain_tracks.each_cons(2) do |t_from, t_to|
              from_data = tracks[t_from]
              to_data   = tracks[t_to]
              next unless from_data && to_data
              from_pts = from_data['pts']
              to_pts   = to_data['pts']
              next unless from_pts.is_a?(Array) && from_pts.size >= 2
              next unless to_pts.is_a?(Array) && to_pts.size >= 2

              # Gap: last point of from_track → first point of to_track
              fp = from_pts.last; tp = to_pts.first
              gap_mm = Math.sqrt((fp['x']-tp['x'])**2 + (fp['y']-tp['y'])**2 + (fp['z']-tp['z'])**2)

              severity = if gap_mm < 50
                           nil  # valid
                         elsif gap_mm < 350
                           :warning
                         elsif gap_mm < 650
                           :edge_hallucination
                         else
                           :disconnect
                         end

              next unless severity

              defect = {
                station: sid, chain: "#{section}.#{chain_name}",
                from: t_from, to: t_to,
                gap_mm: gap_mm.round(1), severity: severity.to_s,
              }

              label = case severity
                      when :warning           then "⚠ SLOPPY"
                      when :edge_hallucination then "🔴 EDGE HALLUCINATION (500mm)"
                      when :disconnect         then "🔴 DISCONNECT"
                      end
              puts "[Noelle] #{label}: #{sid} #{t_from}→#{t_to} gap=#{gap_mm.round(0)}mm (#{section}.#{chain_name})"
              gap_defects << defect
            end
          end
        end
      end

      # Summary
      if gap_defects.any?
        edge_count = gap_defects.count { |d| d[:severity] == 'edge_hallucination' }
        disc_count = gap_defects.count { |d| d[:severity] == 'disconnect' }
        warn_count = gap_defects.count { |d| d[:severity] == 'warning' }
        puts ""
        puts "┌── Track Gap Report ──────────────────────────────"
        puts "│ 🔴 #{edge_count} edge hallucination(s)" if edge_count > 0
        puts "│ 🔴 #{disc_count} disconnect(s)" if disc_count > 0
        puts "│ ⚠  #{warn_count} sloppy connection(s)" if warn_count > 0
        puts "│ #{gap_defects.size} total defect(s) — designer must fix template geometry"
        puts "└──────────────────────────────────────────────────"
        puts ""
      else
        puts "[Noelle] ✓ All track connections within tolerance (<50mm)"
      end

      # ── Place visual flags at defect locations ───────────────────────
      # Purge old flags first
      model.entities.to_a.each do |e|
        next unless e.is_a?(Sketchup::Group) && e.name == 'JPods Defect Flag'
        model.entities.erase_entities(e) rescue nil
      end

      gap_defects.each do |d|
        sid = d[:station]
        from_track = d[:from]
        st_data = all_stations.find { |s| s['id'] == sid }
        next unless st_data
        from_pts = st_data.dig('tracks', from_track, 'pts')
        next unless from_pts.is_a?(Array) && from_pts.size >= 1
        # Flag at the last point of the from-track (where the gap is)
        last_pt = from_pts.last
        world_pt = Geom::Point3d.new(last_pt['x'] / 25.4, last_pt['y'] / 25.4, last_pt['z'] / 25.4)

        flag = model.entities.add_group
        flag.name = 'JPods Defect Flag'
        flag.set_attribute('JPods', 'defect_flag', true)
        flag.set_attribute('JPods', 'defect_info', "#{d[:severity]}: #{sid} #{from_track}→#{d[:to]} gap=#{d[:gap_mm]}mm")

        # Red sphere for edge/disconnect, orange for sloppy
        color = case d[:severity]
                when :edge_hallucination, 'edge_hallucination' then Sketchup::Color.new(255, 0, 0)
                when :disconnect, 'disconnect' then Sketchup::Color.new(255, 0, 0)
                else Sketchup::Color.new(255, 165, 0)
                end
        mat_name = "JPods_Defect_#{d[:severity]}"
        mat = model.materials[mat_name] || model.materials.add(mat_name)
        mat.color = color

        # Draw a vertical post + sphere at the defect location
        up = Geom::Vector3d.new(0, 0, 1)
        post_h = 8.0.m
        top_pt = world_pt.offset(up, post_h)
        # Post
        c = flag.entities.add_circle(world_pt, up, 0.1.m, 8)
        if c.is_a?(Array)
          f = flag.entities.add_face(c)
          f.pushpull(post_h) if f.is_a?(Sketchup::Face)
        end
        flag.material = mat
        # Label
        begin
          label = "#{d[:severity].to_s.upcase}\n#{sid} #{from_track}→#{d[:to]}\ngap=#{d[:gap_mm]}mm"
          flag.entities.add_text(label, top_pt.offset(up, 1.m))
        rescue; end
      end

      puts "[Noelle] #{gap_defects.size} defect flag(s) placed in model" if gap_defects.any?

      # ── Nora's ride quality check — kinks in built guideways ─────────
      kink_defects = []
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::Group) && e.get_attribute('JPods', 'seg_guideway', false)
        seg_id = e.name.to_s
        raw = e.get_attribute('JPods', 'beam_path')
        next unless raw
        pts = JSON.parse(raw) rescue next
        next unless pts.is_a?(Array) && pts.size >= 3

        pts.each_cons(3).with_index do |(a, b, c), i|
          # Vectors
          v1x = b[0]-a[0]; v1y = b[1]-a[1]; v1z = b[2]-a[2]
          v2x = c[0]-b[0]; v2y = c[1]-b[1]; v2z = c[2]-b[2]
          len1 = Math.sqrt(v1x*v1x + v1y*v1y + v1z*v1z)
          len2 = Math.sqrt(v2x*v2x + v2y*v2y + v2z*v2z)
          next if len1 < 1e-6 || len2 < 1e-6
          dot = (v1x*v2x + v1y*v2y + v1z*v2z) / (len1 * len2)
          dot = dot.clamp(-1.0, 1.0)
          angle_deg = Math.acos(dot) * 180.0 / Math::PI

          if angle_deg > 15  # >15° is a kink passengers would feel
            kink_defects << {
              segment: seg_id, point_index: i + 1,
              angle_deg: angle_deg.round(1),
              position_mm: [b[0].round(0), b[1].round(0), b[2].round(0)]
            }
          end
        end
      end

      if kink_defects.any?
        puts ""
        puts "[Nora] ⚠ #{kink_defects.size} kink(s) found — rough ride for passengers:"
        kink_defects.first(5).each do |k|
          puts "[Nora]   #{k[:segment]} pt[#{k[:point_index]}]: #{k[:angle_deg]}° deflection"
        end
      else
        puts "[Nora] ✓ All guideways smooth — good ride"
      end
      output['kink_defects'] = kink_defects

      # Store defects in output for Crew Health
      output['gap_defects'] = gap_defects
      output['orphan_defects'] = orphan_defects
      output['blocked_cps'] = blocked_cps

      out_path = File.join(model_dir, "#{model_base}.network.json")

      # Preserve user data from existing network.json (station_names, etc.)
      # Build regenerates routing/stations/connections but must not destroy
      # network-specific data the user entered.
      # Entity attributes are the source of truth; fall back to previous
      # network.json names for any station not yet named on the entity.
      if File.exist?(out_path)
        begin
          existing = JSON.parse(File.read(out_path, encoding: 'utf-8'))
          output['connections'] = existing['connections'] if existing['connections'] && !output['connections']
          # Merge: entity-attribute names win, then previous network.json names
          if existing['station_names'].is_a?(Hash)
            merged = existing['station_names'].merge(output['station_names'] || {})
            output['station_names'] = merged
            (output['designer']['stations'] || []).each do |st|
              fn = merged[st['id']] || merged[st['id'].to_s.downcase]
              st['friendly_name'] = fn if fn && !fn.empty?
            end
          end
        rescue => e
          puts "[Noelle v2] warning: could not preserve existing network.json data: #{e.message}"
        end
      end

      File.write(out_path, JSON.pretty_generate(output), encoding: 'utf-8')

      puts "[Noelle v2] network.json written — #{all_stations.size} station(s), " \
           "#{connections.size} connection(s), #{routing_graph.size} routing graph entries"
      puts ""
      puts "═══ Noelle v2 — Build complete ═══"
      puts ""

      output
    rescue => ex
      puts "[Noelle v2] error: #{ex.message}\n#{ex.backtrace.first(3).join("\n")}"
      nil
    end

    private

    # Add chains from natalie section to routing graph
    def self._add_chains_to_graph(graph, sid, nat)
      # Landing, exit, originating chains
      %w[landing_chains exit_chains originating_chains].each do |section|
        (nat[section] || {}).each do |_key, chain|
          next if _key == 'note'
          next unless chain.is_a?(Hash)
          tracks = Array(chain['tracks'])
          tracks.each_cons(2) do |a, b|
            key = "#{sid}.#{a}"
            graph[key] = (Array(graph[key]) + ["#{sid}.#{b}"]).uniq
          end
        end
      end

      # Pass chains (traffic circles) — new format: circle + entries + exits
      pc = nat['pass_chains'] || {}
      circle = pc['circle']
      if circle.is_a?(Array) && circle.size >= 2
        # Ring arcs chain CCW
        circle.each_cons(2) do |a, b|
          graph["#{sid}.#{a}"] = (Array(graph["#{sid}.#{a}"]) + ["#{sid}.#{b}"]).uniq
        end
        # Close the ring: last → first
        graph["#{sid}.#{circle.last}"] = (Array(graph["#{sid}.#{circle.last}"]) + ["#{sid}.#{circle.first}"]).uniq

        # Entries: gw_cp_in_N → gw_in_N → entry_arc (first ring arc)
        (pc['entries'] || {}).each do |cp_key, entry_tracks|
          next unless entry_tracks.is_a?(Array)
          entry_tracks.each_cons(2) do |a, b|
            graph["#{sid}.#{a}"] = (Array(graph["#{sid}.#{a}"]) + ["#{sid}.#{b}"]).uniq
          end
          # Connect last entry track to entry_arc
          ea = (pc['entry_arc'] || {})[cp_key]
          if ea && entry_tracks.last
            graph["#{sid}.#{entry_tracks.last}"] = (Array(graph["#{sid}.#{entry_tracks.last}"]) + ["#{sid}.#{ea}"]).uniq
          end
        end

        # Exits: exit_arc → gw_out_N → gw_cp_out_N
        (pc['exits'] || {}).each do |cp_key, exit_tracks|
          next unless exit_tracks.is_a?(Array)
          exit_tracks.each_cons(2) do |a, b|
            graph["#{sid}.#{a}"] = (Array(graph["#{sid}.#{a}"]) + ["#{sid}.#{b}"]).uniq
          end
          # Connect exit_arc to first exit track
          xa = (pc['exit_arc'] || {})[cp_key]
          if xa && exit_tracks.first
            graph["#{sid}.#{xa}"] = (Array(graph["#{sid}.#{xa}"]) + ["#{sid}.#{exit_tracks.first}"]).uniq
          end
        end
      end

      # Legacy pass chains (old format — from_cpN_to_cpM with tracks array)
      (pc).each do |_key, chain|
        next if %w[note circle entries exits entry_arc exit_arc].include?(_key)
        next unless chain.is_a?(Hash)
        tracks = Array(chain['tracks'])
        tracks.each_cons(2) do |a, b|
          key = "#{sid}.#{a}"
          graph[key] = (Array(graph[key]) + ["#{sid}.#{b}"]).uniq
        end
      end

    end

    # Build routing graph edges from designer.tracks successors in lines.json.
    # Called after _add_chains_to_graph to fill gaps between chain endpoints.
    def self._add_successors_to_graph(graph, sid, designer_tracks)
      return unless designer_tracks.is_a?(Hash)
      designer_tracks.each do |track_name, track_def|
        next unless track_def.is_a?(Hash)
        succs = Array(track_def['successors'])
        succs.each do |succ|
          key = "#{sid}.#{track_name}"
          graph[key] = (Array(graph[key]) + ["#{sid}.#{succ}"]).uniq
        end
      end
    end

  end
end

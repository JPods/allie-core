# ── Crew Health Check — each member reports and verifies ──────────────────────
#
# Each crew member knows what healthy looks like for them.
# They can check themselves and flag problems to the team.
#
# Usage:
#   JPods::CrewHealth.check(model)  — full crew health report
#   JPods::CrewHealth.check_sally   — Sally only
#
# Each check returns { ok: bool, agent: name, checks: [...], faults: [...] }

module JPods
  module CrewHealth

    def self.check(model)
      results = []
      results << check_sally(model)
      results << check_natalie(model)
      results << check_nora
      results << check_noelle(model)
      results << check_animation

      total_faults = results.sum { |r| r[:faults].size }
      puts ""
      puts "═══ Crew Health Check ═══"
      results.each do |r|
        status = r[:ok] ? '✓' : '⚠'
        puts "#{status} #{r[:agent]}: #{r[:checks].size} checks, #{r[:faults].size} fault(s)"
        r[:faults].each { |f| puts "    ⛔ #{f}" }
        r[:checks].each { |c| puts "    #{c}" } if defined?(JPods::Log) && JPods::Log.level == :detailed
      end

      # Agent memory summary
      if defined?(JPods::Log)
        puts ""
        puts "── Agent Memory (facets) ──"
        JPods::Log.recall_all
      end

      # Network journal summary
      if model && defined?(JPods::CrewJournal)
        puts ""
        puts "── Network Journal ──"
        JPods::CrewJournal.read(model, n: 10)
      end

      puts "═══ #{total_faults == 0 ? 'ALL HEALTHY' : "#{total_faults} FAULT(S)"} ═══"
      puts ""

      results
    end

    # ── Crew flag — any agent can flag a defect at a coordinate ────────
    # Flags within 2 ticks (~2m at cruise) of existing flag = same defect (count++)
    FLAG_MERGE_DIST_MM = 2000.0  # 2m — flags within this distance are the same defect

    def self.add_flag(agent:, type:, message:, x_mm:, y_mm:, z_mm:)
      model = Sketchup.active_model rescue nil
      return unless model
      nj_path = JPods::NetworkEditor.default_network_json_path(model) rescue nil
      return unless nj_path && File.exist?(nj_path)
      nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
      nj['crew_flags'] ||= []

      # Check for nearby existing flag — merge if within distance
      existing = nj['crew_flags'].find { |f|
        dx = (f['x'].to_f - x_mm.to_f)
        dy = (f['y'].to_f - y_mm.to_f)
        dz = (f['z'].to_f - z_mm.to_f)
        Math.sqrt(dx*dx + dy*dy + dz*dz) < FLAG_MERGE_DIST_MM
      }

      if existing
        existing['count'] = (existing['count'] || 1) + 1
        existing['last_agent'] = agent.to_s
        existing['last_message'] = message.to_s
        existing['last_at'] = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      else
        nj['crew_flags'] << {
          'agent' => agent.to_s, 'type' => type.to_s,
          'message' => message.to_s,
          'x' => x_mm.to_f.round(1), 'y' => y_mm.to_f.round(1), 'z' => z_mm.to_f.round(1),
          'count' => 1,
          'created_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
        }
      end

      File.write(nj_path, JSON.pretty_generate(nj), encoding: 'utf-8')
    rescue => ex
      puts "[CrewHealth] add_flag error: #{ex.message}"
    end

    # ── Sally: ps[] and pods[] consistency ──────────────────────────────────
    def self.check_sally(model = nil)
      checks = []
      faults = []

      unless defined?(SallyV2)
        return { ok: false, agent: 'Sally', checks: [], faults: ['SallyV2 not loaded'] }
      end

      SallyV2.stations.each do |sid, st|
        # Check 1: every occupied slot has a matching pod record
        st.ps.each do |s|
          next unless s.occupied?
          rec = st.pod(s.occupant_id)
          unless rec
            faults << "#{sid} ps#{s.number}: occupant #{s.occupant_id} not in pods[]"
          end
        end
        checks << "#{sid}: ps[] occupants match pods[] — #{st.occupied_slots.size} occupied"

        # Check 2: every pod record with a slot has a matching ps[] entry
        st.pods.each do |nid, rec|
          next unless rec.slot && rec.slot > 0 && rec.parked?
          s = st.slot(rec.slot)
          unless s && s.occupant_id == nid
            faults << "#{sid}: pod #{nid} claims ps#{rec.slot} but slot says #{s&.occupant_id || 'empty'}"
          end
        end
        checks << "#{sid}: pods[] slots match ps[] — #{st.pods.size} pods"

        # Check 3: no slot has two occupants
        occupants = st.ps.select(&:occupied?).map(&:occupant_id)
        dupes = occupants.select { |id| occupants.count(id) > 1 }.uniq
        faults << "#{sid}: duplicate occupant in ps[]: #{dupes.join(', ')}" if dupes.any?
        checks << "#{sid}: no duplicate occupants"

        # Check 4: capacity matches ps[] size
        unless st.ps.size == st.capacity
          faults << "#{sid}: ps[] size #{st.ps.size} != capacity #{st.capacity}"
        end
        checks << "#{sid}: capacity #{st.capacity} consistent"

        # Check 5: pods in :looping state have vacated their slot
        st.pods.each do |nid, rec|
          next unless rec.looping?
          s = st.ps.find { |ps| ps.occupant_id == nid }
          if s
            faults << "#{sid}: pod #{nid} is :looping but still occupies ps#{s.number}"
          end
        end
        checks << "#{sid}: looping pods have vacated slots"
      end

      { ok: faults.empty?, agent: 'Sally', checks: checks, faults: faults }
    end

    # ── Natalie: routing graph connectivity ─────────────────────────────────
    def self.check_natalie(model = nil)
      checks = []
      faults = []

      unless defined?(NatalieV2)
        return { ok: false, agent: 'Natalie', checks: [], faults: ['NatalieV2 not loaded'] }
      end

      rg = NatalieV2.routing_graph
      checks << "routing graph: #{rg.size} entries"

      # Check: every platform station can reach every other platform station
      sids = NatalieV2.platform_stations
      checks << "platform stations: #{sids.join(', ')}"

      sids.each do |from|
        sids.each do |to|
          next if from == to
          route = NatalieV2.plan_route(from, to)
          unless route
            faults << "no route #{from} → #{to}"
          end
        end
      end
      n_routes = sids.size * (sids.size - 1)
      checks << "route pairs tested: #{n_routes} (#{n_routes - faults.size} reachable)"

      # Check: circle stations have circle data
      NatalieV2.circles.each do |sid, cd|
        ring = cd[:circle] || []
        entries = cd[:entries] || {}
        exits = cd[:exits] || {}
        checks << "circle #{sid}: #{ring.size} arcs, #{entries.size} entries, #{exits.size} exits"
        faults << "circle #{sid}: ring empty" if ring.empty?
        faults << "circle #{sid}: no entries" if entries.empty?
        faults << "circle #{sid}: no exits" if exits.empty?
      end

      # Disconnected CPs — Natalie reads what Noelle recorded in network.json.
      # Noelle owns the network definition; Natalie routes based on it.
      if model
        nj_path = File.join(File.dirname(model.path),
                            "#{File.basename(model.path, '.skp')}.network.json")
        if File.exist?(nj_path)
          nj = JSON.parse(File.read(nj_path, encoding: 'utf-8')) rescue {}
          blocked = nj['blocked_cps'] || []
          if blocked.any?
            barriered  = blocked.select { |b| b['barrier'] }
            unresolved = blocked.reject { |b| b['barrier'] }
            checks << "disconnected CPs: #{blocked.size} per Noelle (#{barriered.size} barriered, #{unresolved.size} unresolved)"
            barriered.each do |b|
              checks << "  ◦ #{b['station']}.#{b['track']} (CP #{b['cp']}) — barriered"
            end
            unresolved.each do |b|
              checks << "  ⚠ #{b['station']}.#{b['track']} (CP #{b['cp']}) — unresolved, place cpb"
            end
          else
            checks << "disconnected CPs: none per Noelle"
          end
        end
      end

      { ok: faults.empty?, agent: 'Natalie', checks: checks, faults: faults }
    end

    # ── Nora: pod state consistency ────────────────────────────────────────
    def self.check_nora
      checks = []
      faults = []

      if defined?(AnimationV2) && AnimationV2.running?
        pods = AnimationV2.pods
        checks << "#{pods.size} pod(s) in animation"

        # Check: no pod has nil entity
        nil_ents = pods.count { |p| p.entity.nil? || p.entity.deleted? }
        faults << "#{nil_ents} pod(s) with nil/deleted entity" if nil_ents > 0
        checks << "entity integrity: #{pods.size - nil_ents}/#{pods.size} valid"

        # Check: traveling pods have a current maneuver
        traveling = pods.select { |p| p.state == :traveling }
        no_man = traveling.count { |p| p.current_maneuver.nil? }
        faults << "#{no_man} traveling pod(s) with no maneuver" if no_man > 0
        checks << "traveling pods: #{traveling.size} (#{traveling.size - no_man} with maneuvers)"

        # Check: t is in [0, 1] for all pods
        bad_t = pods.count { |p| p.t < -0.01 || p.t > 1.01 }
        faults << "#{bad_t} pod(s) with t outside [0,1]" if bad_t > 0
        checks << "t range valid: #{pods.size - bad_t}/#{pods.size}"
      else
        checks << "animation not running — no pod checks"
      end

      # Ride quality — kink defects from Build
      model = Sketchup.active_model rescue nil
      if model
        nj_path = File.join(File.dirname(model.path),
                            "#{File.basename(model.path, '.skp')}.network.json")
        if File.exist?(nj_path)
          nj = JSON.parse(File.read(nj_path, encoding: 'utf-8')) rescue {}
          kinks = nj['kink_defects'] || []
          if kinks.any?
            checks << "ride quality: #{kinks.size} kink(s) detected"
            kinks.first(5).each do |k|
              faults << "⚠ KINK: #{k['segment']} pt[#{k['point_index']}] #{k['angle_deg']}° — passengers will feel this"
            end
          else
            checks << "ride quality: ✓ smooth guideways"
          end
        end
      end

      { ok: faults.empty?, agent: 'Nora', checks: checks, faults: faults }
    end

    # ── Noelle: network.json validity ──────────────────────────────────────
    def self.check_noelle(model = nil)
      checks = []
      faults = []

      return { ok: true, agent: 'Noelle', checks: ['no model'], faults: [] } unless model

      nj_path = File.join(File.dirname(model.path),
                          "#{File.basename(model.path, '.skp')}.network.json")
      unless File.exist?(nj_path)
        return { ok: false, agent: 'Noelle', checks: [], faults: ['network.json not found'] }
      end

      nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
      stations = nj.dig('designer', 'stations') || []
      connections = nj.dig('designer', 'connections') || []
      rg = nj.dig('natalie', 'routing_graph') || {}

      checks << "network.json: #{stations.size} stations, #{connections.size} connections, #{rg.size} graph entries"

      # Check: every connection has pts
      connections.each do |c|
        pts = c['pts'] || []
        if pts.size < 2
          faults << "connection #{c['id']}: #{pts.size} pts (need ≥2)"
        end
      end
      checks << "connection geometry: #{connections.count { |c| (c['pts'] || []).size >= 2 }}/#{connections.size} valid"

      # Check: every station has tracks
      stations.each do |st|
        tracks = st['tracks'] || {}
        if tracks.empty?
          faults << "station #{st['id']}: no tracks"
        end
      end
      checks << "station tracks: #{stations.count { |s| !(s['tracks'] || {}).empty? }}/#{stations.size} have tracks"

      # Check: track gap defects from Build
      gap_defects = nj['gap_defects'] || []
      if gap_defects.any?
        edge_count = gap_defects.count { |d| d['severity'] == 'edge_hallucination' }
        disc_count = gap_defects.count { |d| d['severity'] == 'disconnect' }
        warn_count = gap_defects.count { |d| d['severity'] == 'warning' }
        checks << "track gaps: #{gap_defects.size} defect(s)"
        gap_defects.each do |d|
          label = case d['severity']
                  when 'edge_hallucination' then '🔴 EDGE 500mm'
                  when 'disconnect'         then '🔴 DISCONNECT'
                  when 'warning'            then '⚠ SLOPPY'
                  else '?'
                  end
          faults << "#{label}: #{d['station']} #{d['from']}→#{d['to']} gap=#{d['gap_mm']}mm"
        end
      else
        checks << "track gaps: ✓ all within tolerance"
      end

      # Check: orphan tracks — tracks not in any chain
      orphan_defects = nj['orphan_defects'] || []
      if orphan_defects.any?
        checks << "orphan tracks: #{orphan_defects.size} not in any chain"
        orphan_defects.each do |d|
          faults << "🔴 ORPHAN: #{d['station']}.#{d['track']} — not in any chain"
        end
      else
        checks << "orphan tracks: ✓ all tracks in chains"
      end

      { ok: faults.empty?, agent: 'Noelle', checks: checks, faults: faults }
    end

    # ── Animation: tick loop health ────────────────────────────────────────
    def self.check_animation
      checks = []
      faults = []

      if defined?(AnimationV2)
        running = AnimationV2.running?
        checks << "animation #{running ? 'running' : 'stopped'}"

        if running
          pods = AnimationV2.pods
          # Check: Sally and Animation agree on pod count per station
          if defined?(SallyV2)
            SallyV2.stations.each do |sid, st|
              sally_count = st.pods.size
              anim_count = pods.count { |p|
                !p.entity.nil? && !p.entity.deleted? &&
                p.entity.get_attribute('JPods', 'parked_station_id', '').to_s.strip.downcase == sid
              }
              # Not exact — traveling pods have left station. Just check for large discrepancies.
              if (sally_count - anim_count).abs > st.capacity
                faults << "#{sid}: Sally has #{sally_count} pods, Animation entity scan shows #{anim_count}"
              end
            end
            checks << "Sally-Animation pod counts consistent"
          end

          # Check: EZone state
          if defined?(EZone)
            ez = EZone.ezones
            locked = ez.count { |z| z.locked_by }
            total_sw = ez.sum { |z| z.stop_wait_count }
            checks << "ezones: #{ez.size} total, #{locked} locked, #{total_sw} stop-waits"
          end
        end
      else
        checks << "AnimationV2 not defined"
      end

      { ok: faults.empty?, agent: 'Animation', checks: checks, faults: faults }
    end

  end
end

# ── Build v2 — Guideway Geometry Builder ──────────────────────────────────────
#
# Reads connection records from network.json, resolves CPs from station
# entities, builds bezier centerlines, applies terrain snap, creates
# beam/column/solar geometry.
#
# Uses migrated v2 modules:
#   build/build_bezier.rb  — Network.bezier_spline_pts, offset_path
#   build/build_path.rb    — PathBuilder.build (terrain, grade limits)
#   build/build_extrude.rb — JPods.upright_extrude (FollowMe beam)
#   build/build_entities.rb — JPodGuideway.build, place_solar_columns
#   build/build_helpers.rb — find_structure, resolve_cp, find_marker
#
# No codearchive dependencies.

require 'json'

module JPods
  module BuildV2

    def self.build(model)
      model_dir  = File.dirname(model.path)
      model_base = File.basename(model.path, '.skp')

      puts ""
      puts "═══ Build v2 — #{model_base} ═══"
      puts ""

      # ── Load stored constraint overrides from model ────────────────────
      stored = model.get_attribute("JPods", "primary_constraints_overrides")
      if stored
        begin
          overrides = JSON.parse(stored)
          Constants.apply_primary_constraint_overrides(overrides) if overrides.is_a?(Hash) && overrides.any?
          puts "[Build v2] loaded constraint overrides: #{overrides.map { |k,v| "#{k}=#{(v / 1.m).round(1)}m" }.join(', ')}"
        rescue => e
          puts "[Build v2] ⚠ constraint override parse error: #{e.message}"
        end
      end

      # ── Read connections from network.json ─────────────────────────────
      nj_path = File.join(model_dir, "#{model_base}.network.json")
      connections = _read_connections(nj_path)

      if connections.empty?
        puts "[Build v2] no connections — run Connect Guideways first"
        return { ok: false, built_segments: 0, faults: ["No connections"] }
      end
      puts "[Build v2] #{connections.size} connection segment(s)"

      # ── Prepare CP cache ───────────────────────────────────────────────
      cp_cache = Network.prepare_build_cp_cache(model)

      # ── Purge old geometry ─────────────────────────────────────────────
      to_erase = model.entities.select { |e|
        e.is_a?(Sketchup::Group) && (
          !e.get_attribute('JPods', 'connection_id', '').to_s.empty? ||
          e.name.start_with?('GW_', 'Support_', 'Solar_', 'seg_')
        )
      }
      if to_erase.any?
        model.entities.erase_entities(to_erase)
        puts "[Build v2] purged #{to_erase.size} old group(s)"
      end

      # ── Compute station bounding box — nothing built outside this ───────
      @@build_bounds = _compute_station_bounds(cp_cache)
      if @@build_bounds
        puts "[Build v2] station bounds: X(#{@@build_bounds[:x_min].to_m.round(1)}–#{@@build_bounds[:x_max].to_m.round(1)}m) " \
             "Y(#{@@build_bounds[:y_min].to_m.round(1)}–#{@@build_bounds[:y_max].to_m.round(1)}m) " \
             "Z(#{@@build_bounds[:z_min].to_m.round(1)}–#{@@build_bounds[:z_max].to_m.round(1)}m)"
      end

      # ── Preload structure definitions ──────────────────────────────────
      JPodGuideway.preload_structure_definitions(model)

      # ── Build each connection ──────────────────────────────────────────
      built = 0
      faults = []

      model.start_operation('Build Guideways', true)

      # Deduplicate: each physical connection has forward + reverse segments.
      # Build only once per pair — _build_one_segment creates both beam directions.
      built_pairs = {}
      connections.each do |conn|
        from_sid  = conn.dig('from', 'structure_id').to_s.downcase
        from_stub = conn.dig('from', 'stub').to_i
        to_sid    = conn.dig('to', 'structure_id').to_s.downcase
        to_stub   = conn.dig('to', 'stub').to_i
        # Canonical pair key (sorted so fwd and rev map to same key)
        pair = ["#{from_sid}.#{from_stub}", "#{to_sid}.#{to_stub}"].sort.join('_')
        next if built_pairs[pair]
        built_pairs[pair] = true

        result = _build_one_segment(conn, model, cp_cache)
        if result[:ok]
          built += 1
        else
          faults << result[:fault]
        end
      end

      model.commit_operation

      puts ""
      puts "[Build v2] #{built}/#{built_pairs.size} segment(s) built"
      faults.each { |f| puts "[Build v2] ⚠ #{f}" } if faults.any?
      puts ""

      # Clear build-required flag
      begin
        nj_path = File.join(model_dir, "#{model_base}.network.json")
        if File.exist?(nj_path)
          nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
          if nj.delete('build_required')
            File.write(nj_path, JSON.pretty_generate(nj), encoding: 'utf-8')
            puts "[Build v2] build_required flag cleared"
          end
        end
      rescue; end

      { ok: faults.empty?, built_segments: built, faults: faults }
    rescue => ex
      model.abort_operation rescue nil
      puts "[Build v2] error: #{ex.message}\n#{ex.backtrace.first(3).join("\n")}"
      { ok: false, built_segments: 0, faults: [ex.message] }
    end

    private

    # ── Station bounding box — the build fence ─────────────────────────
    # Nothing is built outside the station distribution + margin.
    # Margin = 10% of the longest axis or 50m, whichever is larger.
    def self._compute_station_bounds(cp_cache)
      all_pts = []
      cp_cache.each_value do |entry|
        ent = entry[:entity]
        bb = ent.bounds
        all_pts << bb.min
        all_pts << bb.max
      end
      return nil if all_pts.empty?

      xs = all_pts.map(&:x)
      ys = all_pts.map(&:y)
      zs = all_pts.map(&:z)

      span = [xs.max - xs.min, ys.max - ys.min].max
      margin = [span * 0.1, 50.0.m].max

      {
        x_min: xs.min - margin, x_max: xs.max + margin,
        y_min: ys.min - margin, y_max: ys.max + margin,
        z_min: zs.min - 20.0.m, z_max: zs.max + 30.0.m,  # generous Z
      }
    end

    # Check if a point is within the build fence
    def self._in_bounds?(pt)
      return true unless @@build_bounds
      b = @@build_bounds
      pt.x >= b[:x_min] && pt.x <= b[:x_max] &&
      pt.y >= b[:y_min] && pt.y <= b[:y_max] &&
      pt.z >= b[:z_min] && pt.z <= b[:z_max]
    end

    # Clamp a path to the build fence — remove points outside
    def self._clamp_path(pts)
      return pts unless @@build_bounds
      clamped = pts.select { |pt| _in_bounds?(pt) }
      if clamped.size < pts.size
        puts "[Build v2] ⚠ clamped #{pts.size - clamped.size} pts outside station bounds"
      end
      clamped.size >= 2 ? clamped : pts  # fallback to original if too few remain
    end

    # ── Read connections from network.json ────────────────────────────────
    def self._read_connections(nj_path)
      return [] unless File.exist?(nj_path)
      nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
      connections = []
      (nj['connections'] || {}).each do |conn_key, conn_data|
        next unless conn_data.is_a?(Hash)
        via_markers = conn_data['via_markers'] || []
        conn_data.each do |seg_id, seg_data|
          next if seg_id == 'via_markers'
          next unless seg_data.is_a?(Hash) && seg_data['from'].is_a?(Hash)
          connections << {
            'id' => seg_id, 'from' => seg_data['from'],
            'to' => seg_data['to'], 'via_markers' => via_markers,
          }
        end
      end
      connections
    end

    # ── Build one connection segment ─────────────────────────────────────
    def self._build_one_segment(conn, model, cp_cache)
      seg_id = conn['id']
      from_sid  = conn.dig('from', 'structure_id').to_s.downcase
      from_stub = conn.dig('from', 'stub').to_i
      to_sid    = conn.dig('to', 'structure_id').to_s.downcase
      to_stub   = conn.dig('to', 'stub').to_i

      # Resolve CPs
      from_entry = cp_cache[from_sid]
      to_entry   = cp_cache[to_sid]
      unless from_entry
        return { ok: false, fault: "#{seg_id}: station #{from_sid} not found" }
      end
      unless to_entry
        return { ok: false, fault: "#{seg_id}: station #{to_sid} not found" }
      end

      from_cp = Network.resolve_cp(from_entry[:entity], from_stub)
      to_cp   = Network.resolve_cp(to_entry[:entity], to_stub)
      unless from_cp
        return { ok: false, fault: "#{seg_id}: CP#{from_stub} not found on #{from_sid}" }
      end
      unless to_cp
        return { ok: false, fault: "#{seg_id}: CP#{to_stub} not found on #{to_sid}" }
      end

      # ── Phase 1: Plan — bezier centerline ──────────────────────────────
      # Waypoint markers carry beam_z — the authoritative routing elevation.
      # beam_z is already at beam level (terrain + clearance when placed).
      # Use beam_z directly as the waypoint Z anchor — do NOT add clearance again.
      marker_pts = (conn['via_markers'] || []).filter_map do |n|
        m = Network.find_marker(n.to_i, model)
        next nil unless m
        b = m.bounds
        beam_z = m.get_attribute("JPods", "beam_z")
        routing_z = beam_z ? beam_z.to_f : (b.min.z + Constants::CLEARANCE_HEIGHT)
        puts "[Build] M#{n}: beam_z=#{beam_z.inspect} b.min.z=#{b.min.z.to_m.round(2)}m → routing_z=#{routing_z.to_m.round(2)}m (#{beam_z ? 'from attr' : 'fallback: terrain+clearance'})"
        Geom::Point3d.new(b.center.x, b.center.y, routing_z)
      end

      # Track log — enabled for segments with waypoints
      track = !marker_pts.empty?
      if track
        puts ""
        puts "┌── Track Log: #{seg_id} ──────────────────────────"
        marker_pts.each_with_index do |mp, i|
          puts "│ waypoint[#{i}]: x=#{mp.x.to_m.round(2)}m y=#{mp.y.to_m.round(2)}m beam_z=#{mp.z.to_m.round(2)}m"
        end
      end

      center_pts = Network.bezier_spline_pts(from_cp, marker_pts, to_cp, lead_dist: 2.0.m)

      if track
        zs = center_pts.each_slice([center_pts.size / 8, 1].max).map { |s| s.first.z.to_m.round(2) }
        puts "│ Phase 1 (bezier):  Z samples(m): #{zs.join(', ')}"
      end

      # Anchor Z: CP center + BEAM_DEPTH
      from_z = from_cp[:center].z + Constants::BEAM_DEPTH
      to_z   = to_cp[:center].z + Constants::BEAM_DEPTH
      anchor_zs = [from_z, to_z]

      # Waypoint Z anchors — beam_z is beam-bottom level; add BEAM_DEPTH
      # to match CP anchor frame (beam top).
      waypoint_zs = marker_pts.map { |mp| mp.z + Constants::BEAM_DEPTH }

      if track
        puts "│ anchor_zs: from=#{from_z.to_m.round(2)}m to=#{to_z.to_m.round(2)}m"
        waypoint_zs.each_with_index { |wz, i| puts "│ waypoint_z[#{i}]: #{wz.to_m.round(2)}m (beam_z)" }
      end

      # ── Phase 2: Resolve — terrain snap + grade limits ─────────────────
      center_pts = PathBuilder.build(center_pts, model,
                                     anchor_zs: anchor_zs, pre_smoothed: true,
                                     waypoint_zs: waypoint_zs,
                                     waypoint_xys: marker_pts)

      if track
        zs = center_pts.each_slice([center_pts.size / 8, 1].max).map { |s| s.first.z.to_m.round(2) }
        puts "│ Phase 2 (profile): Z samples(m): #{zs.join(', ')}"
      end

      # Pin XY endpoints to CP centers
      if center_pts.size >= 2
        p0 = center_pts[0]
        center_pts[0] = Geom::Point3d.new(from_cp[:center].x, from_cp[:center].y, p0.z)
        pn = center_pts[-1]
        center_pts[-1] = Geom::Point3d.new(to_cp[:center].x, to_cp[:center].y, pn.z)
      end

      # Clamp to station bounds — nothing built outside the station distribution
      center_pts = _clamp_path(center_pts)

      if track
        zs = center_pts.each_slice([center_pts.size / 8, 1].max).map { |s| s.first.z.to_m.round(2) }
        puts "│ Phase 3 (final):   Z samples(m): #{zs.join(', ')}"
        z_min = center_pts.map { |p| p.z.to_m }.min.round(2)
        z_max = center_pts.map { |p| p.z.to_m }.max.round(2)
        puts "│ Z range: #{z_min}m – #{z_max}m  (Δ#{(z_max - z_min).round(2)}m)"
        puts "└──────────────────────────────────────────────────"
        puts ""
      end

      # Log CP resolution for debugging
      fc = from_cp[:center]; ft = from_cp[:tangent]
      tc = to_cp[:center];   tt = to_cp[:tangent]
      puts "[Build v2] #{seg_id}: from=(#{fc.x.to_m.round(1)},#{fc.y.to_m.round(1)},#{fc.z.to_m.round(1)})m " \
           "tangent=(#{ft.x.round(3)},#{ft.y.round(3)}) → " \
           "to=(#{tc.x.to_m.round(1)},#{tc.y.to_m.round(1)},#{tc.z.to_m.round(1)})m " \
           "tangent=(#{tt.x.round(3)},#{tt.y.round(3)})"
      puts "[Build v2] #{seg_id}: #{center_pts.size} pts centerline"

      # ── Phase 3: Extrude — dual beams + columns + solar ────────────────
      half_off = Constants::DUAL_TRACK_SPACING / 2.0

      # Forward and reverse beams
      seg_fwd = seg_id
      seg_rev = Network.reverse_seg_id(seg_id, conn['from'], conn['to'])

      [1, -1].each_with_index do |sign, track_idx|
        beam_path = Network.offset_path(center_pts, sign * half_off)
        beam_path = _clamp_path(beam_path)
        beam_path = beam_path.reverse if track_idx == 0

        dir_seg = track_idx == 1 ? seg_fwd : seg_rev

        gw = model.entities.add_group
        gw.name = dir_seg
        gw.layer = JPods::LayerManager.get_tag(model, :guideway_beam) if defined?(JPods::LayerManager)
        gw.set_attribute('JPods', 'connection_id', dir_seg)
        gw.set_attribute('JPods', 'seg_guideway', true)
        gw.set_attribute('JPods', 'track_index', track_idx)

        from_node = track_idx == 1 ? from_sid : to_sid
        to_node   = track_idx == 1 ? to_sid : from_sid
        gw.set_attribute('JPods', 'display_name', "GW_#{from_node}-#{to_node}")

        from_key = JPods::ConnectionPoint.new(structure_id: (track_idx == 1 ? from_sid : to_sid),
                                               index: (track_idx == 1 ? from_stub : to_stub)).to_key
        to_key   = JPods::ConnectionPoint.new(structure_id: (track_idx == 1 ? to_sid : from_sid),
                                               index: (track_idx == 1 ? to_stub : from_stub)).to_key
        gw.set_attribute('JPods', 'route_from_key', from_key)
        gw.set_attribute('JPods', 'route_to_key', to_key)

        # Build beam geometry (FollowMe extrusion + stores beam_path attribute)
        JPodGuideway.build(gw, beam_path, model)
      end

      # Columns + solar on centerline
      col_group = model.entities.add_group
      col_group.name = "Support_#{seg_fwd}"
      col_group.layer = JPods::LayerManager.get_tag(model, :support) if defined?(JPods::LayerManager)
      col_group.set_attribute('JPods', 'connection_id', seg_fwd)
      JPodGuideway.place_solar_columns(center_pts, col_group, model)

      puts "[Build v2] #{seg_id}: ✓ beams + columns + solar"
      { ok: true }
    rescue => ex
      puts "[Build v2] #{conn['id']}: error — #{ex.message}"
      { ok: false, fault: "#{conn['id']}: #{ex.message}" }
    end

  end
end

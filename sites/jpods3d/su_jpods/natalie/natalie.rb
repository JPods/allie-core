# ── Natalie v2 — Router ───────────────────────────────────────────────────────
#
# Natalie plans routes. She reads the routing graph from network.json,
# finds paths via BFS, and builds maneuver sequences for Nora to follow.
#
# Responsibilities:
#   - Route planning (BFS on routing graph)
#   - Maneuver building (ordered track pts for Nora)
#   - Random dispatch (assign destinations to idle pods)
#   - Graceful stop (complete trips, rebalance parking)
#
# Natalie does NOT move pods. She plans. Nora executes.
#
# ── su-real ──────────────────────────────────────────────────────────────────
# Physical Natalie (podPresenter/Mac) dispatches via MQTT:
#   - Publishes ACTION with myPath = [lineId, lineId, ...] (integer array)
#   - Each lineId maps to a mapSM.json line with length, servo, speedMin/Max
#   - Physical path = sequence of line IDs; SU path = sequence of track names
#   - Physical lines have segments with radius + direction cosines for curves;
#     SU tracks have pts_mm polyline (Axiom 17: cubic bezier in SU, true analog
#     curve following on physical)
#
# SU simplifications vs physical:
#   - SU BFS is unweighted; physical Natalie should weight by line length,
#     ezone congestion, and current pod positions for better path selection
#   - SU build_maneuvers reverses tracks by comparing endpoints; physical
#     lines have fixed direction (servo left/right encodes which branch)
#   - SU has no speed profile per track; physical lines have speedMin/speedMax
#     and curveRadius → maxLateralG constraints
#   - SU doesn't model servo actuation time; physical servo must be set
#     BEFORE the pod reaches the diverge point (~300mm lookahead)
#
# What SU should produce for physical: route plan with per-maneuver
# estimated speed profile (entry speed, min speed at curve apex, exit speed)
# so physical Natalie can validate feasibility before dispatching.
#
# 4WD floor robots use waypoint graph instead of line/segment — Natalie
# dispatches heading + distance pairs. Same BFS, different output format.
#
# SU model is the naming authority. Physical Natalie dispatches paths
# using SU-generated track IDs (seg_s001_1_s003_1, s002.gw_platform,
# etc.) — not hand-numbered line integers. This means SU simulation
# and physical telemetry use identical vocabulary; Allie can compare
# trajectories without a mapping table.
#
# Physical seg_: a single SU seg_ becomes many physical sub-segments
# (straights, curves, grades). Natalie dispatches the parent seg_ ID;
# physical Nora walks sub-segments (.0, .1, .2, ...) internally.
# Natalie doesn't need to know the sub-segments — she routes at the
# track level. Nora handles the decomposition.
# ─────────────────────────────────────────────────────────────────────────────

require 'json'

module JPods
  module NatalieV2

    # ── Route: a planned path from origin to destination ──────────────────

    Route = Struct.new(
      :origin_sid, :dest_sid, :track_ids, :maneuvers,
      :total_length_mm, :estimated_s, :planned_at,
      keyword_init: true
    )

    # ── Maneuver: one track segment for Nora to follow ────────────────────

    Maneuver = Struct.new(
      :id, :pts, :len, :reversed,
      keyword_init: true
    )

    # ── Dispatch record — tracks one outbound pod ──────────────────────
    Dispatch = Struct.new(
      :nora_id, :dest_sid, :departed_at, :route,
      :clearance_m, :speed_ms,
      keyword_init: true
    )

    # ── Station dispatch registry — per-station outbound flow ────────
    # Natalie manages departure timing. Sally says "pod ready."
    # Natalie says "cleared to depart" or "hold — previous pod in clearance zone."
    #
    # This is the mirror of Sally's slot array but for outbound flow.
    # Each station tracks recent departures and enforces minimum clearance
    # before the next pod can leave.
    #
    # Extends to zipper merge: the same clearance logic applies at merge
    # junctions — Natalie schedules arrivals so pods interleave cleanly.
    @@dispatch_registry = {}  # sid → Array<Dispatch>
    @@clearance_m = 6.0       # metres — pod must be this far from station exit before next departs

    # ── Routing graph ─────────────────────────────────────────────────────

    @@routing_graph = {}  # "sid.track" → ["sid.track", ...]
    @@lookup = {}         # "sid.track" or "seg_..." → { pts:, len: }
    @@stations = {}       # sid → { template:, tracks: {} }
    @@circles = {}        # sid → { circle:, entries:, exits:, entry_arc:, exit_arc: }

    # ── Fleet registry — every pod Natalie knows about ────────────────────
    # Natalie reads entity positions from the model. She knows where every
    # pod IS — not just where Sally thinks it is. This is the cross-check
    # that catches ghosts, desyncs, and stranded pods.
    #
    # Physical equivalent: Natalie reads TELEMETRY from every Nora.
    # SU equivalent: Natalie reads entity.bounds.center from every pod.

    PodStatus = Struct.new(
      :nora_id, :entity, :position_mm, :station_id, :state,
      :last_updated, :destination_sid,
      keyword_init: true
    )

    @@fleet = {}  # nora_id → PodStatus

    def self.fleet; @@fleet; end

    # Scan model for all pod entities and build/update fleet registry
    def self.scan_fleet(model)
      seen = {}
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::ComponentInstance) && !e.deleted?
        nora_id = e.get_attribute('JPods', 'vehicle_id', '').to_s
        next if nora_id.empty?

        pos = e.bounds.center
        pos_mm = [(pos.x * 25.4).round(1), (pos.y * 25.4).round(1), (pos.z * 25.4).round(1)]
        sid = e.get_attribute('JPods', 'parked_station_id', '').to_s.strip.downcase
        dest = e.get_attribute('JPods', 'destination_station_id', '').to_s.strip.downcase

        existing = @@fleet[nora_id]
        if existing
          existing.entity = e
          existing.position_mm = pos_mm
          existing.station_id = sid unless sid.empty?
          existing.destination_sid = dest unless dest.empty?
          existing.last_updated = Time.now.to_f
        else
          @@fleet[nora_id] = PodStatus.new(
            nora_id: nora_id, entity: e, position_mm: pos_mm,
            station_id: sid.empty? ? nil : sid, state: :unknown,
            last_updated: Time.now.to_f,
            destination_sid: dest.empty? ? nil : dest
          )
        end
        seen[nora_id] = true
      end

      # Remove pods whose entities are gone
      @@fleet.reject! { |nid, _| !seen[nid] }

      puts "[Natalie] fleet scan: #{@@fleet.size} pod(s)"
      @@fleet.size
    end

    # Update one pod's state (called by animation on dispatch/arrival)
    def self.update_pod(nora_id, state:, station_id: nil, destination_sid: nil)
      rec = @@fleet[nora_id]
      return unless rec
      rec.state = state
      rec.station_id = station_id if station_id
      rec.destination_sid = destination_sid if destination_sid
      rec.last_updated = Time.now.to_f
    end

    # Where is this pod right now? Returns position_mm or nil.
    def self.pod_position(nora_id)
      rec = @@fleet[nora_id]
      return nil unless rec && rec.entity && !rec.entity.deleted?
      pos = rec.entity.bounds.center
      [(pos.x * 25.4).round(1), (pos.y * 25.4).round(1), (pos.z * 25.4).round(1)]
    end

    # Cross-check: find pods that Sally thinks are at one station
    # but whose entities are physically closer to a different station.
    def self.fleet_desyncs
      desyncs = []
      @@fleet.each do |nora_id, rec|
        next unless rec.entity && !rec.entity.deleted?
        next unless rec.station_id && !rec.station_id.empty?
        # Check if Sally agrees
        if defined?(SallyV2)
          sally_st = SallyV2.station(rec.station_id)
          next unless sally_st
          sally_rec = sally_st.pod(nora_id)
          if sally_rec.nil?
            # Natalie sees pod at this station but Sally doesn't know about it
            desyncs << { nora_id: nora_id, type: :orphan,
                         natalie_station: rec.station_id,
                         position_mm: pod_position(nora_id) }
          end
        end
      end
      desyncs
    end

    def self.routing_graph; @@routing_graph; end
    def self.lookup; @@lookup; end
    def self.dispatch_registry; @@dispatch_registry; end

    # ── Dispatch control ─────────────────────────────────────────────────

    # Can this station dispatch now?
    # Natalie enforces minimum time between departures per station.
    DISPATCH_INTERVAL_S = 5.0

    def self.cleared_to_depart?(sid)
      dispatches = @@dispatch_registry[sid.to_s.downcase]
      return true unless dispatches && dispatches.any?
      elapsed = Time.now.to_f - (dispatches.last.departed_at || 0)
      elapsed >= DISPATCH_INTERVAL_S
    end

    # Record a departure
    def self.record_departure(sid, nora_id, dest_sid:, route: nil, speed_ms: 12.0)
      sid_key = sid.to_s.downcase
      @@dispatch_registry[sid_key] ||= []
      @@dispatch_registry[sid_key] << Dispatch.new(
        nora_id: nora_id, dest_sid: dest_sid,
        departed_at: Time.now.to_f, route: route,
        clearance_m: @@clearance_m, speed_ms: speed_ms
      )
      # Keep only last 5 dispatches per station (memory limit)
      @@dispatch_registry[sid_key] = @@dispatch_registry[sid_key].last(5)
    end

    # Clear dispatch registry (on animation stop/restart)
    def self.clear_dispatches
      @@dispatch_registry = {}
    end

    # Load routing graph from network.json
    def self.load_network(model)
      @@dispatch_registry = {}
      @@routing_graph = {}
      @@lookup = {}
      @@stations = {}

      model_dir  = File.dirname(model.path)
      model_base = File.basename(model.path, '.skp')
      nj_path    = File.join(model_dir, "#{model_base}.network.json")

      unless File.exist?(nj_path)
        puts "[Natalie v2] network.json not found — run Build"
        return false
      end

      nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))

      # Routing graph
      @@routing_graph = nj.dig('natalie', 'routing_graph') || {}

      # Station data
      Array(nj.dig('designer', 'stations')).each do |st|
        sid = st['id'].to_s.downcase
        @@stations[sid] = {
          template: st['template'].to_s,
          tracks: st['tracks'] || {}
        }
      end

      # Build geometry lookup from network.json
      in_per_mm = 1.0 / 25.4

      # Intra-station tracks
      @@stations.each do |sid, st_data|
        st_data[:tracks].each do |role, t|
          pts_raw = Array(t['pts'])
          next unless pts_raw.size >= 2
          pts = pts_raw.map { |p|
            Geom::Point3d.new(p['x'].to_f * in_per_mm,
                              p['y'].to_f * in_per_mm,
                              p['z'].to_f * in_per_mm)
          }
          len = pts.each_cons(2).sum { |a, b| a.distance(b).to_f }
          key = "#{sid}.#{role}"
          dir = t['direction']  # authoritative direction from Noelle's Build
          @@lookup[key] = { pts: pts, len: [len, 1e-6].max, direction: dir }
        end
      end

      # Inter-station connections
      hanger_z = (defined?(JPods::Constants) ? JPods::Constants::BEAM_DEPTH : 500.0 / 25.4) rescue 500.0 / 25.4
      Array(nj.dig('designer', 'connections')).each do |conn|
        cid = conn['id'].to_s
        pts_raw = Array(conn['pts'])
        next unless pts_raw.size >= 2
        pts = pts_raw.map { |p|
          Geom::Point3d.new(p['x'].to_f * in_per_mm,
                            p['y'].to_f * in_per_mm,
                            (p['z'].to_f * in_per_mm) - hanger_z)
        }
        len = pts.each_cons(2).sum { |a, b| a.distance(b).to_f }
        @@lookup[cid] = { pts: pts, len: [len, 1e-6].max }
      end

      # Load circle data for traffic circle stations
      @@circles = {}
      # Circle data comes from lines.json natalie.pass_chains (written by Compute)
      # or from network.json natalie section
      nj_nat = nj.dig('natalie') || {}
      # Check each station for pass_chains with circle/entries/exits structure
      # (These are stored per-template in lines.json, merged into network.json by Noelle)
      # For now, also load from lines.json directly per template
      plugin_dir = File.dirname(File.dirname(__FILE__)) rescue nil
      if plugin_dir
        @@stations.each do |sid, st_data|
          template = st_data[:template]
          next if template.empty?
          lj_path = File.join(plugin_dir, 'templates', 'track_formations', template, 'lines.json')
          next unless File.exist?(lj_path)
          lj = JSON.parse(File.read(lj_path, encoding: 'utf-8'))
          pc = lj.dig('natalie', 'pass_chains')
          next unless pc && pc['circle'].is_a?(Array) && pc['entries'].is_a?(Hash)
          @@circles[sid] = {
            circle:    pc['circle'],
            entries:   pc['entries'],
            exits:     pc['exits'] || {},
            entry_arc: pc['entry_arc'] || {},
            exit_arc:  pc['exit_arc'] || {},
          }
          puts "[Natalie v2] circle #{sid}: #{pc['circle'].size} arcs, #{pc['entries'].size} entries"
        end
      end

      puts "[Natalie v2] loaded: #{@@routing_graph.size} graph entries, " \
           "#{@@lookup.size} geometry entries, #{@@stations.size} stations, " \
           "#{@@circles.size} circle(s)"
      true
    rescue => ex
      puts "[Natalie v2] load_network error: #{ex.message}"
      false
    end

    # ── BFS route planning ─────────────────────────────────────────────────

    def self.plan_route(origin_sid, dest_sid, check_capacity: false)
      origin = origin_sid.to_s.downcase
      dest   = dest_sid.to_s.downcase
      return nil if origin == dest || origin.empty? || dest.empty?

      # Check Sally capacity at destination if requested
      if check_capacity && defined?(JPods::SallyV2)
        st = JPods::SallyV2.station(dest)
        if st && st.full?
          puts "[Natalie v2] #{origin}→#{dest} blocked — destination full (#{st.occupancy}/#{st.capacity})"
          return nil
        end
      end

      # Find departure track (gw_platform at origin)
      start_key = "#{origin}.gw_platform"
      return nil unless @@routing_graph.key?(start_key)

      # BFS to find any track at destination station
      visited = {}
      queue = [[start_key, [start_key]]]

      while !queue.empty?
        current, path = queue.shift
        next if visited[current]
        visited[current] = true

        # Check if we've reached the destination
        track_sid = current.split('.').first
        track_name = current.split('.').last.to_s
        if track_sid == dest && track_name == 'gw_platform'
          # Found destination platform
          puts "[Natalie] route #{origin}→#{dest}: #{path.size} tracks: #{path.join(' → ')}"
          route = Route.new(
            origin_sid: origin,
            dest_sid: dest,
            track_ids: path,
            maneuvers: nil,
            total_length_mm: nil,
            estimated_s: nil,
            planned_at: Time.now.utc
          )
          return route
        end

        # Expand successors
        (@@routing_graph[current] || []).each do |succ|
          queue << [succ, path + [succ]] unless visited[succ]
        end
      end

      puts "[Natalie v2] no route #{origin} → #{dest}"
      nil
    end

    # ── Build maneuvers from route ─────────────────────────────────────────

    def self.build_maneuvers(route)
      return [] unless route && route.track_ids

      maneuvers = []
      prev_end_pt = nil

      route.track_ids.each do |track_id|
        entry = @@lookup[track_id] || @@lookup[track_id.downcase]
        unless entry
          puts "[Natalie v2] gap: #{track_id} not in lookup"
          next
        end

        pts = entry[:pts]
        reversed = false

        # Direction is authoritative — Noelle's Build computes it from the
        # centerline math. Never guess direction by proximity to edges.
        track_name = track_id.split('.').last.to_s
        is_seg = track_id.start_with?('seg_')
        is_ring = track_name.match?(/\Agw_c_/)

        # Use Noelle's direction vector if available (post-2026-06-24 Build).
        # The direction vector defines the flow: pts[0] → pts[1] → ... → pts[N].
        # If pts are stored backwards relative to the direction, reverse them.
        if entry[:direction] && pts.size >= 2
          dir = entry[:direction]
          # Compare stored direction with actual first-to-second point direction
          p0 = pts[0]; p1 = pts[1]
          dx = p1.x - p0.x; dy = p1.y - p0.y
          mag = Math.sqrt(dx*dx + dy*dy)
          if mag > 0.001
            dot = (dx/mag) * dir['x'].to_f + (dy/mag) * dir['y'].to_f
            if dot < -0.5
              # Points are stored backwards relative to Noelle's direction
              pts = pts.reverse
              reversed = true
              puts "[Natalie] #{track_id}: reversed to match Noelle direction"
            end
          end
        elsif prev_end_pt && pts.size >= 2 && !is_seg && !is_ring
          # Fallback for pre-direction network.json: proximity-based orientation.
          # Guard against 500mm edge hallucination (beam width, not centerline gap).
          dist_fwd = prev_end_pt.distance(pts.first).to_f
          dist_rev = prev_end_pt.distance(pts.last).to_f
          rev_mm = dist_rev * 25.4
          if dist_rev < dist_fwd && !(rev_mm > 350 && rev_mm < 650)
            pts = pts.reverse
            reversed = true
            puts "[Natalie] #{track_id}: reversed (fwd_gap=#{(dist_fwd*25.4).round(0)}mm, rev_gap=#{rev_mm.round(0)}mm)"
          elsif rev_mm > 350 && rev_mm < 650
            puts "[Natalie] ⚠ #{track_id}: 500mm edge hallucination detected (#{rev_mm.round(0)}mm) — NOT reversing"
          end
        end

        # CCW enforcement for ring arcs
        if is_ring && prev_end_pt && pts.size >= 2
          gap = prev_end_pt.distance(pts.first).to_f * 25.4
          if gap > 500
            puts "[Natalie v2] ⚠ CW FAULT: #{track_id} gap=#{gap.round(0)}mm — " \
                 "ring arc start is far from prev endpoint. Route may be CW."
          end
        end

        len = pts.each_cons(2).sum { |a, b| a.distance(b).to_f }
        prev_end_pt = pts.last

        maneuvers << Maneuver.new(
          id: track_id, pts: pts, len: [len, 1e-6].max, reversed: reversed
        )
      end

      # Calculate total length
      total_mm = maneuvers.sum { |m| m.len * 25.4 }
      route.maneuvers = maneuvers
      route.total_length_mm = total_mm.round(1)
      route.estimated_s = (total_mm / 8300.0).round(1)  # 8.3 m/s default

      maneuvers
    end

    # ── Circle traversal — build track list for from_cp → to_cp ──────────
    # The ring is one thing. Entry + circle slice (CCW) + exit.
    # Returns array of fully-qualified track IDs (sid.track), or nil.
    def self.build_circle_track_ids(sid, from_cp, to_cp)
      cd = @@circles[sid]
      return nil unless cd

      from_key = "cp#{from_cp}"
      to_key   = "cp#{to_cp}"

      entry  = cd[:entries][from_key]
      exit_s = cd[:exits][to_key]
      ea     = cd[:entry_arc][from_key]   # ring arc where entry connects
      xa     = cd[:exit_arc][to_key]      # ring arc where exit branches off

      return nil unless entry && exit_s && ea && xa

      circle = cd[:circle]
      ea_idx = circle.index(ea)
      xa_idx = circle.index(xa)
      return nil unless ea_idx && xa_idx

      # Slice the circle CCW from entry_arc to exit_arc (inclusive).
      # If from == to (self-loop), traverse the FULL ring — Natalie uses
      # this to loop a pod when she needs time to clear a station.
      ring_slice = if ea_idx == xa_idx && from_cp == to_cp
        # Full loop: start at entry_arc, go all the way around
        circle[ea_idx..-1] + circle[0..ea_idx]
      elsif ea_idx <= xa_idx
        circle[ea_idx..xa_idx]
      else
        # Wrap around: ea_idx to end + beginning to xa_idx
        circle[ea_idx..-1] + circle[0..xa_idx]
      end

      # Build fully-qualified track IDs
      track_ids = entry.map { |t| "#{sid}.#{t}" } +
                  ring_slice.map { |t| "#{sid}.#{t}" } +
                  exit_s.map { |t| "#{sid}.#{t}" }

      track_ids
    end

    def self.circles; @@circles; end

    # ── Station queries ────────────────────────────────────────────────────

    def self.station_ids
      @@stations.keys
    end

    def self.platform_stations
      # Only stations with gw_platform (not traffic circles)
      @@stations.select { |_, st| st[:tracks].key?('gw_platform') }.keys
    end

    # ── Reset ──────────────────────────────────────────────────────────────

    # Circle stations (traffic circles without gw_platform)
    def self.circle_stations
      @@circles.keys
    end

    def self.reset
      @@routing_graph = {}
      @@lookup = {}
      @@stations = {}
      @@circles = {}
      @@fleet = {}
    end

  end
end

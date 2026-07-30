# ── Sally v2 — Station Processor ──────────────────────────────────────────────
#
# Sally owns every station. Two arrays per station:
#   ps[]   — parking slots (infrastructure)
#   pods[] — pod records (every pod Sally knows about)
#
# See: sally/README.md
#
# ── su-real ──────────────────────────────────────────────────────────────────
# Physical Sally runs on station hardware (Pi per station, future: dedicated
# chip). Station detection uses HuskyLens AprilTag recognition — each station
# has a unique tag ID. Pod reads tag → publishes MQTT → Sally registers arrival.
#
# SU simplifications vs physical:
#   - SU detects arrival by t=1.0 on final maneuver; physical detects by
#     AprilTag read + encoder position crossing station entry threshold
#   - SU slot assignment is instant; physical slot = physical position on
#     platform track, pod must drive to slot position using encoder feedback
#   - SU has no conveyor advance animation; physical Sally advances pods
#     toward exit by commanding motor to drive slot_spacing_mm forward
#   - SU pod_departs is instant state change; physical departure requires
#     Nora to drive off platform onto exit track — Sally monitors encoder
#     to confirm pod has cleared the platform before marking slot vacated
#   - SU has no door cycle; physical FullScale has Willi agent managing
#     door open/close with passenger load/unload timing
#
# Physical Sally experience data (arrival_count, avg_dwell_s per slot) feeds
# Natalie's dispatch decisions — high-turnover slots indicate routing
# imbalance. SU Sally collects the same counters; these should be written
# to the animation summary so physical Natalie can pre-seed expectations.
#
# Station capacity in physical = number of pods that physically fit on the
# platform track. SU computes this from track length / 2500mm. Physical
# calibrates from actual measurements + clearance margin for ToF hysteresis.
# ─────────────────────────────────────────────────────────────────────────────

require_relative 'sally_station'

module JPods
  module SallyV2

    @@stations = {}  # sid → Station

    # ── Public API ─────────────────────────────────────────────────────────

    def self.station(sid)
      @@stations[sid.to_s.strip.downcase]
    end

    def self.stations
      @@stations
    end

    def self.station_ids
      @@stations.keys
    end

    # ── Init from model ──────────────────────────────────────────────────

    def self.init(model, lookup_cache)
      @@stations = {}
      slot_spacing_mm = 2500.0
      slot_spacing_in = slot_spacing_mm / 25.4

      # Find all stations with gw_platform — parking is ONLY on gw_platform.
      # gw_platform_parking is the approach track TO the platform, not a parking surface.
      lookup_cache.each do |key, entry|
        key_s = key.to_s
        m = key_s.match(/\A([^.]+)\.(gw_platform)\z/)
        next unless m
        sid = m[1].downcase
        track = m[2]
        next if @@stations[sid]

        pts = entry[:pts]
        next unless pts.is_a?(Array) && pts.size >= 2
        total_len = pts.each_cons(2).sum { |a, b| a.distance(b).to_f }
        next if total_len < 1e-6
        capacity = [(total_len / slot_spacing_in).floor, 1].max

        st = Station.new(id: sid, capacity: capacity, parking_track: track)

        # Compute slot positions along the track
        (1..capacity).each do |n|
          t = (n - 0.5) / capacity.to_f
          idx = [(t * (pts.size - 1)).floor, pts.size - 2].max
          a, b = pts[idx], pts[idx + 1]
          frac = t * (pts.size - 1) - idx
          pos = [
            ((a.x + (b.x - a.x) * frac) * 25.4).round(1),
            ((a.y + (b.y - a.y) * frac) * 25.4).round(1),
            ((a.z + (b.z - a.z) * frac) * 25.4).round(1)
          ]
          dist = (t * total_len * 25.4).round(1)
          st.set_slot_position(n, pos, dist)
        end

        @@stations[sid] = st
      end

      # Pre-populate from existing pods in model
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::ComponentInstance) && !e.deleted?
        nora_id = e.get_attribute('JPods', 'vehicle_id', '').to_s
        next if nora_id.empty?
        sid  = e.get_attribute('JPods', 'parked_station_id', '').to_s.strip.downcase
        slot = e.get_attribute('JPods', 'parking_slot', 0).to_i
        next if sid.empty?
        st = @@stations[sid]
        next unless st

        if slot > 0 && slot <= st.capacity
          st.register_pod(nora_id, entity: e, slot_num: slot, state: :parked)
        else
          # Slot unknown — compute from physical position
          best_slot = _find_nearest_slot(st, e)
          if best_slot
            st.register_pod(nora_id, entity: e, slot_num: best_slot, state: :parked)
            e.set_attribute('JPods', 'parking_slot', best_slot) rescue nil
            puts "[Sally #{sid}] #{nora_id}: slot computed from position → ps#{best_slot}"
          else
            puts "[Sally #{sid}] #{nora_id}: no slot available — not registered"
          end
        end
      end

      total_pods = @@stations.values.sum { |st| st.pods.size }
      puts "[Sally v2] #{@@stations.size} station(s) initialised, #{total_pods} pod(s) registered"
      @@stations.each { |sid, st| puts "  #{st.summary}" }
    end

    # ── Query — Sally's two arrays ───────────────────────────────────────

    def self.query(sid = nil)
      targets = sid ? [@@stations[sid.to_s.strip.downcase]].compact : @@stations.values
      if targets.empty?
        puts "[Sally v2] no stations#{sid ? " matching '#{sid}'" : ''}"
        return
      end
      targets.each do |st|
        puts ""
        puts st.summary
        puts "  Slots: #{st.slot_summary}"
        st.pods.each do |nid, rec|
          puts "  Pod #{nid}: state=#{rec.state} slot=ps#{rec.slot} " \
               "loops=#{rec.loop_count} trips=#{rec.trip_count} faults=#{rec.stop_wait_count}"
        end
      end
      puts ""
    end

    # ── Delegation ─────────────────────────────────────────────────────────

    def self.pod_arrives(sid, nora_id, entity:)
      st = @@stations[sid.to_s.strip.downcase]
      return unless st
      st.pod_arrives(nora_id, entity: entity)
    end

    def self.pod_departs(sid, nora_id, destination: nil)
      st = @@stations[sid.to_s.strip.downcase]
      return unless st
      st.pod_departs(nora_id, destination: destination)
    end

    def self.pod_starts_loop(sid, nora_id)
      st = @@stations[sid.to_s.strip.downcase]
      return unless st
      st.pod_starts_loop(nora_id)
    end

    def self.pod_returns_from_loop(sid, nora_id)
      st = @@stations[sid.to_s.strip.downcase]
      return unless st
      st.pod_returns_from_loop(nora_id)
    end

    def self.advance_pod(sid, nora_id, from_slot, to_slot)
      st = @@stations[sid.to_s.strip.downcase]
      return unless st
      st.advance_pod(nora_id, from_slot, to_slot)
    end

    def self.capacity_for(sid)
      st = @@stations[sid.to_s.strip.downcase]
      st ? st.capacity : 0
    end

    def self.slot_for(sid, nora_id)
      st = @@stations[sid.to_s.strip.downcase]
      return 0 unless st
      s = st.slot_for(nora_id)
      s ? s.number : 0
    end

    # ── Reset ──────────────────────────────────────────────────────────────

    def self.reset
      # Print experience summary before clearing
      @@stations.each do |sid, st|
        high_turnover = st.ps.select { |s| (s.arrival_count || 0) > 5 }
        if high_turnover.any?
          puts "[Sally #{sid}] experience: high-turnover slots: #{high_turnover.map { |s| "ps#{s.number}(#{s.arrival_count})" }.join(', ')}"
        end
      end
      @@stations.each_value(&:reset)
      @@stations = {}
    end

    private

    # Find the nearest empty slot to an entity's physical position
    def self._find_nearest_slot(station, entity)
      pos = entity.bounds.center
      pos_mm = [pos.x * 25.4, pos.y * 25.4, pos.z * 25.4]

      best_slot = nil
      best_dist = Float::INFINITY

      station.ps.each do |s|
        next unless s.empty? && s.position_mm
        dx = pos_mm[0] - s.position_mm[0]
        dy = pos_mm[1] - s.position_mm[1]
        d = Math.sqrt(dx*dx + dy*dy)
        if d < best_dist
          best_dist = d
          best_slot = s.number
        end
      end

      best_slot
    end

  end
end

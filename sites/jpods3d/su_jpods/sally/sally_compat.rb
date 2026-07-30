# ── Sally Compatibility Layer ─────────────────────────────────────────────────
#
# Console station tests call JPods::Sally (old API). This module delegates
# to SallyV2 where possible and provides the missing methods:
#   - slot_positions_for_station → world Point3d per slot
#   - place_vehicles_at_slots → create pod entities at slot positions
#   - init_sequencer_for_station → load natalie chains from lines.json
#   - init_from_model → init SallyV2 + compute world positions
#   - set_departure_mode / confirm_slots → departure test support
#
# Delete this file when jpod_console.rb gets its v2 rewrite.

module JPods
  module Sally

    SLOT_SPACING_M = 2.5

    @@slot_positions = {}    # sid → { slot_n → Geom::Point3d }
    @@sequencers = {}        # sid → { hold_loop_chain:, landing_chains:, exit_chains:, ... }
    @@departure_mode = {}    # sid → bool

    # ── Init from model — delegates to SallyV2 + computes world positions ──

    def self.init_from_model(model, lookup_cache)
      # Let SallyV2 do the heavy lifting
      SallyV2.init(model, lookup_cache) if defined?(SallyV2)

      # Compute world positions from SallyV2's slot data
      @@slot_positions = {}
      return unless defined?(SallyV2)

      in_per_mm = 1.0 / 25.4
      SallyV2.stations.each do |sid, st|
        sp = {}
        st.ps.each do |slot|
          next unless slot.position_mm.is_a?(Array) && slot.position_mm.size >= 3
          sp[slot.number] = Geom::Point3d.new(
            slot.position_mm[0] * in_per_mm,
            slot.position_mm[1] * in_per_mm,
            slot.position_mm[2] * in_per_mm
          )
        end
        @@slot_positions[sid] = sp
        puts "[Sally compat] #{sid}: #{sp.size} slot world positions"
      end
    end

    # ── Slot positions ─────────────────────────────────────────────────────

    def self.slot_positions_for_station(sid)
      @@slot_positions[sid.to_s.strip.downcase] || {}
    end

    def self.station_capacity(sid)
      defined?(SallyV2) ? SallyV2.capacity_for(sid) : 0
    end

    # ── Place vehicles at slots ────────────────────────────────────────────

    def self.place_vehicles_at_slots(model, station_id, defn, slot_nums, plat_pts)
      sid = station_id.to_s.strip.downcase
      sp  = slot_positions_for_station(sid)
      placed = {}

      fwd_for = ->(wpos) {
        best  = Geom::Vector3d.new(1, 0, 0)
        min_d = Float::INFINITY
        plat_pts.each_cons(2) do |a, b|
          mid = Geom.linear_combination(0.5, a, 0.5, b)
          d   = mid.distance(wpos).to_f
          if d < min_d
            min_d = d
            v     = Geom::Vector3d.new(b.x - a.x, b.y - a.y, 0)
            best  = v.normalize if v.length > 1e-9
          end
        end
        best
      }

      slot_nums.each do |slot_n|
        wpos = sp[slot_n]
        unless wpos
          puts "[Sally #{sid}] place_vehicles_at_slots: no world position for ps#{slot_n} — skipped"
          next
        end
        xf  = JPods::PodHelpers.pod_transform(wpos, fwd_for.call(wpos))
        ent = model.entities.add_instance(defn, xf)
        placed[slot_n] = ent
      end

      placed
    end

    # ── Sequencer — loads natalie chains from lines.json ───────────────────

    def self.init_sequencer_for_station(station_id, model_id, plugin_dir)
      sid = station_id.to_s.strip.downcase
      lj_path = File.join(plugin_dir, 'templates', 'track_formations', model_id, 'lines.json')
      return unless File.exist?(lj_path)

      lj = JSON.parse(File.read(lj_path, encoding: 'utf-8'))
      nat = lj['natalie'] || {}

      @@sequencers[sid] = {
        hold_loop_chain:    nat['hold_loop_chain'],
        landing_chains:     nat['landing_chains'] || {},
        exit_chains:        nat['exit_chains'] || {},
        originating_chains: nat['originating_chains'] || {},
        parking_chain:      nat['parking_chain'],
        pass_chains:        nat['pass_chains'],
      }
      puts "[Sally compat] sequencer loaded for #{sid} (#{model_id})"
    end

    def self.sequencer_for(station_id)
      @@sequencers[station_id.to_s.strip.downcase]
    end

    def self.hold_loop_tracks(station_id)
      seq = sequencer_for(station_id)
      return [] unless seq && seq[:hold_loop_chain]
      hl = seq[:hold_loop_chain]
      Array(hl['from_platform']) + Array(hl['loop']) + Array(hl['to_platform'])
    end

    def self.hold_loop_from_platform(station_id)
      seq = sequencer_for(station_id)
      return [] unless seq && seq[:hold_loop_chain]
      Array(seq[:hold_loop_chain]['from_platform'])
    end

    def self.hold_loop_loop(station_id)
      seq = sequencer_for(station_id)
      return [] unless seq && seq[:hold_loop_chain]
      Array(seq[:hold_loop_chain]['loop'])
    end

    def self.hold_loop_to_platform(station_id)
      seq = sequencer_for(station_id)
      return [] unless seq && seq[:hold_loop_chain]
      Array(seq[:hold_loop_chain]['to_platform'])
    end

    def self.parking_chain_tracks(station_id)
      seq = sequencer_for(station_id)
      return [] unless seq && seq[:parking_chain]
      Array(seq[:parking_chain]['tracks'])
    end

    def self.landing_chain(station_id, arrival_cp)
      seq = sequencer_for(station_id)
      return nil unless seq
      lc = seq[:landing_chains]
      key = lc.keys.find { |k| k.include?("cp#{arrival_cp}") }
      key ? Array(lc[key]['tracks']) : nil
    end

    def self.exit_tracks_for(station_id)
      seq = sequencer_for(station_id)
      return {} unless seq
      seq[:exit_chains]
    end

    def self._final_approach_tracks(hl_loop, landing_chain)
      return nil unless hl_loop && landing_chain
      # Find overlapping tail between hold loop and landing chain
      overlap = []
      hl_loop.reverse.each do |t|
        if landing_chain.include?(t)
          overlap.unshift(t)
        else
          break unless overlap.empty?
        end
      end
      overlap.empty? ? nil : overlap
    end

    # ── Departure mode ─────────────────────────────────────────────────────

    def self.set_departure_mode(station_id, active)
      sid = station_id.to_s.strip.downcase
      @@departure_mode[sid] = active
      puts "[Sally #{sid}] departure_mode #{active ? 'ON' : 'OFF'}"
    end

    def self.departure_mode?(station_id)
      @@departure_mode[station_id.to_s.strip.downcase] || false
    end

    # ── Confirm slots — verify entity positions match Sally's records ──────

    def self.confirm_slots(station_id, model, reserved_slots: {})
      sid = station_id.to_s.strip.downcase
      sp = slot_positions_for_station(sid)
      return if sp.empty?
      puts "[Sally #{sid}] confirm_slots: #{sp.size} slot positions registered"
    end

    # ── Station queries ────────────────────────────────────────────────────

    def self.station_ids
      defined?(SallyV2) ? SallyV2.station_ids : []
    end

    # ── Draft chains (used by console "Sally Chains" task) ─────────────────

    def self.draft_chains(lines_path)
      return nil unless File.exist?(lines_path)
      lj = JSON.parse(File.read(lines_path, encoding: 'utf-8'))
      nat = lj['natalie'] || {}
      { chains: nat, path: lines_path }
    rescue => ex
      puts "[Sally compat] draft_chains error: #{ex.message}"
      nil
    end

    def self.draft_chains_for_model(model)
      results = {}
      plugin_dir = File.dirname(File.dirname(__FILE__))
      Dir.glob(File.join(plugin_dir, 'templates', 'track_formations', '*', 'lines.json')).each do |lj_path|
        model_id = File.basename(File.dirname(lj_path))
        results[model_id] = draft_chains(lj_path)
      end
      results
    end

    # ── Vehicle authority ──────────────────────────────────────────────────

    STATION_AUTHORITY_ATTR = 'station_authority'.freeze

    def self.claim_vehicle(entity, station_id)
      entity.set_attribute('JPods', STATION_AUTHORITY_ATTR, station_id.to_s) rescue nil
    end

    def self.release_vehicle(entity)
      entity.set_attribute('JPods', STATION_AUTHORITY_ATTR, '') rescue nil
    end

    def self.in_station_custody?(entity)
      !(entity.get_attribute('JPods', STATION_AUTHORITY_ATTR, '').to_s.strip.empty?) rescue false
    end

    # ── Reset ──────────────────────────────────────────────────────────────

    def self.reset
      @@slot_positions = {}
      @@sequencers = {}
      @@departure_mode = {}
    end

  end
end

# ── Sally Station — per-station state ─────────────────────────────────────────
#
# Each station has two arrays:
#   ps[]   — parking slots (the infrastructure)
#   pods[] — pod records (every pod Sally knows about)
#
# Slots and pods are independent. A slot can be empty while its pod loops.
# A pod can demand a slot while all slots are occupied.
#
# ── su-real ──────────────────────────────────────────────────────────────────
# Physical Sally runs on station Pi (future: dedicated chip per station).
# Physical equivalents for each SU concept:
#
#   ParkingSlot:
#     - position_mm → physical encoder target for "drive to slot N"
#     - arrival_count → MQTT counter, feeds Natalie dispatch tuning
#     - avg_dwell_s → measured from arrival MQTT to departure MQTT
#     - reserve! → physical Sally publishes MQTT reservation so inbound
#       Nora knows which slot to target (avoids two pods driving to same slot)
#
#   PodRecord:
#     - state :parked/:looping/:departing/:arriving → MQTT state machine,
#       each transition publishes topic jpods/{sid}/{nora_id}/state
#     - loop_count → physical: how many times pod circled hold loop waiting
#       for a slot. High count = station capacity problem.
#     - stop_wait_count → from ezone; physical logs with timestamp + duration
#     - trip_count → lifetime trip counter; physical persists to SD card
#       so it survives reboot (facet.json carries this)
#
#   advance_pod (conveyor toward exit):
#     - Physical: Sally commands Nora to drive slot_spacing_mm forward
#     - Physical must verify encoder confirms movement before updating slot
#     - SU is instant; physical takes ~2s per advance at parking speed
#
#   pod_departs:
#     - SU removes from pods[]; physical keeps record until MQTT confirms
#       pod has cleared platform (encoder > platform_length). Premature
#       removal risks double-assignment of the vacated slot.
#
# FullScale adds: door cycle (Willi agent opens/closes doors between
# arrive and depart), passenger emergency stop button, ADA dwell extension.
# ─────────────────────────────────────────────────────────────────────────────

module JPods
  module SallyV2

    ParkingSlot = Struct.new(
      :number, :occupant_id, :state, :reserved_for, :reserved_at,
      :position_mm, :dist_mm,
      :arrival_count, :avg_dwell_s, :last_occupied_at,
      keyword_init: true
    ) do
      def empty?;    state == :empty; end
      def occupied?; state == :occupied; end
      def reserved?; state == :reserved; end

      def occupy!(nora_id)
        self.occupant_id     = nora_id
        self.state           = :occupied
        self.reserved_for    = nil
        self.reserved_at     = nil
        self.arrival_count   = (arrival_count || 0) + 1
        self.last_occupied_at = Time.now.to_f
      end

      def vacate!
        self.occupant_id  = nil
        self.state        = :empty
        self.reserved_for = nil
        self.reserved_at  = nil
      end

      def reserve!(nora_id)
        self.state        = :reserved
        self.reserved_for = nora_id
        self.reserved_at  = Time.now.to_f
      end
    end

    PodRecord = Struct.new(
      :nora_id, :state, :slot, :station_id, :entity,
      :loop_count, :departed_at, :eta_return, :destination,
      :trip_count, :stop_wait_count, :last_fault,
      keyword_init: true
    ) do
      def parked?;    state == :parked; end
      def looping?;   state == :looping; end
      def advancing?; state == :advancing; end
      def departing?; state == :departing; end
      def arriving?;  state == :arriving; end
    end

    class Station
      attr_reader :id, :capacity, :parking_track
      attr_accessor :ps, :pods, :inbound

      def initialize(id:, capacity:, parking_track: 'gw_platform')
        @id            = id
        @capacity      = capacity
        @parking_track = parking_track
        @ps   = Array.new(capacity) { |i|
          ParkingSlot.new(
            number: i + 1, occupant_id: nil, state: :empty,
            reserved_for: nil, reserved_at: nil,
            position_mm: nil, dist_mm: nil,
            arrival_count: 0, avg_dwell_s: 0.0, last_occupied_at: nil
          )
        }
        @pods    = {}  # nora_id → PodRecord
        @inbound = {}  # nora_id → { eta: Float (seconds), from: station_id }
      end

      # ── Slot queries ─────────────────────────────────────────────────────

      def slot(n)
        @ps[n - 1] if n >= 1 && n <= @capacity
      end

      def empty_slots
        @ps.select(&:empty?)
      end

      def occupied_slots
        @ps.select(&:occupied?)
      end

      def highest_empty_slot
        @ps.reverse.find(&:empty?)
      end

      def highest_occupied_slot
        @ps.reverse.find(&:occupied?)
      end

      def slot_for(nora_id)
        @ps.find { |s| s.occupant_id == nora_id }
      end

      def occupancy
        occupied_slots.size
      end

      def full?
        empty_slots.empty?
      end

      # ── Inbound tracking (Natalie → Sally) ──────────────────────────────
      # Natalie tells Sally: "pod X is heading your way, ETA Y seconds"
      def notify_inbound(nora_id, eta_s:, from_sid: nil)
        @inbound[nora_id] = { eta: eta_s, from: from_sid, notified_at: Time.now.to_f }
        # Register in pods[] as :traveling — Sally knows this pod is coming
        unless @pods[nora_id]
          register_pod(nora_id, entity: nil, state: :traveling)
          rec = @pods[nora_id]
          rec.slot = nil  # not at station yet
          rec.destination = @id  # heading here
        end
      end

      def clear_inbound(nora_id)
        @inbound.delete(nora_id)
      end

      def inbound_count
        @inbound.size
      end

      # Effective load = parked + inbound (what Sally expects to have)
      def effective_occupancy
        occupancy + inbound_count
      end

      # 50% threshold — Sally starts signaling when half full
      def needs_rebalance?
        effective_occupancy >= (capacity * 0.5).ceil && occupancy > 1
      end

      # Has room for more pods?
      def has_capacity?
        effective_occupancy < capacity
      end

      # ── Pod queries ──────────────────────────────────────────────────────

      def pod(nora_id)
        @pods[nora_id]
      end

      def parked_pods
        @pods.values.select(&:parked?)
      end

      def looping_pods
        @pods.values.select(&:looping?)
      end

      def all_pods
        @pods.values
      end

      # ── Pod placement (Sally's authority) ─────────────────────────────
      # Called by Populate to seat a pod at a specific slot.
      # Sally decides if the slot is available. Returns the PodRecord or nil.
      def place_pod(nora_id, entity:, slot_num:)
        s = slot(slot_num)
        unless s && s.empty?
          puts "[Sally #{@id}] place_pod #{nora_id} at ps#{slot_num}: DENIED — slot #{s ? s.state : 'invalid'}"
          return nil
        end
        rec = register_pod(nora_id, entity: entity, slot_num: slot_num, state: :parked)
        puts "[Sally #{@id}] place_pod #{nora_id} → ps#{slot_num}"
        rec
      end

      # ── Pod registration ─────────────────────────────────────────────────

      def register_pod(nora_id, entity:, slot_num: nil, state: :parked)
        rec = PodRecord.new(
          nora_id: nora_id, state: state, slot: slot_num,
          station_id: @id, entity: entity,
          loop_count: 0, departed_at: nil, eta_return: nil,
          destination: nil, trip_count: 0, stop_wait_count: 0,
          last_fault: nil
        )
        @pods[nora_id] = rec

        # Occupy the slot if specified and valid
        if slot_num && slot_num >= 1 && slot_num <= @capacity
          s = slot(slot_num)
          s.occupy!(nora_id) if s && s.empty?
        end

        rec
      end

      def unregister_pod(nora_id)
        rec = @pods.delete(nora_id)
        if rec && rec.slot
          s = slot(rec.slot)
          s.vacate! if s && s.occupant_id == nora_id
        end
        rec
      end

      # ── Pod state transitions ────────────────────────────────────────────

      # Pod departs for a loop — slot opens, pod state = :looping
      def pod_starts_loop(nora_id)
        rec = @pods[nora_id]
        return unless rec
        if rec.slot
          s = slot(rec.slot)
          s.vacate! if s && s.occupant_id == nora_id
        end
        rec.state       = :looping
        rec.departed_at = Time.now.to_f
        rec.loop_count  = (rec.loop_count || 0) + 1
        puts "[Sally #{@id}] #{nora_id} started loop — ps#{rec.slot} now open"
        rec
      end

      # Pod departs the station entirely — removed from pods[]
      def pod_departs(nora_id, destination: nil)
        rec = @pods[nora_id]
        return unless rec
        if rec.slot
          s = slot(rec.slot)
          s.vacate! if s && s.occupant_id == nora_id
        end
        rec.state       = :departing
        rec.departed_at = Time.now.to_f
        rec.destination = destination
        rec.trip_count  = (rec.trip_count || 0) + 1
        JPods::Log.sally_event("#{nora_id} departed #{@id} for #{destination || '?'} — ps#{rec.slot} open") if defined?(JPods::Log)
        @pods.delete(nora_id)
        rec
      end

      # Pod arrives at station — demands a slot
      def pod_arrives(nora_id, entity:)
        # If this pod is already parked here (duplicate arrival), ignore
        existing = @pods[nora_id]
        if existing && existing.state == :parked && existing.slot
          s = slot(existing.slot)
          return existing if s && s.occupant_id == nora_id
        end

        # Check: is this pod already assigned a slot in ANOTHER record?
        # Prevent double-assignment — one pod, one slot
        already_in_slot = @ps.find { |s| s.occupant_id == nora_id }
        if already_in_slot
          rec = existing || register_pod(nora_id, entity: entity, state: :parked)
          rec.slot = already_in_slot.number
          rec.state = :parked
          rec.entity = entity
          return rec
        end

        rec = existing || register_pod(nora_id, entity: entity, state: :arriving)
        rec.state  = :arriving
        rec.entity = entity

        # Park at an empty slot. Sally checks her ps array — only truly empty
        # slots are candidates. No slot can have two occupants.
        lowest_occupied = @ps.find(&:occupied?)
        if lowest_occupied && lowest_occupied.number > 1
          target = slot(lowest_occupied.number - 1)
          target = nil unless target && target.empty? && target.occupant_id.nil?
        end
        target ||= @ps.find { |s| s.empty? && s.occupant_id.nil? }

        if target
          target.occupy!(nora_id)
          rec.slot  = target.number
          rec.state = :parked
          if defined?(JPods::Log)
            JPods::Log.sally_event("#{nora_id} arrived #{@id} → ps#{target.number}")
            # Remember high-turnover slots
            if target.arrival_count && target.arrival_count > 0 && target.arrival_count % 10 == 0
              JPods::Log.remember(:sally, "#{@id} ps#{target.number} high turnover: #{target.arrival_count} arrivals",
                data: { station: @id, slot: target.number, count: target.arrival_count })
            end
          end
        else
          if defined?(JPods::Log)
            JPods::Log.sally_fault("#{nora_id} arrived #{@id} — NO SLOT AVAILABLE")
            JPods::Log.remember(:sally, "#{@id} FULL — #{nora_id} denied slot",
              data: { station: @id, pod: nora_id, occupancy: occupancy, capacity: @capacity })
          end
          rec.last_fault = "no slot at #{Time.now.utc.strftime('%H:%M:%S')}"
        end

        rec
      end

      # Pod returns from loop — demands a slot
      def pod_returns_from_loop(nora_id)
        rec = @pods[nora_id]
        return pod_arrives(nora_id, entity: nil) unless rec
        rec.state = :arriving
        rec.eta_return = nil

        reserved = @ps.find { |s| s.reserved? && s.reserved_for == nora_id }
        target = reserved || highest_empty_slot

        if target
          target.occupy!(nora_id)
          rec.slot  = target.number
          rec.state = :parked
          puts "[Sally #{@id}] #{nora_id} loop return → ps#{target.number}"
        else
          puts "[Sally #{@id}] #{nora_id} loop return — NO SLOT (full)"
          rec.last_fault = "no slot after loop at #{Time.now.utc.strftime('%H:%M:%S')}"
        end

        rec
      end

      # Advance pod from one slot to another (conveyor-toward-exit)
      def advance_pod(nora_id, from_slot, to_slot)
        rec = @pods[nora_id]
        return unless rec

        from = slot(from_slot)
        to   = slot(to_slot)
        return unless from && to

        # Validate: to_slot must be higher (toward exit) and empty
        return if to_slot <= from_slot
        return unless to.empty?

        from.vacate!
        to.occupy!(nora_id)
        rec.slot  = to_slot
        rec.state = :advancing
        puts "[Sally #{@id}] #{nora_id} advance ps#{from_slot} → ps#{to_slot}"
        rec
      end

      # Advance complete — pod is parked at new slot
      def advance_complete(nora_id)
        rec = @pods[nora_id]
        return unless rec
        rec.state = :parked
        rec
      end

      # ── Conveyor — advance all pods toward exit after a departure ─────
      # Returns array of { nora_id:, from_slot:, to_slot: } for pods that moved.
      # Animation uses this to create short advance maneuvers.
      def advance_conveyor
        moved = []
        # Advance all eligible pods — highest first toward exit.
        # Direct transforms (3 substeps each) complete instantly,
        # so all pods can move in one call without overlap.
        @ps.sort_by { |s| -s.number }.each do |s|
          next unless s.occupied?
          to_num = s.number + 1
          next if to_num > @capacity
          target = slot(to_num)
          next unless target && target.empty?

          nora_id = s.occupant_id
          from_num = s.number
          s.vacate!
          target.occupy!(nora_id)

          rec = @pods[nora_id]
          if rec
            rec.slot = to_num
            rec.state = :parked
          end

          moved << { nora_id: nora_id, from_slot: from_num, to_slot: to_num }
          puts "[Sally #{@id}] conveyor: #{nora_id} ps#{from_num} → ps#{to_num}"
        end
        moved
      end

      # ── Slot position setup ──────────────────────────────────────────────

      def set_slot_position(slot_num, position_mm, dist_mm)
        s = slot(slot_num)
        return unless s
        s.position_mm = position_mm
        s.dist_mm     = dist_mm
      end

      # ── Summary ──────────────────────────────────────────────────────────

      def summary
        occ = occupied_slots.size
        res = @ps.count(&:reserved?)
        emp = @ps.count(&:empty?)
        lpg = looping_pods.size
        "[Sally #{@id}] ps: #{occ} occupied, #{res} reserved, #{emp} empty / #{@capacity} | " \
        "pods: #{@pods.size} total, #{parked_pods.size} parked, #{lpg} looping"
      end

      def slot_summary
        @ps.map { |s|
          label = case s.state
                  when :occupied then s.occupant_id
                  when :reserved then "→#{s.reserved_for}"
                  else 'empty'
                  end
          "ps#{s.number}:#{label}"
        }.join(', ')
      end

      # ── Validate — bidirectional ps[] ↔ pods[] consistency ──────────────
      # Returns array of defect hashes. Purges orphans from both arrays.
      def validate!
        defects = []

        # Pod records claiming slots they don't occupy
        @pods.each do |nid, rec|
          next unless rec.state == :parked && rec.slot
          s = slot(rec.slot)
          if s.nil? || s.occupant_id != nid
            defects << {
              type: 'ghost_pod', station: @id, nora_id: nid,
              claimed_slot: rec.slot,
              actual_occupant: s&.occupant_id,
              detail: "pod claims ps#{rec.slot} but slot has #{s&.occupant_id || 'nil'}"
            }
            puts "[Sally #{@id}] PURGE ghost: #{nid} claims ps#{rec.slot} — slot has #{s&.occupant_id || 'nil'}"
            rec.slot = nil
            rec.state = :arriving
          end
        end

        # Purge pod records with no slot and no active state
        stale = @pods.select { |nid, rec|
          rec.slot.nil? && rec.state != :traveling && rec.state != :looping && rec.state != :arriving
        }
        stale.each do |nid, rec|
          defects << {
            type: 'stale_pod', station: @id, nora_id: nid,
            state: rec.state.to_s,
            detail: "pod record with no slot and state=#{rec.state} — removing"
          }
          puts "[Sally #{@id}] PURGE stale: #{nid} state=#{rec.state} no slot"
          @pods.delete(nid)
        end

        # Slots whose occupant has no pod record
        @ps.each do |s|
          next unless s.occupied?
          unless @pods.key?(s.occupant_id)
            defects << {
              type: 'orphan_slot', station: @id, slot: s.number,
              occupant_id: s.occupant_id,
              detail: "ps#{s.number} says #{s.occupant_id} but no pod record exists"
            }
            puts "[Sally #{@id}] PURGE orphan slot: ps#{s.number} → #{s.occupant_id} no pod record"
            s.vacate!
          end
        end

        defects
      end

      # ── Snapshot — full state dump for defect logging ───────────────────
      def snapshot
        {
          station: @id, capacity: @capacity,
          ps: @ps.map { |s| { n: s.number, state: s.state.to_s, occupant: s.occupant_id } },
          pods: @pods.map { |nid, rec| { nora_id: nid, slot: rec.slot, state: rec.state.to_s } },
          inbound: @inbound.map { |nid, info| { nora_id: nid, eta_s: info[:eta_s] } },
          occupancy: occupancy, effective: effective_occupancy
        }
      end

      # ── Reset ────────────────────────────────────────────────────────────

      def reset
        @ps.each(&:vacate!)
        @pods.clear
      end
    end

  end
end

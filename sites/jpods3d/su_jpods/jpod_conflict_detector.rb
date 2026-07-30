# jpod_conflict_detector.rb — Occupancy + Routing Integrity Guard
#
# Prevents silent failures when:
#   1. Multiple Noras stack on each other (occupancy violation)
#   2. Natalie's trip assignments get disrupted (manual moves, slot hijacking)
#   3. Vehicle state becomes inconsistent with assigned work
#
# Public API:
#   ConflictDetector.validate_placement(model, vehicle, target_location) → { ok:, complaints: [] }
#   ConflictDetector.validate_all_occupancy(model) → { violations: [] }
#   ConflictDetector.validate_natalie_assignments(model) → { disruptions: [] }
#   ConflictDetector.audit_state_consistency(model) → { inconsistencies: [] }

module JPods
  class ConflictDetector
    def self.vehicle_instances(model)
      vehicles = []
      model.entities.each do |entity|
        if entity.is_a?(Sketchup::ComponentInstance) && entity.get_attribute('JPods', 'vehicle_id', '').to_s != ''
          vehicles << entity
          next
        end

        next unless entity.is_a?(Sketchup::Group) && entity.name == 'JPods Guideway'

        entity.entities.grep(Sketchup::ComponentInstance).each do |child|
          next if child.deleted?
          next if child.get_attribute('JPods', 'vehicle_id', '').to_s.empty?
          vehicles << child
        end
      end
      vehicles
    rescue
      []
    end

    # ── Occupancy conflicts ─────────────────────────────────────────────────

    # Check whether placing a vehicle at this location would violate occupancy
    # (stack it on another vehicle). Returns { ok:, complaints: [] }.
    def self.validate_placement(model, vehicle_inst, target_location_or_platform)
      complaints = []

      begin
        # Extract target position
        target_pt = vehicle_inst&.transformation&.origin
        target_pt ||= if target_location_or_platform.is_a?(Hash) && target_location_or_platform['spawn_pt']
          target_location_or_platform['spawn_pt']
        elsif target_location_or_platform.is_a?(Geom::Point3d)
          target_location_or_platform
        end

        return { ok: false, complaints: ['target_location parse failed'] } unless target_pt

        nora_id = vehicle_inst.get_attribute('JPods', 'vehicle_id', '').to_s

        # Scan all other vehicles for occupancy conflict
        other_vehicles = vehicle_instances(model).reject do |entity|
          entity == vehicle_inst || entity.get_attribute('JPods', 'vehicle_id', '').to_s == nora_id
        end

        other_vehicles.each do |other|
          other_id = other.get_attribute('JPods', 'vehicle_id', '').to_s
          other_pt = other.transformation.origin
          distance_m = target_pt.distance(other_pt) / 1.m  # Convert SU inches to meters

          # Personal zone violation: threshold is slot_spacing minus 1 cm to tolerate
          # floating-point imprecision when vehicles land at exactly slot boundaries.
          # Vehicles exactly 2.5 m apart are within spec — do not flag them.
          if distance_m < 2.49
            complaints << "🔴 OCCUPANCY CONFLICT: Placing #{nora_id} would stack it on #{other_id} (#{distance_m.round(2)}m apart, minimum is 2.5m)"
          end

          # Merge lane violation — only meaningful when both vehicles are on a known line.
          # Skips check when current_line_id is blank (vehicle not yet on a routed segment).
          own_segment = vehicle_inst.get_attribute('JPods', 'current_line_id', '').to_s
          other_segment = other.get_attribute('JPods', 'current_line_id', '').to_s
          if !own_segment.empty? && own_segment == other_segment && distance_m < 5.0
            complaints << "🔴 MERGE CONFLICT: Both #{nora_id} and #{other_id} on segment #{own_segment} (#{distance_m.round(2)}m apart)"
          end
        end
      rescue => ex
        complaints << "occupancy validation error: #{ex.message}"
      end

      { ok: complaints.empty?, complaints: complaints }
    end

    # Scan all vehicles in the model and report occupancy violations
    def self.validate_all_occupancy(model)
      violations = []
      vehicles = vehicle_instances(model)

      (0...vehicles.size).each do |i|
        (i+1...vehicles.size).each do |j|
          v1 = vehicles[i]
          v2 = vehicles[j]
          id1 = v1.get_attribute('JPods', 'vehicle_id', '').to_s
          id2 = v2.get_attribute('JPods', 'vehicle_id', '').to_s
          next if id1.empty? || id2.empty?

          pt1 = v1.transformation.origin
          pt2 = v2.transformation.origin
          distance_m = pt1.distance(pt2) / 1.m  # Convert SU inches to meters

          if distance_m < 3.0
            violations << {
              severity: :critical,
              vehicle_a: id1,
              vehicle_b: id2,
              distance_m: distance_m.round(2),
              message: "🔴 STACKING VIOLATION: #{id1} and #{id2} are only #{distance_m.round(1)}m apart (need 3m minimum)",
            }
          elsif distance_m < 5.0
            violations << {
              severity: :warning,
              vehicle_a: id1,
              vehicle_b: id2,
              distance_m: distance_m.round(2),
              message: "🟡 CLOSE PROXIMITY: #{id1} and #{id2} are #{distance_m.round(1)}m apart (approaching 3m threshold)",
            }
          end
        end
      end

      violations
    end

    # ── Natalie routing disruptions ─────────────────────────────────────────

    # Check whether a vehicle's current state is consistent with Natalie's
    # assigned trip. Returns { disruptions: [] }.
    def self.validate_natalie_assignments(model)
      disruptions = []

      vehicles = vehicle_instances(model)

      vehicles.each do |vehicle|
        nora_id = vehicle.get_attribute('JPods', 'vehicle_id', '').to_s
        assigned_trip_id = vehicle.get_attribute('JPods', 'trip_id', '').to_s
        current_line = vehicle.get_attribute('JPods', 'current_line_id', '').to_s
        parking_platform = vehicle.get_attribute('JPods', 'parking_platform_id', '').to_s
        origin_platform = vehicle.get_attribute('JPods', 'origin_platform_id', '').to_s

        # Rule 1: If trip is assigned, Nora should be en-route or parked at expected platform
        if assigned_trip_id != ''
          if current_line == ''
            # Nora is parked; check if it's at the expected origin
            if parking_platform != origin_platform && origin_platform != ''
              disruptions << {
                severity: :high,
                nora_id: nora_id,
                trip_id: assigned_trip_id,
                message: "🔴 NATALIE DISRUPTION: #{nora_id} has trip #{assigned_trip_id} but is parked at platform #{parking_platform} (assigned origin: #{origin_platform})",
              }
            end
          end
        end

        # Rule 2: If manually moved while on a trip, flag it
        last_move_at = vehicle.get_attribute('JPods', 'last_manual_move_at', '')
        trip_assigned_at = vehicle.get_attribute('JPods', 'trip_assigned_at', '')
        if assigned_trip_id != '' && last_move_at != '' && trip_assigned_at != ''
          begin
            move_time = Time.parse(last_move_at)
            assign_time = Time.parse(trip_assigned_at)
            if move_time > assign_time
              disruptions << {
                severity: :critical,
                nora_id: nora_id,
                trip_id: assigned_trip_id,
                message: "🔴 NATALIE VIOLATED: #{nora_id} was manually moved AFTER trip assignment (#{move_time} > #{assign_time}). Trip state is corrupted.",
              }
            end
          rescue
            # Timestamp parse failed, skip this check
          end
        end
      end

      disruptions
    end

    # ── State consistency checks ────────────────────────────────────────────

    # Audit all vehicles for internal state inconsistencies
    def self.audit_state_consistency(model)
      inconsistencies = []

      vehicles = vehicle_instances(model)

      vehicles.each do |vehicle|
        nora_id = vehicle.get_attribute('JPods', 'vehicle_id', '').to_s
        current_line = vehicle.get_attribute('JPods', 'current_line_id', '').to_s
        mm_on_line = vehicle.get_attribute('JPods', 'mm_on_line', 0).to_i
        trip_id = vehicle.get_attribute('JPods', 'trip_id', '').to_s

        # Consistency 1: If en-route, current_line_id must not be empty
        if current_line == '' && trip_id != ''
          inconsistencies << {
            severity: :medium,
            nora_id: nora_id,
            issue: 'assigned_trip_but_no_current_line',
            message: "🟡 STATE INCONSISTENCY: #{nora_id} has trip #{trip_id} but current_line_id is empty",
          }
        end

        # Consistency 2: mm_on_line must be non-negative
        if mm_on_line < 0
          inconsistencies << {
            severity: :medium,
            nora_id: nora_id,
            issue: 'negative_mm_on_line',
            message: "🟡 STATE CORRUPTION: #{nora_id} has negative mm_on_line (#{mm_on_line})",
          }
        end

        # Consistency 3: If parked, should not have current_line_id set to a valid value
        parking_platform = vehicle.get_attribute('JPods', 'parking_platform_id', '').to_s
        if parking_platform != '' && current_line != ''
          inconsistencies << {
            severity: :low,
            nora_id: nora_id,
            issue: 'parked_but_has_current_line',
            message: "⚠️  STATE AMBIGUITY: #{nora_id} is parked at #{parking_platform} but current_line_id=#{current_line}",
          }
        end
      end

      inconsistencies
    end

    # ── Loud complaint reporter ─────────────────────────────────────────────

    def self.report_all_conflicts(model)
      puts "\n" + "="*80
      puts "JPods Conflict Detector — Full Audit Report"
      puts "="*80

      violations = validate_all_occupancy(model)
      disruptions = validate_natalie_assignments(model)
      inconsistencies = audit_state_consistency(model)

      if violations.empty? && disruptions.empty? && inconsistencies.empty?
        puts "✅ All checks passed — no conflicts detected."
      else
        puts ""
        if violations.any?
          puts "🔴 OCCUPANCY VIOLATIONS (#{violations.size}):"
          violations.each do |v|
            puts "  #{v[:message]}"
          end
          puts ""
        end

        if disruptions.any?
          puts "🔴 NATALIE DISRUPTIONS (#{disruptions.size}):"
          disruptions.each do |d|
            puts "  #{d[:message]}"
          end
          puts ""
        end

        if inconsistencies.any?
          puts "⚠️  STATE INCONSISTENCIES (#{inconsistencies.size}):"
          inconsistencies.each do |inc|
            puts "  #{inc[:message]}"
          end
          puts ""
        end
      end

      puts "="*80 + "\n"

      {
        violations: violations,
        disruptions: disruptions,
        inconsistencies: inconsistencies,
        total_issues: violations.size + disruptions.size + inconsistencies.size,
      }
    end
  end
end

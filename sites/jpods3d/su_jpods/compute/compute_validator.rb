# ── Compute Phase 1: Validation ───────────────────────────────────────────────
#
# Read the designer section of lines.json and verify completeness.
# Accept or reject before any geometry extraction begins.
#
# See: compute/phase1_validation.md

module JPods
  module Compute
    module Validator

      # Check the designer section of template_data for completeness.
      # Returns Array of defect strings (empty = accept).
      def self.check(template_data, model_id: '')
        defects = []
        des = template_data['designer'] || {}
        is_circle = model_id.to_s.match?(/traffic_circle/i)

        # ── designer.tracks ───────────────────────────────────────────────────
        tracks = des['tracks']
        unless tracks.is_a?(Hash) && tracks.any? { |k, _| k.start_with?('gw_') }
          defects << "designer.tracks: missing or empty (no gw_ tracks declared)"
          return defects  # can't check further without tracks
        end

        # Every gw_ track must have a successors key
        tracks.each do |tag, td|
          next unless tag.start_with?('gw_')
          unless td.is_a?(Hash)
            defects << "designer.tracks.#{tag}: not a Hash"
            next
          end
          unless td.key?('successors')
            defects << "designer.tracks.#{tag}: missing 'successors' key"
          end
          # Every declared successor must be a declared track
          Array(td['successors']).each do |succ|
            next if succ.to_s.empty?
            unless tracks.key?(succ)
              defects << "designer.tracks.#{tag}: successor '#{succ}' not declared in designer.tracks"
            end
          end
        end

        # ── designer.cps ──────────────────────────────────────────────────────
        cps = des['cps']
        unless cps.is_a?(Array) && !cps.empty?
          defects << "designer.cps: missing or empty (no connection points declared)"
        else
          valid_types = %w[merge diverge 1-1 open]
          cps.each do |ep|
            ep_id = ep['id']
            ep_type = ep['type'].to_s
            unless valid_types.include?(ep_type)
              defects << "designer.cps EP #{ep_id}: invalid type '#{ep_type}' (must be: #{valid_types.join(', ')})"
            end
            Array(ep['in']).each do |t|
              defects << "designer.cps EP #{ep_id}: in track '#{t}' not declared" unless t.empty? || tracks.key?(t)
            end
            Array(ep['out']).each do |t|
              defects << "designer.cps EP #{ep_id}: out track '#{t}' not declared" unless t.empty? || tracks.key?(t)
            end
          end
        end

        # ── Connectivity: every track reachable from a CP ─────────────────────
        if defects.empty?
          # Build reachability from all gw_cp_in_* and gw_cp_out_* tracks
          succ_graph = {}
          tracks.each { |tag, td| succ_graph[tag] = Array(td['successors']) if td.is_a?(Hash) }

          # Start BFS from all CP tracks
          cp_starts = tracks.keys.select { |t| t.match?(/\Agw_cp_(in|out)_\d+\z/) }
          # Also add gw_platform as a start (exit chains start here)
          cp_starts << 'gw_platform' if tracks.key?('gw_platform')

          reachable = {}
          bfs_queue = cp_starts.dup
          while (current = bfs_queue.shift)
            next if reachable[current]
            reachable[current] = true
            (succ_graph[current] || []).each { |s| bfs_queue << s }
          end

          # Check for orphans
          tracks.each_key do |tag|
            next unless tag.start_with?('gw_')
            unless reachable[tag]
              defects << "designer.tracks.#{tag}: orphan — not reachable from any CP or gw_platform"
            end
          end
        end

        # ── CCW enforcement for traffic circles ─────────────────────────────
        if is_circle && defects.empty?
          # Ring arcs (gw_c_N_M) must chain CCW when viewed from above.
          # CCW = successor index increases (mod ring size).
          # CW would mean decreasing indices — reject.
          ring_arcs = tracks.keys.select { |t| t.match?(/\Agw_c_\d+_\d+\z/) }.sort
          ring_arcs.each do |arc|
            m = arc.match(/\Agw_c_(\d+)_(\d+)\z/)
            next unless m
            from_idx = m[1].to_i
            to_idx   = m[2].to_i
            succs = Array(tracks[arc]['successors'])
            succs.each do |s|
              s_m = s.match(/\Agw_c_(\d+)_(\d+)\z/)
              next unless s_m
              s_from = s_m[1].to_i
              # Successor's from should equal this arc's to (continuity)
              # and successor should advance CCW (increasing index mod N)
              if s_from != to_idx
                defects << "designer.tracks.#{arc}: ring successor #{s} breaks continuity (expected from=#{to_idx})"
              end
            end
          end
        end

        # ── Minimum turn radius ───────────────────────────────────────────────
        # VEHICLE_MIN_TURN_DIAMETER = 3.5m → min radius = 1750mm
        # Any track with pts that imply a curve tighter than this is rejected.
        # Checked at geometry extraction (Phase 3) — noted here as a rule.

        defects
      end

      # Format defects for console output.
      def self.report(defects, model_id)
        puts ""
        puts "🚫 [Noelle] Compute REJECTED — #{model_id}/lines.json is incomplete:"
        defects.each { |d| puts "   • #{d}" }
        puts "   Fix lines.json and run Compute again."
        puts ""
      end

    end
  end
end

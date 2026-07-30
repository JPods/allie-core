# ── Compute Phase 2: Chain Building ───────────────────────────────────────────
#
# Build Natalie chains from the designer successor graph.
# The designer declares tracks + successors. Natalie computes the chains.
# No hand-authored chains.
#
# See: compute/phase2_chain_building.md

module JPods
  module Compute
    module ChainBuilder

      # Build all chains from designer topology.
      # Returns { natalie: Hash (chains to merge into template_data), failures: Array }
      def self.build(template_data, model_id: '')
        des = template_data['designer'] || {}
        tracks = des['tracks'] || {}
        cps = des['cps'] || []
        is_circle = model_id.to_s.match?(/traffic_circle/i)

        # Build successor graph
        succ_graph = {}
        tracks.each do |tag, td|
          next unless tag.start_with?('gw_') && td.is_a?(Hash)
          succ_graph[tag] = Array(td['successors']).reject { |s| s.to_s.empty? }
        end

        failures = []
        natalie = {}

        if is_circle
          natalie['pass_chains'] = _build_pass_chains(succ_graph, tracks, cps, failures)
        else
          result = _build_platform_chains(succ_graph, tracks, cps, failures)
          natalie.merge!(result)
        end

        { natalie: natalie, failures: failures }
      end

      private

      # ── Platform station chains ────────────────────────────────────────────

      def self._build_platform_chains(succ_graph, tracks, cps, failures)
        result = {}

        # Derive CP indices from track names
        cp_nums = tracks.keys.filter_map { |t|
          m = t.match(/\Agw_cp_(?:in|out)_(\d+)\z/)
          m ? m[1].to_i : nil
        }.uniq.sort

        landing = {}
        exit_chains = {}
        originating = {}

        cp_nums.each do |cp_n|
          # Landing chain: gw_cp_in_N → ... → gw_platform
          lc = _bfs(succ_graph, "gw_cp_in_#{cp_n}", /\Agw_platform\z/)
          if lc
            switches = _detect_switches(lc, cps)
            landing["in_cp#{cp_n}"] = { 'tracks' => lc, 'switches' => switches }
            puts "[Natalie] landing chain cp#{cp_n}: #{lc.join(' → ')}"
          else
            failures << "landing chain cp#{cp_n}: BFS from gw_cp_in_#{cp_n} cannot reach gw_platform"
            puts "[Natalie] ⚠ could not build landing chain for cp#{cp_n}"
          end

          # Exit chain: gw_platform → ... → gw_cp_out_N
          ec = _bfs(succ_graph, 'gw_platform', /\Agw_cp_out_#{cp_n}\z/)
          if ec
            switches = _detect_switches(ec, cps)
            exit_chains["out_cp#{cp_n}"] = { 'tracks' => ec, 'switches' => switches }
            originating["out_cp#{cp_n}"] = {
              'tracks' => ec, 'switches' => switches, 'clip_start' => true,
              'note' => "Same as exit — clip_start trims gw_platform to pod slot"
            }
            puts "[Natalie] exit chain cp#{cp_n}: #{ec.join(' → ')}"
          else
            failures << "exit chain cp#{cp_n}: BFS from gw_platform cannot reach gw_cp_out_#{cp_n}"
            puts "[Natalie] ⚠ could not build exit chain for cp#{cp_n}"
          end
        end

        # Parking chain
        parking = { 'tracks' => ['gw_platform'], 'note' => 'Single parking track. Slot 1 = entry end, slot N = exit end.' }

        # Hold loop: gw_platform → ... → gw_platform_parking (then close with gw_platform)
        # Multi-CP stations: filter gw_cp_out_* to stay inside (prevent exit to wrong CP).
        # Single-CP stations: allow gw_cp_out_* because the hold loop MUST go through
        # the CP stubs — there's no other path around. The vehicle exits and re-enters
        # through the same CP.
        if cp_nums.size > 1
          # Only filter the actual CP stubs (gw_cp_out_N), not the lead tracks
          # (gw_cp_out_lead_N). The lead tracks are internal to the station.
          filtered_graph = succ_graph.transform_values { |succs|
            succs.reject { |s| s.match?(/\Agw_cp_out_\d+\z/) }
          }
        else
          filtered_graph = succ_graph  # single CP — no filtering
        end
        # Target: gw_platform_parking if it exists, otherwise loop back
        # to gw_platform itself (BFS skips start_tag so it must go OUT
        # and come BACK). If neither works, try gw_platform_in* as last resort.
        has_parking = succ_graph.key?('gw_platform_parking')
        if has_parking
          hl = _bfs(filtered_graph, 'gw_platform', /\Agw_platform_parking\z/)
        else
          # Loop back to gw_platform — BFS won't match at start (line 178)
          hl = _bfs(filtered_graph, 'gw_platform', /\Agw_platform\z/)
        end
        hold_loop = if hl
          # If target was gw_platform itself, no need to append it again
          loop_tracks = if has_parking
            hl + ['gw_platform']
          elsif hl.last == 'gw_platform'
            hl  # already ends at gw_platform
          else
            hl + ['gw_platform']
          end
          puts "[Natalie] hold_loop: #{loop_tracks.join(' → ')}"
          { 'loop' => loop_tracks, 'from_platform' => [], 'to_platform' => [] }
        else
          failures << "hold_loop: BFS from gw_platform cannot reach platform entry (staying inside station)"
          puts "[Natalie] ⚠ could not build hold_loop chain"
          nil
        end

        result['landing_chains']     = landing     if landing.any?
        result['exit_chains']        = exit_chains if exit_chains.any?
        result['originating_chains'] = originating if originating.any?
        result['parking_chain']      = parking
        result['hold_loop_chain']    = hold_loop   if hold_loop

        total = landing.size + exit_chains.size
        puts "[Natalie] Phase 2: #{total} chains built (#{cp_nums.size} CP(s), " \
             "#{hold_loop ? 'hold_loop ✓' : 'hold_loop ✗'})"
        result
      end

      # ── Traffic circle: circle + entries + exits ───────────────────────────
      #
      # The ring is ONE thing — define it once, traverse at runtime.
      #   circle: CCW-ordered array of ring arcs
      #   entries: cpN → [gw_cp_in_N, gw_in_N] (stub from CP to ring)
      #   exits:   cpN → [gw_out_N, gw_cp_out_N] (stub from ring to CP)
      #   entry_arc: cpN → which ring arc gw_in_N connects to
      #   exit_arc:  cpN → which ring arc has gw_out_N as successor
      #
      # Natalie builds maneuvers at dispatch: entry[from] + circle slice + exit[to]

      def self._build_pass_chains(succ_graph, tracks, cps, failures)
        result = {}
        cp_nums = tracks.keys.filter_map { |t|
          m = t.match(/\Agw_cp_(?:in|out)_(\d+)\z/)
          m ? m[1].to_i : nil
        }.uniq.sort

        # ── Circle: CCW-ordered ring arcs from successor graph ────────────
        # Start from any gw_c_ track, follow successors staying on gw_c_,
        # collect the full ring in CCW order.
        ring_starts = tracks.keys.select { |t| t.match?(/\Agw_c_\d+_\d+\z/) }
        circle = []
        if ring_starts.any?
          visited = {}
          current = ring_starts.first
          loop do
            break if visited[current]
            visited[current] = true
            circle << current
            # Follow to next ring arc (skip gw_out_ exits)
            next_arc = (succ_graph[current] || []).find { |s| s.match?(/\Agw_c_/) }
            break unless next_arc
            current = next_arc
          end
        end

        if circle.size != ring_starts.size
          failures << "circle: expected #{ring_starts.size} ring arcs, got #{circle.size} in CCW chain"
          puts "[Natalie] ⚠ ring chain incomplete: #{circle.size}/#{ring_starts.size} arcs"
        end

        # ── Entries: CP → ring ────────────────────────────────────────────
        entries = {}
        entry_arc = {}
        cp_nums.each do |cp_n|
          in_stub = ["gw_cp_in_#{cp_n}"]
          # BFS from gw_cp_in_N to first gw_c_ track
          chain = _bfs(succ_graph, "gw_cp_in_#{cp_n}", /\Agw_c_/)
          if chain
            # Entry is everything BEFORE the ring arc
            ring_idx = chain.index { |t| t.match?(/\Agw_c_/) }
            entries["cp#{cp_n}"] = chain[0...ring_idx]
            entry_arc["cp#{cp_n}"] = chain[ring_idx]
            puts "[Natalie] entry cp#{cp_n}: #{entries["cp#{cp_n}"].join(' → ')} → ring at #{entry_arc["cp#{cp_n}"]}"
          else
            failures << "entry cp#{cp_n}: cannot reach ring from gw_cp_in_#{cp_n}"
          end
        end

        # ── Exits: ring → CP ─────────────────────────────────────────────
        exits = {}
        exit_arc = {}
        cp_nums.each do |cp_n|
          out_track = "gw_out_#{cp_n}"
          # Find which ring arc has gw_out_N as a successor
          ring_arc = circle.find { |arc| (succ_graph[arc] || []).include?(out_track) }
          if ring_arc
            exit_arc["cp#{cp_n}"] = ring_arc
            # Exit stub: gw_out_N → gw_cp_out_N
            exit_chain = _bfs(succ_graph, out_track, /\Agw_cp_out_#{cp_n}\z/)
            exits["cp#{cp_n}"] = exit_chain || [out_track, "gw_cp_out_#{cp_n}"]
            puts "[Natalie] exit cp#{cp_n}: ring at #{ring_arc} → #{exits["cp#{cp_n}"].join(' → ')}"
          else
            failures << "exit cp#{cp_n}: no ring arc leads to gw_out_#{cp_n}"
          end
        end

        result['circle']    = circle
        result['entries']   = entries
        result['exits']     = exits
        result['entry_arc'] = entry_arc
        result['exit_arc']  = exit_arc
        result['note']      = "#{cp_nums.size}-CP circle. Ring defined once (#{circle.size} arcs CCW). " \
                              "Natalie builds from→to at dispatch: entry + circle slice + exit."

        puts "[Natalie] Phase 2: #{cp_nums.size}-CP circle — #{circle.size} ring arcs, " \
             "#{entries.size} entries, #{exits.size} exits"
        result
      end

      # ── BFS: find path from start_tag to first tag matching end_pattern ────

      def self._bfs(graph, start_tag, end_pattern)
        return nil unless graph.key?(start_tag)
        visited = {}
        queue = [[start_tag, [start_tag]]]
        while !queue.empty?
          current, path = queue.shift
          next if visited[current]
          visited[current] = true
          return path if current != start_tag && current.match?(end_pattern)
          (graph[current] || []).each do |s|
            queue << [s, path + [s]] unless visited[s]
          end
        end
        nil
      end

      # ── Detect switches from chain path + EP definitions ───────────────────
      # At diverge EPs, the chain path determines which out track the switch selects.

      def self._detect_switches(chain, cps)
        switches = []
        cps.select { |ep| ep['type'] == 'diverge' }.each do |ep|
          in_tracks = Array(ep['in'])
          out_tracks = Array(ep['out'])
          next unless out_tracks.size > 1
          # Find where the chain passes through this diverge
          in_tracks.each do |in_t|
            idx = chain.index(in_t)
            next unless idx && idx + 1 < chain.size
            selected = chain[idx + 1]
            if out_tracks.include?(selected)
              switches << { 'ep_id' => ep['id'], 'at_track' => in_t, 'setting' => selected }
            end
          end
        end
        switches
      end

    end
  end
end

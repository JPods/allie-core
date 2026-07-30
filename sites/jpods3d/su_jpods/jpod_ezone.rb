# ── JPods Exclusive Zone (EZone) — Zipper Merge Protocol ──────────────────────
#
# Each merge and diverge EP defines an exclusive zone where only one pod
# may be present at a time. Natalie adjusts approaching pod speeds so they
# arrive staggered (zipper merge). If speed adjustment isn't sufficient,
# the trailing pod decelerates to zero (stop-wait) — logged as a fault.
#
# EZone object: rich, extensible, per-junction. Carries shape, timing,
# priority rules, and experience-driven parameters.
#
# Physical equivalent: UTD/jpod_OS/mapV2.json ezones + mqtt.py EZONE protocol.
# SU animation: checked every tick in enforce_ezone_spacing!
#
# ── su-real ──────────────────────────────────────────────────────────────────
# Physical ezone (JPodsSM_RPi/ezone.py) operates on MQTT-coordinated timing:
#   - Each ezone has inPoint1, inPoint2, outPoint with distFrom/distTo in mm
#   - Pod publishes position → ezone.py computes entry_time/exit_time windows
#   - Gap-finding algorithm scans scheduled arrivals, computes optimal speed
#     to hit a gap between converging pods (EZ_LOOKAHEAD_MM = 300mm)
#   - If no gap within speed bounds → blockedByEZ = True (pod stops)
#   - Ring traffic has priority at merge (same as SU :ring priority)
#
# SU simplifications vs physical:
#   - SU uses remaining_mm linear scaling; physical uses time-window gap-finding
#     with actual pod speed + deceleration curve. Time-based is more accurate
#     because it accounts for speed differences between converging pods.
#   - SU zone_length_mm is flat 3000mm; physical ezones have per-junction
#     distFrom/distTo from mapSM.json + curveRadius + maxLateralG constraints.
#     Physical speed limit at curve = sqrt(maxLateralG * 9.81 * curveRadius).
#   - SU locks zone per-pod; physical ezone.py manages time windows for
#     multiple pods — supports back-to-back transit if gaps are sufficient.
#   - SU stop_wait_count is a counter; physical logs each stop-wait with
#     timestamp, pod IDs, wait duration — feeds capacity analysis.
#   - SU has no ToF safety layer; physical has personal space (50mm),
#     care zone (50-150mm), clear (>150mm) with proportional speed reduction
#     as a SEPARATE system from ezone — defense in depth.
#
# What SU should produce for physical: per-ezone stop_wait_count + the
# pods involved + the time delta between arrivals. This tells physical
# Natalie whether the ezone geometry needs widening (infrastructure fix)
# or whether dispatch timing needs adjustment (software fix).
#
# All four platforms (scale model, 4WD, FullScale, SkyRide) use identical
# ezone zipper algorithm — only the transport layer differs.
# ─────────────────────────────────────────────────────────────────────────────

module JPods
  module EZone

    # ── EZone definition ─────────────────────────────────────────────────────
    # Built from lines.json merge/diverge EPs at animation start.
    # Each ezone tracks which tracks converge and which pod has priority.
    #
    # Fields:
    #   ep_id:        EP number from lines.json
    #   station_id:   which station this junction belongs to
    #   type:         :merge | :diverge
    #   tracks_in:    Array of track IDs that feed INTO this junction
    #   tracks_out:   Array of track IDs that exit this junction
    #   priority:     :ring (ring traffic has priority at merge)
    #   ring_track:   the ring arc track (has priority at merge)
    #   entry_track:  the entry approach track (yields at merge)
    #   zone_length_mm: how far before the junction the zone starts (vehicle envelope)
    #   locked_by:    nora_id of pod currently in the zone (nil = clear)
    #   locked_at:    Time when lock was acquired
    #   stop_wait_count: number of times a pod had to stop-wait here
    #   stop_wait_log:  Array of { yielder:, blocker:, time:, gap_ms: } (su-real)
    #   note:         human-readable description
    EZoneDef = Struct.new(
      :ep_id, :station_id, :type, :tracks_in, :tracks_out,
      :priority, :ring_track, :entry_track,
      :zone_length_mm, :locked_by, :locked_at,
      :stop_wait_count, :stop_wait_log, :note,
      keyword_init: true
    )

    @@ezones = []  # Array<EZoneDef> — built at animation start

    def self.ezones; @@ezones; end

    # ── Build ezones from lines.json merge/diverge EPs ───────────────────────
    # Called at animation start. Reads network.json for station templates,
    # then reads lines.json for each template's EPs.
    def self.build_from_network(model)
      @@ezones = []
      plugin_dir = File.expand_path('../', __FILE__)

      nj_path = File.join(File.dirname(model.path), "#{File.basename(model.path, '.skp')}.network.json")
      return unless File.exist?(nj_path)

      nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
      formation_registry = nj.dig('noelle', 'formation_registry') || {}

      Array(nj.dig('designer', 'stations')).each do |st|
        sid      = st['id'].to_s.downcase
        template = (formation_registry[sid] || st['template'].to_s).strip
        next if template.empty?

        lj_path = File.join(plugin_dir, 'templates', 'track_formations', template, 'lines.json')
        next unless File.exist?(lj_path)

        lj = JSON.parse(File.read(lj_path, encoding: 'utf-8'))
        eps = lj.dig('designer', 'cps') || []

        eps.each do |ep|
          next unless %w[merge diverge].include?(ep['type'])
          tracks_in  = Array(ep['in'])
          tracks_out = Array(ep['out'])

          # For merge: identify ring track (gw_c_*) vs entry track (gw_in_*)
          ring_track  = nil
          entry_track = nil
          if ep['type'] == 'merge'
            ring_track  = tracks_in.find { |t| t.start_with?('gw_c_') }
            entry_track = tracks_in.find { |t| t.start_with?('gw_in_') }
          end

          ezone = EZoneDef.new(
            ep_id:           ep['id'],
            station_id:      sid,
            type:            ep['type'].to_sym,
            tracks_in:       tracks_in.map { |t| "#{sid}.#{t}" },
            tracks_out:      tracks_out.map { |t| "#{sid}.#{t}" },
            priority:        ep['type'] == 'merge' ? :ring : :none,
            ring_track:      ring_track  ? "#{sid}.#{ring_track}"  : nil,
            entry_track:     entry_track ? "#{sid}.#{entry_track}" : nil,
            zone_length_mm:  3000,  # 3m default — vehicle length + clearance
            locked_by:       nil,
            locked_at:       nil,
            stop_wait_count: 0,
            stop_wait_log:   [],
            note:            ep['note'].to_s,
          )
          @@ezones << ezone
        end
      end

      puts "[Noelle] #{@@ezones.size} ezone(s) built — #{@@ezones.count { |z| z.type == :merge }} merge, #{@@ezones.count { |z| z.type == :diverge }} diverge"
    rescue => ex
      puts "[Noelle] ezone build error: #{ex.message}"
      @@ezones = []
    end

    # ── Zipper merge: adjust speeds for approaching pods ─────────────────────
    # Called every tick from JPodVehicleAnim.tick, after proposals are built
    # but before they are applied.
    #
    # For each merge ezone:
    #   1. Find pods on the converging tracks
    #   2. If two pods approach the junction simultaneously:
    #      - Ring pod has priority (keeps speed)
    #      - Entry pod speed scales down: full speed when far, zero when at junction
    #   3. Lock the zone when a pod enters; unlock when it exits
    #   4. Log every stop-wait (speed = 0) as a fault
    #
    # Speed scaling: linear from zone_length_mm.
    #   distance_to_junction / zone_length_mm * normal_speed
    #   Clamps to 0 when at junction. Scales to full speed at zone boundary.
    # Lookahead distance — Natalie adjusts speeds this far before the junction.
    # Longer than the 3m zone — gives pods time to decelerate smoothly.
    LOOKAHEAD_MM = 10_000  # 10m — pod has ~1.2s at cruise to adjust
    SAFETY_GAP_MM = 2_000  # 2m — minimum gap between pods at junction

    def self.enforce_ezone_spacing!(pods, proposals, lookup)
      return if @@ezones.empty?

      # Build current pod positions by track
      pod_tracks = {}  # "sid.track" → { pod:, t:, remaining_mm:, proposal: }
      proposals.each do |prop|
        pod = prop[:pod]
        next unless pod.state == :traveling
        man = pod.current_maneuver
        next unless man && man[:id]
        track_id = man[:id].to_s.downcase
        t = prop[:t] || pod.t
        remaining_mm = man[:len] * (1.0 - t) * 25.4  # inches to mm
        pod_tracks[track_id] = { pod: pod, t: t, remaining_mm: remaining_mm, proposal: prop }
      end

      # Also track pods by nora_id for queue lookahead
      pod_by_id = {}
      proposals.each do |prop|
        pod = prop[:pod]
        pod_by_id[pod.pod_id] = { pod: pod, proposal: prop } if pod.state == :traveling
      end

      @@ezones.each do |ezone|
        next unless ezone.type == :merge

        ring_pod_info  = ezone.ring_track  ? pod_tracks[ezone.ring_track]  : nil
        entry_pod_info = ezone.entry_track ? pod_tracks[ezone.entry_track] : nil

        # ── Lookahead: find pods approaching the entry track ──────────
        # A pod on a track BEFORE the entry track is also approaching.
        # Check its maneuver queue — if the entry track is in the queue,
        # calculate total distance to the merge point.
        approaching_entry = nil
        if !entry_pod_info
          pod_by_id.each do |nora_id, info|
            queue = (defined?(AnimationV2) ? (AnimationV2.send(:_queues)[nora_id] || []) : []) rescue []
            next if queue.empty?
            # Check if entry_track is in the upcoming maneuvers
            entry_idx = queue.index { |m| m[:id].to_s.downcase == ezone.entry_track }
            next unless entry_idx
            # Calculate distance: remaining on current track + all tracks before entry
            man = info[:pod].current_maneuver
            next unless man
            dist = man[:len] * (1.0 - (info[:proposal][:t] || info[:pod].t)) * 25.4
            queue[0...entry_idx].each { |m| dist += (m[:len] || 0) * 25.4 }
            # Add the entry track length itself
            entry_man = queue[entry_idx]
            dist += (entry_man[:len] || 0) * 25.4 if entry_man
            next if dist > LOOKAHEAD_MM  # too far — no action needed
            approaching_entry = { pod: info[:pod], proposal: info[:proposal], distance_mm: dist }
            break
          end
        end

        # Zone lock management
        if ezone.locked_by
          locker_still_here = pod_tracks.values.any? { |pi|
            pi[:pod].pod_id == ezone.locked_by &&
            (ezone.tracks_in + ezone.tracks_out).include?(pi[:pod].current_maneuver&.dig(:id).to_s.downcase)
          }
          unless locker_still_here
            ezone.locked_by = nil
            ezone.locked_at = nil
          end
        end

        # If ring pod is approaching — lock for it (priority)
        if ring_pod_info && ring_pod_info[:remaining_mm] < LOOKAHEAD_MM
          ezone.locked_by ||= ring_pod_info[:pod].pod_id
        end

        # ── Zipper: boost the lock holder to clear faster ──────────────
        if ezone.locked_by && (entry_pod_info || approaching_entry)
          yielder_id = entry_pod_info ? entry_pod_info[:pod].pod_id : approaching_entry[:pod].pod_id
          if ezone.locked_by != yielder_id
            locker_info = pod_tracks.values.find { |pi| pi[:pod].pod_id == ezone.locked_by }
            if locker_info && locker_info[:remaining_mm] < LOOKAHEAD_MM
              locker_prop = locker_info[:proposal]
              if locker_prop && locker_prop[:state] == :traveling
                original_t = locker_prop[:t]
                current_t  = locker_info[:pod].t
                delta_t    = original_t - current_t
                locker_prop[:t] = [current_t + delta_t * 1.5, 1.0].min
              end
            end
          end
        end

        # ── Speed adjustment for entry/approaching pod ─────────────────
        # Proactive: start adjusting at LOOKAHEAD_MM, not just at zone boundary.
        # The pod decelerates smoothly so it arrives with a 2m gap after the ring pod.
        yielder = entry_pod_info || approaching_entry
        if yielder && ezone.locked_by && ezone.locked_by != yielder[:pod].pod_id
          remaining = yielder[:remaining_mm] || yielder[:distance_mm]
          if remaining < LOOKAHEAD_MM
            # Smooth deceleration: speed scales linearly from full at LOOKAHEAD to zero at junction
            speed_factor = (remaining / LOOKAHEAD_MM).clamp(0.0, 1.0)

            if speed_factor < 0.05
              speed_factor = 0.0
              ezone.stop_wait_count += 1
              ezone.stop_wait_log << {
                yielder: yielder[:pod].pod_id,
                blocker: ezone.locked_by,
                time: Time.now.to_f,
                remaining_mm: remaining.round(1),
              }
              if ezone.stop_wait_count % 20 == 0 && defined?(JPods::Log)
                JPods::Log.remember(:natalie,
                  "EP#{ezone.ep_id} #{ezone.station_id}: #{ezone.stop_wait_count} stop-waits — capacity investigation needed",
                  data: { ep: ezone.ep_id, station: ezone.station_id, count: ezone.stop_wait_count })
              end
              if ezone.stop_wait_count % 10 == 1
                puts "[Natalie ezone] STOP-WAIT #{yielder[:pod].pod_id} at EP#{ezone.ep_id} #{ezone.station_id} — " \
                     "yielding to #{ezone.locked_by} (count=#{ezone.stop_wait_count})"
              end
            end

            # Scale back the proposal's t advancement
            prop = yielder[:proposal]
            pod  = yielder[:pod]
            man  = pod.current_maneuver
            if man && prop[:state] == :traveling
              original_t = prop[:t]
              current_t  = pod.t
              delta_t    = original_t - current_t
              prop[:t]   = current_t + delta_t * speed_factor
            end
          end
        end

        # If entry pod is approaching and zone is clear — lock for entry
        if entry_pod_info && !ezone.locked_by && entry_pod_info[:remaining_mm] < ezone.zone_length_mm
          ezone.locked_by = entry_pod_info[:pod].nora_id
        end
      end
    end

    # ── Session summary — called before reset ────────────────────────────────
    # su-real: produces data physical Natalie needs for dispatch tuning
    def self.session_summary
      summary = { total_stop_waits: 0, junctions: [] }
      @@ezones.each do |z|
        next if z.stop_wait_count == 0
        summary[:total_stop_waits] += z.stop_wait_count
        # Compute average gap between stop-wait events
        times = z.stop_wait_log.map { |e| e[:time] }
        avg_interval = times.size > 1 ? ((times.last - times.first) / (times.size - 1)).round(1) : 0
        summary[:junctions] << {
          ep_id: z.ep_id, station_id: z.station_id,
          stop_wait_count: z.stop_wait_count,
          avg_interval_s: avg_interval,
          unique_yielders: z.stop_wait_log.map { |e| e[:yielder] }.uniq,
          unique_blockers: z.stop_wait_log.map { |e| e[:blocker] }.uniq,
        }
      end
      summary
    end

    # ── Reset — called at animation stop ─────────────────────────────────────
    def self.reset
      # Log session ezone summary to crew journal
      model = Sketchup.active_model rescue nil
      if model && defined?(JPods::CrewJournal)
        total_stops = @@ezones.sum { |z| z.stop_wait_count }
        if total_stops > 0
          hot = @@ezones.select { |z| z.stop_wait_count > 5 }
                        .map { |z| "EP#{z.ep_id}(#{z.stop_wait_count})" }.join(', ')
          JPods::CrewJournal.log(:natalie, model,
            "session: #{total_stops} stop-wait(s)#{hot.empty? ? '' : " — hot: #{hot}"}",
            severity: total_stops > 20 ? :warn : :info,
            data: { total: total_stops, hot_junctions: hot })
        end
      end

      total_stops = @@ezones.sum { |z| z.stop_wait_count }
      if total_stops > 0
        puts "[Natalie ezone] session total: #{total_stops} stop-wait(s) across #{@@ezones.count { |z| z.stop_wait_count > 0 }} junction(s)"
        @@ezones.select { |z| z.stop_wait_count > 0 }.each do |z|
          puts "[Natalie ezone]   EP#{z.ep_id} #{z.station_id}: #{z.stop_wait_count} stop-wait(s) — capacity investigation needed"
          # su-real: log pod pairs for physical dispatch analysis
          pairs = z.stop_wait_log.map { |e| "#{e[:yielder]}←#{e[:blocker]}" }.tally
          pairs.each { |pair, n| puts "[Natalie ezone]     #{pair}: #{n}×" } if pairs.size <= 10
        end
      end
      @@ezones = []
    end

  end
end

# ── Animation v2 — Orchestrator ────────────────────────────────────────────────
#
# The tick loop. Moves pods, enforces spacing, runs ezone checks,
# manages camera follow, dispatches new trips.
#
# Uses: NatalieV2 (routing), NoraV2 (pod movement), SallyV2 (stations),
#       EZone (zipper merge)
#
# ── su-real ──────────────────────────────────────────────────────────────────
# Physical equivalent: main.py ~10Hz control loop on each Pi.
# SU runs one centralized tick for ALL pods at 24fps; physical runs
# one independent loop PER pod at ~10Hz with MQTT coordination.
#
# Architecture difference:
#   - SU: centralized — one process sees all pods, enforces spacing globally
#   - Physical: distributed — each pod sees only MQTT telemetry from others,
#     makes independent speed decisions. No central coordinator in the loop.
#   - This is deliberate: physical system must survive broker lag, pod
#     reboot, network partition. Each Nora is sovereign.
#
# SU simplifications vs physical:
#   - SU proposals are instantaneous; physical motor commands have latency
#     (I2C round-trip ~2ms, CAN ~0.5ms) + motor response time (~50ms)
#   - SU spacing enforcement is frame-perfect; physical relies on ToF
#     hysteresis (50/150mm zones) + ezone time windows for safety
#   - SU random dispatch is timer-based; physical Natalie dispatches based
#     on passenger requests (Alice ticket) or rebalancing need
#   - SU graceful stop sets a flag; physical sends MQTT STOP to all pods
#     with "complete current trip" semantics — each Nora decides when to park
#   - SU resume saves t + maneuver_id; physical saves last_trip.txt with
#     pathId (line index in path array) — resumes from last completed line
#
# What SU animation should log for physical validation:
#   - Per-tick: pod_id, maneuver_id, t, world_xyz, speed_ms
#   - Per-arrival: pod_id, station_id, trip_time_s, maneuver_count
#   - Per-ezone-event: pod_ids involved, speed_factor applied, stop_wait y/n
#   - Per-session: total trips, total stop_waits, per-station throughput
# This data feeds physical Natalie's dispatch tuning and ezone calibration.
# ─────────────────────────────────────────────────────────────────────────────

require 'json'

module JPods
  module AnimationV2

    ANIM_INTERVAL = 1.0 / 24   # 24 fps
    RANDOM_DISPATCH_MIN_S = 3.0
    RANDOM_DISPATCH_MAX_S = 11.0
    RANDOM_HF_MIN_S = 0.5
    RANDOM_HF_MAX_S = 2.0

    @@pods           = []     # Array<NoraV2::Pod>
    @@queues         = {}     # pod_id → Array<Maneuver>
    @@dwelling       = {}     # pod_id → true
    @@timer          = nil
    @@running        = false
    @@paused         = false
    @@graceful_stop  = false
    @@random_on      = false
    @@random_hf      = false
    @@random_t       = 0.0
    @@camera_follow_id = ''
    @@camera_xf_old  = nil
    @@rebalance_t    = 0.0
    @@dwell_start    = {}     # pod_id → Time.now.to_f — when dwelling started

    def self.running?; @@running; end
    def self.paused?; @@paused; end

    # Pause: stop the timer but keep all pod/queue/Sally state intact.
    # Resume restarts the timer from where it left off.
    def self.pause
      return unless @@running && !@@paused
      if @@timer
        UI.stop_timer(@@timer) rescue nil
        @@timer = nil
      end
      @@paused = true
      puts "[Animation v2] paused — reposition camera, then resume"
    end

    def self.resume
      return unless @@paused
      @@paused = false
      _start_timer
      puts "[Animation v2] resumed"
    end
    def self.pods; @@pods; end
    def self.dwelling?(pod_id); @@dwelling.key?(pod_id.to_s); end
    def self._set_dwelling(pod_id); @@dwelling[pod_id.to_s] = true; end
    def self._set_queue(pod_id, queue); @@queues[pod_id.to_s] = queue; end
    def self._undwell(pod_id); @@dwelling.delete(pod_id.to_s); end
    def self._record_exit(sid); @@exit_slot_vacated_at[sid.to_s.downcase] = Time.now.to_f; end

    # ── Start ──────────────────────────────────────────────────────────────

    def self.start(model)
      stop if @@running

      # Check build-required flag — block animation on stale network
      begin
        model_dir  = File.dirname(model.path.to_s)
        model_base = File.basename(model.path.to_s, '.skp')
        nj_path = File.join(model_dir, "#{model_base}.network.json")
        if File.exist?(nj_path)
          nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
          if nj['build_required']
            puts ""
            puts "⚠ BUILD REQUIRED — network changed since last Build."
            puts "  Run Build before starting animation."
            puts ""
            return false
          end
        end
      rescue; end

      # Load routing
      return false unless NatalieV2.load_network(model)

      # ── Pre-flight: validate all station-to-station routes ────────────
      _validate_routes

      # Init Sally — restore saved state if available, otherwise fresh init
      if defined?(SallyV2)
        SallyV2.init(model, NatalieV2.lookup)
        _restore_sally_state(model)
      end

      # Natalie fleet scan — she knows where every pod is
      NatalieV2.scan_fleet(model)

      # Init EZones
      EZone.build_from_network(model) if defined?(EZone)

      # Build pod fleet from model entities
      @@pods = []
      @@queues = {}
      @@dwelling = {}

      model.entities.each do |e|
        next unless e.is_a?(Sketchup::ComponentInstance) && !e.deleted?
        pod_id = e.get_attribute('JPods', 'vehicle_id', '').to_s
        next if pod_id.empty?

        origin_sid = e.get_attribute('JPods', 'parked_station_id', '').to_s.strip.downcase
        dest_sid   = e.get_attribute('JPods', 'destination_station_id', '').to_s.strip.downcase

        # Check for resume state
        resume_json = e.get_attribute('JPods', 'resume_state', '').to_s
        unless resume_json.empty?
          resume = begin; JSON.parse(resume_json); rescue; nil; end
          if resume && resume['v'].to_i >= 2
            pod = _resume_pod(pod_id, e, resume)
            if pod
              @@pods << pod
              e.delete_attribute('JPods', 'resume_state')
              next
            end
          end
          e.delete_attribute('JPods', 'resume_state')
        end

        # Normal dispatch
        speed_ms = e.get_attribute('JPods', 'speed_ms', 8.3).to_f
        pod = NoraV2::Pod.new(pod_id, e, speed_ms: speed_ms)

        if !origin_sid.empty? && !dest_sid.empty? && origin_sid != dest_sid
          route = NatalieV2.plan_route(origin_sid, dest_sid)
          if route
            maneuvers = NatalieV2.build_maneuvers(route)
            unless maneuvers.empty?
              queue = maneuvers.dup
              pod.receive_maneuver(_maneuver_to_hash(queue.shift), seed_pos: e.bounds.center)
              @@queues[pod_id] = queue.map { |m| _maneuver_to_hash(m) }
              puts "[Natalie v2] #{pod_id}: #{origin_sid} → #{dest_sid} (#{maneuvers.size} maneuvers)"
            end
          end
        end

        # Sally v2 registration already done in SallyV2.init() above —
        # no need to register again here.

        @@pods << pod
      end

      # Mark all parked pods as dwelling so random dispatch can pick them up
      @@pods.each do |pod|
        if pod.state == :parked || pod.state != :traveling
          pod.start_dwell(0)  # dwell_until = now → immediately available
          @@dwelling[pod.pod_id] = true
          @@dwell_start[pod.pod_id] = Time.now.to_f
        end
      end

      @@running = true
      @@random_on = true
      @@random_t = _rand_interval

      JPods::Log.network_mode! if defined?(JPods::Log)
      puts "[Animation v2] started — #{@@pods.size} pod(s)"
      JPods::CrewJournal.log(:animation, model, "started — #{@@pods.size} pods, #{SallyV2.stations.size rescue 0} stations") if defined?(JPods::CrewJournal)

      # Start timer
      @@anim_model = model
      _start_timer

      true
    end

    def self._start_timer
      model = @@anim_model
      last_t = [Time.now.to_f]
      @@timer = UI.start_timer(ANIM_INTERVAL, true) do
        begin
          now = Time.now.to_f
          dt  = [now - last_t[0], 0.5].min
          last_t[0] = now
          tick(model, dt)
        rescue => ex
          puts "[Animation v2] tick error: #{ex.message}"
          stop
        end
      end
    end

    # ── Stop ───────────────────────────────────────────────────────────────

    def self.stop
      return unless @@running || @@timer

      # Save resume state for traveling pods
      @@pods.each do |pod|
        next unless pod.state == :traveling
        pod.save_resume_state(@@queues[pod.pod_id])
      end

      # Sally saves her station state — survives stop/start like Nora's resume
      _save_sally_state if defined?(SallyV2)

      # su-real: session summary for physical Natalie dispatch tuning
      _write_session_summary

      if @@timer
        UI.stop_timer(@@timer) rescue nil
        @@timer = nil
      end

      @@pods           = []
      @@queues         = {}
      @@dwelling       = {}
      @@running        = false
      @@graceful_stop  = false
      @@camera_xf_old  = nil

      # Natalie purges old trip reports on stop
      JPods::CrewJournal.purge_trip_reports(Sketchup.active_model) if defined?(JPods::CrewJournal)

      EZone.reset if defined?(EZone)
      SallyV2.reset if defined?(SallyV2)

      puts "[Animation v2] stopped"
    end

    # ── Graceful stop ──────────────────────────────────────────────────────

    def self.graceful_stop!
      return unless @@running
      return if @@graceful_stop
      @@graceful_stop = true
      @@random_on = false

      # Proactive parking rebalance — check if any station is oversubscribed
      if defined?(SallyV2) && defined?(NatalieV2)
        sids = NatalieV2.platform_stations
        demand = {}
        sids.each do |sid|
          st = SallyV2.station(sid)
          next unless st
          parked  = st.parked_pods.size
          inbound = @@pods.count { |p|
            p.state == :traveling &&
            p.entity&.get_attribute('JPods', 'destination_station_id', '').to_s.strip.downcase == sid
          }
          demand[sid] = { parked: parked, inbound: inbound, capacity: st.capacity,
                          surplus: parked + inbound - st.capacity }
          puts "[Natalie v2] #{sid}: #{parked} parked + #{inbound} inbound / #{st.capacity} cap"
        end

        over  = demand.select { |_, d| d[:surplus] > 0 }
        under = demand.select { |_, d| d[:surplus] < 0 }
        if over.any? && under.any?
          puts "[Natalie v2] parking rebalance needed — #{over.size} over, #{under.size} under"
          # TODO: dispatch rebalancing trips from over → under stations
        end
      end

      puts "[Animation v2] graceful stop — completing current trips"
    end

    # ── Tick ───────────────────────────────────────────────────────────────

    def self.tick(model, dt)
      return if @@pods.empty?

      # Camera follow: capture before
      _camera_before

      # Proposals
      proposals = @@pods.map { |pod| pod.propose(dt) }

      # Spacing enforcement
      _enforce_spacing!(proposals)

      # EZone zipper merge
      EZone.enforce_ezone_spacing!(@@pods, proposals, NatalieV2.lookup) if defined?(EZone)

      # Telemetry ping — dense logging at :debug level
      # su-real: matches physical pod MQTT telemetry pings
      if defined?(JPods::Log) && JPods::Log.level == :debug
        @@telemetry_tick = (@@telemetry_tick || 0) + 1
        if @@telemetry_tick % 12 == 0  # every 0.5s at 24fps
          proposals.each do |prop|
            pod = prop[:pod]
            next unless pod.state == :traveling && pod.entity && !pod.entity.deleted?
            pos = pod.entity.bounds.center
            man_id = pod.current_maneuver&.dig(:id).to_s.split('.').last || '?'
            speed = pod.speed_in / NoraV2::INCH_PER_METER
            eff_speed = pod.current_maneuver&.dig(:speed_cap_in)
            speed_s = eff_speed ? "#{(eff_speed / NoraV2::INCH_PER_METER).round(1)}ms(cap)" : "#{speed.round(1)}ms"
            JPods::Log.debug "[telemetry] #{pod.pod_id} t=#{prop[:t].round(3)} #{man_id} " \
              "(#{(pos.x*25.4).round(0)},#{(pos.y*25.4).round(0)},#{(pos.z*25.4).round(0)})mm #{speed_s}"
          end
          # Ezone status
          if defined?(EZone)
            EZone.ezones.each do |ez|
              next unless ez.locked_by
              JPods::Log.debug "[telemetry] ezone EP#{ez.ep_id} #{ez.station_id}: locked by #{ez.locked_by} sw=#{ez.stop_wait_count}"
            end
          end
          # Sally station occupancy
          if defined?(SallyV2) && @@telemetry_tick % 48 == 0  # every 2s
            SallyV2.stations.each do |sid, st|
              JPods::Log.debug "[telemetry] Sally #{sid}: #{st.occupancy}/#{st.capacity} parked, #{st.looping_pods.size} looping"
            end
          end
        end
      end

      # Apply proposals
      arrived_ids = []
      model.start_operation('JPods Animate', true, false, true)
      proposals.each do |prop|
        pod = prop[:pod]
        pod.apply(prop)

        if prop[:state] == :arrived && pod.state == :arrived
          # Try next maneuver
          queue = @@queues[pod.pod_id] || []
          next_man = queue.shift
          if next_man
            # ── Sally takes over at gw_platform ──────────────────────────
            # Nora's trip ends here. Sally assigns a slot and clips
            # gw_platform so the pod animates to that slot. Pod state is
            # :entering — dispatch cannot grab it. When the pod finishes
            # the clipped maneuver, it becomes :parked. ONE code path.
            track_name = next_man[:id].to_s.split('.').last.to_s
            dest_sid = pod.entity.get_attribute('JPods', 'destination_station_id', '').to_s.strip.downcase rescue ''
            if track_name == 'gw_platform' && !dest_sid.empty? && queue.empty? && defined?(SallyV2)
              dst = SallyV2.station(dest_sid)
              if dst && dst.has_capacity?
                # Sally assigns the lowest empty slot
                rec = dst.pod_arrives(pod.pod_id, entity: pod.entity)
                if rec && rec.slot && rec.slot > 0
                  # Clip gw_platform from entry to assigned slot position
                  sp = JPods::Sally.slot_positions_for_station(dest_sid) rescue {}
                  slot_pos = sp[rec.slot]
                  if slot_pos && next_man[:pts] && next_man[:pts].size >= 2
                    clipped = [next_man[:pts].first]
                    next_man[:pts].each_cons(2) do |a, b|
                      clipped << b
                      if b.distance(slot_pos) < a.distance(slot_pos) && b.distance(slot_pos).to_f * 25.4 < 500
                        break
                      end
                    end
                    clipped[-1] = slot_pos
                    clip_len = clipped.each_cons(2).sum { |a, b| a.distance(b).to_f }
                    next_man = { id: next_man[:id], pts: clipped, len: [clip_len, 1e-6].max }
                  end
                  # Mark as :entering — dispatch guard. State becomes :parked
                  # in the arrival handler when the clipped maneuver finishes.
                  rec.state = :entering
                  pod.entity.set_attribute('JPods', 'parking_slot', rec.slot)
                  pod.entity.set_attribute('JPods', 'parked_station_id', dest_sid)
                  puts "[Sally] #{pod.pod_id} → animate to ps#{rec.slot} at #{dest_sid}"
                  # Camera hold
                  if @@camera_follow_id == pod.pod_id
                    UI.start_timer(5.0, false) {
                      @@camera_follow_id = '' if @@camera_follow_id == pod.pod_id
                      @@camera_xf_old = nil
                    }
                  end
                  # next_man has the clipped maneuver — pod will animate it
                end
              elsif dst
                  # ── Station full — Sally tells Natalie to add travel ─────
                  # Pod loops back to the same destination. More travel,
                  # not a different station. Like a hold pattern.
                  puts "[Sally→Natalie] #{pod.pod_id} → #{dest_sid} FULL — adding travel"
                  looped = false
                  if defined?(NatalieV2)
                    # Route from this station back to itself — station loop
                    # Uses hold_loop if available, otherwise exit → circle → re-enter
                    hl_tracks = JPods::Sally.hold_loop_tracks(dest_sid) rescue []
                    if hl_tracks.any?
                      # Hold loop + gw_platform on return
                      fq_tracks = hl_tracks.map { |t| "#{dest_sid}.#{t}" }
                      fq_tracks << "#{dest_sid}.gw_platform"
                      loop_maneuvers = NatalieV2.build_maneuvers(
                        NatalieV2::Route.new(origin_sid: dest_sid, dest_sid: dest_sid,
                          track_ids: fq_tracks, maneuvers: nil, total_length_mm: nil,
                          estimated_s: nil, planned_at: Time.now.utc)
                      )
                      if loop_maneuvers.any?
                        next_man = _maneuver_to_hash(loop_maneuvers.shift)
                        @@queues[pod.pod_id] = loop_maneuvers.map { |m| _maneuver_to_hash(m) }
                        puts "[Natalie] #{pod.pod_id} hold loop at #{dest_sid} (#{loop_maneuvers.size + 1} tracks) — will retry parking"
                        looped = true
                      end
                    end
                    unless looped
                      # Fallback: route out and back through the network
                      # Pick a random neighbor — shuffle so we don't always loop through the same station
                      neighbors = NatalieV2.platform_stations.reject { |s| s == dest_sid }.shuffle
                      neighbors.each do |nb|
                        out_route = NatalieV2.plan_route(dest_sid, nb)
                        back_route = NatalieV2.plan_route(nb, dest_sid)
                        next unless out_route && back_route
                        combined = out_route.track_ids + back_route.track_ids
                        combined_maneuvers = NatalieV2.build_maneuvers(
                          NatalieV2::Route.new(origin_sid: dest_sid, dest_sid: dest_sid,
                            track_ids: combined, maneuvers: nil, total_length_mm: nil,
                            estimated_s: nil, planned_at: Time.now.utc)
                        )
                        if combined_maneuvers.any?
                          next_man = _maneuver_to_hash(combined_maneuvers.shift)
                          @@queues[pod.pod_id] = combined_maneuvers.map { |m| _maneuver_to_hash(m) }
                          puts "[Natalie] #{pod.pod_id} loop via #{nb} back to #{dest_sid} (#{combined_maneuvers.size + 1} tracks)"
                          looped = true
                          break
                        end
                      end
                    end
                  end
                  unless looped
                    puts "[Sally] #{pod.pod_id} → #{dest_sid} — FULL, no loop available"
                  end
              end
            end

            if next_man
              pod.receive_maneuver(next_man, seed_pos: nil)
              pod.instance_variable_set(:@t, 0.0)
              pod.instance_variable_set(:@state, :traveling)
            end
          else
            arrived_ids << pod.pod_id
          end
        end
      end
      model.commit_operation

      # Handle arrivals — pod reached the end of its last maneuver
      arrived_ids.each do |pod_id|
        pod = @@pods.find { |p| p.pod_id == pod_id }
        next unless pod

        # Pod finished its last maneuver. If Sally set :entering during
        # the clip, change to :parked now. Clear inbound. One code path.
        dest_sid = pod.entity.get_attribute('JPods', 'destination_station_id', '').to_s.strip.downcase rescue ''
        if defined?(SallyV2) && !dest_sid.empty?
          dst = SallyV2.station(dest_sid)
          if dst
            dst.clear_inbound(pod_id)
            rec = dst.pod(pod_id)
            if rec && rec.state == :entering
              rec.state = :parked
              puts "[Sally] #{pod_id} PARKED at ps#{rec.slot} at #{dest_sid}"
            end
          end
        end

        # All arriving pods dwell — Sally manages departure timing
        pod.start_dwell
        @@dwelling[pod_id] = true
        @@dwell_start[pod_id] = Time.now.to_f

        # Release camera after hold
        if @@camera_follow_id == pod.pod_id
          UI.start_timer(3.0, false) {
            @@camera_follow_id = '' if @@camera_follow_id == pod.pod_id
            @@camera_xf_old = nil
          }
        end

        if @@graceful_stop
          puts "[Animation v2] #{pod_id} trip complete (graceful stop)"
          next
        end

        # Redispatch
        _redispatch(model, pod)
      end

      # Graceful stop: check if all done
      if @@graceful_stop
        traveling = @@pods.count { |p| p.state == :traveling }
        if traveling == 0
          total = model.entities.count { |e|
            e.is_a?(Sketchup::ComponentInstance) &&
            !e.get_attribute('JPods', 'vehicle_id', '').to_s.empty?
          } rescue @@pods.size
          puts "[Animation v2] graceful stop — all #{total} pod(s) parked"
          stop
          return
        end
      end

      # Random dispatch
      if @@random_on && !@@graceful_stop
        @@random_t -= dt
        if @@random_t <= 0
          @@random_t = _rand_interval
          _random_dispatch(model)
        end
      end

      # Sally periodic tick — conveyor + rebalance
      if !@@graceful_stop && defined?(SallyV2) && defined?(NatalieV2)
        @@rebalance_t = (@@rebalance_t || 0) - dt
        if @@rebalance_t <= 0
          @@rebalance_t = 0.5  # every 0.5 seconds — fast check, lock prevents overlap
          # Shuffle all stations — pods advance toward exit
          NatalieV2.platform_stations.each { |sid| _sally_advance_conveyor(sid, model) }
          # Rebalance overloaded stations
          _rebalance_parking(model)
        end
      end

      # Camera follow: apply delta
      _camera_after(model)
    end

    # ── Random dispatch ────────────────────────────────────────────────────

    def self._random_dispatch(model)
      sids = NatalieV2.platform_stations
      return if sids.size < 2

      sids.each do |sid|
        next if defined?(JPods::DispatchServer) && JPods::DispatchServer.passenger_hold?(sid) rescue false

        # Natalie checks: has enough time passed since last departure?
        next unless NatalieV2.cleared_to_depart?(sid)

        # ── Sally decides who departs ──────────────────────────────────────
        st = defined?(SallyV2) ? SallyV2.station(sid) : nil
        next unless st
        # Only :parked pods are eligible for dispatch — never :entering or :traveling.
        # Top 4 slots must dwell MIN_DWELL_S for passenger unload/load.
        now = Time.now.to_f
        cap = st.capacity
        depart_id = nil
        st.ps.sort_by { |s| -s.number }.each do |s|
          next unless s.occupied? && @@dwelling.key?(s.occupant_id)
          # Check Sally's pod record — must be :parked
          rec = st.pod(s.occupant_id)
          next unless rec && rec.state == :parked
          # Top 4 slots = boarding zone — must dwell
          if s.number > cap - 4
            dwell_elapsed = now - (@@dwell_start[s.occupant_id] || 0)
            next if dwell_elapsed < MIN_DWELL_S
          end
          depart_id = s.occupant_id
          break
        end
        next unless depart_id

        pod = @@pods.find { |p| p.pod_id == depart_id && !p.entity.nil? && !p.entity.deleted? }
        next unless pod

        # Sally authorizes departure FIRST — she vacates the slot
        # Prefer destinations with available capacity — ask Sally
        # Also count pods currently traveling to each destination
        others = sids - [sid]
        with_capacity = others.select { |d|
          dst = SallyV2.station(d)
          next false unless dst && dst.has_capacity?
          # Double-check: count actual traveling pods headed there
          en_route = @@pods.count { |p|
            p.state == :traveling &&
            (p.entity.get_attribute('JPods', 'destination_station_id', '') rescue '').to_s.strip.downcase == d
          }
          dst.occupancy + en_route < dst.capacity
        }
        # Random destination weighted toward stations with capacity —
        # models real passenger demand (people go where they're going,
        # not where there's the most room). Stations at capacity are
        # excluded; remaining candidates are equally weighted.
        dest = if with_capacity.any?
                 with_capacity.sample
               else
                 others.sample
               end
        SallyV2.pod_departs(sid, depart_id, destination: dest)
        @@exit_slot_vacated_at[sid] = Time.now.to_f  # hold conveyor for 3s

        # Natalie routes
        route = NatalieV2.plan_route(sid, dest)
        unless route
          # Route failed — Sally takes pod back
          SallyV2.pod_arrives(sid, depart_id, entity: pod.entity)
          next
        end

        maneuvers = NatalieV2.build_maneuvers(route)
        if maneuvers.empty?
          SallyV2.pod_arrives(sid, depart_id, entity: pod.entity)
          next
        end

        # Nora executes — Sally already authorized, Natalie already planned.
        # Skip gw_platform at origin — Sally owns the platform. The pod is
        # already at its slot. Nora's trip starts at gw_platform_out1.
        pod.entity.set_attribute('JPods', 'destination_station_id', dest)
        queue = maneuvers.map { |m| _maneuver_to_hash(m) }
        if queue.first && queue.first[:id].to_s.split('.').last == 'gw_platform'
          queue.shift  # skip origin gw_platform — Sally handles departure
        end
        pod.receive_maneuver(queue.shift, seed_pos: pod.entity.bounds.center)
        @@queues[pod.pod_id] = queue
        @@dwelling.delete(pod.pod_id)

        # Natalie records the departure — clearance check for next dispatch
        NatalieV2.record_departure(sid, depart_id, dest_sid: dest, route: route)

        # Natalie tells destination Sally: pod is inbound with ETA
        _notify_sally_inbound(dest, depart_id, maneuvers)

        # Sally advances the conveyor — remaining pods move toward exit
        _sally_advance_conveyor(sid, model)

        if defined?(JPods::Log)
          JPods::Log.event "[Natalie] dispatch: #{pod.pod_id} #{sid} → #{dest}"
        else
          puts "[Natalie v2] dispatch: #{pod.pod_id} #{sid} → #{dest}"
        end
      end
    end

    # ── Redispatch after arrival ────────────────────────────────────────────

    # ── Sally-Natalie rebalance — Sally signals at 50% occupancy ────────
    # Sally checks her ps array. At 50% effective occupancy (parked + inbound),
    # she tells Natalie to dispatch an empty to a station with capacity.
    # Natalie informs destination Sally of the inbound pod with ETA.
    def self._rebalance_parking(model)
      sids = NatalieV2.platform_stations
      return if sids.size < 2

      busy = []  # stations Sally says need rebalancing (≥50%)
      open = []  # stations with room
      sids.each do |sid|
        st = SallyV2.station(sid)
        next unless st
        if st.needs_rebalance?
          busy << sid
        elsif st.has_capacity?
          open << sid
        end
      end
      return unless busy.any? && open.any?

      busy.each do |sid|
        st = SallyV2.station(sid)
        next unless st
        highest = st.highest_occupied_slot
        next unless highest
        depart_id = highest.occupant_id
        next unless depart_id && @@dwelling.key?(depart_id)
        # Only :parked pods — never :entering or :traveling
        rec = st.pod(depart_id)
        next unless rec && rec.state == :parked
        pod = @@pods.find { |p| p.pod_id == depart_id && p.entity && !p.entity.deleted? }
        next unless pod

        # Pick destination with most room
        dest = open.min_by { |d| SallyV2.station(d)&.effective_occupancy || 999 }
        SallyV2.pod_departs(sid, depart_id, destination: dest)
        @@exit_slot_vacated_at[sid] = Time.now.to_f
        route = NatalieV2.plan_route(sid, dest)
        unless route
          SallyV2.pod_arrives(sid, depart_id, entity: pod.entity)
          next
        end
        maneuvers = NatalieV2.build_maneuvers(route)
        if maneuvers.empty?
          SallyV2.pod_arrives(sid, depart_id, entity: pod.entity)
          next
        end
        pod.entity.set_attribute('JPods', 'destination_station_id', dest)
        queue = maneuvers.map { |m| _maneuver_to_hash(m) }
        # Skip gw_platform at origin — Sally owns the platform
        if queue.first && queue.first[:id].to_s.split('.').last == 'gw_platform'
          queue.shift
        end
        pod.receive_maneuver(queue.shift, seed_pos: pod.entity.bounds.center)
        @@queues[pod.pod_id] = queue
        @@dwelling.delete(pod.pod_id)
        _notify_sally_inbound(dest, depart_id, maneuvers)
        _sally_advance_conveyor(sid, model)

        if defined?(JPods::Log)
          JPods::Log.event "[Sally→Natalie] rebalance: #{pod.pod_id} #{sid} → #{dest} (#{st.occupancy}/#{st.capacity} ps, #{st.inbound_count} inbound)"
        else
          puts "[Sally→Natalie] rebalance: #{pod.pod_id} #{sid} → #{dest} (#{st.occupancy}/#{st.capacity} ps)"
        end
        break  # one per tick
      end
    rescue => ex
      puts "[Rebalance] error: #{ex.message}"
    end

    # Natalie tells destination Sally a pod is inbound with ETA
    def self._notify_sally_inbound(dest_sid, nora_id, maneuvers)
      return unless defined?(SallyV2)
      dst = SallyV2.station(dest_sid)
      return unless dst
      # Estimate ETA from total maneuver path length / speed
      # Maneuvers may be structs (.len) or hashes (:len)
      total_dist = maneuvers.sum { |m|
        m.respond_to?(:len) ? (m.len || 0) : (m[:len] || 0)
      }
      speed_in = NoraV2::DEFAULT_SPEED_MS * NoraV2::INCH_PER_METER rescue 472.44
      eta_s = speed_in > 0 ? total_dist / speed_in : 30.0
      dst.notify_inbound(nora_id, eta_s: eta_s.round(1), from_sid: nil)
    rescue => ex
      puts "[Natalie→Sally] inbound notify error: #{ex.message}"
    end

    # Travel direction vector from a maneuver's pts at parameter t
    def self._travel_direction(pts, t)
      return nil unless pts && pts.size >= 2
      idx = [(t * (pts.size - 1)).floor, pts.size - 2].max
      a = pts[idx]; b = pts[[idx + 1, pts.size - 1].min]
      dx = b.x - a.x; dy = b.y - a.y
      len = Math.sqrt(dx * dx + dy * dy)
      return nil if len < 1e-6
      Geom::Vector3d.new(dx / len, dy / len, 0)
    rescue
      nil
    end

    # ── Pre-flight route validation ─────────────────────────────────────
    # Tests every station-to-station pair before animation starts.
    # Reports disconnects so the designer can fix them before traffic jams.
    def self._validate_routes
      sids = NatalieV2.platform_stations
      return if sids.size < 2

      puts ""
      puts "┌── Route Validation ──────────────────────────────"
      ok = 0; broken = 0
      sids.each do |from|
        sids.each do |to|
          next if from == to
          route = NatalieV2.plan_route(from, to)
          if route
            maneuvers = NatalieV2.build_maneuvers(route)
            if maneuvers.any?
              ok += 1
            else
              broken += 1
              puts "│ ✗ #{from} → #{to}: route found but no maneuvers (chain gap)"
            end
          else
            broken += 1
            puts "│ ✗ #{from} → #{to}: NO ROUTE"
          end
        end
      end
      total = ok + broken
      if broken == 0
        puts "│ ✓ All #{total} routes valid (#{sids.size} stations)"
      else
        puts "│ ⚠ #{broken}/#{total} routes BROKEN — #{ok} OK"
        puts "│   Fix connections or template chains before running traffic"
      end
      puts "└──────────────────────────────────────────────────"
      puts ""
    rescue => ex
      puts "[Route Validation] error: #{ex.message}"
    end

    def self._redispatch(model, pod)
      pod.start_dwell
      @@dwelling[pod.pod_id] = true
      @@dwell_start[pod.pod_id] = Time.now.to_f  # minimum dwell timer

      return if @@graceful_stop

      e = pod.entity
      return unless e && !e.deleted?

      orig = e.get_attribute('JPods', 'parked_station_id', '').to_s.strip.downcase
      dest = e.get_attribute('JPods', 'destination_station_id', '').to_s.strip.downcase

      # Swap for return trip — pod is now at dest, going back to orig
      if !orig.empty? && !dest.empty? && orig != dest
        e.set_attribute('JPods', 'parked_station_id', dest)
        e.set_attribute('JPods', 'destination_station_id', orig)

        # Tell Sally: pod arrived at dest (already done in arrival handler)
        # The dwelling handler or random dispatch will trigger the return trip
      end
    end

    # ── Sally conveyor — direct entity moves, no animation maneuvers ────
    # Sally owns the platform. She moves pods directly in 3 substeps per
    # slot advance — immediate transforms, no waiting for animation clock.
    # After each pod completes its 3 steps, Sally sees the vacated slot
    # and advances the next pod. All pods shuffle in one tick.
    MIN_DWELL_S = 10.0  # seconds — simulate passenger unload/load at station
    CONVEYOR_SUBSTEPS = 3
    CONVEYOR_EXIT_HOLD_S = 3.0  # seconds to wait before filling ps_max after departure
    @@exit_slot_vacated_at = {}  # sid → Time.now.to_f

    def self._sally_advance_conveyor(sid, model)
      return unless defined?(SallyV2)
      st = SallyV2.station(sid)
      return unless st

      sp = JPods::Sally.slot_positions_for_station(sid) rescue {}
      return if sp.empty?

      # Sally validate runs on demand (Validate button), not on tick — Rule 24

      # Don't fill exit slot until departing pod has cleared
      vacated = @@exit_slot_vacated_at[sid]
      if vacated && (Time.now.to_f - vacated) < CONVEYOR_EXIT_HOLD_S
        return  # hold — departing pod still in exit zone
      end

      # ── First: handle pods at the door (slot 0 / :entering) ──────────
      # These pods just arrived from gw_platform_in2. Sally shuffles them
      # into ps1 (the first slot), then the normal conveyor advances them.
      st.pods.each do |nora_id, rec|
        next unless rec.state == :entering && rec.slot == 0
        target = st.slot(1)  # ps1 — first slot
        next unless target && target.empty?

        adv_pod = @@pods.find { |p| p.pod_id == nora_id }
        next unless adv_pod && adv_pod.entity && !adv_pod.entity.deleted?
        next unless @@dwelling.key?(adv_pod.pod_id)

        to_pos = sp[1]
        next unless to_pos

        # Move pod from door to ps1
        target.occupy!(nora_id)
        rec.slot = 1
        rec.state = :parked

        ent = adv_pod.entity
        plat_entry = NatalieV2.lookup["#{sid}.gw_platform"] rescue nil
        fwd = Geom::Vector3d.new(1, 0, 0)
        if plat_entry && plat_entry[:pts] && plat_entry[:pts].size >= 2
          a, b = plat_entry[:pts][0], plat_entry[:pts][1]
          v = Geom::Vector3d.new(b.x - a.x, b.y - a.y, 0)
          fwd = v.normalize if v.length > 1e-9
        end
        angle = Math.atan2(fwd.y, fwd.x)
        rotate = Geom::Transformation.rotation(Geom::Point3d.new, Geom::Vector3d.new(0,0,1), angle)
        ent.transformation = Geom::Transformation.translation(to_pos) * rotate
        ent.set_attribute('JPods', 'parking_slot', 1)
        puts "[Sally] #{nora_id} entered ps1 at #{sid}"
      end

      # ── Then: advance parked pods toward exit (normal conveyor) ──────
      # Sally's slot data and the entity must stay in sync.
      # Only commit the slot move if the entity moves too.
      st.ps.sort_by { |s| -s.number }.each do |s|
        next unless s.occupied?
        to_num = s.number + 1
        next if to_num > st.capacity
        target = st.slot(to_num)
        next unless target && target.empty?

        nora_id = s.occupant_id
        adv_pod = @@pods.find { |p| p.pod_id == nora_id }
        next unless adv_pod && adv_pod.entity && !adv_pod.entity.deleted?
        # Ensure parked pods are always in dwelling — prevents stuck pods
        @@dwelling[adv_pod.pod_id] = true unless @@dwelling.key?(adv_pod.pod_id)
        @@dwell_start[adv_pod.pod_id] ||= Time.now.to_f

        from_pos = sp[s.number]
        to_pos   = sp[to_num]
        next unless from_pos && to_pos

        # Commit: move both Sally's data AND the entity together
        s.vacate!
        target.occupy!(nora_id)
        rec = st.pod(nora_id)
        rec.slot = to_num if rec

        # Direct transform in substeps — Sally moves the entity herself
        ent = adv_pod.entity
        fwd = Geom::Vector3d.new(to_pos.x - from_pos.x, to_pos.y - from_pos.y, 0)
        fwd_len = fwd.length
        fwd = fwd.normalize if fwd_len > 1e-6
        angle = Math.atan2(fwd.y, fwd.x)
        z_axis = Geom::Vector3d.new(0, 0, 1)
        rotate = Geom::Transformation.rotation(Geom::Point3d.new, z_axis, angle)

        CONVEYOR_SUBSTEPS.times do |step|
          t = (step + 1).to_f / CONVEYOR_SUBSTEPS
          pt = Geom::Point3d.new(
            from_pos.x + (to_pos.x - from_pos.x) * t,
            from_pos.y + (to_pos.y - from_pos.y) * t,
            from_pos.z + (to_pos.z - from_pos.z) * t
          )
          ent.transformation = Geom::Transformation.translation(pt) * rotate
        end

        ent.set_attribute('JPods', 'parking_slot', to_num)
      end
    end

    # ── Spacing enforcement ────────────────────────────────────────────────

    # ── Personal space enforcement ──────────────────────────────────────
    # su-real: physical has three-zone ToF:
    #   < 50mm (personal space) → stop
    #   50-150mm (care zone) → proportional speed reduction
    #   > 150mm (clear) → full speed
    #
    # SU implements the same three zones using world-space distance between
    # ALL pod entities — not just same-segment. This prevents pods from
    # driving through parked pods or overtaking on adjacent tracks.

    # Personal space zones — station (parked) vs traveling
    # Station: tight spacing (pods are on platform, Sally manages)
    # Traveling: 1500mm personal space (pod length + clearance)
    # Personal space — in SketchUp inches (converted from metres)
    # Station spacing is TIGHT — pods park adjacent in slots ~3m apart.
    # A pod must be able to reach its slot, so station personal space
    # is just physical overlap protection (0.5m), not comfort spacing.
    # Guideway spacing is the passenger comfort zone.
    STATION_PERSONAL_IN = 0.5.m    # 0.5m — physical overlap only (pods park tight)
    STATION_CARE_IN     = 2.0.m    # 2m — gentle slow on approach to parked pods
    TRAVEL_PERSONAL_IN  = 5.0.m    # 5m — hard stop between traveling pods
    TRAVEL_CARE_IN      = 10.0.m   # 10m — proportional slow between traveling
    SAME_SEG_MIN_IN     = 5.0.m    # 5m — same-segment minimum gap

    def self._enforce_spacing!(proposals)
      # Phase 1: same-segment spacing (original logic — t-based)
      by_seg = Hash.new { |h, k| h[k] = [] }
      proposals.each do |prop|
        next unless prop[:state] == :traveling
        seg_id = prop[:pod].current_maneuver&.dig(:id).to_s
        next if seg_id.empty?
        by_seg[seg_id] << prop
      end

      by_seg.each do |_, seg_props|
        next if seg_props.size < 2
        seg_props.sort_by! { |p| -p[:t] }
        seg_len = seg_props.first[:pod].current_maneuver&.dig(:len).to_f
        next if seg_len < 1e-9
        min_t = SAME_SEG_MIN_IN / seg_len
        seg_props.each_cons(2) do |leader, follower|
          if leader[:t] - follower[:t] < min_t
            follower[:t] = [leader[:t] - min_t, 0.0].max
          end
        end
      end

      # Phase 2: cross-segment personal space (world-space distance)
      # Only check pods that share a track or are on successive tracks
      # in the same route. Pods on different sides of a traffic circle
      # should NOT slow each other — the ezone handles merge conflicts.
      traveling = proposals.select { |p| p[:state] == :traveling }
      return if traveling.empty?

      traveling.each do |prop|
        pod = prop[:pod]
        next unless pod.entity && !pod.entity.deleted?
        my_pos = pod.entity.bounds.center
        my_seg = pod.current_maneuver&.dig(:id).to_s

        @@pods.each do |other|
          next if other.pod_id == pod.pod_id
          next unless other.entity && !other.entity.deleted?

          # Only check personal space for:
          # 1. Pods on the SAME segment (already handled in Phase 1 by t-based check)
          # 2. Pods on ADJACENT segments (my next segment = their current, or vice versa)
          # 3. Parked pods at stations we're approaching
          # Skip pods on unrelated segments (e.g. opposite side of traffic circle)
          other_seg = other.current_maneuver&.dig(:id).to_s
          other_traveling = other.state == :traveling

          if other_traveling
            # Only check if on same or adjacent segment
            next if my_seg == other_seg  # Phase 1 handles same-segment
            my_queue = @@queues[pod.pod_id] || []
            next_seg = my_queue.first&.dig(:id).to_s
            # Adjacent: other is on my next segment, or I'm on other's next
            other_queue = @@queues[other.pod_id] || []
            other_next = other_queue.first&.dig(:id).to_s
            adjacent = (next_seg == other_seg) || (other_next == my_seg)
            next unless adjacent

            # Skip if pods are traveling in OPPOSITE directions (diverging).
            # After a U-turn, the pod reversed direction — a pod behind it on
            # the outbound track is diverging, not converging. No collision.
            my_man = pod.current_maneuver
            other_man = other.current_maneuver
            if my_man && my_man[:pts] && my_man[:pts].size >= 2 &&
               other_man && other_man[:pts] && other_man[:pts].size >= 2
              my_fwd = _travel_direction(my_man[:pts], pod.t)
              oth_fwd = _travel_direction(other_man[:pts], other.t)
              if my_fwd && oth_fwd
                dir_dot = my_fwd.x * oth_fwd.x + my_fwd.y * oth_fwd.y
                next if dir_dot < -0.3  # opposing directions — diverging, skip
              end
            end
          end

          other_pos = other.entity.bounds.center
          dist = my_pos.distance(other_pos).to_f

          personal = other_traveling ? TRAVEL_PERSONAL_IN : STATION_PERSONAL_IN
          care     = other_traveling ? TRAVEL_CARE_IN     : STATION_CARE_IN

          next if dist > care

          # Determine if the other pod is AHEAD or BEHIND
          # Use dot product of my travel direction with vector to other pod
          man = pod.current_maneuver
          ahead = true  # default: treat as ahead (slow down)
          if man && man[:pts] && man[:pts].size >= 2
            # Forward direction from current interpolated position
            idx = [(pod.t * (man[:pts].size - 1)).floor, man[:pts].size - 2].max
            a = man[:pts][idx]; b = man[:pts][[idx + 1, man[:pts].size - 1].min]
            fwd_x = b.x - a.x; fwd_y = b.y - a.y
            fwd_len = Math.sqrt(fwd_x * fwd_x + fwd_y * fwd_y)
            if fwd_len > 1e-6
              # Vector from me to other
              to_x = other_pos.x - my_pos.x
              to_y = other_pos.y - my_pos.y
              dot = (fwd_x * to_x + fwd_y * to_y) / fwd_len
              ahead = dot > 0  # positive dot = other is ahead of me
            end
          end

          if ahead
            # Other pod is AHEAD — slow down or stop
            if dist < personal
              prop[:t] = pod.t  # hard stop
              if defined?(JPods::Log)
                JPods::Log.debug "[spacing] #{pod.pod_id} STOP — #{(dist*25.4).round(0)}mm ahead: #{other.pod_id}"
              end
            else
              scale = ((dist - personal) / (care - personal)).clamp(0.0, 1.0)
              original_dt = prop[:t] - pod.t
              prop[:t] = pod.t + original_dt * scale
              if defined?(JPods::Log) && scale < 0.5
                JPods::Log.debug "[spacing] #{pod.pod_id} SLOW #{(scale*100).round(0)}% — #{(dist*25.4).round(0)}mm ahead: #{other.pod_id}"
              end
            end
          else
            # Other pod is BEHIND — speed up to create gap
            if dist < care
              # Boost: closer = more boost, max 1.5x
              boost = 1.0 + (1.0 - (dist / care).clamp(0.0, 1.0)) * 0.5
              original_dt = prop[:t] - pod.t
              prop[:t] = [pod.t + original_dt * boost, 1.0].min
              if defined?(JPods::Log) && boost > 1.2
                JPods::Log.debug "[spacing] #{pod.pod_id} BOOST #{(boost*100).round(0)}% — #{(dist*25.4).round(0)}mm behind: #{other.pod_id}"
              end
            end
          end
        end
      end
    end

    # ── Camera follow (ene_railroad pattern) ──────────────────────────────

    def self._camera_before
      vid = @@camera_follow_id.to_s
      @@camera_xf_old = nil
      return if vid.empty?
      pod = @@pods.find { |p| p.pod_id == vid }
      return unless pod && pod.entity && !pod.entity.deleted?
      @@camera_xf_old = pod.entity.transformation
    rescue
      @@camera_xf_old = nil
    end

    def self._camera_after(model)
      return unless @@camera_xf_old
      vid = @@camera_follow_id.to_s
      return if vid.empty?
      pod = @@pods.find { |p| p.pod_id == vid }
      return unless pod && pod.entity && !pod.entity.deleted?
      xf_new = pod.entity.transformation

      # Translate the camera by the pod's movement delta — but preserve the
      # user's viewing angle. The user can orbit/rotate freely while the
      # camera tracks the pod's position.
      old_pos = @@camera_xf_old.origin
      new_pos = xf_new.origin
      dx = new_pos.x - old_pos.x
      dy = new_pos.y - old_pos.y
      dz = new_pos.z - old_pos.z
      move = Geom::Vector3d.new(dx, dy, dz)

      cam = model.active_view.camera
      cam.set(cam.eye.offset(move), cam.target.offset(move), cam.up)
    rescue
      nil
    end

    def self.camera_follow_id; @@camera_follow_id; end

    # Camera offset defaults (metres) — behind travel vector, right of vector, above pod.
    @@camera_back  = 25.0
    @@camera_right = 20.0
    @@camera_up    = 5.0

    def self.camera_offsets; { back: @@camera_back, right: @@camera_right, up: @@camera_up }; end

    def self.set_camera_offsets(back, right, up)
      @@camera_back  = back.to_f  if back.to_f > 0
      @@camera_right = right.to_f if right.to_f >= 0
      @@camera_up    = up.to_f    if up.to_f >= 0
    end

    def self.set_camera_follow(pod_id)
      @@camera_follow_id = pod_id.to_s
      # Snap camera to fixed offset on follow start
      return if pod_id.to_s.empty?
      pod = @@pods.find { |p| p.pod_id == pod_id.to_s }
      return unless pod && pod.entity && !pod.entity.deleted?
      _snap_camera_to_pod(pod, Sketchup.active_model)
    end

    # Position camera at fixed offset relative to pod's travel direction.
    # back = metres behind (opposite travel vector)
    # right = metres to the right of travel vector
    # up = metres above pod
    def self._snap_camera_to_pod(pod, model)
      return unless pod && pod.entity && !pod.entity.deleted?
      xf = pod.entity.transformation
      pod_pos = xf.origin

      # Travel direction from the pod's Y axis (SketchUp component forward)
      fwd = xf.yaxis.normalize rescue Geom::Vector3d.new(0, 1, 0)
      right_v = Geom::Vector3d.new(fwd.y, -fwd.x, 0)  # perpendicular right in XY
      right_v = right_v.normalize rescue Geom::Vector3d.new(1, 0, 0)

      eye = Geom::Point3d.new(
        pod_pos.x - fwd.x * @@camera_back.m + right_v.x * @@camera_right.m,
        pod_pos.y - fwd.y * @@camera_back.m + right_v.y * @@camera_right.m,
        pod_pos.z + @@camera_up.m
      )
      target = Geom::Point3d.new(
        pod_pos.x + fwd.x * 12.m,
        pod_pos.y + fwd.y * 12.m,
        pod_pos.z
      )
      cam = model.active_view.camera
      cam.set(eye, target, Z_AXIS)
    rescue => e
      puts "[Camera] snap error: #{e.message}"
    end

    # ── Resume a pod from saved state ──────────────────────────────────────

    def self._resume_pod(pod_id, entity, resume)
      man_id = resume['maneuver_id'].to_s
      entry = NatalieV2.lookup[man_id] || NatalieV2.lookup[man_id.downcase]
      return nil unless entry && entry[:pts].is_a?(Array) && entry[:pts].size >= 2

      speed_ms = resume['speed_ms'].to_f
      speed_ms = NoraV2::DEFAULT_SPEED_MS if speed_ms < 0.1
      pod = NoraV2::Pod.new(pod_id, entity, speed_ms: speed_ms)

      # Direction recovery
      man_pts = entry[:pts]
      if resume['man_start'].is_a?(Array)
        saved = Geom::Point3d.new(*resume['man_start'])
        man_pts = man_pts.reverse if saved.distance(man_pts.last) < saved.distance(man_pts.first)
      end
      man_len = man_pts.each_cons(2).sum { |a, b| a.distance(b).to_f }

      pod.receive_maneuver({ id: man_id, pts: man_pts, len: [man_len, 1e-6].max },
                           seed_pos: entity.bounds.center)

      # Rebuild remaining queue with direction recovery
      remaining = Array(resume['remaining']).filter_map do |rd|
        rid = rd.is_a?(Hash) ? rd['id'].to_s : rd.to_s
        re = NatalieV2.lookup[rid] || NatalieV2.lookup[rid.to_s.downcase]
        next unless re && re[:pts].is_a?(Array) && re[:pts].size >= 2
        pts = re[:pts]
        if rd.is_a?(Hash) && rd['sp'].is_a?(Array)
          sp = Geom::Point3d.new(*rd['sp'])
          pts = pts.reverse if sp.distance(pts.last) < sp.distance(pts.first)
        end
        r_len = pts.each_cons(2).sum { |a, b| a.distance(b).to_f }
        { id: rid, pts: pts, len: [r_len, 1e-6].max }
      end
      @@queues[pod_id] = remaining

      dest_r = resume['dest_sid'].to_s
      entity.set_attribute('JPods', 'destination_station_id', dest_r) unless dest_r.empty?

      puts "[Nora v2] #{pod_id} ▶ resumed — #{man_id} t=#{pod.t.round(3)} + #{remaining.size} remaining"
      pod
    end

    # ── Helpers ─────────────────────────────────────────────────────────────

    def self._maneuver_to_hash(m)
      return m if m.is_a?(Hash)
      h = { id: m.id, pts: m.pts, len: m.len }
      # su-real: compute speed cap from min curve radius (physical maxLateralG)
      h[:speed_cap_in] = _speed_cap_from_pts(m.pts)
      h
    end

    # su-real: compute max speed (inches/s) from minimum curve radius in pts.
    # Physical formula: max_speed = sqrt(maxLateralG * g * radius)
    # Matches physical mapSM.json curveRadius + maxLateralG = 0.3
    MAX_LATERAL_G = 0.3
    G_IN_S2 = 386.09  # gravity in inches/s² (9810 mm/s² / 25.4)

    def self._speed_cap_from_pts(pts)
      return nil unless pts.is_a?(Array) && pts.size >= 3
      min_radius = Float::INFINITY
      pts.each_cons(3) do |a, b, c|
        r = _circumradius(a, b, c)
        min_radius = r if r && r < min_radius
      end
      return nil if min_radius > 1e6  # straight — no cap needed
      # max_speed_in_per_s = sqrt(lateralG * g_in * radius_in)
      Math.sqrt(MAX_LATERAL_G * G_IN_S2 * min_radius)
    end

    # su-real: write session summary to process/inbox for Allie + physical Natalie
    def self._write_session_summary
      return if @@pods.empty? && !defined?(EZone)

      # Per-station throughput from Sally
      station_data = {}
      if defined?(SallyV2)
        SallyV2.stations.each do |sid, st|
          station_data[sid] = {
            capacity: st.capacity,
            parked: st.parked_pods.size,
            total_arrivals: st.ps.sum { |s| s.arrival_count || 0 },
            high_turnover_slots: st.ps.select { |s| (s.arrival_count || 0) > 5 }.map { |s| "ps#{s.number}(#{s.arrival_count})" },
          }
        end
      end

      # EZone data
      ezone_data = defined?(EZone) ? EZone.session_summary : {}

      summary = {
        timestamp: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        pod_count: @@pods.size,
        stations: station_data,
        ezones: ezone_data,
      }

      # Write to process/inbox
      inbox = File.expand_path('~/Allie/process/inbox')
      if File.directory?(inbox)
        ts = Time.now.utc.strftime('%Y%m%dT%H%M%S')
        path = File.join(inbox, "#{ts}-anim-session-summary.json")
        File.write(path, JSON.pretty_generate(summary), encoding: 'utf-8')
        puts "[Animation v2] session summary → #{File.basename(path)}"
      end

      # Console summary
      puts "[Animation v2] session: #{@@pods.size} pods, #{station_data.size} stations"
      station_data.each do |sid, d|
        puts "  #{sid}: #{d[:total_arrivals]} arrivals, #{d[:parked]}/#{d[:capacity]} parked"
      end
    rescue => ex
      puts "[Animation v2] session summary error: #{ex.message}"
    end

    # Circumradius of triangle formed by three Point3d (2D projection)
    def self._circumradius(a, b, c)
      ax = a.x.to_f; ay = a.y.to_f
      bx = b.x.to_f; by = b.y.to_f
      cx = c.x.to_f; cy = c.y.to_f
      # Twice the signed area
      d = 2.0 * ((bx - ax) * (cy - ay) - (by - ay) * (cx - ax))
      return nil if d.abs < 1e-12  # collinear
      ab2 = (bx - ax)**2 + (by - ay)**2
      bc2 = (cx - bx)**2 + (cy - by)**2
      ca2 = (ax - cx)**2 + (ay - cy)**2
      a_len = Math.sqrt(ab2)
      b_len = Math.sqrt(bc2)
      c_len = Math.sqrt(ca2)
      (a_len * b_len * c_len) / d.abs
    end

    def self._rand_interval
      min_s = @@random_hf ? RANDOM_HF_MIN_S : RANDOM_DISPATCH_MIN_S
      max_s = @@random_hf ? RANDOM_HF_MAX_S : RANDOM_DISPATCH_MAX_S
      min_s + rand * (max_s - min_s)
    end

    def self.toggle_random_hf
      @@random_hf = !@@random_hf
      puts "[Animation v2] HF #{@@random_hf ? 'ON (0.5–2s)' : 'OFF (3–11s)'}"
      @@random_hf
    end

    # ── Sally state persistence — survives stop/start ──────────────────
    # Sally saves her pods[] and ps[] per station, just like Nora saves
    # resume positions. On restart, Sally restores from the saved state
    # so pods don't disappear from her arrays.

    @@sally_saved_state = nil  # in-memory — lasts for the SU session

    def self._save_sally_state
      return unless defined?(SallyV2)
      @@sally_saved_state = {}
      SallyV2.stations.each do |sid, st|
        @@sally_saved_state[sid] = {
          slots: st.ps.map { |s| { number: s.number, state: s.state, occupant_id: s.occupant_id } },
          pods: st.pods.map { |nid, rec| { nora_id: nid, state: rec.state, slot: rec.slot } },
        }
      end
      puts "[Sally] state saved — #{@@sally_saved_state.size} station(s)"
    end

    def self._restore_sally_state(model)
      return unless @@sally_saved_state && !@@sally_saved_state.empty?
      return unless defined?(SallyV2)

      restored = 0
      @@sally_saved_state.each do |sid, saved|
        st = SallyV2.station(sid)
        next unless st

        # Restore slot occupants
        saved[:slots].each do |ss|
          ps = st.slot(ss[:number])
          next unless ps
          if ss[:state] == :occupied && ss[:occupant_id]
            # Find the entity in the model
            ent = model.entities.find { |e|
              e.is_a?(Sketchup::ComponentInstance) && !e.deleted? &&
              e.get_attribute('JPods', 'vehicle_id', '').to_s == ss[:occupant_id]
            }
            if ent
              ps.occupy!(ss[:occupant_id])
              st.register_pod(ss[:occupant_id], entity: ent, slot_num: ss[:number], state: :parked)
              restored += 1
            end
          end
        end
      end

      if restored > 0
        puts "[Sally] state restored — #{restored} pod(s) across #{@@sally_saved_state.size} station(s)"
      end
      @@sally_saved_state = nil  # consumed
    end

  end
end

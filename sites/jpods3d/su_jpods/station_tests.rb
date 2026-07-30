# ── Station Tests v3 — unified with network behavior ──────────────────────────
#
# One code path: tests use the same Sally/Natalie/AnimationV2 code as the
# network animation. No separate dispatch timing, no manual advance, no
# parallel implementation.
#
# Each test:
#   1. Init Sally + Natalie for the template
#   2. Place pods at correct positions, register with Sally
#   3. Use SallyV2.pod_departs / NatalieV2 for dispatch (same as network)
#   4. Start template animation via AnimationV2 (same engine)
#   5. Sally's conveyor advance runs in the animation tick (same as network)
#
# The console calls these via StationTests.run(model, test_id, ...)

require 'json'

module JPods
  module StationTests

    # Pod colors — different per role so mistakes are visible at a glance
    POD_COLORS = %w[passenger_Yellow passenger_Blue passenger_Red passenger_Green].freeze

    def self._pod_color(index)
      POD_COLORS[index % POD_COLORS.size]
    end

    def self._load_pod(model, color_id)
      JPods::PodHelpers.load_pod_definition(model, color_id)
    end

    # ── Shared helpers ─────────────────────────────────────────────────────

    def self._init_station(model, station_id, fid, plugin_dir, template_lookup)
      JPods::Sally.init_sequencer_for_station(station_id, fid, plugin_dir)
      JPods::Sally.init_from_model(model, template_lookup)
    end

    def self._clear_test_entities(model)
      to_erase = model.entities.select { |e|
        (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Text)) &&
        (e.get_attribute('JPods', 'station_test', '').to_s == 'true' rescue false)
      }
      model.entities.erase_entities(to_erase) unless to_erase.empty?

      # Clear stale pods from AnimationV2 — prior tests accumulate deleted entities
      if defined?(AnimationV2)
        stale = AnimationV2.pods.select { |p| p.entity.nil? || p.entity.deleted? }
        stale.each { |p| AnimationV2._undwell(p.pod_id) }
        AnimationV2.pods.reject! { |p| p.entity.nil? || p.entity.deleted? }
      end
    end

    def self._fwd_from_pts(pts)
      return Geom::Vector3d.new(1, 0, 0) unless pts.is_a?(Array) && pts.size >= 2
      a, b = pts[0], pts[1]
      v = Geom::Vector3d.new(b.x - a.x, b.y - a.y, 0)
      v.length > 1e-9 ? v.normalize : Geom::Vector3d.new(1, 0, 0)
    end

    # Place a pod, assign NORA ID, register with Sally, create AnimationV2 pod
    def self._place_and_register(model, station_id, slot, color_idx, plat_pts, sp)
      color = _pod_color(color_idx)
      slot_defn = _load_pod(model, color)
      return nil unless slot_defn

      slot_placed = JPods::Sally.place_vehicles_at_slots(model, station_id, slot_defn, [slot], plat_pts)
      ent = slot_placed[slot]
      return nil unless ent

      nora_num = JPods::PodHelpers.next_nora_num(model)
      vid = format('NORA_%04d', nora_num)
      ent.set_attribute('JPods', 'speed_ms', NoraV2::DEFAULT_SPEED_MS)
      ent.set_attribute('JPods', 'vehicle_num', nora_num)
      ent.set_attribute('JPods', 'vehicle_template_id', color)
      ent.set_attribute('JPods', 'vehicle_id', vid)
      ent.set_attribute('JPods', 'parked_station_id', station_id)
      ent.set_attribute('JPods', 'parking_slot', slot)
      ent.set_attribute('JPods', 'station_test', 'true')
      ent.set_attribute('JPods', 'template_model_id', station_id)
      JPods::PodHelpers.assign_nora_tag(ent, vid, model)

      # Register with Sally — she is the authority
      if defined?(SallyV2)
        st = SallyV2.station(station_id)
        st.register_pod(vid, entity: ent, slot_num: slot, state: :parked) if st
      end

      # Create AnimationV2 pod — same object the network uses
      pod = nil
      if defined?(NoraV2) && defined?(AnimationV2)
        pod = NoraV2::Pod.new(vid, ent, speed_ms: NoraV2::DEFAULT_SPEED_MS)
        AnimationV2.pods << pod
        pod.start_dwell(0)  # immediately available for conveyor
        AnimationV2._set_dwelling(vid)
      end

      { vid: vid, ent: ent, slot: slot, pod: pod }
    end

    # Orient plat_pts entry-first using ps1
    def self._orient_plat_pts(plat_pts, sp)
      ps1 = sp[1]
      return plat_pts unless ps1
      d0 = plat_pts.first.distance(ps1).to_f
      dn = plat_pts.last.distance(ps1).to_f
      dn < d0 ? plat_pts.reverse : plat_pts
    end

    # Dispatch a pod using Natalie — same code path as network
    def self._dispatch_via_natalie(station_id, vid, dest_sid, pod)
      return false unless defined?(SallyV2) && defined?(NatalieV2) && defined?(AnimationV2)

      SallyV2.pod_departs(station_id, vid, destination: dest_sid)
      pod.entity.set_attribute('JPods', 'destination_station_id', dest_sid)

      route = NatalieV2.plan_route(station_id, dest_sid)
      return false unless route

      maneuvers = NatalieV2.build_maneuvers(route)
      return false if maneuvers.empty?

      queue = maneuvers.map { |m| AnimationV2.send(:_maneuver_to_hash, m) }
      pod.receive_maneuver(queue.shift, seed_pos: pod.entity.bounds.center)
      AnimationV2.send(:_set_queue, pod.pod_id, queue)
      AnimationV2.send(:_undwell, pod.pod_id)

      NatalieV2.record_departure(station_id, vid, dest_sid: dest_sid)
      true
    end

    # ── Shuffle Test ───────────────────────────────────────────────────────
    #
    # 3 pods on platform. Runner (ps_max) departs on hold_loop, probes
    # advance toward exit (conveyor). Runner returns, Sally assigns slot.
    #
    # Uses the same AnimationV2 engine and Sally conveyor as the network.

    def self.shuffle(model, station_id, defn, template_lookup, plat_pts, dialog)
      fid = station_id
      plugin_dir = File.dirname(__FILE__)

      _init_station(model, station_id, fid, plugin_dir, template_lookup)
      _clear_test_entities(model)

      sp = JPods::Sally.slot_positions_for_station(station_id)
      cap = sp.size
      raise "No slot positions for #{station_id}" if cap < 2

      plat_pts = _orient_plat_pts(plat_pts, sp)

      # Place 3 pods at last 3 slots
      slot_front = cap
      slot_mid   = [cap - 1, 1].max
      slot_deep  = [cap - 2, 1].max
      slots = [slot_deep, slot_mid, slot_front].uniq

      model.start_operation('Shuffle Test Place Pods', true)
      all_pod_info = []
      slots.each_with_index do |slot, i|
        role = slot == slot_front ? :runner : :probe
        info = _place_and_register(model, station_id, slot, i, plat_pts, sp)
        next unless info
        info[:role] = role
        all_pod_info << info
        JPods::Log.event "[shuffle] #{info[:vid]} #{role} at ps#{slot} (#{_pod_color(i)})"
      end
      model.commit_operation

      raise "Could not place pods" unless all_pod_info.size == slots.size

      # Log Sally's state
      if defined?(SallyV2)
        st = SallyV2.station(station_id)
        if st
          JPods::Log.info "[Sally] #{st.summary}"
          JPods::Log.detail "[Sally] #{st.slot_summary}"
          st.pods.each { |nid, rec| JPods::Log.detail "[Sally] pod #{nid}: state=#{rec.state} slot=ps#{rec.slot}" }
        end
      end

      runner = all_pod_info.find { |p| p[:role] == :runner }

      # ── Runner starts hold_loop — use Sally's loop protocol ─────────
      if defined?(SallyV2)
        SallyV2.pod_starts_loop(station_id, runner[:vid])
        JPods::Log.event "[Sally] #{runner[:vid]} starts loop from ps#{slot_front}"
        # Record exit time so conveyor respects the hold — same as network dispatch
        if defined?(AnimationV2)
          AnimationV2.send(:_record_exit, station_id)
        end
      end

      # Build runner maneuvers from hold_loop chain — same chain data Natalie uses
      hl_tracks = JPods::Sally.hold_loop_tracks(station_id)
      raise "No hold_loop tracks for #{station_id}" if hl_tracks.empty?
      hl_tracks = hl_tracks + ['gw_platform'] unless hl_tracks.last == 'gw_platform'
      fq_hl = hl_tracks.map { |t| "#{station_id}.#{t}" }
      runner[:ent].set_attribute('JPods', 'sally_transit_tracks', fq_hl.to_json)
      runner[:ent].set_attribute('JPods', 'station_test_phase', 'parking')

      # Sally's conveyor advance runs in AnimationV2._sally_advance_conveyor
      # during the animation tick — same code as network. No manual advance here.

      # Log Sally state before animation
      if defined?(SallyV2)
        st = SallyV2.station(station_id)
        JPods::Log.info "[Sally] after loop start: #{st.summary}" if st
      end

      # Start animation — same engine as network
      ok = JPods::JPodVehicleAnim.start_for_template(model, template_lookup)
      raise "Template animation failed to start." unless ok

      JPods::Log.info "[shuffle] animation started — #{runner[:vid]} departs, #{all_pod_info.size - 1} probes advance via Sally conveyor"
      { runner: runner[:vid], test: 'shuffle', pod_count: all_pod_info.size, station_id: station_id }
    end

    # ── Departure Test ─────────────────────────────────────────────────────
    #
    # Fill all platform slots. Sequential departure with conveyor:
    #   1. Pod at ps_max departs via exit chain — Sally/Natalie dispatch
    #   2. Sally advances remaining pods (conveyor in AnimationV2 tick)
    #   3. Next pod at ps_max departs via alternate CP
    #
    # Uses SallyV2.pod_departs and exit chains — same as network dispatch.
    # Sally's conveyor runs in AnimationV2._sally_advance_conveyor.

    def self.departure(model, station_id, defn, template_lookup, plat_pts, dialog)
      fid = station_id
      plugin_dir = File.dirname(__FILE__)

      _init_station(model, station_id, fid, plugin_dir, template_lookup)
      _clear_test_entities(model)

      sp = JPods::Sally.slot_positions_for_station(station_id)
      cap = sp.size
      raise "No slot positions for #{station_id}" if cap == 0

      plat_pts = _orient_plat_pts(plat_pts, sp)

      # Get exit chains — alternate between CPs
      seq = JPods::Sally.sequencer_for(station_id)
      raise "No sequencer for #{station_id}" unless seq
      exit_chains = seq[:exit_chains] || {}
      exit_keys = exit_chains.keys.reject { |k| k == 'note' }.sort
      raise "No exit_chains for #{station_id}" if exit_keys.empty?

      # Place pods at all slots
      all_slots = (1..cap).to_a
      model.start_operation('Departure Test Place Pods', true)
      all_pod_info = []
      all_slots.each_with_index do |slot, i|
        info = _place_and_register(model, station_id, slot, i, plat_pts, sp)
        next unless info
        all_pod_info << info
        JPods::Log.event "[departure] #{info[:vid]} placed at ps#{slot}"
      end
      model.commit_operation

      # Log Sally initial state
      if defined?(SallyV2)
        st = SallyV2.station(station_id)
        JPods::Log.info "[Sally] #{st.summary}" if st
        JPods::Log.detail "[Sally] #{st.slot_summary}" if st
      end

      # ── Sally enforces departure order: ps_max only ──────────────────
      # Dispatch 2 pods sequentially, one via each CP.
      # Sally's conveyor runs in AnimationV2._sally_advance_conveyor.
      departed_count = 0
      num_departures = [2, exit_keys.size, cap].min

      num_departures.times do |dep_idx|
        st = defined?(SallyV2) ? SallyV2.station(station_id) : nil
        highest_occ = st ? st.highest_occupied_slot : nil
        next unless highest_occ

        pod_info = all_pod_info.find { |p|
          p[:slot] == highest_occ.number && p[:ent] && !p[:ent].deleted? &&
          p[:ent].get_attribute('JPods', 'station_test_phase', '').to_s != 'exiting'
        }
        next unless pod_info

        # Exit chain tracks — same chain data the network uses
        exit_key = exit_keys[dep_idx % exit_keys.size]
        exit_tracks = Array(exit_chains[exit_key]['tracks'])
        fq_tracks = exit_tracks.map { |t| "#{station_id}.#{t}" }

        # Use Sally's departure protocol — same as network
        pod_info[:ent].set_attribute('JPods', 'sally_transit_tracks', fq_tracks.to_json)
        pod_info[:ent].set_attribute('JPods', 'station_test_phase', 'exiting')
        SallyV2.pod_departs(station_id, pod_info[:vid]) if st
        # Record exit time so conveyor respects 3-second hold — same as network
        AnimationV2._record_exit(station_id) if defined?(AnimationV2)
        departed_count += 1

        JPods::Log.event "[departure] #{pod_info[:vid]} departs ps#{pod_info[:slot]} via #{exit_key} (Sally authorized — ps_max)"

        # Log Sally state after each departure
        if st
          JPods::Log.info "[Sally] after departure #{dep_idx + 1}: #{st.summary}"
          JPods::Log.detail "[Sally] ps: #{st.slot_summary}"
          st.pods.each { |nid, prec| JPods::Log.detail "[Sally] pod #{nid}: state=#{prec.state} slot=ps#{prec.slot}" }
        end
      end

      # Start animation — conveyor advance handled by AnimationV2
      ok = JPods::JPodVehicleAnim.start_for_template(model, template_lookup)
      raise "Template animation failed to start." unless ok

      JPods::Log.info "[departure] #{departed_count} departing, #{all_pod_info.size - departed_count} advance via Sally conveyor"
      { vids: all_pod_info.map { |p| p[:vid] }, test: 'departure', pod_count: all_pod_info.size }
    end

    # ── Arrival Test ───────────────────────────────────────────────────────
    #
    # Platform starts empty. Place pods at CP entry points.
    # Each pod traverses its landing chain + gw_platform.
    # Sally assigns slots on arrival — same as network.

    def self.arrival(model, station_id, defn, template_lookup, plat_pts, dialog)
      fid = station_id
      plugin_dir = File.dirname(__FILE__)

      _init_station(model, station_id, fid, plugin_dir, template_lookup)
      _clear_test_entities(model)

      seq = JPods::Sally.sequencer_for(station_id)
      raise "No sequencer for #{station_id}" unless seq
      landing_chains = seq[:landing_chains] || {}
      lc_keys = landing_chains.keys.reject { |k| k == 'note' }.sort
      raise "No landing_chains for #{station_id}" if lc_keys.empty?

      # Log Sally initial state (empty platform)
      if defined?(SallyV2)
        st = SallyV2.station(station_id)
        if st
          JPods::Log.info "[Sally] before arrival: #{st.summary}"
          JPods::Log.detail "[Sally] #{st.slot_summary}"
        end
      end

      placed_vids = []
      model.start_operation('Arrival Test Place Pods', true)

      lc_keys.each_with_index do |lc_key, lc_idx|
        lc = landing_chains[lc_key]
        tracks = Array(lc['tracks'])
        next if tracks.empty?

        # Place pod at start of first track
        cp_key = "#{station_id}.#{tracks.first}"
        cp_entry = template_lookup[cp_key] || template_lookup[cp_key.tr('.', '_')]
        next unless cp_entry && cp_entry[:pts].is_a?(Array) && cp_entry[:pts].size >= 2

        pos = cp_entry[:pts].first
        fwd = _fwd_from_pts(cp_entry[:pts])

        # Landing chain + gw_platform — Sally clips to assigned slot
        full_tracks = tracks + ['gw_platform']
        fq_tracks = full_tracks.map { |t| "#{station_id}.#{t}" }

        color = _pod_color(lc_idx)
        arr_defn = _load_pod(model, color)
        next unless arr_defn
        xf = JPods::PodHelpers.pod_transform(pos, fwd)
        ent = model.entities.add_instance(arr_defn, xf)

        nora_num = JPods::PodHelpers.next_nora_num(model)
        vid = format('NORA_%04d', nora_num)
        ent.set_attribute('JPods', 'speed_ms', NoraV2::DEFAULT_SPEED_MS)
        ent.set_attribute('JPods', 'vehicle_num', nora_num)
        ent.set_attribute('JPods', 'vehicle_template_id', color)
        ent.set_attribute('JPods', 'vehicle_id', vid)
        ent.set_attribute('JPods', 'parked_station_id', station_id)
        ent.set_attribute('JPods', 'parking_slot', 0)
        ent.set_attribute('JPods', 'station_test', 'true')
        ent.set_attribute('JPods', 'station_test_phase', 'parking')
        ent.set_attribute('JPods', 'template_model_id', fid)
        ent.set_attribute('JPods', 'sally_transit_tracks', fq_tracks.to_json)
        JPods::PodHelpers.assign_nora_tag(ent, vid, model)

        # Create AnimationV2 pod — same as network
        if defined?(NoraV2) && defined?(AnimationV2)
          pod = NoraV2::Pod.new(vid, ent, speed_ms: NoraV2::DEFAULT_SPEED_MS)
          AnimationV2.pods << pod
        end

        placed_vids << vid
        JPods::Log.event "[arrival] #{vid} at #{tracks.first} → #{lc_key} → gw_platform (#{full_tracks.size} tracks) — Sally clips to ps.N"
      end

      model.commit_operation

      # Start animation — same engine as network
      ok = JPods::JPodVehicleAnim.start_for_template(model, template_lookup)
      raise "Template animation failed to start." unless ok

      JPods::Log.info "[arrival] animation started — #{placed_vids.size} pods arriving, Sally assigns slots"
      { vids: placed_vids, test: 'arrival', pod_count: placed_vids.size }
    end

    # ── Test approval chain ─────────────────────────────────────────────
    # Stamps lines.computed.json with individual test pass times and
    # approved_at when all three pass. Any subsequent file save
    # (model.skp, lines.json, lines.computed.json) invalidates approval.

    def self.stamp_test_pass(template_dir, test_name)
      computed_path = File.join(template_dir, 'lines.computed.json')
      return unless File.exist?(computed_path)

      data = JSON.parse(File.read(computed_path, encoding: 'utf-8'))
      data['test_results'] ||= {}
      data['test_results'][test_name] = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')

      # Required tests depend on model type:
      # - Platform stations (has_platform: true): shuffle, departure, arrival
      # - Non-platform (traffic_circle, cpb): transit
      has_platform = data['has_platform'] == true
      required = has_platform ? %w[shuffle departure arrival] : %w[transit]
      all_passed = required.all? { |t| data['test_results'][t] }

      if all_passed
        data['approved_at'] = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
        puts "[StationTests] ✓ All #{required.size} required tests passed — approved_at stamped"
      end

      File.write(computed_path, JSON.pretty_generate(data), encoding: 'utf-8')
    end

    # Check if a template's approval is still valid.
    # Returns { ok: true/false, reason: String }
    def self.check_approval(template_dir)
      computed_path = File.join(template_dir, 'lines.computed.json')
      lj_path       = File.join(template_dir, 'lines.json')
      model_path    = File.join(template_dir, 'model.skp')

      unless File.exist?(computed_path)
        return { ok: false, reason: 'lines.computed.json not found' }
      end

      data = JSON.parse(File.read(computed_path, encoding: 'utf-8'))
      approved_at = data['approved_at']

      unless approved_at
        return { ok: false, reason: 'Not approved — run shuffle, departure, and arrival tests' }
      end

      require 'time'
      approved_t = Time.parse(approved_at)

      # Check if any source file was saved after approval
      [computed_path, lj_path, model_path].each do |path|
        next unless File.exist?(path)
        if File.mtime(path).utc > approved_t
          fname = File.basename(path)
          return { ok: false, reason: "#{fname} modified after approval (#{approved_at}) — re-run tests" }
        end
      end

      { ok: true, reason: 'Approved' }
    rescue => ex
      { ok: false, reason: "Approval check error: #{ex.message}" }
    end

  end
end

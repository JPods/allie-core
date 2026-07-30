# ── Nora v2 — Pod (Vehicle) ───────────────────────────────────────────────────
#
# Nora is the pod. She follows maneuvers planned by Natalie.
# Each NoraPod instance tracks one physical pod in the animation.
#
# State machine: :parked → :traveling → :arrived → :parked
#
# Nora does NOT plan routes. Natalie plans. Nora executes.
#
# ── su-real ──────────────────────────────────────────────────────────────────
# Physical Nora (JPodsSM_RPi/main.py) runs a ~10Hz control loop:
#   1. Read ToF (obstacle distance) → blockedByTof if < 50mm
#   2. Read HuskyLens (AprilTag) → optical position correction
#   3. Motor control: encoder feedback → PID on RPM → I2C to Romeo
#   4. EZone zipper: speed adjustment on approach to merge
#   5. MQTT telemetry ping (position, speed, battery, state)
#
# SU simplifications vs physical:
#   - SU uses t∈[0,1] along polyline; physical uses mmDistance along line segments
#   - SU has no encoder drift; physical self-calibrates at HuskyLens tags
#   - SU speed is constant per pod; physical has PID speed control with min/max RPM
#   - SU has no ToF; physical stops on obstacle detection (50mm personal space)
#   - SU has no servo; physical actuates servo at diverge BEFORE line transition
#   - SU has no battery; physical monitors voltage, degrades gracefully
#
# Physical transport layer varies by platform:
#   - Scale model: I2C to Romeo (12 magnets/wheel, ~7.1mm/step)
#   - 4WD floor robot: I2C to Romeo BLE (differential steering, in-place turns)
#   - FullScale: CAN bus to EZkontrol (3kW PMSM, regenerative braking)
#   - SkyRide: CAN to VESC (300W brushless, hang detection)
#
# What SU should produce for physical: trajectory.jsonl with per-tick
# position, speed, maneuver_id, t — physical Natalie can replay as
# reference path and compare actual encoder telemetry against it.
# ─────────────────────────────────────────────────────────────────────────────

module JPods
  module NoraV2

    INCH_PER_METER = 39.3701
    DEFAULT_SPEED_MS = 12.0   # 12 m/s = 27 mph = 43 km/h — below US road speed limits

    # ── Pod state machine ─────────────────────────────────────────────────

    class Pod
      attr_reader :pod_id, :entity, :state, :t, :speed_in
      attr_reader :current_maneuver, :maneuver_queue
      attr_accessor :dwell_until

      # Alias for backward compat with EZone and other modules
      alias nora_id pod_id

      def initialize(pod_id, entity, speed_ms: DEFAULT_SPEED_MS)
        @pod_id     = pod_id
        @entity     = entity
        @speed_in   = speed_ms * INCH_PER_METER
        @state      = :parked
        @t          = 0.0
        @current_maneuver = nil
        @maneuver_queue   = []
        @dwell_until      = nil
      end

      # ── Receive a maneuver from Natalie ──────────────────────────────────

      def receive_maneuver(maneuver, seed_pos: nil)
        if maneuver.nil?
          @state = :arrived
          return
        end

        # Accept both Maneuver struct and Hash
        man = if maneuver.respond_to?(:id)
          { id: maneuver.id, pts: maneuver.pts, len: maneuver.len }
        else
          maneuver
        end

        @current_maneuver = man
        @maneuver_queue   = []
        @state = :traveling

        # Project seed_pos onto the maneuver to find starting t
        if seed_pos && man[:pts] && man[:pts].size >= 2
          @t = _project_onto(man[:pts], seed_pos)
        else
          @t = 0.0
        end
      end

      def receive_queue(queue)
        @maneuver_queue = queue || []
      end

      # ── Propose movement for this tick ──────────────────────────────────
      # su-real: physical pods have speedMin/speedMax per line and
      # maxLateralG constraints at curves. SU computes min curve radius
      # from pts and caps speed: max_speed = sqrt(lateralG * g * radius).

      MAX_LATERAL_G = 0.3   # physical default from mapSM.json
      G_MM_S2 = 9810.0      # gravity in mm/s²

      def propose(dt)
        return { pod: self, t: @t, state: @state } unless @state == :traveling

        man = @current_maneuver
        return { pod: self, t: @t, state: :arrived } unless man && man[:len] > 1e-9

        # Speed cap from curve radius (su-real: matches physical maxLateralG)
        effective_speed = @speed_in
        if man[:speed_cap_in]
          effective_speed = [effective_speed, man[:speed_cap_in]].min
        end

        distance = effective_speed * dt
        remain   = man[:len] * (1.0 - @t)

        if distance >= remain
          { pod: self, t: 1.0, state: :arrived }
        else
          tt = @t + distance / man[:len]
          { pod: self, t: [[tt, 0.0].max, 1.0].min, state: :traveling }
        end
      end

      # ── Apply a proposal ────────────────────────────────────────────────

      def apply(proposal)
        @t     = proposal[:t]
        @state = proposal[:state]

        # Move entity to interpolated position
        if @state == :traveling && @current_maneuver
          pt, fwd = _interpolate(@current_maneuver[:pts], @t)
          if pt && fwd && @entity && !@entity.deleted?
            _apply_transform(pt, fwd)
          end
        end
      end

      # ── Advance to next maneuver ────────────────────────────────────────

      def next_maneuver!
        if @maneuver_queue.empty?
          @current_maneuver = nil
          @state = :arrived
          return nil
        end

        @current_maneuver = @maneuver_queue.shift
        @t = 0.0
        @state = :traveling
        @current_maneuver
      end

      # ── Dwelling ────────────────────────────────────────────────────────

      def start_dwell(duration_s = 3600.0)
        @state = :parked
        @dwell_until = Time.now.to_f + duration_s
      end

      def dwelling?
        @dwell_until && Time.now.to_f < @dwell_until
      end

      # ── Save/restore for stop/start resume ──────────────────────────────

      def save_resume_state(remaining_queue)
        man = @current_maneuver
        return unless man && @state == :traveling

        man_start = man[:pts]&.first
        man_start_arr = man_start ? [man_start.x.round(2), man_start.y.round(2), man_start.z.round(2)] : nil

        remaining_data = Array(remaining_queue).map { |m|
          sp = m[:pts]&.first
          { 'id' => m[:id].to_s,
            'sp' => sp ? [sp.x.round(2), sp.y.round(2), sp.z.round(2)] : nil }
        }.reject { |r| r['id'].empty? }

        dest_sid = @entity.get_attribute('JPods', 'destination_station_id', '').to_s.strip rescue ''

        state_data = {
          'v'          => 2,
          'maneuver_id' => man[:id].to_s,
          't'          => @t.round(6),
          'man_start'  => man_start_arr,
          'remaining'  => remaining_data,
          'dest_sid'   => dest_sid,
          'speed_ms'   => (@speed_in / INCH_PER_METER).round(3)
        }
        @entity.set_attribute('JPods', 'resume_state', state_data.to_json)
        puts "[Nora #{@pod_id}] resume saved — #{man[:id]} t=#{@t.round(3)}"
      rescue => ex
        puts "[Nora #{@pod_id}] save_resume error: #{ex.message}"
      end

      private

      # Project a world point onto a polyline, return t ∈ [0, 1]
      def _project_onto(pts, pos)
        return 0.0 unless pts.size >= 2
        total_len = pts.each_cons(2).sum { |a, b| a.distance(b).to_f }
        return 0.0 if total_len < 1e-9

        best_dist = Float::INFINITY
        best_cum  = 0.0
        cum = 0.0

        pts.each_cons(2) do |a, b|
          seg_len = a.distance(b).to_f
          next if seg_len < 1e-12
          # Project pos onto segment a→b
          ab = [b.x - a.x, b.y - a.y, b.z - a.z]
          ap = [pos.x - a.x, pos.y - a.y, pos.z - a.z]
          dot = ab[0]*ap[0] + ab[1]*ap[1] + ab[2]*ap[2]
          t_seg = (dot / (seg_len * seg_len)).clamp(0.0, 1.0)
          px = a.x + ab[0] * t_seg
          py = a.y + ab[1] * t_seg
          pz = a.z + ab[2] * t_seg
          d = Math.sqrt((pos.x - px)**2 + (pos.y - py)**2 + (pos.z - pz)**2)
          if d < best_dist
            best_dist = d
            best_cum = cum + seg_len * t_seg
          end
          cum += seg_len
        end

        (best_cum / total_len).clamp(0.0, 1.0)
      end

      # Interpolate position and forward vector at t along polyline
      def _interpolate(pts, t)
        return [nil, nil] unless pts.size >= 2
        total_len = pts.each_cons(2).sum { |a, b| a.distance(b).to_f }
        target = t * total_len
        walked = 0.0

        pts.each_cons(2) do |a, b|
          seg_len = a.distance(b).to_f
          if walked + seg_len >= target || b == pts.last
            frac = seg_len > 1e-9 ? ((target - walked) / seg_len).clamp(0.0, 1.0) : 0.0
            pt = Geom::Point3d.new(
              a.x + (b.x - a.x) * frac,
              a.y + (b.y - a.y) * frac,
              a.z + (b.z - a.z) * frac
            )
            dx = b.x - a.x; dy = b.y - a.y
            len2d = Math.sqrt(dx*dx + dy*dy)
            fwd = len2d > 1e-9 ? Geom::Vector3d.new(dx/len2d, dy/len2d, 0) : Geom::Vector3d.new(1, 0, 0)
            return [pt, fwd]
          end
          walked += seg_len
        end

        [pts.last, Geom::Vector3d.new(1, 0, 0)]
      end

      # Apply position and rotation to entity
      def _apply_transform(pt, fwd)
        angle = Math.atan2(fwd.y, fwd.x)
        z_axis = Geom::Vector3d.new(0, 0, 1)
        rotate = Geom::Transformation.rotation(Geom::Point3d.new, z_axis, angle)
        translate = Geom::Transformation.translation(pt)
        @entity.transformation = translate * rotate
      rescue => ex
        # Don't crash animation for transform errors
      end
    end

  end
end

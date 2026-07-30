# JPods Engineering Constants
# All distances are in SketchUp internal units (inches).
# The .m suffix converts meters to inches at load time.

module JPods
  module Constants

    # ── Horizontal alignment ──────────────────────────────────────────────────
    # Minimum curve radius at design speed (~30 km/h)
    MIN_TURN_RADIUS      = 30.0.m    # 30 metres  # TODO F-01: expose as per-model user setting (feature-list.md)

    # Spatial radius for the Gaussian low-pass filter applied to the HORIZONTAL
    # (XY) path before arc insertion. Deviations shorter than this are dampened;
    # broad intentional curves are preserved. 5 m removes digitising jitter
    # while leaving the platform-entry arc and U-turn geometry intact.
    HORIZONTAL_SMOOTH_RADIUS = 5.0.m

    # ── Vertical alignment ────────────────────────────────────────────────────
    # Maximum guideway grade (rise / run).  15 % ≈ 8.5°.  Structural hard limit.
    MAX_GRADE            = 0.15

    # Maximum grade used by the vertical profile algorithm.  Smaller than MAX_GRADE
    # so the guideway changes elevation more gradually — needs more horizontal distance
    # to make a given rise or fall.  Increase to follow terrain more aggressively.
    PROFILE_MAX_GRADE    = 0.08

    # Minimum vertical-curve radius — softens station joins and interior hill/valley
    # transitions.  Smaller values permit sharper changes in grade.
    MIN_Z_CHANGE_DIAMETER = 60.0.m  # Profile smooth radius — gentle vertical transitions

    # Vehicle runtime turning capability at FollowMe joins.
    # Interpreted as the minimum admissible turn diameter through a join.
    VEHICLE_MIN_TURN_DIAMETER = 3.5.m

    # Minimum arc radius for any in-station turn (gw_* arc tracks).
    # A pod cannot navigate a tighter arc without derailing or structural overload.
    # Enforced at populate time, proof time, and arc generation.
    # Uturn arc — three concentric radii (beam width = 500 mm total, 250 mm each side):
    #   Inside rail:   1500 mm  ← ArcCurve in SketchUp; what MIN_STATION_ARC_RADIUS_MM enforces
    #   Centerline:    1750 mm  ← pod travel path; physical minimum for vehicle dynamics
    #   Outside rail:  2000 mm  ← outer envelope
    # Enforcement uses inside radius because that is what the model geometry contains.
    MIN_STATION_ARC_RADIUS_M  = 1.5     # inside rail radius (m)
    MIN_STATION_ARC_RADIUS_MM = 1500.0  # inside rail radius (mm)

    # ── Structural clearances ─────────────────────────────────────────────────
    # ═══════════════════════════════════════════════════════════════════════════
    # SINGLE SOURCE OF TRUTH FOR GUIDEWAY HEIGHT
    #
    #   CLEARANCE_HEIGHT  — height from terrain surface to guideway CENTERLINE.
    #   WAYPOINT_STANDOFF — identical value; use this name when the intent is
    #                       "how high above a waypoint marker does the beam fly."
    #
    # Both names point to the same 4.6 m value.  Change only here.
    # Exposed in Network Editor › Constraints panel so it can be tuned per model.
    #
    # ── SAFETY NOTE — DO NOT LOWER WITHOUT READING THIS ─────────────────────
    # The original clearance was 7.5 m (AASHTO highway overpass standard).
    # At 7.5 m a standard semi (4.1 m) passes under with ≥3 m margin —
    # passive safety; height alone is the protection; no sensors needed.
    #
    # At 4.6 m the GUIDEWAY STRUCTURE is safe.  The JPods VEHICLE (pod)
    # traveling on the guideway is what enters the overheight truck envelope.
    # A pod on a 4.6 m beam is within reach of a raised dump bed or
    # double-stack flatbed load.
    #
    # Bill James (2026-05-13) accepts responsibility for building active
    # height-sensing and pod defensive-stop systems as the required complement
    # to this clearance choice.  The guideways are safe.  The pods need cover.
    #
    # Risk items: CL-01 through CL-06 in readmes/system/ouch-list.md.
    # Rule: do not carry passengers at 4.6 m until CL-02 has a design,
    #       an owner, and a certification path.
    # ═══════════════════════════════════════════════════════════════════════════
    CLEARANCE_HEIGHT     = 4.6.m
    WAYPOINT_STANDOFF    = CLEARANCE_HEIGHT   # alias — same value, clearer intent

    # Retained for backward compatibility; no longer used by apply_vertical_profile.
    # The vertical profile is now grade-limited terrain-following (see PathBuilder).
    VERTICAL_PROFILE_HORIZONTAL_BIAS = 0.85

    # Spatial radius (metres) for the Gaussian low-pass filter applied to the
    # terrain elevation signal before computing the vertical guideway profile.
    # Terrain variation over distances shorter than this radius is smoothed out;
    # the guideway only follows elevation changes broader than this window.
    #
    # DESIGN PRINCIPLE — Smooth Guideways Are Primary:
    # Every Z change applies acceleration and g-forces to passengers.
    # The guideway must be smooth; columns absorb terrain variation with
    # variable height. SU terrain meshes are noisy approximations — the
    # profile algorithm must not treat mesh noise as physical reality.
    # Raw terrain (hard_floor_z) is a safety log, not a profile driver.
    #
    # 15 m follows the actual road/path grade without averaging in
    # adjacent steep terrain (hills, embankments next to the route).
    # Increase for flat terrain where broader bridging is acceptable.
    VERTICAL_SMOOTH_RADIUS = 80.0.m

    # Nominal spacing between support columns
    SUPPORT_SPACING      = 25.0.m   # 25 metres

    # Column height threshold for JSON logging.  Columns taller than this are
    # flagged { tall: true } in the column_heights attribute so the user can
    # identify spans that may need review.  The column base is always placed at
    # terrain level; depth into the ground is unconstrained (let it float).
    MAX_COLUMN_HEIGHT    = 25.0.m   # 25 metres

    # Support column outside diameter
    POST_DIAMETER        = 0.4.m    # 40 cm

    # ── Guideway beam cross-section ───────────────────────────────────────────
    # Simple 0.5 m × 0.5 m box — illustration only; vehicles follow the path.
    BEAM_WIDTH           = 0.5.m    # 50 cm
    BEAM_DEPTH           = 0.5.m    # 50 cm

    # ── Marker visualisation ──────────────────────────────────────────────────
    # Red disk radius — station platform / boarding zone
    STATION_RADIUS       = 3.0.m
    # Orange disk radius — cleared access buffer
    BUFFER_RADIUS        = 10.0.m
    # Height of the orange marker post
    MARKER_POST_HEIGHT   = 3.0.m

    # Marker-to-guideway drift threshold for continuity diagnostics.
    # If a guideway misses an assigned via marker by more than this value,
    # continuity scan raises a yellow risk marker.
    MARKER_ALIGN_RISK_TOLERANCE = 3.0.m

    # Primary constraints exposed in the Network Editor.
    # Defaults are captured once and never mutated; active constants may be
    # temporarily overridden at runtime for interactive tuning.
    PRIMARY_CONSTRAINT_DEFAULTS = {
      "STATION_RADIUS"                => STATION_RADIUS,
      "BUFFER_RADIUS"                 => BUFFER_RADIUS,
      "MARKER_POST_HEIGHT"            => MARKER_POST_HEIGHT,
      "MARKER_ALIGN_RISK_TOLERANCE"   => MARKER_ALIGN_RISK_TOLERANCE,
      "CLEARANCE_HEIGHT"              => CLEARANCE_HEIGHT,
      "PROFILE_MAX_GRADE"             => PROFILE_MAX_GRADE,
      "MIN_Z_CHANGE_DIAMETER"         => MIN_Z_CHANGE_DIAMETER,
      "VEHICLE_MIN_TURN_DIAMETER"     => VEHICLE_MIN_TURN_DIAMETER,
      "HORIZONTAL_SMOOTH_RADIUS"      => HORIZONTAL_SMOOTH_RADIUS,
      "VERTICAL_SMOOTH_RADIUS"        => VERTICAL_SMOOTH_RADIUS,
    }.freeze

    @primary_constraint_overrides = {}

    def self.primary_constraint_defaults
      PRIMARY_CONSTRAINT_DEFAULTS.dup
    end

    def self.primary_constraint_overrides
      @primary_constraint_overrides.dup
    end

    # Applies overrides to active constants.
    # Expected units: internal SketchUp units (inches) for lengths,
    # unitless ratio for PROFILE_MAX_GRADE.
    def self.apply_primary_constraint_overrides(overrides = {})
      normalized = {}
      PRIMARY_CONSTRAINT_DEFAULTS.each_key do |name|
        value = overrides[name] || overrides[name.to_sym]
        next if value.nil?
        numeric = value.to_f
        next unless numeric.finite?
        next if numeric <= 0.0
        normalized[name] = numeric
      end

      @primary_constraint_overrides = normalized

      PRIMARY_CONSTRAINT_DEFAULTS.each do |name, default_value|
        effective = normalized.fetch(name, default_value)
        remove_const(name) if const_defined?(name, false)
        const_set(name, effective)
      end

      primary_constraint_overrides
    end

    def self.reset_primary_constraint_overrides
      apply_primary_constraint_overrides({})
    end

    # ── Arc generation ────────────────────────────────────────────────────────
    # Segments per 90° of arc.  Higher = smoother but more geometry.
    ARC_SEGS_PER_QUARTER = 8

    # ── Structure template ────────────────────────────────────────────────────
    # Path to the support structure .skp component.
    STRUCTURE_SKP = File.join(
      File.dirname(__FILE__),               # .../JPods/
      "templates", "structures",
      "JPod_support_solar_double", "model.skp"
    ).freeze

    # Height from the component base (origin) to the track centre-line,
    # as declared in the template info file (314.96" = 8.0 m).
    STRUCTURE_NATIVE_HEIGHT = 314.96062992125985   # inches

    # The component's default "track runs along" axis in its local space.
    # ene_railroad places structures with Transformation.axes(pt, v×Z, v, Z)
    # where v = travel direction → the structure's LOCAL +Y = travel direction.
    STRUCTURE_TRACK_AXIS    = Geom::Vector3d.new(0, 1, 0)

    # ── Dual guideway ─────────────────────────────────────────────────────────
    # Centre-to-centre spacing between the two parallel guideways.
    # Must match the track_parallel_distance in the formation templates
    # (station, traffic circle, support structures) = 3.5 m = 137.795 inches.
    DUAL_TRACK_SPACING = 3.5.m   # 3.5 metres centre-to-centre

    # ── Curve speed limit ─────────────────────────────────────────────────────
    # Maximum lateral acceleration a passenger may experience in a curve.
    # Formula: v_max_mps = Math.sqrt(LATERAL_G_LIMIT_MPS2 * radius_m)
    #
    # Normal passenger comfort range: 0.1g – 0.3g (0.981 – 2.943 m/s²).
    # Use 0.1g for conservative design; 0.3g is the outer comfort boundary.
    #
    # Reference speeds at known radii:
    #   U-turn    r = 3.5 m  → v_max =  1.85 m/s  ( 4.1 mph)  at 0.1g
    #   U-turn    r = 3.5 m  → v_max =  3.21 m/s  ( 7.2 mph)  at 0.3g
    #   TC ring   r ≈ 8.3 m  → v_max =  2.85 m/s  ( 6.4 mph)  at 0.1g
    #   TC ring   r ≈ 8.3 m  → v_max =  4.94 m/s  (11.0 mph)  at 0.3g
    #
    # NOTE: The animator does not yet enforce curve speed limits.
    # radius_m and speed_limit_mps are stored in line.json/feature.json as
    # requirements documentation.  Ezone enforcement is a future task.
    LATERAL_G_LIMIT_MPS2 = 0.981   # m/s²  (= 0.1g) — conservative design default

    # Helper: maximum speed (m/s) for a curve of the given radius (metres).
    def self.curve_speed_limit_mps(radius_m)
      Math.sqrt(LATERAL_G_LIMIT_MPS2 * radius_m.to_f)
    end

    # Minimum curve radius in the approach zone of inter-station guideways.
    # Below this radius, pods must slow significantly and mechanical stress rises.
    # More critically: arrival speed at a merge point is set by the approach curve;
    # a sharp curve forces V below nominal, making the zipper gap calculation wrong.
    # Noelle flags any inter-station guideway whose approach zone violates this value.
    #
    # IMPORTANT — enforcement boundary and designer responsibility:
    # This constant applies ONLY to open-air inter-station guideways.
    # Curves below this radius are REQUIRED inside features (U-turns, traffic
    # circles, platform loops). Those tight curves are built into the feature
    # geometry, executed at reduced station-entry speed, and protected by the
    # feature's own ezone speed limits. They are never executed at cruise speed.
    # check_approach_curves() skips internal-connection guideways for this reason.
    #
    # It is the network designer's responsibility to accommodate these feature
    # requirements in the surrounding layout — positioning stations far enough
    # apart, orienting them to face their connections, and placing waypoint markers
    # to produce gentle approach curves. Noelle reports violations; she does not
    # redesign the network.
    MIN_APPROACH_CURVE_RADIUS = 8.0.m

    # Hard floor — never allow a per-connection override below 3.5 m.
    # 3.5 m is the U-turn hairpin radius inside a station; tighter than this
    # the pod cannot physically steer. Speed at 3.5 m: sqrt(0.1g * 3.5) ≈ 1.85 m/s.
    # Speed at default 8.0 m: sqrt(0.1g * 8.0) ≈ 2.80 m/s.
    MIN_ABSOLUTE_APPROACH_CURVE_RADIUS = 3.5.m

    # Model attribute dictionary that stores per-connection radius overrides.
    # Key: connection_id (e.g. "seg_S048_cp1_S050_cp0"), Value: Float metres.
    APPROACH_RADIUS_DICT = 'JPods_approach_radii'.freeze

    # Depth of the approach zone — how far from each CP end Noelle inspects.
    # The first/last APPROACH_CHECK_DEPTH metres of a built inter-station guideway
    # must satisfy MIN_APPROACH_CURVE_RADIUS before Noelle will approve the network.
    APPROACH_CHECK_DEPTH = 12.0.m

    # Skip distance at each end of the approach zone.
    # The bezier path transitions from the CP stub angle to the open guideway
    # over the first/last ~2m. Circumradius measured in this transition zone
    # reflects stub geometry, not the actual approach curve. Skip it.
    APPROACH_SKIP_DEPTH = 2.0.m

    # Material name applied to guideway groups that violate their approach radius.
    # SketchUp renders group material as a tint — orange-red draws the eye
    # without hiding the geometry. Cleared automatically on next clean build.
    APPROACH_VIOLATION_MATERIAL = 'JPods_approach_violation'.freeze

    # Solar panel module depth along the travel direction = 2.43 m.
    # Matches the ene_railroad arrayed sub-component width convention.
    SOLAR_PANEL_SPACING = 2.43.m

    # Leading-edge to leading-edge repeat distance between panel modules = 2.5 m.
    # 2.43 m panels at 2.5 m pitch → 97 % coverage (0.07 m gap between modules).
    # 10 panels × 2.5 m = 25 m = one column span.
    SOLAR_PANEL_REPEAT  = 2.5.m

    # Vertical offset applied to the column origin so the T arm lands at beam
    # top face.  The JPod_support_T component's T arm is at local Z > native_h
    # (8 m); this offset pulls the origin down so the arm aligns with beam top.
    # Calibrated April 18 2026: 0.43 (old) + 2.52 (measured correction) = 2.95 m.
    # ⚠️ TODO: replace with auto-detection from component bounding box so this
    # does not need manual recalibration when the template changes.
    T_ARM_OFFSET = 2.95.m

    # ── Animation ─────────────────────────────────────────────────────────────
    # Constants used by JPodGuideway (jpod_animator.rb) for vehicle movement,
    # gap regulation, camera follow, and route graph snapping.
    # Defined here so jpod_constants loads first (before jpod_animator) and the
    # remove_const / redefinition pattern in jpod_animator is no longer needed.
    module Animation
      ANIM_INTERVAL  = 0.1   # seconds per animation tick (~10 fps)

      # Runtime occupancy rules:
      # Rule 1 — hard stop: a stopped vehicle holds the full queue behind it on
      #   the same path.  No phantom passing through a stopped vehicle.
      # Rule 2 — sequential ordering: vehicles are committed leader-first so a
      #   trailing vehicle can never advance through a leading vehicle.
      # Rule 3 — gap regulation: when the path-gap to the vehicle directly ahead
      #   drops below PERSONAL_ZONE_DIST (3 m), the leader speeds up by
      #   GAP_ADJUST_PER_TICK and the follower slows by GAP_ADJUST_PER_TICK each
      #   tick. Exception: platform guideways (parking slots) are exempt so
      #   vehicles can close up tightly for boarding.
      # HARD_STOP_DIST is the physical overlap threshold — triggers hard stop even
      #   under gap regulation and is also used for cross-path junction safety.
      VEHICLE_FOLLOWME_REFERENCE    = 'centerpoint'

      # Telemetry-based minimum gap on guideways: 5.0 m.
      # This is the physical headway JPods telemetry maintains between vehicles
      # when they are running on a guideway (not parked on a platform).
      # @see PlatformQueue::GUIDEWAY_SPACING_M — same value, class-scoped
      # @see FiveVTest::GUIDEWAY_SPACING_M     — same value, test-scoped
      GUIDEWAY_SPACING_M            = 5.0    # meters (unitless — used for comparison with /1.m conversions)

      # Minimum gap when parking: 3.0 m.
      # Vehicles can close to 3 m when occupying adjacent parking slots.
      # @see PlatformQueue::PARKING_SPACING_M  — same value, class-scoped
      # @see FiveVTest::PARKING_SPACING_M      — same value, test-scoped
      PARKING_SPACING_M             = 3.0    # meters (unitless)

      # PERSONAL_ZONE_DIST is the SketchUp-unit (inches) form of PARKING_SPACING_M.
      # Kept for backward compatibility with existing callers in jpod_animator.rb.
      # New code should use GUIDEWAY_SPACING_M or PARKING_SPACING_M as appropriate.
      PERSONAL_ZONE_DIST            = 3.m    # gap-regulation trigger distance (backward compat)
      MIN_HEADWAY                   = PERSONAL_ZONE_DIST
      HARD_STOP_DIST                = 0.3.m  # physical overlap hard-stop threshold
      GAP_ADJUST_PER_TICK           = 0.1.m  # position nudge per tick (~0.1 m/tick at 10 fps)
      FOLLOWME_UTURN_PROB           = 0.02
      FOLLOWME_CONNECT_TOL          = 1.m
      FOLLOWME_CONNECT_TOL_RELAXED  = 3.m
      MM_PER_INCH                   = 25.4
      ROUTE_NODE_SNAP_TOL           = 1.m
      ROUTE_NODE_Z_TOL              = 1.m
      RUNTIME_BUILD_TAG             = 'nora-platform-routing-v3'

      # Camera follow constants
      CAMERA_FOLLOW_BACK_DIST  = 20.m
      CAMERA_FOLLOW_LOOK_AHEAD = 12.m
      CAMERA_FOLLOW_EYE_UP     = 4.m

      # Dead-end and connection tolerances
      DEAD_END_SNAP_TOL = 2.m
      CONNECT_TOL       = 0.25.m

      # FollowMe path visualiser overlay constants
      FOLLOWME_LIFT   = 3.m     # above vehicle path (beam bottom face)
      FOLLOWME_SEGS   = 24      # segments in endpoint circles
      FOLLOWME_RING   = 1.0.m   # circle radius at path endpoints
      FOLLOWME_Z_BIAS = 0.02.m  # draw slightly below bottom path to avoid z-fighting
    end

  end

  # ── Long-tail defect log ──────────────────────────────────────────────────────
  #
  # Sally, Natalie, and Nora call JPods.long_tail(agent, event, data) whenever
  # they detect a rare condition that is not worth chasing immediately but should
  # be counted.  Each call appends one JSON line to ~/Allie/process/long_tail.log
  # so Allie can analyze frequency and surface patterns over time.
  #
  # If ~/Allie/process/ does not exist (e.g. on a bare Pi), the write is silently
  # skipped — agents must never crash because the log is unavailable.
  #
  # Format (one JSON object per line):
  #   {"ts":"2026-06-14T10:23:45Z","agent":"Sally","event":"personal_space_violation",
  #    "data":{...}}
  #
  LONG_TAIL_LOG = File.expand_path('~/Allie/process/long_tail.log')

  def self.long_tail(agent, event, data = {})
    return unless File.directory?(File.dirname(LONG_TAIL_LOG))
    ts     = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
    record = { ts: ts, agent: agent.to_s, event: event.to_s, data: data }
    File.open(LONG_TAIL_LOG, 'a') { |f| f.puts(record.to_json) }
  rescue => _e
    # Never propagate — log failure must not disrupt agent operation
  end

end

# ── Build Path — Terrain-following, grade-limited path builder ─────────────────
#
# Migrated from codearchive/jpod_path_builder.rb.
# Converts raw marker positions into a smooth, physically-constrained
# guideway centerline:
#   1. Horizontal arcs — rounds corners to >= MIN_TURN_RADIUS
#   2. Terrain snap — drops points onto terrain surface
#   3. Vertical profile — grade-limited Z with clearance and smoothing

module JPods
  module PathBuilder

    def self.build(raw_points, model, anchor_zs: nil, pre_smoothed: false,
                    waypoint_zs: nil, waypoint_xys: nil)
      return raw_points.dup if raw_points.size < 2

      if pre_smoothed
        arc_pts = raw_points.dup
      else
        if raw_points.size >= 3
          cum_raw = [0.0]
          (1...raw_points.size).each { |i| cum_raw << cum_raw.last + horiz_dist(raw_points[i - 1], raw_points[i]) }
          raw_points = smooth_horizontal_xy(raw_points, cum_raw)
        end
        arc_pts = insert_horizontal_arcs(raw_points)
      end

      terrain_pts = Terrain.snap_to_terrain(model, arc_pts)
      beam_pts = apply_vertical_profile(terrain_pts, source_pts: arc_pts, anchor_zs: anchor_zs,
                                        waypoint_zs: waypoint_zs, waypoint_xys: waypoint_xys)
      beam_pts
    end

    def self.insert_horizontal_arcs(points)
      return points.dup if points.size < 3
      result = [points[0]]
      (1...points.size - 1).each do |i|
        arc = arc_at_corner(points[i - 1], points[i], points[i + 1])
        result.concat(arc)
      end
      result << points.last
      result
    end

    def self.arc_at_corner(p0, p1, p2)
      r = Constants::MIN_TURN_RADIUS
      entry  = horiz_unit(p0, p1)
      exit_v = horiz_unit(p1, p2)
      dot        = (entry.x * exit_v.x + entry.y * exit_v.y).clamp(-1.0, 1.0)
      deflection = Math.acos(dot)
      return [p1] if deflection < 0.0175

      cross_z = entry.x * exit_v.y - entry.y * exit_v.x
      setback = r * Math.tan(deflection / 2.0)
      h1      = horiz_dist(p0, p1)
      h2      = horiz_dist(p1, p2)
      setback = [setback, h1 * 0.45, h2 * 0.45].min
      return [p1] if setback < 0.001

      pt_in  = Geom::Point3d.new(p1.x - entry.x  * setback, p1.y - entry.y  * setback,  p1.z)
      pt_out = Geom::Point3d.new(p1.x + exit_v.x * setback, p1.y + exit_v.y * setback,  p1.z)

      if cross_z >= 0
        nx, ny = -entry.y, entry.x
      else
        nx, ny = entry.y, -entry.x
      end

      cx = pt_in.x + nx * r
      cy = pt_in.y + ny * r
      a_start = Math.atan2(pt_in.y  - cy, pt_in.x  - cx)
      a_end   = Math.atan2(pt_out.y - cy, pt_out.x - cx)

      if cross_z >= 0
        sweep = a_end - a_start
        sweep += 2.0 * Math::PI if sweep < 0
      else
        sweep = a_end - a_start
        sweep -= 2.0 * Math::PI if sweep > 0
      end

      segs = [(deflection / (Math::PI / 2.0) * Constants::ARC_SEGS_PER_QUARTER).ceil, 2].max
      pts = []
      (0..segs).each do |j|
        t = j.to_f / segs
        a = a_start + sweep * t
        pts << Geom::Point3d.new(cx + r * Math.cos(a), cy + r * Math.sin(a), p1.z)
      end
      pts
    end

    # Z jump threshold for logging — any point-to-point Z change larger than
    # this is flagged in the build log so the designer can see where defects are.
    Z_JUMP_THRESHOLD = 1.0.m  # 1 metre

    def self.apply_vertical_profile(terrain_pts, source_pts: nil, anchor_zs: nil,
                                     waypoint_zs: nil, waypoint_xys: nil)
      n = terrain_pts.size
      return terrain_pts if n < 2

      clearance = Constants::CLEARANCE_HEIGHT
      max_grade = Constants::PROFILE_MAX_GRADE

      cum_dist = Array.new(n, 0.0)
      (1...n).each { |i| cum_dist[i] = cum_dist[i - 1] + horiz_dist(terrain_pts[i - 1], terrain_pts[i]) }
      total_dist = cum_dist[n - 1]

      smoothed_terrain_z = smooth_terrain_z(terrain_pts, cum_dist)
      floor_z = smoothed_terrain_z.map { |tz| tz + clearance }
      hard_floor_z = terrain_pts.map { |pt| pt.z + clearance }

      anchored = anchor_zs && anchor_zs.size == 2
      z0 = anchored ? anchor_zs[0].to_f : floor_z[0]
      z1 = anchored ? anchor_zs[1].to_f : floor_z[n - 1]

      # ── Z log header ──────────────────────────────────────────────────
      puts "[Z-profile] #{n} pts, total dist=#{total_dist.to_m.round(1)}m, " \
           "anchor z0=#{z0.to_m.round(2)}m z1=#{z1.to_m.round(2)}m, " \
           "clearance=#{clearance.to_m.round(1)}m, max_grade=#{max_grade}"

      # Log terrain Z — where the raycasts landed
      _log_z_jumps("terrain", terrain_pts.map(&:z), cum_dist)
      _log_z_jumps("floor(terrain+clr)", floor_z, cum_dist)

      # Build waypoint distance anchors — map each waypoint XY to the nearest
      # path point's cumulative distance, then interpolate piecewise through
      # waypoint Zs instead of straight CP-to-CP linear.
      wp_anchors = nil  # array of [cum_dist, z] sorted by distance
      if waypoint_zs && waypoint_xys && waypoint_zs.size > 0 && waypoint_xys.size == waypoint_zs.size
        wp_anchors = waypoint_xys.each_with_index.map do |wp, wi|
          # Find the path point closest to this waypoint XY
          best_idx = 0
          best_d2  = Float::INFINITY
          terrain_pts.each_with_index do |pt, pi|
            d2 = (pt.x - wp.x)**2 + (pt.y - wp.y)**2
            if d2 < best_d2
              best_d2  = d2
              best_idx = pi
            end
          end
          puts "[Z-profile] waypoint[#{wi}]: marker_z=#{wp.z.to_m.round(2)}m " \
               "target_z=#{waypoint_zs[wi].to_m.round(2)}m " \
               "at dist=#{cum_dist[best_idx].to_m.round(1)}m (pt #{best_idx}/#{n})"
          [cum_dist[best_idx], waypoint_zs[wi].to_f]
        end
        wp_anchors.sort_by!(&:first)
      end

      desired_z = if anchored
                    if wp_anchors && wp_anchors.any?
                      # Piecewise linear through [start, wp1, wp2, ..., end]
                      knots = [[0.0, z0]] + wp_anchors + [[total_dist, z1]]
                      puts "[Z-profile] piecewise knots: #{knots.map { |d,z| "d=#{d.to_m.round(1)}m→z=#{z.to_m.round(2)}m" }.join(' | ')}"
                      (0...n).map do |i|
                        d = cum_dist[i]
                        # Find surrounding knots
                        seg_idx = knots.index { |k| k[0] >= d } || (knots.size - 1)
                        seg_idx = [seg_idx, 1].max
                        d0, z_a = knots[seg_idx - 1]
                        d1, z_b = knots[seg_idx]
                        span = d1 - d0
                        t = span > 0.001 ? (d - d0) / span : 0.0
                        z_a + (z_b - z_a) * t.clamp(0.0, 1.0)
                      end
                    else
                      (0...n).map do |i|
                        t = total_dist > 0.001 ? cum_dist[i] / total_dist : (i.to_f / [n - 1, 1].max)
                        z0 + (z1 - z0) * t
                      end
                    end
                  elsif source_pts && source_pts.size == n
                    source_pts.map { |pt| pt.z.to_f }
                  else
                    floor_z.dup
                  end

      _log_z_jumps("desired", desired_z, cum_dist)

      # ── Grade limits — piecewise between waypoint anchors ─────────────
      # Grade envelopes must run between consecutive anchors (CP→WP→WP→CP),
      # not from endpoint to endpoint.  Otherwise the grade cone from a distant
      # CP overrides the waypoint Z the user placed deliberately.
      anchor_pts = [[0, z0]]   # [path_index, z]
      if wp_anchors
        wp_anchors.each do |wp_d, wp_z|
          # Find nearest path point to this waypoint distance
          best = (0...n).min_by { |i| (cum_dist[i] - wp_d).abs }
          anchor_pts << [best, wp_z]
        end
      end
      anchor_pts << [n - 1, z1]

      grade_fwd = Array.new(n)
      grade_bwd = Array.new(n)
      ceil_fwd  = Array.new(n)
      ceil_bwd  = Array.new(n)

      # For each span between consecutive anchors, compute local grade envelopes
      (0...anchor_pts.size - 1).each do |si|
        ai, az = anchor_pts[si]
        bi, bz = anchor_pts[si + 1]
        next if ai >= bi
        # Forward from anchor start
        grade_fwd[ai] = az
        ceil_fwd[ai]  = az
        ((ai + 1)..bi).each do |i|
          dd = cum_dist[i] - cum_dist[i - 1]
          grade_fwd[i] = grade_fwd[i - 1] - dd * max_grade
          ceil_fwd[i]  = ceil_fwd[i - 1]  + dd * max_grade
        end
        # Backward from anchor end
        grade_bwd[bi] = bz
        ceil_bwd[bi]  = bz
        (bi - 1).downto(ai) do |i|
          dd = cum_dist[i + 1] - cum_dist[i]
          grade_bwd[i] = grade_bwd[i + 1] - dd * max_grade
          ceil_bwd[i]  = ceil_bwd[i + 1]  + dd * max_grade
        end
      end

      # Smoothed terrain floor governs the profile — not raw terrain.
      # Raw terrain (hard_floor_z) is noisy SU mesh data.  Every mesh bump
      # creates an acceleration the pod must absorb.  Smooth guideways are
      # the primary requirement; columns absorb terrain variation.
      # hard_floor_z is retained as a safety-only check (logged, not enforced).
      min_z_bounds = (0...n).map { |i| [floor_z[i], grade_fwd[i], grade_bwd[i]].compact.max }
      max_z_bounds = (0...n).map { |i| [[ceil_fwd[i], ceil_bwd[i]].compact.min, min_z_bounds[i]].compact.max }

      beam_z = (0...n).map { |i| clamp_profile_z(desired_z[i], min_z_bounds[i], max_z_bounds[i]) }
      _log_z_jumps("after-clamp", beam_z, cum_dist)

      # Safety check: log any points where beam dips below raw terrain + clearance.
      # This is informational — the smooth profile is authoritative.
      terrain_violations = (0...n).select { |i| beam_z[i] < hard_floor_z[i] }
      if terrain_violations.any?
        puts "[Z-profile] ℹ #{terrain_violations.size} pts below raw terrain+clearance (columns will be short at these points)"
      end

      curve_radius = [Constants::MIN_Z_CHANGE_DIAMETER.to_f, 3.0.m.to_f].max
      if n > 2 && curve_radius > 0.001
        # Smooth the profile — do NOT re-clamp afterward.
        # The clamp already enforced grade limits. The smoother's job is to
        # gentle the transitions at waypoint knots. Re-clamping undoes the
        # smoothing at exactly the points that need it most.
        beam_z = smooth_profile_z(beam_z, cum_dist, curve_radius)
        _log_z_jumps("after-smooth", beam_z, cum_dist)
      end

      beam_z[0]     = z0 if anchored
      beam_z[n - 1] = z1 if anchored

      # Endpoint blend — only within the first/last anchor span
      if anchored && cum_dist.last > 0.001
        # First span: CP start to first waypoint (or CP end if no waypoints)
        first_wp_dist = anchor_pts.size > 2 ? cum_dist[anchor_pts[1][0]] : cum_dist.last
        blend_start = [10.0.m, first_wp_dist * 0.35].min
        # Last span: last waypoint to CP end
        last_wp_dist = anchor_pts.size > 2 ? cum_dist.last - cum_dist[anchor_pts[-2][0]] : cum_dist.last
        blend_end = [10.0.m, last_wp_dist * 0.35].min
        puts "[Z-profile] endpoint blend: start=#{blend_start.to_m.round(1)}m end=#{blend_end.to_m.round(1)}m"
        (0...n).each do |i|
          d_s = cum_dist[i]
          d_e = cum_dist.last - cum_dist[i]
          if d_s < blend_start
            t = d_s / blend_start
            w = t * t * (3.0 - 2.0 * t)
            beam_z[i] = z0 + (beam_z[i] - z0) * w
          elsif d_e < blend_end
            t = d_e / blend_end
            w = t * t * (3.0 - 2.0 * t)
            beam_z[i] = z1 + (beam_z[i] - z1) * w
          end
        end
        beam_z[0]     = z0
        beam_z[n - 1] = z1
      end

      _log_z_jumps("final", beam_z, cum_dist)

      terrain_pts.each_with_index.map { |pt, i| Geom::Point3d.new(pt.x, pt.y, beam_z[i]) }
    end

    # ── Z jump detector — logs point-to-point Z changes above threshold ──
    def self._log_z_jumps(phase, z_array, cum_dist)
      jumps = []
      z_min = z_array.first.to_f
      z_max = z_array.first.to_f
      (1...z_array.size).each do |i|
        dz = (z_array[i] - z_array[i - 1]).abs
        z_val = z_array[i].to_f
        z_min = z_val if z_val < z_min
        z_max = z_val if z_val > z_max
        dd = cum_dist[i] - cum_dist[i - 1]
        grade = dd > 0.001 ? (z_array[i] - z_array[i - 1]).abs / dd : 0
        if dz > Z_JUMP_THRESHOLD
          jumps << { i: i, dist: cum_dist[i], dz: dz, grade: grade }
        end
      end
      range = z_max - z_min
      summary = "[Z-profile] #{phase}: z=#{z_min.to_m.round(2)}–#{z_max.to_m.round(2)}m (Δ#{range.to_m.round(2)}m)"
      if jumps.any?
        puts "#{summary} ⚠ #{jumps.size} Z-JUMP(S):"
        jumps.each do |j|
          puts "[Z-profile]   pt[#{j[:i]}] d=#{j[:dist].to_m.round(1)}m: " \
               "Δz=#{j[:dz].to_m.round(2)}m grade=#{(j[:grade] * 100).round(1)}%"
        end
      else
        puts summary
      end
    end

    def self.smooth_horizontal_xy(points, cum_dist)
      sigma2 = (Constants::HORIZONTAL_SMOOTH_RADIUS / 2.0) ** 2
      n      = points.size
      result = (0...n).map do |i|
        wx = wy = w_sum = 0.0
        (0...n).each do |j|
          d2 = (cum_dist[i] - cum_dist[j]) ** 2
          w  = Math.exp(-d2 / sigma2)
          wx += w * points[j].x; wy += w * points[j].y; w_sum += w
        end
        Geom::Point3d.new(wx / w_sum, wy / w_sum, points[i].z)
      end
      result[0] = points[0]; result[n - 1] = points[n - 1]
      result
    end

    def self.smooth_terrain_z(terrain_pts, cum_dist)
      sigma2 = (Constants::VERTICAL_SMOOTH_RADIUS / 2.0) ** 2
      n      = terrain_pts.size
      (0...n).map do |i|
        weight_sum = z_sum = 0.0
        (0...n).each do |j|
          w = Math.exp(-((cum_dist[i] - cum_dist[j]) ** 2) / sigma2)
          z_sum += w * terrain_pts[j].z; weight_sum += w
        end
        weight_sum > 0 ? z_sum / weight_sum : terrain_pts[i].z
      end
    end

    def self.smooth_profile_z(profile_z, cum_dist, radius)
      sigma2 = (radius / 2.0) ** 2
      n      = profile_z.size
      (0...n).map do |i|
        weight_sum = z_sum = 0.0
        (0...n).each do |j|
          w = Math.exp(-((cum_dist[i] - cum_dist[j]) ** 2) / sigma2)
          z_sum += w * profile_z[j]; weight_sum += w
        end
        weight_sum > 0 ? z_sum / weight_sum : profile_z[i]
      end
    end

    def self.clamp_profile_z(value, min_z, max_z)
      low = min_z.to_f; high = max_z.to_f
      return [low, high].find { |v| v.finite? } || value.to_f if low.nan? || high.nan?
      high = low if high < low
      numeric = value.to_f
      numeric = low unless numeric.finite?
      [[numeric, low].max, high].min
    end

    private

    def self.horiz_unit(a, b)
      dx = b.x - a.x; dy = b.y - a.y
      len = Math.sqrt(dx * dx + dy * dy)
      return Geom::Vector3d.new(1, 0, 0) if len < 0.001
      Geom::Vector3d.new(dx / len, dy / len, 0)
    end

    def self.horiz_dist(a, b)
      Math.sqrt((b.x - a.x)**2 + (b.y - a.y)**2)
    end

  end
end

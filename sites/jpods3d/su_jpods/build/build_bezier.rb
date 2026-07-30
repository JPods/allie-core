# ── Build Bezier — proven bezier math from jpod_network.rb ────────────────────
#
# Migrated from codearchive/jpod_network.rb.
# Pure math — no SketchUp API calls, no model access.
#
# Methods:
#   Network.tangent_curve_pts — 2-CP cubic bezier with tangent alignment
#   Network.bezier_spline_pts — multi-waypoint C1 Catmull-Rom spline
#   Network.offset_path — perpendicular offset for dual tracks

module JPods
  module Network

    BEZIER_TARGET_SEG_M = 1.0.m  # ~1m between sample points

    # ── 2-CP cubic bezier with tangent alignment ─────────────────────────

    def self.tangent_curve_pts(from_cp, to_cp)
      p0 = from_cp[:center]
      p1 = to_cp[:center]
      chord = p0.distance(p1)
      n     = [[(chord / BEZIER_TARGET_SEG_M).ceil, 16].max, 256].min
      # Cap control point distance to 50m — prevents overshoot on long connections
      scale = [chord / 3.0, 50.0.m].min

      t0 = from_cp[:tangent].normalize
      t1 = to_cp[:tangent].normalize

      c0 = Geom::Point3d.new(p0.x + t0.x * scale, p0.y + t0.y * scale, p0.z + t0.z * scale)
      c1 = Geom::Point3d.new(p1.x + t1.x * scale, p1.y + t1.y * scale, p1.z + t1.z * scale)

      (0..n).map do |i|
        t  = i.to_f / n
        mt = 1.0 - t
        Geom::Point3d.new(
          mt*mt*mt*p0.x + 3*mt*mt*t*c0.x + 3*mt*t*t*c1.x + t*t*t*p1.x,
          mt*mt*mt*p0.y + 3*mt*mt*t*c0.y + 3*mt*t*t*c1.y + t*t*t*p1.y,
          mt*mt*mt*p0.z + 3*mt*mt*t*c0.z + 3*mt*t*t*c1.z + t*t*t*p1.z
        )
      end
    end

    # ── Multi-waypoint C1 Catmull-Rom spline ─────────────────────────────

    def self.bezier_spline_pts(from_cp, marker_pts, to_cp, lead_dist: 0)
      from_anchor = from_cp[:center]
      to_anchor   = to_cp[:center]

      return tangent_curve_pts(from_cp, to_cp) if marker_pts.empty? && lead_dist <= 0.001

      # Sort markers by projection onto FROM→TO axis
      sorted = marker_pts.dup
      if sorted.size > 1
        axis  = to_cp[:center] - from_cp[:center]
        a_len = axis.length
        if a_len > 0.001
          sorted = sorted.sort_by { |p| (p - from_cp[:center]).dot(axis) / a_len }
        end
      end

      # Straight-approach composite with lead_dist
      if lead_dist > 0.001
        from_t = from_cp[:tangent].normalize
        to_t   = to_cp[:tangent].normalize
        from_start = Geom::Point3d.new(from_anchor.x + from_t.x * lead_dist,
                                       from_anchor.y + from_t.y * lead_dist, 0)
        to_end     = Geom::Point3d.new(to_anchor.x + to_t.x * lead_dist,
                                       to_anchor.y + to_t.y * lead_dist, 0)
        from_cp_inner = from_cp.merge(center: from_start)
        to_cp_inner   = to_cp.merge(center: to_end)
        bezier_pts = bezier_spline_pts(from_cp_inner, sorted, to_cp_inner, lead_dist: 0)
        return [from_anchor] + bezier_pts + [to_anchor]
      end

      pts = [from_anchor] + sorted + [to_anchor]
      n   = pts.size

      # Catmull-Rom tangent vectors
      tangents = Array.new(n)
      max_tangent = 50.0.m  # cap tangent magnitude to prevent overshoot
      d0 = [pts[0].distance(pts[1]), max_tangent].min
      t0 = from_cp[:tangent].normalize
      tangents[0] = Geom::Vector3d.new(t0.x * d0, t0.y * d0, t0.z * d0)

      dn = [pts[n - 2].distance(pts[n - 1]), max_tangent].min
      tn = to_cp[:tangent].normalize.reverse
      tangents[n - 1] = Geom::Vector3d.new(tn.x * dn, tn.y * dn, tn.z * dn)

      (1...n - 1).each do |i|
        v = Geom::Vector3d.new(pts[i+1].x - pts[i-1].x, pts[i+1].y - pts[i-1].y, pts[i+1].z - pts[i-1].z)
        cr_len = v.length * 0.5
        if cr_len > 0.001
          d_prev = pts[i].distance(pts[i - 1])
          d_next = pts[i].distance(pts[i + 1])
          scale  = [[d_prev, d_next].min / cr_len, 1.0].min
          tangents[i] = Geom::Vector3d.new(v.x * 0.5 * scale, v.y * 0.5 * scale, v.z * 0.5 * scale)
        else
          tangents[i] = tangents[i - 1]
        end
      end

      # Forward-agreement: strip backward component
      (1...n - 1).each do |i|
        fwd = pts[i + 1] - pts[i]
        next if fwd.length < 1e-6
        next if tangents[i].dot(fwd) >= 0
        unit = fwd.normalize
        dot  = tangents[i].dot(unit)
        proj = Geom::Vector3d.new(unit.x * dot, unit.y * dot, unit.z * dot)
        tangents[i] = tangents[i] - proj
        if tangents[i].length < 1e-6
          bwd = pts[i] - pts[i - 1]
          bis = fwd.normalize + bwd.normalize
          s   = [pts[i].distance(pts[i-1]), pts[i].distance(pts[i+1])].min * 0.4
          if bis.length > 1e-6
            bn = bis.normalize
            tangents[i] = Geom::Vector3d.new(bn.x * s, bn.y * s, bn.z * s)
          else
            tangents[i] = Geom::Vector3d.new(0, 0, 0)
          end
        end
      end

      # Sample each cubic segment
      result = []
      (0...n - 1).each do |i|
        p0 = pts[i]; p3 = pts[i + 1]
        chord = p0.distance(p3)
        ti = tangents[i]; tj = tangents[i + 1]

        p1 = Geom::Point3d.new(p0.x + ti.x/3.0, p0.y + ti.y/3.0, p0.z + ti.z/3.0)
        p2 = Geom::Point3d.new(p3.x - tj.x/3.0, p3.y - tj.y/3.0, p3.z - tj.z/3.0)

        seg_n   = [[(chord / BEZIER_TARGET_SEG_M).ceil, 8].max, 64].min
        start_k = i == 0 ? 0 : 1

        (start_k..seg_n).each do |k|
          t  = k.to_f / seg_n
          mt = 1.0 - t
          result << Geom::Point3d.new(
            mt*mt*mt*p0.x + 3*mt*mt*t*p1.x + 3*mt*t*t*p2.x + t*t*t*p3.x,
            mt*mt*mt*p0.y + 3*mt*mt*t*p1.y + 3*mt*t*t*p2.y + t*t*t*p3.y,
            mt*mt*mt*p0.z + 3*mt*mt*t*p1.z + 3*mt*t*t*p2.z + t*t*t*p3.z
          )
        end
      end
      result
    end

    # ── Perpendicular offset for dual tracks ─────────────────────────────

    def self.offset_path(pts, offset_dist)
      return pts if pts.size < 2 || offset_dist.abs < 0.001
      n = pts.size
      pts.each_with_index.map do |pt, i|
        dir = case i
              when 0     then horiz_unit(pts[0], pts[1])
              when n - 1 then horiz_unit(pts[n-2], pts[n-1])
              else
                d1 = horiz_unit(pts[i-1], pts[i])
                d2 = horiz_unit(pts[i], pts[i+1])
                avg = Geom::Vector3d.new((d1.x+d2.x)/2.0, (d1.y+d2.y)/2.0, 0)
                avg_len = avg.length
                if avg_len > 0.001
                  miter = [1.0 / avg_len, 3.0].min
                  n_vec = avg.normalize
                  Geom::Vector3d.new(n_vec.x * miter, n_vec.y * miter, 0)
                else
                  d1
                end
              end
        perp = Geom::Vector3d.new(-dir.y, dir.x, 0)
        Geom::Point3d.new(pt.x + perp.x * offset_dist, pt.y + perp.y * offset_dist, pt.z)
      end
    end

    def self.horiz_unit(a, b)
      dx = b.x - a.x; dy = b.y - a.y
      len = Math.sqrt(dx*dx + dy*dy)
      return Geom::Vector3d.new(1, 0, 0) if len < 0.001
      Geom::Vector3d.new(dx/len, dy/len, 0)
    end

    def self.reverse_seg_id(conn_id, from_spec, to_spec)
      fsid  = (from_spec || {})['structure_id'].to_s.strip
      fstub = (from_spec || {})['stub'].to_i
      tsid  = (to_spec   || {})['structure_id'].to_s.strip
      tstub = (to_spec   || {})['stub'].to_i
      (fsid.empty? || tsid.empty?) ? "#{conn_id}_rev" : "seg_#{tsid}_#{tstub}_#{fsid}_#{fstub}"
    end

  end
end

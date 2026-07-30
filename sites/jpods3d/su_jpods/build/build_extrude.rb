# ── Build Extrude — Upright FollowMe beam extrusion ───────────────────────────
#
# Migrated from codearchive/upright_extruder.rb (Eneroth Railroad origin).
# Keeps the beam cross-section aligned to world Z (upright) while following
# a 3D path — the profile rotates only in XY, never banks.
#
# Public interface:
#   JPods.upright_extrude(face, path, vector_upright = Z_AXIS) → end_face | nil

module JPods

  def self.flatten_vector(vector, plane)
    point_start   = plane[0]
    normal        = plane[1]
    pt_vec_end    = point_start.offset(vector)
    line_to_plane = [pt_vec_end, normal]
    pt_intersect  = Geom.intersect_line_plane(line_to_plane, plane)
    pt_intersect.- point_start
  end

  def self.remove_or_soften_smooth(edge)
    return if edge.deleted?
    return unless edge.faces.length == 2
    on_plane = edge.faces[1].vertices.all? do |v|
      (edge.faces[0].classify_point(v.position) != Sketchup::Face::PointNotOnPlane)
    end
    on_plane ? edge.erase! : (edge.soft = edge.smooth = true)
  end

  def self.upright_extrude(extrusion, path, vector_upright = nil)
    vector_upright ||= Geom::Vector3d.new(0, 0, 1)

    return unless vector_upright.is_a?(Geom::Vector3d)
    return unless extrusion.is_a?(Sketchup::Face)

    closed = (path[0] == path[-1])
    drawing_context = extrusion.parent
    ents = drawing_context.entities
    mat      = extrusion.material
    mat_back = extrusion.back_material
    up_plane = [Geom::Point3d.new, vector_upright]

    if closed
      index_of_closest = 0
      p_closest        = path[0]
      d_closest        = extrusion.vertices[0].position.distance(path[0])
      (0..(path.length - 2)).each do |i|
        p1 = path[i]; p2 = path[i + 1]
        p  = extrusion.vertices[0].position.project_to_line([p1, (p2 - p1)])
        if p1.distance(p) > p1.distance(p2)
          p = p2
        elsif p2.distance(p) > p2.distance(p1)
          p = p1
        end
        d = extrusion.vertices[0].position.distance(p)
        next unless d < d_closest
        index_of_closest = i
        p_closest = p
        d_closest = d
      end
      unless path.include?(p_closest)
        index_of_closest += 1
        path.insert(index_of_closest, p_closest)
      end
      path.pop
      index_of_closest.times { path.push(path.shift) }
      path << path[0]
    else
      if extrusion.vertices[0].position.distance(path[-1]) <
         extrusion.vertices[0].position.distance(path[0])
        path.reverse!
      end
    end

    start_profile = extrusion.outer_loop.vertices.map(&:position)
    smooth_points = (0...extrusion.outer_loop.vertices.length).select do |i|
      v = extrusion.outer_loop.vertices[i]
      v.edges[0].curve && v.edges[1].curve
    end

    edges_to_remove_or_soften = []
    hidden_indices = extrusion.outer_loop.edges.map(&:hidden?)
    geometry_to_hide = []
    previous_profile = start_profile
    previous_edges   = []

    if closed
      v1 = flatten_vector((path[1] - path[0]), up_plane).normalize
      v2 = flatten_vector((path[0] - path[-2]), up_plane).normalize
      vec_rotation_start = Geom::linear_combination(1, v1, 1, v2)
    else
      vec_rotation_start = flatten_vector((path[1] - path[0]), up_plane).normalize
    end

    if closed
      angle_at_start = flatten_vector((path[0] - path[-2]), up_plane)
                         .angle_between(flatten_vector((path[1] - path[0]), up_plane))
      scale_start = 1.0 / Math.cos(angle_at_start / 2.0)
    end

    if closed
      extrusion.erase!
    else
      remove_start = extrusion.outer_loop.edges.all? { |e| e.faces.length == 2 }
      extrusion.erase! if remove_start
    end

    (1..(path.length - 1)).each do |i|
      translation = Geom::Transformation.translation(path[i] - path[0])

      if i == path.length - 1
        vec_rotation = closed ? vec_rotation_start
                               : flatten_vector((path[i] - path[i - 1]), up_plane)
        vec_rotation = vec_rotation.length > 0.001 ? vec_rotation.normalize : vec_rotation_start
      else
        v1 = flatten_vector((path[i] - path[i - 1]), up_plane)
        v2 = flatten_vector((path[i + 1] - path[i]), up_plane)
        v1 = v1.length > 0.001 ? v1.normalize : vec_rotation_start
        v2 = v2.length > 0.001 ? v2.normalize : vec_rotation_start
        vec_rotation = Geom::linear_combination(1, v1, 1, v2)
      end
      next if vec_rotation.length < 0.001

      rotation_angle = vec_rotation.angle_between(vec_rotation_start)
      neg_fwd  = Geom::Point3d.new.offset(vec_rotation_start)
      neg_pos  = neg_fwd.transform(Geom::Transformation.rotation(Geom::Point3d.new, vector_upright,  Math::PI / 2))
      neg_neg  = neg_fwd.transform(Geom::Transformation.rotation(Geom::Point3d.new, vector_upright, -Math::PI / 2))
      neg_path = Geom::Point3d.new.offset(vec_rotation)
      rotation_angle *= -1 if neg_path.distance(neg_neg) < neg_path.distance(neg_pos)
      rotation = Geom::Transformation.rotation(path[i], vector_upright, rotation_angle)

      angle_in_point = if i == path.length - 1
        closed ? angle_at_start : 0
      else
        flatten_vector((path[i] - path[i - 1]), up_plane)
          .angle_between(flatten_vector((path[i + 1] - path[i]), up_plane))
      end
      scale = 1.0 / Math.cos(angle_in_point / 2.0)
      scale /= scale_start if closed

      r_scaling = Geom::Transformation.axes(
        path[i],
        (vec_rotation.cross(vector_upright)),
        vec_rotation,
        vector_upright
      )
      scaling = Geom::Transformation.scaling(Geom::Point3d.new, scale, 1, 1)
      scaling = r_scaling * scaling * r_scaling.inverse
      combined = scaling * rotation * translation

      profile = start_profile.map { |p| p.transform(combined) }
      # Build profile edges directly — never create a face (avoids "not planar" error).
      # The face was only used to get edges, then erased. Edges are all we need.
      prof_edges = []
      profile.each_with_index do |pt, j|
        nj = (j + 1) % profile.length
        edge = ents.add_line(pt, profile[nj]) rescue nil
        prof_edges << edge if edge
      end
      next if prof_edges.empty?

      smooth_extrude_lines = []
      profile.each_with_index do |pt, j|
        edge = ents.add_line(pt, previous_profile[j])
        smooth_extrude_lines << edge if smooth_points.include?(j)
      end

      diagonals = []
      profile.each_with_index do |pt, j|
        nj = (j + 1) % profile.length
        begin
          diag = ents.add_line(pt, previous_profile[nj])
          diagonals << diag if diag
          f1 = ents.add_face(pt, previous_profile[j], previous_profile[nj]) rescue nil
          f2 = ents.add_face(pt, profile[nj], previous_profile[nj]) rescue nil
          [f1, f2].each do |f|
            next unless f.is_a?(Sketchup::Face)
            f.material      = mat
            f.back_material = mat_back
          end
          if hidden_indices[j] && diag && !diag.deleted?
            geometry_to_hide += diag.faces + diag.faces.flat_map(&:edges)
          end
        rescue
          next
        end
      end

      edges_to_remove_or_soften += diagonals + previous_edges + smooth_extrude_lines
      previous_profile = profile
      previous_edges   = prof_edges
    end

    edges_to_remove_or_soften += previous_edges if closed
    edges_to_remove_or_soften.uniq!
    edges_to_remove_or_soften.each { |e| remove_or_soften_smooth(e) }

    geometry_to_hide.uniq!
    geometry_to_hide.each { |g| g.hidden = true unless g.deleted? }

    end_face = nil
    unless closed
      draw_end = previous_edges.any? { |e| e.faces.length != 2 }
      if draw_end
        end_face = ents.add_face(previous_edges)
        end_face.material      = mat
        end_face.back_material = mat_back
      end
    end

    end_face
  end

end

# ── Build Entities — beam geometry, column placement, solar panels ─────────────
#
# Migrated from codearchive/jpod_entities_builder.rb.
# Reopens JPods::JPodGuideway to add geometry-construction class methods.
# Load order: AFTER build_extrude.rb (needs JPods.upright_extrude).

require 'json'

module JPods
  class JPodGuideway

    Z_AXIS = Geom::Vector3d.new(0, 0, 1) unless defined?(Z_AXIS)

    # ── Public entry point ────────────────────────────────────────────────────

    def self.build(group, beam_path, model)
      return if beam_path.size < 2
      group.set_attribute("JPods", "beam_path",
                          beam_path.map { |p| [p.x.to_f, p.y.to_f, p.z.to_f] }.to_json)
      @@structure_followme_paths_cache = nil if defined?(@@structure_followme_paths_cache)
      mat_beam = get_material(model, "JPods_Beam", Sketchup::Color.new(30, 100, 200), 0.85)
      draw_beam(group, beam_path, mat_beam)
    end

    # ── Beam geometry ─────────────────────────────────────────────────────────

    def self.draw_beam(group, path, mat)
      return if path.size < 2
      min_seg = 0.5.m
      clean = [path[0]]
      path.each { |pt| clean << pt if clean.last.distance(pt) >= min_seg }
      clean << path.last if clean.last.distance(path.last) > 0.001
      clean.uniq!
      return if clean.size < 2

      half  = Constants::BEAM_WIDTH / 2.0
      depth = Constants::BEAM_DEPTH

      sg   = group.entities.add_group
      ents = sg.entities

      # Perpendicular in XY plane only — ensures the start face is vertical
      # (planar) regardless of path slope. Z handled separately as beam depth.
      dx = clean[1].x - clean[0].x
      dy = clean[1].y - clean[0].y
      len2d = Math.sqrt(dx * dx + dy * dy)
      rx, ry = len2d < 0.001 ? [1.0, 0.0] : [-dy / len2d, dx / len2d]

      pt = clean[0]
      z_top = pt.z
      z_bot = pt.z - depth
      tl = Geom::Point3d.new(pt.x + rx * half, pt.y + ry * half, z_top)
      tr = Geom::Point3d.new(pt.x - rx * half, pt.y - ry * half, z_top)
      br = Geom::Point3d.new(pt.x - rx * half, pt.y - ry * half, z_bot)
      bl = Geom::Point3d.new(pt.x + rx * half, pt.y + ry * half, z_bot)

      begin
        face = ents.add_face(tl, tr, br, bl)
        unless face.is_a?(Sketchup::Face)
          puts "[Build] draw_beam: start face failed — falling back to line geometry"
          clean.each_cons(2) { |a, b| group.entities.add_line(a, b) rescue nil }
          return
        end
        face.material      = mat
        face.back_material = mat

        start_face = face
        end_face   = JPods.upright_extrude(face, clean.map(&:clone), Z_AXIS)

        ents.grep(Sketchup::Face).each do |f|
          f.material      = mat
          f.back_material = mat
        end

        [start_face, end_face].each do |f|
          next unless f.is_a?(Sketchup::Face) && !f.deleted?
          f.erase!
        end
      rescue => ex
        puts "[Build] draw_beam extrude error: #{ex.message} — falling back to line geometry"
        # Fallback: draw the beam path as colored lines so the connection is visible
        clean.each_cons(2) { |a, b| group.entities.add_line(a, b) rescue nil }
      end
    end

    # ── Structure loading ─────────────────────────────────────────────────────

    def self.available_structures
      base = File.join(File.dirname(File.dirname(__FILE__)), "templates", "structures")
      Dir.glob(File.join(base, "*/model.skp")).map { |f| File.basename(File.dirname(f)) }.sort
    rescue => e
      ["JPod_support_solar_double"]
    end

    remove_const(:STRUCTURE_DISPLAY_NAMES) if const_defined?(:STRUCTURE_DISPLAY_NAMES)
    STRUCTURE_DISPLAY_NAMES = {
      "JPod_station"             => "Station",
      "JPod_support"             => "Support Column",
      "JPod_support_double"      => "Support Column, Double",
      "JPod_support_postmodern"  => "Support Column, Postmodern",
      "JPod_support_solar_double"=> "Support Structure with Solar Panels, Double",
    }.freeze

    def self.display_name(structure_id)
      STRUCTURE_DISPLAY_NAMES[structure_id] || structure_id
    end

    def self.load_structure_definition(model)
      load_structure_definition_by_id(model, "JPod_support_solar_double")
    end

    def self.load_structure_definition_by_id(model, structure_id)
      comp_name = "JPod_structure:#{structure_id}"
      existing  = model.definitions[comp_name]
      return existing if existing

      skp = File.join(File.dirname(File.dirname(__FILE__)), "templates", "structures",
                      structure_id, "model.skp")
      unless File.exist?(skp)
        puts "⚠ JPods: structure template not found: #{skp}"
        return nil
      end

      begin
        defn      = model.definitions.load(skp)
        defn.name = comp_name
        JPods::LayerManager.retag_solar_in_definition(model, defn) if defined?(JPods::LayerManager)
        defn
      rescue => e
        puts "⚠ JPods: failed to load structure SKP — #{e.message}"
        nil
      end
    end

    def self.preload_structure_definitions(model)
      %w[JPod_support_T JPod_solar].each { |id| load_structure_definition_by_id(model, id) }
    end

    remove_const(:STRUCTURE_NATIVE_HEIGHTS) if const_defined?(:STRUCTURE_NATIVE_HEIGHTS)
    STRUCTURE_NATIVE_HEIGHTS = {
      "JPod_support_solar_double" => Constants::STRUCTURE_NATIVE_HEIGHT,
      "JPod_support_double"       => Constants::STRUCTURE_NATIVE_HEIGHT,
      "JPod_support"              => Constants::STRUCTURE_NATIVE_HEIGHT,
      "JPod_support_postmodern"   => Constants::STRUCTURE_NATIVE_HEIGHT,
      "JPod_station"              => Constants::STRUCTURE_NATIVE_HEIGHT,
    }.freeze

    def self.structure_native_height(sid)
      STRUCTURE_NATIVE_HEIGHTS[sid] || Constants::STRUCTURE_NATIVE_HEIGHT
    end

    def self.structure_native_height_for(defn)
      return Constants::STRUCTURE_NATIVE_HEIGHT unless defn
      id = defn.name.sub(/^JPod_structure:/, "")
      STRUCTURE_NATIVE_HEIGHTS[id] || Constants::STRUCTURE_NATIVE_HEIGHT
    end

    # ── Guide circle detection ────────────────────────────────────────────────

    def self.detect_guide_circle_z(defn, target_radius: 0.027.m, tolerance: 0.002.m)
      z = find_circle_z_by_tag(defn.entities, "CenterGuideway")
      return z if z
      z = find_circle_z_by_tag(defn.entities, "CenterCP")
      return z if z
      find_circle_z_in_entities(defn.entities, target_radius, tolerance)
    end

    def self.find_circle_z_by_tag(entities, tag_name)
      entities.each do |e|
        case e
        when Sketchup::Edge
          next unless e.layer.name == tag_name
          c = e.curve
          next unless c.is_a?(Sketchup::ArcCurve)
          pts = c.edges.flat_map { |edge| edge.vertices.map(&:position) }
          return pts.sum { |p| p.z } / pts.size.to_f
        when Sketchup::Group
          z = find_circle_z_by_tag(e.entities, tag_name); return z if z
        when Sketchup::ComponentInstance
          z = find_circle_z_by_tag(e.definition.entities, tag_name); return z if z
        end
      end
      nil
    end

    def self.find_circle_z_in_entities(entities, r_target, tol)
      entities.each do |e|
        case e
        when Sketchup::Edge
          c = e.curve
          next unless c.is_a?(Sketchup::ArcCurve)
          next unless (c.radius - r_target).abs < tol
          pts = c.edges.flat_map { |edge| edge.vertices.map(&:position) }
          return pts.sum { |p| p.z } / pts.size.to_f
        when Sketchup::Group
          z = find_circle_z_in_entities(e.entities, r_target, tol); return z if z
        when Sketchup::ComponentInstance
          z = find_circle_z_in_entities(e.definition.entities, r_target, tol); return z if z
        end
      end
      nil
    end

    # ── Solar + column placement ──────────────────────────────────────────────

    def self.place_solar_columns(centerline_path, conn_group, model)
      col_defn = load_structure_definition_by_id(model, "JPod_support_T")
      spacing  = Constants::SUPPORT_SPACING

      t_arm_z = if col_defn
        detect_guide_circle_z(col_defn) ||
          (Constants::CLEARANCE_HEIGHT - Constants::T_ARM_OFFSET)
      end

      z_axis   = Geom::Vector3d.new(0, 0, 1)
      dist_acc = 0.0
      count    = 0
      (0...centerline_path.size - 1).each do |i|
        p1      = centerline_path[i]
        p2      = centerline_path[i + 1]
        seg_len = p1.distance(p2)
        dir     = horiz_unit(p1, p2)
        x_axis  = dir.cross(z_axis)
        while dist_acc < seg_len
          t       = dist_acc / seg_len
          beam_pt = Geom.linear_combination(1.0 - t, p1, t, p2)
          terrain = Terrain.ground_z_at(model, beam_pt.x, beam_pt.y)
          if col_defn && t_arm_z && t_arm_z > 0
            col_base  = Geom::Point3d.new(beam_pt.x, beam_pt.y, beam_pt.z - t_arm_z)
            transform = Geom::Transformation.axes(col_base, x_axis, dir, z_axis)
            conn_group.entities.add_instance(col_defn, transform)
          else
            clearance = beam_pt.z - terrain.z
            draw_fallback_column(conn_group,
              Geom::Point3d.new(terrain.x, terrain.y, terrain.z),
              clearance) if clearance > 0.05.m
          end
          count += 1
          dist_acc += spacing
        end
        dist_acc -= seg_len
      end
      puts "[Build] #{count} columns placed"

      # Solar panels
      conn_id = conn_group.get_attribute("JPods", "connection_id", "unknown")
      solar_group = model.entities.add_group
      solar_group.name = "Solar_#{conn_id}"
      solar_group.set_attribute("JPods", "connection_id", conn_id)
      solar_group.layer = JPods::LayerManager.get_tag(model, :solar) if defined?(JPods::LayerManager)

      panel_defn = load_structure_definition_by_id(model, "JPod_solar")
      if panel_defn
        place_solar_panel_components(solar_group, centerline_path, model, panel_defn)
      else
        place_solar_panel_faces(solar_group, centerline_path, model)
      end
    end

    def self.place_solar_panel_components(group, path, model, defn)
      repeat = Constants::SOLAR_PANEL_REPEAT
      z_axis = Geom::Vector3d.new(0, 0, 1)
      dist_acc = 0.0
      (0...path.size - 1).each do |i|
        p1 = path[i]; p2 = path[i + 1]; seg_len = p1.distance(p2)
        dir = horiz_unit(p1, p2); x_axis = dir.cross(z_axis)
        while dist_acc < seg_len
          t = dist_acc / seg_len
          bpt = Geom.linear_combination(1.0 - t, p1, t, p2)
          group.entities.add_instance(defn, Geom::Transformation.axes(bpt, x_axis, dir, z_axis))
          dist_acc += repeat
        end
        dist_acc -= seg_len
      end
    end

    def self.place_solar_panel_faces(group, path, model)
      mat = (m = model.materials["JPods_Solar"]) ? m :
            (n = model.materials.add("JPods_Solar"); n.color = Sketchup::Color.new(20, 60, 120); n.alpha = 0.9; n)
      repeat = Constants::SOLAR_PANEL_REPEAT
      depth  = Constants::SOLAR_PANEL_SPACING
      width  = Constants::DUAL_TRACK_SPACING + 3.0.m
      half_d = depth / 2.0; half_w = width / 2.0
      dist_acc = 0.0
      (0...path.size - 1).each do |i|
        p1 = path[i]; p2 = path[i + 1]; seg = p1.distance(p2)
        dir = horiz_unit(p1, p2)
        perp = Geom::Vector3d.new(-dir.y, dir.x, 0)
        while dist_acc < seg
          t = dist_acc / seg
          c = Geom.linear_combination(1.0 - t, p1, t, p2); z = c.z
          c1 = Geom::Point3d.new(c.x+dir.x*half_d+perp.x*half_w, c.y+dir.y*half_d+perp.y*half_w, z)
          c2 = Geom::Point3d.new(c.x+dir.x*half_d-perp.x*half_w, c.y+dir.y*half_d-perp.y*half_w, z)
          c3 = Geom::Point3d.new(c.x-dir.x*half_d-perp.x*half_w, c.y-dir.y*half_d-perp.y*half_w, z)
          c4 = Geom::Point3d.new(c.x-dir.x*half_d+perp.x*half_w, c.y-dir.y*half_d+perp.y*half_w, z)
          pg = group.entities.add_group
          f = pg.entities.add_face(c1, c2, c3, c4)
          (f.material = f.back_material = mat) if f.is_a?(Sketchup::Face)
          dist_acc += repeat
        end
        dist_acc -= seg
      end
    end

    def self.draw_fallback_column(group, base_pt, height)
      # Cap column height — no columns taller than MAX_COLUMN_HEIGHT
      max_h = Constants::MAX_COLUMN_HEIGHT rescue 25.0.m
      height = [height.abs, max_h].min
      return if height < 0.1.m  # skip tiny columns

      pg = group.entities.add_group
      r  = Constants::POST_DIAMETER / 2.0
      c  = pg.entities.add_circle(base_pt, Geom::Vector3d.new(0, 0, 1), r, 8)
      return unless c.is_a?(Array)
      f = pg.entities.add_face(c)
      return unless f.is_a?(Sketchup::Face)
      f.reverse! if f.normal.z < 0
      f.pushpull(height)
    end

    # ── Helpers ───────────────────────────────────────────────────────────────

    def self.horiz_unit(a, b)
      dx = b.x - a.x; dy = b.y - a.y
      len = Math.sqrt(dx * dx + dy * dy)
      return Geom::Vector3d.new(1, 0, 0) if len < 0.001
      Geom::Vector3d.new(dx / len, dy / len, 0)
    end

    def self.get_material(model, name, color, alpha)
      mat = model.materials[name] || model.materials.add(name)
      mat.color = color; mat.alpha = alpha; mat
    end

    def self.add_structures_to_guideway(guideway_group, structure_id, model)
      raw = guideway_group.get_attribute("JPods", "beam_path")
      return false unless raw
      path = JSON.parse(raw).map { |arr| Geom::Point3d.new(*arr) }
      defn = load_structure_definition_by_id(model, structure_id)
      return false unless defn
      model.start_operation("Add Structure to Guideway", true)
      place_columns(guideway_group, path, model, nil, defn: defn)
      model.commit_operation
      true
    rescue => e
      model.abort_operation rescue nil; false
    end

    def self.place_columns(group, path, model, _mat, defn: nil, spacing: nil, arm_z: nil)
      defn    ||= load_structure_definition(model)
      spacing ||= Constants::SUPPORT_SPACING
      native_h = structure_native_height_for(defn)
      dist_acc = 0.0
      (0...path.size - 1).each do |i|
        p1 = path[i]; p2 = path[i + 1]; seg_len = p1.distance(p2)
        dir = horiz_unit(p1, p2)
        while dist_acc < seg_len
          t = dist_acc / seg_len
          beam_pt = Geom.linear_combination(1.0 - t, p1, t, p2)
          terrain = Terrain.ground_z_at(model, beam_pt.x, beam_pt.y)
          clearance = beam_pt.z - terrain.z
          if clearance > 0.05.m
            col_base = Geom::Point3d.new(terrain.x, terrain.y, terrain.z)
            draw_fallback_column(group, col_base, clearance)
          end
          dist_acc += spacing
        end
        dist_acc -= seg_len
      end
    end

  end
end

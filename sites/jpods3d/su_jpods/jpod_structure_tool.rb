# JPods Structure Placer
#
# Provides:
#   JPods::StructurePlacer  — detects stubs, assigns IDs, stores connection data
#   JPods::JPodStructureTool — interactive SketchUp tool for clicking to place
#
# Workflow:
#   Plugins > JPods > Place Structure
#     -> Choose formation type from list
#     -> Click terrain to place  (auto-assigns structure ID like "S001")
#     -> Connection points labeled "s001.0", "s001.1", ... appear in model
#
# Connection-point data is stored in LOCAL coordinates on the instance.
# At network-build time the current instance.transformation is applied to get
# world coordinates, so moving a structure after placement still works.
#
# ── Connection Point Rule ────────────────────────────────────────────────────
#
# THE RULE (April 22, 2026):
#
#   "The Connection Point (CP) is the midpoint between the two seam points where
#    the two parallel guideways meet their removable ending caps."
#
#   CP_center = (seam_left + seam_right) / 2
#
# Each seam is the 3D point where a guideway main extrusion (built by upright_extrude)
# ends and the removable ene_railroad ending cap begins. This is the joint where
# jpod_network.rb cuts the caps away and links two network segments.
#
# Geometrically derived (not guessed):
# - Stubs are paired by outer-tip distance (~3.5 m for dual-guideway structures)
# - Paired outer tips define pd_outer (their midpoint)
# - pd_outer is typically 13.5 m from formation center in a traffic circle
# - The true seam is 9 meters radially outward: seam ≈ pd_outer + 9m * outward_unit
# - The 9m offset was empirically validated: Bill confirmed CPs are now at the
#   correct location where caps join beams
#
# Implementation: see detect_cps_from_cp_markers() and resolve_connection_points().
# Traffic circles apply outward_offset=9.m via pair_stubs fallback; all other formations
# use cp_marker_* as the authoritative CP signal.

require 'json'

module JPods
  module StructurePlacer

    # Toggle state: true when CP labels + gate rings are visible in the viewport.
    # Set false on model open/new (jpod_oversight.rb LoadObserver).
    @cps_shown = false
    def self.cps_shown?  = @cps_shown
    def self.cps_shown=(v); @cps_shown = v; end

    FORMATION_LABELS = {
      "JPods_traffic_circle7"   => "Traffic Circle (7-gate)",
      "JPods_station_container" => "Station (Container)",
      "station_parking"   => "Station (Parking)",
      "JPods_station_solar"     => "Station (Solar)",
      "traffic_circle7"         => "Traffic Circle (7-gate)",
      "station_solar"           => "Station (Solar)",
      "station_line_end"        => "Station (Line End)",
      "station_thru_dip"        => "Station (Thru Dip)",
    }.freeze

    # Legacy formation IDs kept in saved model attributes may outlive template
    # folder renames. Resolve them to current on-disk folder names.
    FORMATION_ALIASES = {
      "JPods_station_solar"   => "station_solar",
      "JPods_traffic_circle7" => "traffic_circle7",
      "JPods_station_short"   => "station_line_end",
    }.freeze

    def self.track_formations_dir
      File.join(File.dirname(__FILE__), "templates", "track_formations")
    end

    # Discover formations from folders that contain model.skp so removals/additions
    # in templates/track_formations are reflected automatically in the picker.
    def self.available_formations
      return [] unless Dir.exist?(track_formations_dir)

      Dir.children(track_formations_dir)
         .sort
         .select { |name| File.file?(formation_skp_path(name)) }
    rescue => e
      puts "JPods: cannot list formations: #{e.message}"
      []
    end

    def self.formation_label(model_id)
      FORMATION_LABELS[model_id] || model_id.sub(/^JPods_/, "").tr("_", " ").split.map(&:capitalize).join(" ")
    end

    def self.formation_options
      available_formations.each_with_object({}) do |model_id, out|
        out[model_id] = formation_label(model_id)
      end
    end

    # Return a formation id that maps to an existing template folder.
    # Preference order: exact id, alias target, then id as-is (for diagnostics).
    def self.resolve_model_id(model_id)
      fid = model_id.to_s
      return fid if File.file?(formation_skp_path(fid))

      mapped = FORMATION_ALIASES[fid]
      return mapped if mapped && File.file?(formation_skp_path(mapped))

      fid
    end

    # ── Formation data loading ────────────────────────────────────────────────

    # Load (or reuse) the formation component definition.
    # Pass force: true to purge any cached copy and reload from disk.
    def self.load_formation_def(model, model_id, force: false)
      resolved_id  = resolve_model_id(model_id)
      comp_name    = "JPods Formation: #{model_id}"
      existing     = model.definitions.find { |d| d.name == comp_name }
      skp          = formation_skp_path(resolved_id)
      source_stamp = File.exist?(skp) ? File.mtime(skp).to_i.to_s : nil

      if existing && !force
        cached_stamp = existing.get_attribute("JPods", "source_stamp")
        if cached_stamp == source_stamp
          return existing  # SKP unchanged — safe to reuse cached definition
        end
        # SKP changed on disk. Rename the stale definition so we can load a
        # fresh copy. Instances that reference the stale definition keep their
        # old geometry — they are not erased.  New placements will use the
        # fresh definition.
        puts "JPods: '#{comp_name}' template changed on disk — loading fresh copy " \
             "(existing placed structures keep their old geometry until re-placed)"
        existing.name = "#{comp_name}__stale"
      end

      unless File.exist?(skp)
        alias_msg = FORMATION_ALIASES[model_id.to_s]
        UI.messagebox("Formation template not found:\n#{skp}\n\nmodel_id=#{model_id}\nresolved_id=#{resolved_id}" +
                      (alias_msg ? "\nalias_candidate=#{alias_msg}" : ""),
                      MB_OK, "JPods")
        return nil
      end

      puts "JPods: loading formation from #{skp}"
      defn      = model.definitions.load(skp)
      defn.name = comp_name
      defn.set_attribute("JPods", "source_stamp", source_stamp)
      defn
    end

    # Read the formation's info file (Ruby Marshal binary, written by ene_railroad).
    # Returns the deserialized Hash or nil on failure.
    def self.load_formation_info(model_id)
      resolved_id = resolve_model_id(model_id)
      info_path = formation_info_path(resolved_id)
      return nil unless File.exist?(info_path)
      Marshal.load(File.binread(info_path))
    rescue => e
      puts "⚠️  JPods: cannot read formation info for '#{model_id}': #{e.message}"
      nil
    end

    def self.formation_skp_path(model_id)
      File.join(track_formations_dir, model_id, "model.skp")
    end

    def self.formation_info_path(model_id)
      File.join(track_formations_dir, model_id, "info")
    end

    # ── Unique structure ID assignment ────────────────────────────────────────

    # Returns a new unique structure ID (e.g. "S001").
    # The model-level counter only ever increases — IDs are never recycled,
    # even after structures are deleted.
    def self.next_structure_id(model, model_id: nil)
      # Prefix by model type:
      #   s### = stations (parking, line_end, thru_dip)
      #   tc### = traffic circles
      #   b### = barriers (cpb)
      #
      # Barriers are serialized because they are subject to barrier inspection
      # to assure guideway safety. Every barrier must be individually identifiable
      # for inspection records. Barriers are pre-placed on all models — users
      # remove them to open CPs, not add them. Barrier IDs are assigned at Build
      # time, not at placement.
      mid = model_id.to_s.downcase
      if mid.include?('cpb') || mid.include?('barrier')
        prefix = 'b'
        count_key = 'barrier_count'
        fmt = "#{prefix}%03d"
      elsif mid.include?('traffic_circle')
        prefix = 'tc'
        count_key = 'tc_count'
        fmt = "#{prefix}%03d"
      else
        prefix = 's'
        count_key = 'structure_count'
        fmt = "#{prefix}%03d"
      end
      n = model.get_attribute("JPods", count_key, 0).to_i + 1
      model.set_attribute("JPods", count_key, n)
      fmt % n
    end

    # ── Stub-pair tag scanner (primary — most direct method) ─────────────────
    #
    # GEOMETRY MODEL — read before editing:
    #
    # CP detection uses cp_marker_* components placed at each gate by the model author.
    # Every cp_marker_* is paired with an inbound gw_cp_in_N track and an outbound
    # gw_cp_out_N track. cp_marker_* is the only authoritative CP signal.
    # No gw_stub_pair tags are used or recognized.

    PLATFORM_TAG    = "gw_platform"
    # Legacy names retained for backward compatibility with older .skp files
    # that have not yet been retagged to the gw_ prefix convention.
    PLATFORM_TAGS   = %w[platform platform_in gw_platform gw_platform_in].freeze
    PLATFORM_TAG_PREFIX = "gw_platform"

    # Return normalized SketchUp tag name for an entity.
    # SketchUp evolved from Layers -> Tags naming; keep compatibility with both.
    def self.entity_tag_name(entity)
      legacy = (entity.layer.name rescue '').to_s.strip
      modern = (entity.tag.name rescue '').to_s.strip
      chosen = modern.empty? ? legacy : modern
      chosen.downcase
    rescue
      ''
    end

    def self.platform_marker?(entity)
      return false unless entity

      tag = entity_tag_name(entity)
      return true if PLATFORM_TAGS.include?(tag) || tag.start_with?(PLATFORM_TAG_PREFIX)

      entity_name = (entity.name rescue '').to_s.strip.downcase
      return true if PLATFORM_TAGS.include?(entity_name) || entity_name.start_with?(PLATFORM_TAG_PREFIX)

      if entity.is_a?(Sketchup::ComponentInstance)
        defn_name = (entity.definition.name rescue '').to_s.strip.downcase
        return true if PLATFORM_TAGS.include?(defn_name) || defn_name.start_with?(PLATFORM_TAG_PREFIX)
      end

      false
    rescue
      false
    end

    def self.platform_record_from_verts(verts)
      return nil if verts.nil? || verts.empty?

      # Use XY distance from origin to identify the two ends of the platform run.
      dists2 = verts.map { |v| v.x * v.x + v.y * v.y }
      max_d2 = dists2.max
      min_d2 = dists2.min
      clus_tol = Constants::BEAM_WIDTH * Constants::BEAM_WIDTH

      far_verts  = verts.select { |v| max_d2 - (v.x * v.x + v.y * v.y) <= clus_tol }
      near_verts = verts.select { |v| (v.x * v.x + v.y * v.y) - min_d2 <= clus_tol }
      return nil if far_verts.empty? || near_verts.empty?

      centroid = lambda do |pts|
        n = pts.size.to_f
        Geom::Point3d.new(
          pts.sum(&:x) / n,
          pts.sum(&:y) / n,
          pts.map(&:z).min # bottom-seam Z datum, same as stub_pair
        )
      end

      far_pt  = centroid.call(far_verts)
      near_pt = centroid.call(near_verts)
      mid_pt  = Geom::Point3d.new(
        (far_pt.x + near_pt.x) / 2.0,
        (far_pt.y + near_pt.y) / 2.0,
        [far_pt.z, near_pt.z].min
      )
      len_m = near_pt.distance(far_pt).to_m.round(3)

      { start: near_pt, end: far_pt, midpoint: mid_pt, length_m: len_m }
    end

    # ── Platform tag scanner ─────────────────────────────────────────────────
    # Finds every entity tagged "platform" inside a ComponentDefinition.
    # For each, collects { start:, end:, midpoint:, length_m: } in LOCAL coords
    # by finding the min and max XY-distance vertices of the entity's geometry.
    # This mirrors the stub_pair scanner so Noelle can identify platform guideways
    # without any geometric inference — the tag is the ground truth.
    def self.scan_platform_entities(entities, transform, out, depth = 0, inherited_platform = false, path = [])
      return if depth > 8
      entities.each do |e|
        layer_name = entity_tag_name(e)
        tagged_platform = inherited_platform || platform_marker?(e)
        entity_name = (e.name rescue '').to_s
        defn_name = (e.is_a?(Sketchup::ComponentInstance) ? (e.definition.name rescue '').to_s : '')
        here = {
          class_name: e.class.to_s,
          entity_name: entity_name,
          definition_name: defn_name,
          tag_name: layer_name,
        }
        next_path = path + [here]
        combined   = if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          transform * e.transformation
        else
          transform
        end

        if tagged_platform
          verts = []
          if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
            child_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
            scan_vertices(child_ents, combined) { |pt| verts << pt }
          elsif e.respond_to?(:vertices)
            e.vertices.each { |v| verts << (combined * v.position) }
          end
          rec = platform_record_from_verts(verts)

          # Some platform-tagged containers may not expose usable edge vertices
          # through scan_vertices (or can be face-only wrappers). Fall back to
          # local bounds corners so platform export still has a usable record.
          if rec.nil? && (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance))
            local_bb = e.is_a?(Sketchup::Group) ? e.entities.bounds : e.definition.bounds
            if local_bb && local_bb.valid?
              bb_pts = (0..7).map { |i| combined * local_bb.corner(i) }
              rec = platform_record_from_verts(bb_pts)
              puts "JPods platform: bounds fallback used for #{e.class} tag=#{layer_name.inspect}" if rec
            end
          end

          if rec
            rec = rec.merge(
              source: {
                entity: e,
                class_name: here[:class_name],
                entity_name: here[:entity_name],
                definition_name: here[:definition_name],
                tag_name: here[:tag_name],
                path: next_path.map { |row|
                  n = row[:entity_name].to_s.strip
                  d = row[:definition_name].to_s.strip
                  c = row[:class_name].to_s
                  label = n.empty? ? (d.empty? ? c : d) : n
                  "#{label}(#{c})"
                }.join(' > '),
              }
            )
            out << rec
          end
          # Do not recurse into a tagged container to avoid double-counting.
          next if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        end

        if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          child_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          scan_platform_entities(child_ents, combined, out, depth + 1, tagged_platform, next_path)
        end
      end
    end

    # Detect platform guideways starting from a placed structure instance/group.
    # This supports tags applied at instance level as well as inside definitions.
    def self.detect_platform_guideways_on_structure(structure_entity)
      return [] unless structure_entity.is_a?(Sketchup::ComponentInstance) || structure_entity.is_a?(Sketchup::Group)

      child_ents = structure_entity.is_a?(Sketchup::Group) ? structure_entity.entities : structure_entity.definition.entities
      inherited_platform = platform_marker?(structure_entity)
      platforms = []
      scan_platform_entities(child_ents, structure_entity.transformation, platforms, 0, inherited_platform)
      platforms
    rescue => ex
      puts "JPods detect_platform_guideways_on_structure error: #{ex.message}"
      []
    end

    # Console diagnostic for platform-tagged entities currently detected in model.
    # Returns a summary hash and prints a station-by-station breakdown.
    def self.list_platform_tagged_items(model)
      structures = model.entities.select do |e|
        (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
          (jpods_structure_candidate?(e) rescue false)
      end

      if structures.empty?
        puts 'JPods platform tags: no placed structures found in model.'
        return { ok: false, structure_count: 0, platform_count: 0, stations_with_platforms: 0 }
      end

      total_platforms = 0
      stations_with_platforms = 0
      report = []

      structures.each do |structure|
        sid = structure.get_attribute('JPods', 'structure_id', '?').to_s
        fid = structure.get_attribute('JPods', 'model_id', '?').to_s
        platforms = detect_platform_guideways_on_structure(structure)
        count = platforms.size
        total_platforms += count
        stations_with_platforms += 1 if count > 0

        # Tag each detected platform entity with its station's P-ID.
        # Using a JPods attribute rather than renaming the group, because all
        # station_solar instances share the same ComponentDefinition — renaming
        # a group inside one instance renames it in all instances.
        if count > 0 && sid =~ /^S(\d+)$/
          pid = "P#{$1}"
          platforms.each do |p|
            ent = p.dig(:source, :entity)
            ent.set_attribute('JPods', 'platform_id', pid) if ent.respond_to?(:set_attribute) rescue nil
          end
        end

        puts "JPods platform tags: #{sid} (#{fid}) -> #{count} detected platform item(s)"
        platforms.each_with_index do |p, idx|
          mid = p[:midpoint]
          src = p[:source] || {}
          path = src[:path].to_s
          pid  = (src[:entity].get_attribute('JPods', 'platform_id', nil) rescue nil)
          puts "  [#{idx + 1}] length=#{p[:length_m]}m mid=(#{mid.x.to_m.round(3)}, #{mid.y.to_m.round(3)}, #{mid.z.to_m.round(3)})m"
          puts "      source=#{path}" unless path.empty?
          pid_str = pid ? " platform_id=#{pid}" : ''
          puts "      tag=#{src[:tag_name]} name=#{src[:entity_name]}#{pid_str}"
        end

        report << {
          structure_id: sid,
          model_id: fid,
          platform_count: count,
          platforms: platforms,
        }
      end

      puts "JPods platform tags summary: structures=#{structures.size}, stations_with_platforms=#{stations_with_platforms}, platform_items=#{total_platforms}"
      {
        ok: true,
        structure_count: structures.size,
        stations_with_platforms: stations_with_platforms,
        platform_count: total_platforms,
        report: report,
      }
    rescue => ex
      puts "JPods list_platform_tagged_items error: #{ex.message}"
      { ok: false, structure_count: 0, platform_count: 0, stations_with_platforms: 0, fault: ex.message }
    end

    # Detect platform guideways in a ComponentDefinition.
    # Returns Array of { start:, end:, midpoint:, length_m: } in LOCAL coords, or [].
    def self.detect_platform_guideways_in_defn(defn)
      return [] unless defn.respond_to?(:entities)
      platforms = []
      scan_platform_entities(defn.entities, Geom::Transformation.new, platforms)
      if platforms.empty?
        puts "  JPods platform: no 'platform' tagged entities found in #{defn.name}"
      else
        puts "  JPods platform: #{platforms.size} platform guideway(s) found in #{defn.name}"
        platforms.each_with_index do |p, i|
          puts "    [#{i}] length=#{p[:length_m]} m  mid=(#{p[:midpoint].x.to_m.round(3)}, #{p[:midpoint].y.to_m.round(3)}, #{p[:midpoint].z.to_m.round(3)}) m"
        end
      end
      platforms
    rescue => ex
      puts "JPods detect_platform_guideways_in_defn error: #{ex.message}"
      []
    end

    # ── Stub geometry helpers ─────────────────────────────────────────────────

    # Centroid XY + minimum Z of a vertex array (bottom-centerline seam datum).
    def self.centroid_min_z(verts)
      n = verts.size.to_f
      Geom::Point3d.new(verts.sum(&:x) / n, verts.sum(&:y) / n, verts.map(&:z).min)
    end

    # Unit vector in XY pointing from `from_pt` toward `to_pt`. Falls back to +X.
    def self.xy_tangent(from_pt, to_pt)
      dx = to_pt.x - from_pt.x
      dy = to_pt.y - from_pt.y
      len = Math.sqrt(dx * dx + dy * dy)
      len > 0.001 ? Geom::Vector3d.new(dx / len, dy / len, 0) : Geom::Vector3d.new(1, 0, 0)
    end

    # Cluster stub vertices into outer (gate face) and inner (loop face) groups
    # by projection along the outward axis from formation center through stub centroid.
    # Falls back to radial distance when stub centroid coincides with formation center.
    def self.cluster_verts_by_projection(verts, stub_cx, stub_cy, fc_x, fc_y, tolerance)
      odx = stub_cx - fc_x
      ody = stub_cy - fc_y
      od_len = Math.sqrt(odx * odx + ody * ody)
      if od_len > 0.001
        odx /= od_len; ody /= od_len
        projs  = verts.map { |v| (v.x - stub_cx) * odx + (v.y - stub_cy) * ody }
        max_p  = projs.max; min_p = projs.min
        outer  = verts.select.with_index { |_, i| max_p - projs[i] <= tolerance }
        inner  = verts.select.with_index { |_, i| projs[i] - min_p <= tolerance }
      else
        dists2 = verts.map { |v| v.x * v.x + v.y * v.y }
        max_d2 = dists2.max; min_d2 = dists2.min; tol2 = tolerance * tolerance
        outer  = verts.select { |v| max_d2 - (v.x * v.x + v.y * v.y) <= tol2 }
        inner  = verts.select { |v| (v.x * v.x + v.y * v.y) - min_d2 <= tol2 }
      end
      { outer: outer, inner: inner }
    end

    # Average the outward tangents of two paired stub tips.
    # Falls back to the radial direction from inward_ref when the average is degenerate.
    def self.avg_outward_tangent(ta, tb, gate_ctr, inward_ref)
      avg = Geom::Vector3d.new((ta[:tangent].x + tb[:tangent].x) / 2.0,
                               (ta[:tangent].y + tb[:tangent].y) / 2.0, 0)
      if avg.length > 0.001
        outward = Geom::Vector3d.new(gate_ctr.x - inward_ref.x,
                                     gate_ctr.y - inward_ref.y, 0)
        avg = avg.reverse if outward.length > 0.001 && avg.dot(outward) < 0
        return avg.normalize
      end
      rv = Geom::Vector3d.new(gate_ctr.x - inward_ref.x, gate_ctr.y - inward_ref.y, 0)
      rv.length > 0.001 ? rv.normalize : Geom::Vector3d.new(1, 0, 0)
    end

    # Centroid of all tip outer_pts in XY — used as interior reference point
    # for unpaired stubs and degenerate tangent fallback.
    def self.inward_ref_from_tips(tips)
      n = tips.size.to_f
      Geom::Point3d.new(tips.sum { |t| t[:point].x } / n,
                        tips.sum { |t| t[:point].y } / n, 0)
    end

    # Orient each stub so stub[:point] is the outer (cap) tip, then deduplicate
    # by outer-tip position. Called by pair_stubs before the pairing loop.
    def self.normalize_stubs_to_outer(stubs, centroid)
      stubs = stubs.map do |s|
        s[:point].distance(centroid) >= s[:companion].distance(centroid) ? s :
          { point: s[:companion], tangent: s[:tangent].reverse, companion: s[:point] }
      end
      seen = {}
      stubs.reject do |s|
        key = [s[:point].x.round(2), s[:point].y.round(2), s[:point].z.round(2)]
        seen.key?(key) ? true : (seen[key] = true; false)
      end
    end


    # ── CP detection from explicit 'cp' component instances ──────────────────
    #
    # Authoritative method (Axiom 10).
    #
    # A 3-line axis indicator (named/tagged 'cp') is placed at each CP gate:
    #   • 1500mm line → outward tangent direction
    #   • ~11mm line  → cross-track (right when looking outward)
    #   • ~7mm line   → downward (−Z)
    #
    # Legacy fallback: cp instances nested anywhere inside the station definition.
    # Not called when detect_cps_from_top_level_cp (Priority 1) succeeds.
    #
    # Returns sorted Array of { index:, center:, tangent:, half_offset: },
    # or [] if no cp instances found.
    def self.detect_cps_from_cp_instances(defn)
      formation_center = defn.bounds.center

      # Legacy fallback: bare 'cp' component instances at the top level of the definition.
      # Modern templates place cp_marker_N components instead (caught by detect_cps_from_top_level_cp).
      nested = []
      top_level = []
      defn.entities.each do |e|
        next unless e.is_a?(Sketchup::ComponentInstance)
        ct = entity_tag_name(e)
        dn = e.definition.name.to_s.strip.downcase
        next unless ct == 'cp' || dn == 'cp' || dn.match?(/\Acp#\d+\z/)
        top_level << { xform: e.transformation, defn: e.definition }
      end

      if top_level.any?
        puts "  JPods cp: #{top_level.size} bare cp instance(s) at top level — legacy fallback"
        nested = top_level
      end

      return [] if nested.empty?

      # ── Build result — index by atan2 from formation center ──────────────
      result = nested.map do |entry|
        world_xform = entry[:xform]
        center      = world_xform.origin
        b           = entry[:defn].bounds

        x_ext = (b.max.x - b.min.x).abs
        y_ext = (b.max.y - b.min.y).abs
        z_ext = (b.max.z - b.min.z).abs
        local_long = if x_ext >= y_ext && x_ext >= z_ext
          Geom::Vector3d.new(1, 0, 0)
        elsif y_ext >= z_ext
          Geom::Vector3d.new(0, 1, 0)
        else
          Geom::Vector3d.new(0, 0, 1)
        end

        tangent = world_xform * local_long
        tangent = tangent.length > 1e-6 ? tangent.normalize : Geom::Vector3d.new(1, 0, 0)

        outward = Geom::Vector3d.new(center.x - formation_center.x,
                                      center.y - formation_center.y, 0)
        tangent = tangent.reverse if outward.length > 1e-6 && tangent.dot(outward) < 0

        { center: center, tangent: tangent,
          half_offset: Constants::DUAL_TRACK_SPACING / 2.0 }
      end

      result.sort_by! { |cp|
        Math.atan2(cp[:center].y - formation_center.y, cp[:center].x - formation_center.x)
      }
      result.each_with_index do |cp, i|
        cp[:index] = i
        c = cp[:center]; t = cp[:tangent]
        puts "  JPods cp: .#{i} at " \
             "(#{c.x.to_m.round(3)}, #{c.y.to_m.round(3)}, #{c.z.to_m.round(3)}) m  " \
             "tangent=(#{t.x.round(3)}, #{t.y.round(3)})"
      end
      result
    rescue => ex
      puts "JPods detect_cps_from_cp_instances error: #{ex.message}"
      []
    end

    # Detect CPs from paired gw_N_in / gw_N_out arm groups (traffic circle model).
    #
    # Traffic circle templates have separate single-rail arms: gw_0_in, gw_0_out,
    # gw_1_in, gw_1_out, etc.  The gate CP center is the midpoint of both arms'
    # outer endpoints.  This avoids the ~0.25m lateral error that occurs when cp
    # instances are placed at only one arm's gate face.
    #
    # Returns Array of { index:, center:, tangent:, half_offset: }
    # or [] if no gw_N_in / gw_N_out pairs found.
    def self.detect_cps_from_arm_pairs(defn)
      formation_center = defn.bounds.center
      fc_x = formation_center.x
      fc_y = formation_center.y

      arm_in  = {}
      arm_out = {}

      defn.entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        label = entity_tag_name(e)
        label = (e.name rescue '').to_s.strip.downcase if label.empty?
        if (m = label.match(/\Agw_(\d+)_in\z/))
          arm_in[m[1].to_i] = e
        elsif (m = label.match(/\Agw_(\d+)_out\z/))
          arm_out[m[1].to_i] = e
        end
      end

      paired_ns = arm_in.keys & arm_out.keys
      return [] if paired_ns.empty?

      puts "  JPods arm_pair: #{paired_ns.size} arm pair(s) — traffic circle CP detection"

      result = paired_ns.map do |n|
        in_ent  = arm_in[n]
        out_ent = arm_out[n]

        in_child  = in_ent.is_a?(Sketchup::Group)  ? in_ent.entities  : in_ent.definition.entities
        out_child = out_ent.is_a?(Sketchup::Group) ? out_ent.entities : out_ent.definition.entities

        in_verts  = []
        out_verts = []
        scan_vertices(in_child,  in_ent.transformation)  { |pt| in_verts  << pt }
        scan_vertices(out_child, out_ent.transformation) { |pt| out_verts << pt }
        next nil if in_verts.empty? || out_verts.empty?

        in_cx  = in_verts.sum(&:x)  / in_verts.size.to_f
        in_cy  = in_verts.sum(&:y)  / in_verts.size.to_f
        out_cx = out_verts.sum(&:x) / out_verts.size.to_f
        out_cy = out_verts.sum(&:y) / out_verts.size.to_f

        tol = Constants::BEAM_WIDTH / 2.0
        in_clusters  = cluster_verts_by_projection(in_verts,  in_cx,  in_cy,  fc_x, fc_y, tol)
        out_clusters = cluster_verts_by_projection(out_verts, out_cx, out_cy, fc_x, fc_y, tol)

        in_outer_pt  = centroid_min_z(in_clusters[:outer])
        out_outer_pt = centroid_min_z(out_clusters[:outer])

        gate_ctr    = Geom::Point3d.linear_combination(0.5, in_outer_pt, 0.5, out_outer_pt)
        tangent     = xy_tangent(formation_center, gate_ctr)
        half_offset = in_outer_pt.distance(out_outer_pt) / 2.0
        half_offset = Constants::DUAL_TRACK_SPACING / 2.0 if half_offset < 0.01.m

        puts "  JPods arm_pair: .#{n} at " \
             "(#{gate_ctr.x.to_m.round(3)}, #{gate_ctr.y.to_m.round(3)}, #{gate_ctr.z.to_m.round(3)}) m  " \
             "tangent=(#{tangent.x.round(3)}, #{tangent.y.round(3)})  " \
             "half_offset=#{half_offset.to_m.round(3)}m"

        { index: n, center: gate_ctr, tangent: tangent, half_offset: half_offset }
      end.compact

      result.sort_by { |cp| cp[:index] }
    rescue => ex
      puts "JPods detect_cps_from_arm_pairs error: #{ex.message}"
      []
    end

    # Recursive collector for cp component instances within a formation definition.
    # Recurses into groups and non-cp components up to max_depth.
    # Stops recursing when it finds a cp instance — does not descend into it.
    def self.collect_cp_instances(entities, xform, out, depth = 0)
      return if depth > 4
      entities.each do |e|
        case e
        when Sketchup::ComponentInstance
          ct    = entity_tag_name(e)
          dname = e.definition.name.to_s.strip.downcase
          if ct == 'cp' || ct.match?(/\Acp_marker(_\d+)?\z/) ||
             dname == 'cp' || dname.match?(/\Acp(#\d+)?\z/) || dname.match?(/\Acp_marker(_\d+)?\z/)
            # Extract the marker index from the tag or definition name.
            # Prefer tag (set by user in Outliner/Tags); fall back to definition name.
            marker_lbl = ct.to_s.strip.downcase
            marker_lbl = dname if marker_lbl.empty?
            m_idx = marker_lbl.match(/(\d+)\z/)
            out << { xform: xform * e.transformation, defn: e.definition,
                     marker_index: m_idx ? m_idx[1].to_i : nil }
          else
            collect_cp_instances(e.definition.entities, xform * e.transformation,
                                 out, depth + 1)
          end
        when Sketchup::Group
          collect_cp_instances(e.entities, xform * e.transformation, out, depth + 1)
        end
      end
    rescue => ex
      puts "  JPods collect_cp_instances error at depth #{depth}: #{ex.message}"
    end

    # Detect CPs from cp component instances (uniform cp design).
    #
    # The uniform cp component is placed by the model author at the exact gate
    # center in each template.  Its world-transform origin IS the CP position
    # (Axiom 10 — explicit model datum beats derived reference).
    #
    # Scans recursively into formation sub-groups (depth ≤ 4) so cp instances
    # are found regardless of nesting level in the template model.
    #
    # Returns Array of { index:, center:, tangent:, half_offset: } or [].
    def self.detect_cps_from_top_level_cp(defn)
      formation_center = defn.bounds.center
      puts "  JPods CP formation_center (#{defn.name}): " \
           "(#{formation_center.x.to_m.round(3)}, #{formation_center.y.to_m.round(3)}, #{formation_center.z.to_m.round(3)})m"
      collected = []
      collect_cp_instances(defn.entities, Geom::Transformation.new, collected)

      if collected.empty?
        puts "  JPods top-level cp: none found in #{defn.name} (depth ≤ 4)"
        return []
      end

      cps = []
      collected.each do |entry|
        world_xform = entry[:xform]
        cp_defn     = entry[:defn]

        # The cp component has two 1750mm rail edges connecting hub to each rail.
        # Hub vertex = the vertex shared by both rail edges = CP gate center.
        # CP tangent = outward direction from formation center through hub.
        # No special tangent-indicator edge required.
        half_off_in = Constants::DUAL_TRACK_SPACING / 2.0  # 1.75m in inches
        tol_in      = 100.0 / 25.4                          # ±100mm tolerance

        rail_edges = []
        cp_defn.entities.each do |e|
          next unless e.is_a?(Sketchup::Edge)
          rail_edges << e if (e.length - half_off_in).abs < tol_in
        end

        # Hub = vertex shared by two rail edges; if none shared, use insertion origin.
        hub_vertex = nil
        if rail_edges.size >= 2
          vertex_count = Hash.new(0)
          rail_edges.each { |e| e.vertices.each { |v| vertex_count[v] += 1 } }
          hub_vertex = vertex_count.select { |_, cnt| cnt >= 2 }.max_by { |_, cnt| cnt }&.first
        end

        center_local = if hub_vertex
          hub_vertex.position
        else
          # Fallback: use cp_marker insertion origin.
          edge_lens = cp_defn.entities.select { |e| e.is_a?(Sketchup::Edge) }
                                      .map    { |e| (e.length * 25.4).round(1) }.sort
          puts "  JPods cp WARN: no hub vertex found (rail_edges=#{rail_edges.size}, " \
               "edges=#{edge_lens.inspect}) — using insertion origin"
          Geom::Point3d.new(0, 0, 0)
        end

        # Transform center to formation-local (world_xform = accumulated formation hierarchy xf).
        center_world  = world_xform * center_local

        # Tangent: perpendicular to the rail span at this CP gate, pointing outward.
        # This is exact — independent of bounding-box center bias.
        # xy_tangent(formation_center, center_world) introduces angular error when the
        # formation bounding box is asymmetric (e.g. parking bays offset the center).
        # The rail span direction IS the cross-track direction; its perpendicular IS
        # the exact stub axis. formation_center is used only to resolve the ±sign.
        tangent_world = if rail_edges.size >= 2 && hub_vertex
          rail_tips = rail_edges.flat_map { |re| re.vertices }
                                .reject { |v| v.entityID == hub_vertex.entityID }
                                .first(2)
                                .map { |v| world_xform * v.position }
          if rail_tips.size == 2
            span_x  = rail_tips[1].x - rail_tips[0].x
            span_y  = rail_tips[1].y - rail_tips[0].y
            span_len = Math.sqrt(span_x * span_x + span_y * span_y)
            if span_len > 0.001
              perp_a = Geom::Vector3d.new(-span_y / span_len,  span_x / span_len, 0)
              perp_b = Geom::Vector3d.new( span_y / span_len, -span_x / span_len, 0)
              out_x  = center_world.x - formation_center.x
              out_y  = center_world.y - formation_center.y
              (perp_a.x * out_x + perp_a.y * out_y) >= 0 ? perp_a : perp_b
            else
              xy_tangent(formation_center, center_world)
            end
          else
            xy_tangent(formation_center, center_world)
          end
        else
          xy_tangent(formation_center, center_world)
        end

        puts "  JPods cp gate: center=(#{center_world.x.to_m.round(3)},#{center_world.y.to_m.round(3)},#{center_world.z.to_m.round(3)}) " \
             "tangent=(#{tangent_world.x.round(3)},#{tangent_world.y.round(3)})"

        cps << { center: center_world, tangent: tangent_world,
                 half_offset: Constants::DUAL_TRACK_SPACING / 2.0 }
      end

      return [] if cps.empty?

      # Assign indices directly from marker_index saved during collection.
      # Each entry in `collected` corresponds 1-to-1 with an entry in `cps`
      # (same iteration order).  If ALL entries have a marker_index, use them
      # directly — no nearest-neighbour matching, no atan2 bias.
      all_have_index = collected.all? { |e| !e[:marker_index].nil? }
      if all_have_index
        collected.each_with_index do |entry, i|
          cps[i][:index] = entry[:marker_index]
        end
      else
        # Fallback: atan2 sort from formation center (no marker_index available)
        puts "  JPods cp: no marker indices on some entries — using atan2 fallback"
        fc = formation_center
        cps.sort_by! { |cp| Math.atan2(cp[:center].y - fc.y, cp[:center].x - fc.x) }
        cps.each_with_index { |cp, i| cp[:index] = i }
      end
      cps.sort_by! { |cp| cp[:index] }

      cps.each do |cp|
        c = cp[:center]; t = cp[:tangent]
        puts "  JPods top-level cp: .#{cp[:index]} at " \
             "(#{c.x.to_m.round(3)}, #{c.y.to_m.round(3)}, #{c.z.to_m.round(3)}) m  " \
             "tangent=(#{t.x.round(3)}, #{t.y.round(3)})"
      end

      cps
    rescue => ex
      puts "JPods detect_cps_from_top_level_cp error: #{ex.message}"
      []
    end

    # Build CP list from formation entities.
    # Priority order:
    #   1. Top-level cp_marker_* instances — authoritative (all formations)
    #   2. cp instances nested elsewhere in the definition — legacy fallback
    # Returns Array of { index:, center:, tangent:, half_offset: } or [].
    # Universal requirement: every template model must have cp_marker_* at each CP.
    def self.detect_cps_from_cp_markers(defn)
      # Priority 1: top-level cp_marker_* instances (Axiom 10 — explicit datum).
      top_cps = detect_cps_from_top_level_cp(defn)
      unless top_cps.empty?
        puts "  JPods CP detection: #{top_cps.size} cp_marker_* instance(s) — using placed positions"
        return top_cps
      end

      # Priority 2: cp instances nested anywhere in the definition (legacy placement).
      cp_instances = detect_cps_from_cp_instances(defn)
      unless cp_instances.empty?
        puts "  JPods CP detection: #{cp_instances.size} nested cp instance(s) found"
        return cp_instances
      end

      # No cp instances found — fail loudly. No silent fallback.
      puts "  JPods CP detection: FAILED — no cp_marker_* found in #{defn.name}"
      puts "  JPods CP detection: Open the template model and place cp_marker_* at each CP."
      []
    rescue => e
      puts "JPods detect_cps_from_cp_markers error: #{e.message}"
      []
    end

    # ── Stub detection from formation placement_data ──────────────────────────

    # Returns all track endpoints that are NOT shared with another endpoint —
    # i.e., the "open" ends that connect to the outside world.
    # All coordinates are in the formation's LOCAL space (inches).
    #
    # placement_data — Array of hashes:
    #   { controls: [[x,y,z], [x,y,z], [vx,vy,vz], [vx,vy,vz]],
    #     curve_algorithm: "arc" }
    # controls[0] = start point,  controls[2] = start tangent (into track)
    # controls[1] = end point,    controls[3] = end tangent   (into track)
    # Collect every track endpoint from placement_data (both external and
    # internal joints).  Used by detect_external_stubs and pair_stubs.
    def self.collect_all_endpoints(placement_data)
      all_eps = []
      return all_eps unless placement_data.is_a?(Array)
      placement_data.each do |track|
        ctrl = track[:controls] || track["controls"]
        next unless ctrl.is_a?(Array) && ctrl.size >= 4

        p0 = point3d_from_any(ctrl[0])
        p1 = point3d_from_any(ctrl[1])
        v0 = vector3d_from_any(ctrl[2])
        v1 = vector3d_from_any(ctrl[3])
        next unless p0 && p1 && v0 && v1

        # companion = the OTHER end of this same track segment.
        all_eps << { point: p0, tangent: v0, companion: p1 }
        all_eps << { point: p1, tangent: v1, companion: p0 }
      end
      all_eps
    end

    def self.detect_external_stubs(placement_data)
      tolerance = 0.5  # inches — two points closer than this are the same joint

      all_eps = collect_all_endpoints(placement_data)

      # Tag every endpoint that shares its position with another (internal joint).
      is_internal = Array.new(all_eps.size, false)
      all_eps.each_with_index do |ep_a, i|
        all_eps.each_with_index do |ep_b, j|
          next if j <= i
          if ep_a[:point].distance(ep_b[:point]) < tolerance
            is_internal[i] = true
            is_internal[j] = true
          end
        end
      end

      all_eps.each_with_index
             .reject { |_, i| is_internal[i] }
             .map    { |ep, _| ep }
    end

    MAX_PAIR_DIST = 4.0.m

    # CP marker circles drawn at each connection-point centre.
    # Supports two sizes:
    #   A — original 100 mm radius circles
    #   B — small ~11 mm circles (SketchUp rounds drawn 0.0111 m to 0.011 m)
    # The circle center = CP position.  Outbound tangent = radially outward.
    CP_CIRCLE_RADIUS_A = 0.1.m     # 100 mm
    CP_CIRCLE_TOL_A    = 0.015.m   # ±15 mm
    CP_CIRCLE_RADIUS_B = 0.011.m   # 11 mm
    CP_CIRCLE_TOL_B    = 0.004.m   # ±4 mm
    CP_CIRCLE_RADIUS   = CP_CIRCLE_RADIUS_A   # primary alias
    CP_CIRCLE_TOL      = CP_CIRCLE_TOL_A

    # ── Gate-line detection (primary method) ─────────────────────────────────

    # Scan a ComponentDefinition for 100 mm circles drawn at each CP location.
    # Each circle edge belongs to a Sketchup::ArcCurve; we de-duplicate by
    # curve entity ID so the same circle is not added multiple times.
    #
    # Returns Array of { midpoint:, tangent:, half_offset: } in LOCAL coords.
    def self.detect_gate_lines(entities, transform = Geom::Transformation.new,
                               depth = 0)
      return [] if depth > 4
      raw_results = []
      seen_curves = {}

      entities.each do |e|
        case e
        when Sketchup::Edge
          curve = e.curve
          next unless curve.is_a?(Sketchup::ArcCurve)
          next unless full_circle_arc?(curve)
          next if seen_curves[curve.entityID]
          r = curve.radius.abs  # guard against negative-scale transform artefacts
          is_cp = (r - CP_CIRCLE_RADIUS_A).abs < CP_CIRCLE_TOL_A ||
                  (r - CP_CIRCLE_RADIUS_B).abs < CP_CIRCLE_TOL_B
          next unless is_cp

          seen_curves[curve.entityID] = true
          center = transform * curve.center

          # Tangent = radially outward from structure origin in XY plane.
          radial  = Geom::Vector3d.new(center.x, center.y, 0)
          tangent = radial.length > 0.001 ? radial.normalize
                                          : Geom::Vector3d.new(1, 0, 0)

          raw_results << { midpoint:    center,
                           tangent:     tangent,
                           half_offset: Constants::DUAL_TRACK_SPACING / 2.0 }

        when Sketchup::Group
          tag = e.name.to_s.downcase
          if tag.include?("cp_tag")
            cp_pos  = transform * e.transformation.origin
            radial  = Geom::Vector3d.new(cp_pos.x, cp_pos.y, 0)
            tangent = radial.length > 0.001 ? radial.normalize : Geom::Vector3d.new(1, 0, 0)
            raw_results << { midpoint:    cp_pos,
                             tangent:     tangent,
                             half_offset: Constants::DUAL_TRACK_SPACING / 2.0,
                             source:      :cp_tag }
          else
            raw_results += detect_gate_lines(e.entities,
                                             transform * e.transformation,
                                             depth + 1)
          end
        when Sketchup::ComponentInstance
          defn_name = e.definition.name.to_s.downcase
          inst_name = e.name.to_s.downcase
          if defn_name.include?("cp_tag") || inst_name.include?("cp_tag")
            cp_pos  = transform * e.transformation.origin
            radial  = Geom::Vector3d.new(cp_pos.x, cp_pos.y, 0)
            tangent = radial.length > 0.001 ? radial.normalize : Geom::Vector3d.new(1, 0, 0)
            raw_results << { midpoint:    cp_pos,
                             tangent:     tangent,
                             half_offset: Constants::DUAL_TRACK_SPACING / 2.0,
                             source:      :cp_tag }
          else
            raw_results += detect_gate_lines(e.definition.entities,
                                             transform * e.transformation,
                                             depth + 1)
          end
        end
      end

      # All CP markers (whether raw circles or CP_tag groups/components) go
      # through merge_dual_gate_markers.  That step:
      #   - leaves alone any marker already at the gate midpoint (no nearby pair)
      #   - merges pairs ~3.5 m apart (one per guideway CL) into the true midpoint
      # The :source tag is preserved so callers can see which path was used.
      puts "  JPods detect_gate_lines: #{raw_results.size} raw results before merge"
      merge_dual_gate_markers(raw_results)
    end

    # Some templates place CP circle markers on each individual guideway stub
    # rather than at the centerline between them. Merge such left/right pairs
    # into one CP at the midpoint so nodes land on the true gate centerline.
    def self.merge_dual_gate_markers(gates)
      return gates if gates.size < 2

      used   = Array.new(gates.size, false)
      merged = []

      min_pair = Constants::DUAL_TRACK_SPACING * 0.60
      max_pair = Constants::DUAL_TRACK_SPACING * 1.40

      gates.each_with_index do |ga, i|
        next if used[i]

        best_j    = nil
        best_dist = Float::INFINITY

        gates.each_with_index do |gb, j|
          next if j <= i || used[j]
          dist = ga[:midpoint].distance(gb[:midpoint])
          next if dist < min_pair || dist > max_pair

          dot = (ga[:tangent].normalize % gb[:tangent].normalize).abs
          next if dot < 0.90

          if dist < best_dist
            best_dist = dist
            best_j    = j
          end
        end

        if best_j
          gb = gates[best_j]
          ctr = Geom::Point3d.linear_combination(0.5, ga[:midpoint], 0.5, gb[:midpoint])
          tan = Geom::Vector3d.new(
            (ga[:tangent].x + gb[:tangent].x) * 0.5,
            (ga[:tangent].y + gb[:tangent].y) * 0.5,
            (ga[:tangent].z + gb[:tangent].z) * 0.5
          )
          tan = tan.length > 0.001 ? tan.normalize : ga[:tangent].normalize

          merged << { midpoint: ctr, tangent: tan, half_offset: best_dist / 2.0 }
          used[i] = true
          used[best_j] = true
        else
          # Unpaired Cap -- one guideway CL only (station with siding on inner guideway).
          # Shift DUAL_TRACK_SPACING/2 = 1.75 m cross-track toward structure origin
          # so the CP lands at the true gate midpoint between the two guideway CLs.
          ga_out = ga
          if ga[:source] == :cap
            half   = Constants::DUAL_TRACK_SPACING / 2.0
            tan    = ga[:tangent]
            z_up   = Geom::Vector3d.new(0, 0, 1)
            cv     = tan.cross(z_up)
            cv_len = Math.sqrt(cv.x * cv.x + cv.y * cv.y + cv.z * cv.z)
            if cv_len > 1e-6
              cv = Geom::Vector3d.new(cv.x / cv_len, cv.y / cv_len, cv.z / cv_len)
              ox = -ga[:midpoint].x
              oy = -ga[:midpoint].y
              cv = cv.dot(Geom::Vector3d.new(ox, oy, 0)) >= 0 ? cv : cv.reverse
              new_pt = ga[:midpoint].offset(cv, half)
              ga_out = { midpoint: new_pt, tangent: ga[:tangent],
                         half_offset: half, source: :cap }
              puts "  JPods merge_dual: Cap offset 1.75m cross-track to #{new_pt.x.to_m.round(3)},#{new_pt.y.to_m.round(3)}"
            end
          end
          merged << ga_out
          used[i] = true
        end
      end

      merged
    end

    # SketchUp ArcCurve does not expose #closed? in all versions.
    # Treat it as a circle when sweep is ~2π, with a topological fallback.
    def self.full_circle_arc?(curve)
      if curve.respond_to?(:closed?)
        return curve.closed?
      end

      if curve.respond_to?(:start_angle) && curve.respond_to?(:end_angle)
        sweep = (curve.end_angle - curve.start_angle).abs
        return (sweep - (2.0 * Math::PI)).abs < 0.01
      end

      edges = curve.respond_to?(:edges) ? curve.edges : []
      return false if edges.empty?

      counts = Hash.new(0)
      edges.each do |edge|
        counts[edge.start] += 1
        counts[edge.end]   += 1
      end
      counts.values.all? { |c| c == 2 }
    end

    # ── Geometry scanning (fallback helper) ─────────────────────────────────

    # Yield every vertex position in a component definition, recursing into
    # nested groups/components up to max_depth levels.
    def self.scan_vertices(entities, transform, depth = 0, &block)
      # Station formations can nest guideway geometry several containers deep.
      # Keep this aligned with the tag scanners so tagged platform/stub geometry
      # is still reachable when wrapped by station/container components.
      return if depth > 8
      entities.each do |e|
        case e
        when Sketchup::Edge
          block.call(transform * e.start.position)
          block.call(transform * e.end.position)
        when Sketchup::Group
          scan_vertices(e.entities, transform * e.transformation, depth + 1, &block)
        when Sketchup::ComponentInstance
          scan_vertices(e.definition.entities, transform * e.transformation,
                        depth + 1, &block)
        end
      end
    end

    # Starting from the placement_data outer tip (outer_pt), walk along
    # tangent_out through the component geometry to find the true visual
    # end of the stub arm.  Returns the centroid of all vertices at the
    # maximum projection (the tip face/cap), or outer_pt if none found.
    #
    # lateral_max: max transverse distance from arm centre-line to accept.
    def self.find_stub_tip_in_geometry(defn, outer_pt, tangent_out,
                                       lateral_max: 4.0.m)
      candidates = []  # [{ proj: Float, pt: Point3d }]

      scan_vertices(defn.entities, Geom::Transformation.new) do |v_pt|
        delta = v_pt - outer_pt
        proj  = delta.dot(tangent_out)
        next if proj < 0.02.m           # must extend beyond outer_pt
        lat_sq = [delta.length_squared - proj * proj, 0.0].max
        next if Math.sqrt(lat_sq) > lateral_max
        candidates << { proj: proj, pt: v_pt }
      end

      return outer_pt if candidates.empty?

      max_proj = candidates.max_by { |c| c[:proj] }[:proj]
      tip_pts  = candidates
                   .select { |c| (max_proj - c[:proj]).abs < 0.05.m }
                   .map    { |c| c[:pt] }

      # Return centroid of the tip face/cluster
      n = tip_pts.size.to_f
      Geom::Point3d.new(
        tip_pts.sum { |p| p.x } / n,
        tip_pts.sum { |p| p.y } / n,
        tip_pts.sum { |p| p.z } / n
      )
    rescue => e
      puts "JPods find_stub_tip error: #{e.message}"
      outer_pt
    end

    # ── Stub pairing ─────────────────────────────────────────────────────────
    #
    # Group external stubs into connection-point pairs and locate each gate's
    # true outer tip by scanning the loaded component definition geometry.
    #
    # STUB NORMALIZATION AND DEDUPLICATION (April 22, 2026):
    #
    # Problem: Traffic-circle arms produce TWO external stubs each due to the
    # positional gap tolerance between arm-track endpoints and ring-segment
    # endpoints. The old code could not distinguish the true outer stub from
    # the shadow ring-junction stub, sometimes pairing wrong stubs and placing
    # CPs at the wrong end of the guideway pair (wrong by ~9 meters).
    #
    # Solution:
    # 1. For each stub, normalise so stub[:point] is ALWAYS the outer end
    #    (the endpoint farther from the formation centroid). Reverse stubs
    #    that had it backwards; flip the tangent to remain outbound.
    # 2. Deduplicate by outer-tip position: if two stubs have the same outer
    #    tip (one real, one phantom from the ring-junction gap), keep only
    #    the first occurrence.
    # 3. Pair the cleaned stubs by distance — now all pairs are valid.
    #
    # PAIRING GEOMETRY:
    #
    # For each valid pair:
    #   pd_outer = midpoint of the two outer tips (typically at ~13.5 m from
    #              formation center in a traffic circle)
    #   pd_inner = midpoint of the two inner ends
    #   out_dir  = (pd_outer - pd_inner).normalize  [geometric chord direction]
    #
    # SEAM LOCATION (April 22, 2026):
    #
    # The CP sits at the midpoint between the two seam points (the locations where
    # guideways meet their ending caps). For traffic circles, the seam is empirically
    # located 9 meters radially outward from the formation center:
    #
    #   seam_radial = (pd_outer - centroid).normalize
    #   CP_final = pd_outer + 9.m * seam_radial   [IN XY; Z from pd_outer]
    #
    # The outward_offset parameter controls this:
    # - Traffic circles: outward_offset = 9.m → applies the radial shift
    # - Other formations: outward_offset = 0.0 → CP at pd_outer (fallback)
    #
    # Rationale: 9m was empirically validated by Bill in SketchUp. CPs with this
    # offset sit exactly at the point where jpod_network.rb joins guideway segments
    # to the station stub face.
    #
    # See /memories/repo/connection-point-rule.md for full derivation.
    #
    # Parameters:
    #   stubs           — Array of { point:, tangent:, companion: } (LOCAL coords)
    #   defn            — Sketchup::ComponentDefinition (optional)
    #   all_eps         — Array of all endpoints (optional, used for unpaired fallback)
    #   outward_offset  — Distance to shift CP radially outward from formation center
    #
    # Returns Array of { index:, center:, tangent:, half_offset: } in LOCAL coords.
    def self.pair_stubs(stubs, defn = nil, all_eps = nil, outward_offset: 0.0)
      # Formation centroid in LOCAL space — used to identify which end of each
      # stub track is the outer (free) tip vs. the inner (structure-body) end.
      all_pts  = stubs.flat_map { |s| [s[:point], s[:companion]] }
      return [] if all_pts.empty?
      centroid = Geom::Point3d.new(
        all_pts.sum { |p| p.x } / all_pts.size,
        all_pts.sum { |p| p.y } / all_pts.size,
        all_pts.sum { |p| p.z } / all_pts.size
      )

# Normalise each stub so that stub[:point] is always the OUTER (cap) end —
      # the endpoint further from the formation centroid.  The companion is the
      # inner ring-junction end.  Stubs where the stored point IS the inner end
      # (because ene_railroad drew that arm from ring→outer) are re-oriented;
      # those where both ends are equidistant (degenerate) are dropped.
      # Duplicate/redundant stubs for the same outer tip are also deduplicated:
      # both the outer-tip stub and the ring-junction stub of the same arm track
      # appear as external stubs when the ring junction doesn't exactly match a
      # ring-segment endpoint. We keep the one whose point IS the outer tip.
      stubs = normalize_stubs_to_outer(stubs, centroid)

      pairs = []
      used  = Array.new(stubs.size, false)

      stubs.each_with_index do |sa, i|
        next if used[i]

        best_j    = nil
        best_dist = Float::INFINITY

        stubs.each_with_index do |sb, j|
          next if j <= i || used[j]
          # All stubs now have point = outer tip — pair by direct distance.
          dist = sa[:point].distance(sb[:point])
          next if dist > MAX_PAIR_DIST

          # Accept parallel OR anti-parallel tangents
          dot = (sa[:tangent].normalize % sb[:tangent].normalize).abs
          next if dot < 0.75

          if dist < best_dist
            best_dist = dist
            best_j    = j
          end
        end

        if best_j
          sb        = stubs[best_j]
          pd_outer  = Geom::Point3d.linear_combination(0.5, sa[:point],     0.5, sb[:point])
          pd_inner  = Geom::Point3d.linear_combination(0.5, sa[:companion], 0.5, sb[:companion])

          # Outward direction: from inner junction toward outer stub tip
          out_dir   = pd_outer - pd_inner
          out_dir   = out_dir.length > 0.01 ? out_dir.normalize : sa[:tangent].normalize.negate

          # Paired CP sits at the midpoint of the two outer guideway ends.
          # For non-traffic-circle fallback, store CP on the beam-bottom datum.
          gate_ctr  = pd_outer
          if outward_offset > 0.0
            radial_out = Geom::Vector3d.new(pd_outer.x - centroid.x,
                                            pd_outer.y - centroid.y,
                                            0)
            radial_out = radial_out.length > 0.01 ? radial_out.normalize : out_dir
            shifted = gate_ctr.offset(radial_out, outward_offset)
            gate_ctr = Geom::Point3d.new(shifted.x, shifted.y, gate_ctr.z)
          else
            gate_ctr = Geom::Point3d.new(gate_ctr.x, gate_ctr.y,
                                         gate_ctr.z - Constants::BEAM_DEPTH)
          end

          # Use the geometric outward direction (pd_inner → pd_outer) rather
          # than the arc tangent stored in placement_data.  For straight arms
          # they are identical; for any formation where the arm track is not
          # exactly radial, the chord direction is the correct gate normal.
          pairs << {
            index:       pairs.size,
            center:      gate_ctr,
            tangent:     out_dir,
            half_offset: best_dist / 2.0,
          }
          puts "  JPods pair_stubs: .#{pairs.size - 1} paired -> " \
               "center (#{gate_ctr.x.to_m.round(3)}, #{gate_ctr.y.to_m.round(3)}, #{gate_ctr.z.to_m.round(3)}) m  " \
               "tangent (#{out_dir.x.round(3)}, #{out_dir.y.round(3)}, #{out_dir.z.round(3)})  " \
               "half_off=#{(best_dist / 2.0).to_m.round(3)} m"
          used[i]      = true
          used[best_j] = true
        else
          # Unpaired stub — only one guideway has an external endpoint at this
          # gate (e.g. station: lower guideway connects internally to a ramp).
          # sa[:point] is the outer (cap) end after the normalisation above.
          outer   = sa[:point]
          out_dir = (outer - sa[:companion]).length > 0.01 ?
                    (outer - sa[:companion]).normalize :
                    sa[:tangent].normalize.negate

          # CP sits DUAL_TRACK_SPACING/2 outward (away from formation centroid)
          # from the stub CL. Traffic circles keep their existing seam-height
          # datum; non-traffic fallback stores CP on the beam-bottom datum.
          # The stub is the inner guideway of the outgoing pair; the CP is the
          # midpoint between that inner guideway and the outer one beyond it.
          center = outer

          z_axis  = Geom::Vector3d.new(0, 0, 1)
          cross_v = out_dir.cross(z_axis)
          if cross_v.valid? && cross_v.length > 1e-6
            cross_v = cross_v.normalize
            # Formation origin = (0,0,0) in local coords = structure center.
            # The missing guideway is always on the same side as the origin.
            # Orient cross_v toward the origin so the offset lands at the gate midpoint.
            to_origin = Geom::Vector3d.new(-outer.x, -outer.y, 0)
            cross_v = cross_v.reverse if cross_v.dot(to_origin) < 0
            shifted = outer.offset(cross_v, Constants::DUAL_TRACK_SPACING / 2.0)
            center_z = outward_offset > 0.0 ? outer.z : (outer.z - Constants::BEAM_DEPTH)
            center  = Geom::Point3d.new(shifted.x, shifted.y, center_z)
            puts "  JPods pair_stubs: .#{pairs.size} unpaired -> center (#{center.x.to_m.round(3)},#{center.y.to_m.round(3)},#{center.z.to_m.round(3)})"
          end

          pairs << {
            index:       pairs.size,
            center:      center,
            tangent:     sa[:tangent].normalize.reverse,  # outbound: reverse of "into track"
            half_offset: Constants::DUAL_TRACK_SPACING / 2.0,
          }
          used[i] = true
        end
      end

      puts "  JPods pair_stubs: #{stubs.size} stubs -> #{used.count(true)} used, #{pairs.size} CPs total"
      pairs
    end

    # ── Attribute persistence ─────────────────────────────────────────────────

    # Reorder CPs into a deterministic clockwise sequence around centroid and
    # rewrite indexes as CP0..CPn. This makes traffic-circle labels readable
    # and stable across reload/recompute runs.
    def self.order_connection_points(pairs)
      return pairs if pairs.nil? || pairs.empty?

      cx = pairs.sum { |cp| cp[:center].x } / pairs.size.to_f
      cy = pairs.sum { |cp| cp[:center].y } / pairs.size.to_f

      sorted = pairs.sort_by do |cp|
        dx = cp[:center].x - cx
        dy = cp[:center].y - cy
        angle = Math.atan2(dy, dx)
        ((Math::PI / 2.0) - angle) % (2.0 * Math::PI)
      end

      sorted.each_with_index.map do |cp, i|
        cp.merge(index: i)
      end
    end

    # Build CPs from placement_data stubs (same approach as traffic circle).
    # Circle markers in the template SKP are not used — pair_stubs computes
    # the exact cross-track midpoint from the track endpoint geometry.
    #
    # TRAFFIC CIRCLE SPECIAL CASE (April 22, 2026):
    #
    # Traffic circles use pair_stubs with a 9-meter radial outward offset
    # (the empirically validated seam location for this formation type).
    # Other formations fall back to pair_stubs with offset=0 when gw_stub_pair
    # tags are not present.
    #
    # When outward_offset > 0:
    #   CP = pd_outer + outward_offset * (pd_outer - centroid).normalize
    # Terminus guard: station_line_end has exactly one gate → max 1 CP.
    # Applied to ALL priority paths so the guard fires regardless of which
    # detector found the CPs.
    def self.apply_line_end_guard(cps, model_id, source_label)
      return cps unless model_id.to_s.include?("line_end") && cps.size > 1
      puts "⚠️  JPods station_line_end (#{source_label}): found #{cps.size} CPs — trimming to 1." \
           " Station_line_end has exactly one CP. Check that only one cp_marker_* is placed."
      centroid_x = cps.sum { |cp| cp[:center].x } / cps.size.to_f
      centroid_y = cps.sum { |cp| cp[:center].y } / cps.size.to_f
      gate_cp = cps.max_by { |cp|
        dx = cp[:center].x - centroid_x
        dy = cp[:center].y - centroid_y
        Math.sqrt(dx * dx + dy * dy)
      }
      [gate_cp.merge(index: 0)]
    end

    # This places the CP at the guideway/cap seam for traffic circles.
    #
    # For other formation types, we try endings first (offset=0), then fall back
    # to pair_stubs if no endings are found.
    def self.resolve_connection_points(model_id, defn, placement_data)
      is_traffic_circle = model_id.to_s.downcase.include?("traffic_circle")

      # ── Priority 1: cp_marker_* components ─────────────────────────────────
      # Every template model has cp_marker_* placed at each CP by the model author.
      # detect_cps_from_top_level_cp assigns :index from the cp_marker_N suffix —
      # sort by that index directly; do NOT call order_connection_points which
      # re-sorts CW by angle and discards the authored numbering.
      from_tags = detect_cps_from_cp_markers(defn)
      if from_tags && !from_tags.empty?
        puts "  JPods resolve_connection_points: #{from_tags.size} CPs from cp_marker_* (marker indices preserved)"
        from_tags = apply_line_end_guard(from_tags, model_id, "cp_marker_*")
        return [from_tags.sort_by { |cp| cp[:index] }, "#{from_tags.size} CPs from cp_marker_*"]
      end

      # ── Priority 2: pair_stubs from placement_data ──────────────────────────
      # Traffic circles use 9 m radial outward offset (empirically validated).
      stubs   = detect_external_stubs(placement_data)
      all_eps = collect_all_endpoints(placement_data)
      outward_offset = is_traffic_circle ? 9.m : 0.0
      from_stubs = order_connection_points(
        pair_stubs(stubs, defn, all_eps, outward_offset: outward_offset)
      )

      # ── Terminus guard for station_line_end ─────────────────────────────────
      # A line-end station has exactly one gate (terminus) → max 1 CP.
      # pair_stubs can return 2+ CPs when internal track endpoints leak through
      # detect_external_stubs (joints not coinciding within the 0.5-inch tolerance).
      from_stubs = apply_line_end_guard(from_stubs, model_id, "pair_stubs fallback")

      [from_stubs, "#{stubs.size} stubs -> #{from_stubs.size} CPs (pair_stubs fallback)"]
    end

    def self.average_nearest_center_distance(a_pairs, b_pairs)
      return 0.0 if a_pairs.empty? || b_pairs.empty?
      a_pairs.sum do |a|
        b_pairs.map { |b| a[:center].distance(b[:center]) }.min
      end / a_pairs.size.to_f
    end

    # Store connection-point data (LOCAL coordinates) on the entity as a JSON string.
    # LOCAL coordinates are used so that moving the structure after placement
    # still produces correct world-space positions at build time.
    def self.store_connection_points(entity, pairs)
      data = pairs.map do |cp|
        h = {
          "index"       => cp[:index],
          "half_offset" => cp[:half_offset],
          "center"      => cp[:center].to_a,
          "tangent"     => cp[:tangent].to_a,
        }
        h
      end
      entity.set_attribute("JPods", "connection_points", data.to_json)
    end

    # Retrieve a single connection point from an entity, transformed to WORLD space.
    # Returns { center: Point3d, tangent: Vector3d, half_offset: Float } or nil.
    def self.connection_point(entity, index)
      raw = entity.get_attribute("JPods", "connection_points")
      return nil unless raw

      data = JSON.parse(raw)
      cp   = data.find { |d| d["index"].to_i == index.to_i }
      return nil unless cp

      t = entity.respond_to?(:transformation) ? entity.transformation
                                               : Geom::Transformation.new

      center_local = point3d_from_any(cp["center"])
      tangent_local = vector3d_from_any(cp["tangent"])
      return nil unless center_local && tangent_local

      {
        center:      t * center_local,
        tangent:     t * tangent_local,
        half_offset: cp["half_offset"].to_f,
      }
    rescue => e
      puts "⚠️  JPods: connection_point read error on #{entity.name}: #{e.message}"
      nil
    end

    # ── Connection-point labels ───────────────────────────────────────────────

    # Add "s001.0", "s001.1", ... text annotations to the model's top-level
    # entities.  Positioned 2.5 m above each connection-point center in world space.
    def self.add_connection_labels(model, entity, pairs, transform)
      struct_id = entity.get_attribute("JPods", "structure_id", "?")
      up        = Geom::Vector3d.new(0, 0, 1)

      pairs.each do |cp|
        world_pt = transform * cp[:center]
        label_pt = world_pt.offset(up, 2.5.m)
        label    = JPods::ConnectionPoint.new(structure_id: struct_id, index: cp[:index]).to_key
        model.entities.add_text(label, label_pt)
      end
    rescue => e
      puts "⚠️  JPods: could not add connection labels: #{e.message}"
    end

    # Erase all CP text labels in the model and mark the toggle as hidden.
    # Also removes any CP display circles added by _show_cp_circles.
    def self.hide_all_cp_labels(model)
      model.entities.select { |e|
        e.is_a?(Sketchup::Text) && e.text.to_s.match?(/\A[A-Za-z][A-Za-z0-9]*\.(?:CP)?\d+\z/)
      }.each(&:erase!)
      _hide_cp_circles(model)
      @cps_shown = false
    end

    # Draw green circle geometry at every CP position — the single visual mechanism.
    # Works in both network models (reads stored connection_points on placed instances)
    # and template models (reads cp.json when no structure instances are found).
    # Circles are grouped and tagged 'cp_display' so _hide_cp_circles can remove them.
    def self._show_cp_circles(model)
      _hide_cp_circles(model)   # remove stale circles first
      cp_edges = []
      normal   = Geom::Vector3d.new(0, 0, 1)

      # Mode 1: network — structures with stored CP data
      model.entities.each do |inst|
        next unless jpods_structure_candidate?(inst)
        raw = inst.get_attribute("JPods", "connection_points")
        next unless raw
        begin
          JSON.parse(raw).each do |cpd|
            center = point3d_from_any(cpd["center"])
            next unless center
            world_pt = inst.transformation * center
            cp_edges.concat(model.entities.add_circle(world_pt, normal, 1.5.m, 32))
          end
        rescue
        end
      end

      # Mode 2: template model — read CP data from lines.computed.json['cp'].
      # Single source of truth: run Compute to generate lines.computed.json.
      if cp_edges.empty? && model.path.to_s.include?('track_formations')
        model_id = File.basename(File.dirname(model.path))
        lc_path  = File.join(__dir__, 'templates', 'track_formations', model_id, 'lines.computed.json')
        cp_data  = nil
        if File.exist?(lc_path)
          begin
            lc      = JSON.parse(File.read(lc_path, encoding: 'utf-8'))
            cp_data = lc['cp'] if lc['cp'].is_a?(Hash)
          rescue; end
        end
        (cp_data && cp_data['cps'] || []).each do |cpd|
          center = cpd['center']
          next unless center.is_a?(Array) && center.size >= 2
          world_pt = Geom::Point3d.new(center[0].to_f, center[1].to_f, (center[2] || 0).to_f)
          cp_edges.concat(model.entities.add_circle(world_pt, normal, 1.5.m, 32))
        end
      end

      return if cp_edges.empty?

      model.start_operation("JPods CP Circles Show", true)
      grp = model.entities.add_group(cp_edges)
      grp.set_attribute('JPods', 'cp_display', true)
      grp.name = "JPods CP Display"
      model.commit_operation
    rescue => ex
      model.abort_operation rescue nil
      puts "JPods _show_cp_circles: #{ex.message}"
    end

    # Remove the CP display circle group from the model.
    def self._hide_cp_circles(model)
      to_erase = model.entities.grep(Sketchup::Group).select { |g|
        g.get_attribute('JPods', 'cp_display', false)
      }
      return if to_erase.empty?
      model.start_operation("JPods CP Circles Hide", true)
      to_erase.each(&:erase!)
      model.commit_operation
    rescue
    end

    def self.refresh_cp_labels(model)
      # Remove stale labels.
      model.entities.select { |e|
        e.is_a?(Sketchup::Text) && e.text.to_s.match?(/\A[A-Za-z][A-Za-z0-9]*\.(?:CP)?\d+\z/)
      }.each(&:erase!)

      # Re-add from stored data on each structure.
      model.entities.each do |e|
        next unless jpods_structure_candidate?(e)
        raw = e.get_attribute("JPods", "connection_points")
        next unless raw
        begin
          pairs = JSON.parse(raw).map do |d|
            center = point3d_from_any(d["center"])
            tangent = vector3d_from_any(d["tangent"])
            next nil unless center && tangent
            { index:       d["index"],
              center:      center,
              half_offset: d["half_offset"].to_f,
              tangent:     tangent }
          end.compact
          add_connection_labels(model, e, pairs, e.transformation)
        rescue => e2
          puts "⚠️  JPods refresh_cp_labels: #{e2.message}"
        end
      end
    end

    # True for top-level entities that look like JPods structures.
    # Name is preferred, but we also accept metadata/tag matches to survive
    # template/name drift in SketchUp scenes.
    # ── Placement validation ──────────────────────────────────────────────────
    # Run after every place_at commit. Returns array of issue strings (empty = pass).
    # Reports via status bar and a timed notice — never a blocking dialog.
    def self.validate_placement(model, instance, struct_id)
      issues = []

      # 1. structure_id present
      sid = instance.get_attribute('JPods', 'structure_id').to_s
      issues << "missing structure_id attribute" if sid.empty?

      # 2. At least one CP detected
      cps = instance.get_attribute('JPods', 'connection_points')
      if cps.nil? || (cps.is_a?(Array) && cps.empty?) || (cps.is_a?(String) && cps.empty?)
        issues << "no Connection Points detected — add cp_marker_* components at each CP, then run Calculate CPs"
      end

      # 3. Platform guideways detectable
      platforms = detect_platform_guideways_on_structure(instance) rescue []
      if platforms.empty?
        issues << "no platform guideways found — Noelle cannot route through this station"
      end

      # 4. Duplicate structure_id
      dup = model.entities.any? do |e|
        e != instance &&
        (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) &&
        e.get_attribute('JPods', 'structure_id').to_s == struct_id
      end
      issues << "duplicate structure_id #{struct_id} — two stations share the same ID" if dup

      if issues.empty?
        Sketchup.set_status_text("✅ #{struct_id} placed — CPs and platform OK")
      else
        summary = "#{struct_id}: #{issues.size} issue#{issues.size == 1 ? '' : 's'} — #{issues.first}"
        Sketchup.set_status_text("⚠️  #{summary}")
        issues.each { |msg| puts "[JPods validate] #{struct_id}: #{msg}" }
        if defined?(JPods) && JPods.respond_to?(:show_timed_notice)
          JPods.show_timed_notice(
            "#{struct_id} placed with issues:\n" + issues.map { |i| "• #{i}" }.join("\n"),
            title: 'JPods — Structure Check',
            seconds: 5.0
          )
        end
      end

      issues
    end

    def self.jpods_structure_candidate?(e)
      return false unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)

      return true if e.name.to_s == "JPods Structure"

      sid = e.get_attribute("JPods", "structure_id").to_s
      return true unless sid.empty?

      stype = e.get_attribute("JPods", "structure_type", "").to_s.downcase
      return true if stype == "station"

      tag = entity_tag_name(e)
      return true if tag == "station"

      false
    rescue
      false
    end

    def self.point3d_from_any(v)
      if v.is_a?(Geom::Point3d)
        v
      elsif v.is_a?(Array) && v.size >= 3
        Geom::Point3d.new(v[0].to_f, v[1].to_f, v[2].to_f)
      elsif v.is_a?(Hash)
        Geom::Point3d.new(v["x"].to_f, v["y"].to_f, v["z"].to_f)
      elsif v.respond_to?(:x) && v.respond_to?(:y) && v.respond_to?(:z)
        Geom::Point3d.new(v.x.to_f, v.y.to_f, v.z.to_f)
      else
        nil
      end
    rescue
      nil
    end

    def self.vector3d_from_any(v)
      out = if v.is_a?(Geom::Vector3d)
              v
            elsif v.is_a?(Array) && v.size >= 3
              Geom::Vector3d.new(v[0].to_f, v[1].to_f, v[2].to_f)
            elsif v.is_a?(Hash)
              Geom::Vector3d.new(v["x"].to_f, v["y"].to_f, v["z"].to_f)
            elsif v.respond_to?(:x) && v.respond_to?(:y) && v.respond_to?(:z)
              Geom::Vector3d.new(v.x.to_f, v.y.to_f, v.z.to_f)
            else
              nil
            end
      return nil unless out
      out.length > 0.001 ? out : Geom::Vector3d.new(1, 0, 0)
    rescue
      nil
    end

    # ── Full placement ────────────────────────────────────────────────────────

    # Place model_id at base_pt (world coordinates, on terrain surface).
    # Returns the assigned structure_id string, or nil on failure.
    def self.place_at(model, model_id, base_pt)
      defn = load_formation_def(model, model_id)
      return nil unless defn

      info           = load_formation_info(model_id)
      placement_data = info && (info[:placement_data] || info["placement_data"])

      struct_id = next_structure_id(model, model_id: model_id)
      transform = Geom::Transformation.translation(base_pt)

      model.start_operation("Place JPods Structure #{struct_id}", true)
      begin
        instance      = model.entities.add_instance(defn, transform)
        instance.name = "JPods Structure"  # must match jpods_structure_candidate? name check
        instance.layer = JPods::LayerManager.get_tag(model, :formation) if defined?(JPods::LayerManager)
        instance.set_attribute("JPods", "structure_id",  struct_id)
        instance.set_attribute("JPods", "model_id",  model_id)

        # structure_type is declared by the model author inside every template model.skp.
        # Read from: (1) top-level entity tag filtered to known types,
        #            (2) instance name filtered to known types,
        #            (3) definition name prefix.
        # Only known types are accepted — unknown tags (e.g. "canopy") are skipped.
        begin
          known_types = %w[station traffic_circle]
          stype = ''

          # (1) tag on the top-level ComponentInstance — what Bill set in Tags panel
          #     Only ComponentInstances are checked; faces/edges/groups carry geometry tags,
          #     not the structure_type the model author declared.
          defn.entities.each do |top_ent|
            next unless top_ent.is_a?(Sketchup::ComponentInstance)
            next unless top_ent.layer
            t = top_ent.layer.name.to_s.strip.downcase
            next unless known_types.include?(t)
            stype = t
            break
          end

          # (2) instance name on the top-level ComponentInstance
          if stype.empty?
            defn.entities.each do |top_ent|
              next unless top_ent.is_a?(Sketchup::ComponentInstance)
              iname = top_ent.name.to_s.strip.downcase
              if known_types.include?(iname)
                stype = iname
                break
              end
            end
          end

          # (3) definition name prefix
          if stype.empty?
            known_types.each do |t|
              if defn.name.to_s.downcase.start_with?(t)
                stype = t
                break
              end
            end
          end

          instance.set_attribute("JPods", "structure_type", stype) unless stype.empty?
        rescue => _e
        end

        if placement_data.is_a?(Array) && !placement_data.empty?
          pairs, source_msg = resolve_connection_points(model_id, defn, placement_data)
        else
          # No info file or empty placement_data — detect from formation geometry.
          from_tags = detect_cps_from_cp_markers(defn)
          if from_tags && !from_tags.empty?
            pairs      = order_connection_points(from_tags)
            source_msg = "#{from_tags.size} CPs from cp_marker_* (fallback)"
          end
        end

        if pairs && !pairs.empty?
          puts "✅  JPods: placed #{struct_id} (#{model_id}) — #{source_msg}"
          store_connection_points(instance, pairs)
          # Add the new label for this instance only (refresh_cp_labels is too heavy
          # during placement — it rescans all structures in the model).
          add_connection_labels(model, instance, pairs, transform)
        else
          puts "⚠️  JPods: placed #{struct_id} (#{model_id}) — no CPs detected. " \
               "Add cp_marker_* components at each CP in the template model, then run Calculate CPs."
        end

        model.commit_operation
        validate_placement(model, instance, struct_id)
        struct_id
      rescue => e
        model.abort_operation
        UI.messagebox("Failed to place structure:\n#{e.message}", MB_OK, "JPods — Error")
        puts "JPods structure error: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
        nil
      end
    end

    # ── Recompute CPs on existing structures ─────────────────────────────────

    # Re-run CP detection for every "JPods Structure" already in the model,
    # picking up any new marker geometry drawn in the template SKPs since
    # the structures were originally placed.
    #
    # Strategy: snapshot structure attributes + transforms FIRST, then erase
    # old instances so load_formation_def(force: true) can safely purge the
    # stale definition, then re-place fresh instances with updated CPs.
    # Replaced instances get NEW unique structure IDs (non-recycled).
    # Scan all entities recursively and report any component/group still named
    # "ending" (legacy ene_railroad name). Call from recompute to catch stale caps.
    def self.flag_legacy_endings(model)
      found = []
      scan_for_legacy_endings(model.entities, Geom::Transformation.new, found)
      if found.empty?
        puts "JPods: no legacy 'ending' entities found."
      else
        puts "\n⚠️  JPods: #{found.size} entity(ies) still named 'ending' — legacy ene_railroad name, no longer used:"
        found.each { |msg| puts "    #{msg}" }
        puts ""
      end
      found
    end

    def self.scan_for_legacy_endings(entities, xf, out, depth = 0)
      return if depth > 8
      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        name      = e.name.to_s.downcase
        defn_name = e.is_a?(Sketchup::ComponentInstance) ? e.definition.name.to_s.downcase : ""
        attr_type = e.get_attribute("ene_railroad_template_part", "type").to_s.downcase rescue ""
        if name.include?("ending") || defn_name.include?("ending") || attr_type == "ending"
          combined = xf * e.transformation
          origin   = Geom::Point3d.new(0, 0, 0).transform(combined)
          out << "name='#{e.name}' defn='#{defn_name}' ene_attr='#{attr_type}' " \
                 "at (#{origin.x.to_m.round(2)}, #{origin.y.to_m.round(2)}, #{origin.z.to_m.round(2)}) m"
          next  # don't recurse into it
        end
        child_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        scan_for_legacy_endings(child_ents, xf * e.transformation, out, depth + 1)
      end
    end

    # ── Formation template audit ──────────────────────────────────────────────

    # Load each model.skp under templates/track_formations/, run CP detection
    # (Priority 1 + 2 only — no placement_data needed), and report tag presence
    # + detected CPs to the Ruby Console.  Purges the loaded definitions when done.
    def self.audit_formation_templates(model)
      formations_dir = File.join(__dir__, 'templates', 'track_formations')
      unless Dir.exist?(formations_dir)
        puts "JPods Audit: templates/track_formations/ not found at #{formations_dir}"
        return
      end

      skp_files = Dir.glob(File.join(formations_dir, '*', 'model.skp')).sort
      if skp_files.empty?
        puts "JPods Audit: no model.skp files found in #{formations_dir}"
        return
      end

      bar = '=' * 62
      puts "\n#{bar}"
      puts "JPods Formation Template Audit — #{Time.now.strftime('%Y-%m-%d')}"
      puts bar
      puts "Directory: #{formations_dir}"
      puts "#{skp_files.size} formation(s) found\n\n"

      loaded_defns = []

      skp_files.each do |skp_path|
        model_id = File.basename(File.dirname(skp_path))
        puts "── #{model_id} " + ('─' * [1, 60 - model_id.length].max)

        begin
          defn = model.definitions.load(skp_path)
          loaded_defns << defn

          # ── Tag presence count ──────────────────────────────────────────
          tag_counts = {}
          %w[gw_cp_in_0 gw_cp_out_0 gw_platform].each do |tag|
            tag_counts[tag] = count_tagged_entities(defn.entities, tag, 0)
          end
          puts "   Tags:"
          tag_counts.each do |tag, n|
            icon = n > 0 ? "✅" : "❌"
            puts "     #{icon}  #{tag}: #{n > 0 ? n.to_s : 'missing'}"
          end

          # ── CP detection from cp_marker_* ────────────────────────────────
          puts "   CPs:"
          from_tags = detect_cps_from_cp_markers(defn)
          if from_tags && !from_tags.empty?
            from_tags = apply_line_end_guard(from_tags, model_id, "audit/cp_marker_*")
            from_tags.each do |cp|
              c = cp[:center]
              t = cp[:tangent]
              puts "     .#{cp[:index]}  center=(#{c.x.to_m.round(3)}, #{c.y.to_m.round(3)}, #{c.z.to_m.round(3)}) m" \
                   "  tangent=(#{t.x.round(3)},#{t.y.round(3)})  [cp_marker_*]"
            end
          else
            puts "     (no cp_marker_* found — place cp_marker_* at each CP in the template model)"
          end

        rescue => e
          puts "   ❌  Error loading #{skp_path}: #{e.message}"
        end
        puts
      end

      # Purge the definitions we loaded so they don't pollute the open model.
      begin
        model.definitions.purge_unused
      rescue => e
        puts "JPods Audit: purge_unused warning: #{e.message}"
      end

      puts "#{'-' * 62}"
      puts "Audit complete — #{loaded_defns.size} template(s) checked."
      puts "#{'-' * 62}\n"
    end

    # Export feature data into lines.computed.json['feature'] for every template.
    # Harvests Track groups from each model.skp, merges with existing roles/flags from
    # the current lines.computed.json, and writes back. No standalone feature.json created.
    # Uses the same definition-load / purge pattern as audit_formation_templates.
    #
    # Naming convention written into each file:
    #   Track IDs  →  TEMPLATE.<tag>   (instance will substitute TEMPLATE with Sxxx)
    #   seg_ IDs   →  seg_Axxx_cpN_Bxxx_cpM.0 / .1  (track_index; lengths differ)
    #
    # ── Auto-Tag Formation Tracks ──────────────────────────────────────────────
    #
    # When a template model.skp is the active model, reads that template's
    # lines.json and assigns the correct SketchUp tag to every Track group whose
    # tag is currently Layer0, matching by length (within TOL_MM tolerance).
    # Also stamps the JPods track_id attribute on each tagged entity.
    #
    # Usage (Ruby Console, with the template model open):
    #   JPods::StructurePlacer.auto_tag_formation_tracks(Sketchup.active_model)
    #
    # model_id — folder name under track_formations/. If nil, inferred from
    # the open model's file path.
    #
    def self.auto_tag_formation_tracks(model, model_id = nil)
      require 'json'
      formations_dir = File.join(__dir__, 'templates', 'track_formations')

      # Detect formation from the open model's path if not provided.
      if model_id.nil?
        model_path = model.path.to_s
        model_id = Dir.glob(File.join(formations_dir, '*', 'model.skp')).find { |p|
          File.realpath(p) rescue p == File.realpath(model_path) rescue false
        }
        model_id = model_id ? File.basename(File.dirname(model_id)) : nil

        # Fallback: match by folder name contained in the path string
        if model_id.nil?
          Dir.glob(File.join(formations_dir, '*/'), File::FNM_CASEFOLD).each do |d|
            if model_path.include?(File.basename(d.chomp('/')))
              model_id = File.basename(d.chomp('/'))
              break
            end
          end
        end
      end

      unless model_id
        UI.messagebox(
          "Could not detect template formation.\n\n" \
          "Open the template model.skp directly in SketchUp, then run again.\n" \
          "Or call: auto_tag_formation_tracks(model, 'station_line_end')",
          MB_OK, "JPods — Auto-Tag"
        )
        return
      end

      lines_json_path = File.join(formations_dir, model_id, 'lines.json')
      unless File.exist?(lines_json_path)
        puts "[JPods auto-tag] No lines.json found at #{lines_json_path}"
        return
      end

      lines_data = JSON.parse(File.read(lines_json_path))
      lines_dict = lines_data['lines'] || {}

      # Build length → tag map from lines.json entries that have length_mm.
      # Key is the track name (= SketchUp tag name). Skip lift tracks (auxiliary).
      tol_mm = 100.0
      len_to_tag = {}
      lines_dict.each do |track_name, attrs|
        next unless attrs.is_a?(Hash) && attrs['length_mm']
        next if track_name.start_with?('gw_lift')
        len_to_tag[attrs['length_mm'].to_f] = track_name
      end

      puts "\n[JPods auto-tag] #{model_id}"
      puts "[JPods auto-tag] #{len_to_tag.size} length→tag mapping(s) from lines.json"
      puts "[JPods auto-tag] tolerance: ±#{tol_mm} mm\n\n"

      tagged   = 0
      skipped  = 0
      no_match = 0

      auto_tag_entities_recursive(model.entities, model, len_to_tag, tol_mm,
                                  model_id, tagged, skipped, no_match)

      puts "\n[JPods auto-tag] Done — #{tagged} tagged, #{skipped} already tagged, #{no_match} unmatched."
      tagged
    end

    def self.auto_tag_entities_recursive(entities, model, len_to_tag, tol,
                                          model_id, tagged, skipped, no_match)
      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        name = e.name.to_s
        child = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities

        name_lc = name.downcase
        if name_lc.start_with?('gw') || name_lc.start_with?('track')
          current_tag = e.layer&.name.to_s
          if current_tag != 'Layer0' && !current_tag.empty?
            puts "  skip  '#{name}'  (already tagged: #{current_tag})"
            skipped += 1
            next
          end

          length_mm = parse_length_mm_from_identity(name)
          if length_mm.nil?
            puts "  skip  '#{name}'  (no parseable length)"
            no_match += 1
            next
          end

          best_len, best_tag = len_to_tag.min_by { |len, _| (len - length_mm).abs }
          if best_tag && (best_len - length_mm).abs <= tol
            layer = model.layers[best_tag] || model.layers.add(best_tag)
            e.layer = layer
            id = "TEMPLATE.#{best_tag}"
            e.set_attribute('JPods', 'track_id', id) rescue nil
            puts "  tag   '#{name}'  #{length_mm.round} mm → #{best_tag}"
            tagged += 1
          else
            puts "  WARN  '#{name}'  #{length_mm.round} mm — no match within #{tol} mm"
            no_match += 1
          end
        else
          auto_tag_entities_recursive(child, model, len_to_tag, tol,
                                       model_id, tagged, skipped, no_match)
        end
      end
    end
    private_class_method :auto_tag_entities_recursive

    # ── Validate Template Tags ─────────────────────────────────────────────────
    #
    # Loads every model.skp, harvests Track groups, and reports any that are still
    # on Layer0 (untagged).  Returns true if all templates are clean, false if any
    # have defects.  Prints a checklist to the Ruby Console; callers may also
    # show the summary as a dialog.
    #
    # Called automatically by export_feature_jsons — export is blocked until clean.
    #
    def self.validate_template_tags(model)
      require 'json'
      formations_dir = File.join(__dir__, 'templates', 'track_formations')
      skp_files      = Dir.glob(File.join(formations_dir, '*', 'model.skp')).sort

      puts "\n#{'=' * 66}"
      puts "JPods Template Tag Validator — #{Time.now.strftime('%Y-%m-%d')}"
      puts "#{'=' * 66}"

      all_pass   = true
      fail_lines = []   # accumulates text for the UI dialog

      skp_files.each do |skp_path|
        model_id = File.basename(File.dirname(skp_path))

        begin
          tracks = {}
          active_path = (model.path rescue nil).to_s
          if !active_path.empty? && File.expand_path(skp_path) == File.expand_path(active_path)
            harvest_track_groups(model.entities, Geom::Transformation.new, tracks, 0)
          else
            defn = model.definitions.load(skp_path)
            harvest_track_groups(defn.entities, Geom::Transformation.new, tracks, 0)
          end

          untagged = tracks.select { |_id, t| t['tag'].to_s.empty? || t['tag'] == 'Layer0' }
          tags     = tracks.values.map { |t| t['tag'].to_s }
          ins      = tags.count { |tg| tg.end_with?('_in') }
          outs     = tags.count { |tg| tg.end_with?('_out') }

          formation_ok = untagged.empty? && ins == outs

          if formation_ok
            puts "\n  PASS  #{model_id}  (#{tracks.size} tracks, #{ins} in / #{outs} out)"
          else
            all_pass = false
            puts "\n  FAIL  #{model_id}"
            fail_lines << "FAIL  #{model_id}"

            if untagged.any?
              puts "        #{untagged.size} untagged track(s):"
              untagged.each do |_id, t|
                len_str = t['length_mm'] ? "#{t['length_mm'].round.to_s.rjust(7)} mm" : "  length?"
                line    = "  [ ] #{len_str}  \"#{t['identity']}\""
                puts "        #{line}"
                fail_lines << line
              end
              puts "        Open model.skp, select each track, assign tag in Entity Info."
            end

            if ins != outs
              msg = "  IN/OUT IMBALANCE — #{ins} _in track(s) vs #{outs} _out track(s)"
              puts "        #{msg}"
              puts "        Every entry must have a matching exit. Check model geometry."
              fail_lines << msg
              in_tags  = tags.select { |tg| tg.end_with?('_in') }.sort
              out_tags = tags.select { |tg| tg.end_with?('_out') }.sort
              (in_tags - out_tags.map  { |tg| tg.sub(/_out$/, '_in') }).each  { |tg| puts "          missing _out for: #{tg}" }
              (out_tags - in_tags.map { |tg| tg.sub(/_in$/,  '_out') }).each { |tg| puts "          missing _in  for: #{tg}" }
            end
          end

          model.definitions.purge_unused rescue nil

        rescue => ex
          all_pass = false
          msg = "  ERROR  #{model_id}: #{ex.message}"
          puts msg
          fail_lines << msg
        end
      end

      puts "\n#{'─' * 66}"
      if all_pass
        puts "ALL TEMPLATES PASS — ready to run Export Feature JSON"
      else
        puts "BLOCKED — fix untagged tracks above, then re-run."
      end
      puts "#{'─' * 66}\n"

      all_pass
    end

    # ── Audit naming conventions across all template models ───────────────────
    #
    # Runs audit_model_names logic against every template .skp file, not just
    # the active model.  Noelle calls this autonomously; humans use:
    #
    #   JPods::StructurePlacer.audit_all_template_names(Sketchup.active_model)
    #
    # Returns { pass: bool, results: { model_id => { pass:, issues:, checked: } } }
    #
    def self.audit_all_template_names(model)
      formations_dir = File.join(__dir__, 'templates', 'track_formations')
      skp_files      = Dir.glob(File.join(formations_dir, '*', 'model.skp')).sort

      puts "\n#{'=' * 66}"
      puts "JPods Naming Audit — All Templates — #{Time.now.strftime('%Y-%m-%d')}"
      puts "#{'=' * 66}"

      all_pass = true
      results  = {}

      skp_files.each do |skp_path|
        model_id = File.basename(File.dirname(skp_path))

        begin
          # Resolve entities — use active model if it IS this template
          active_path = (model.path rescue nil).to_s
          entities = if !active_path.empty? && File.expand_path(skp_path) == File.expand_path(active_path)
            model.entities
          else
            model.definitions.load(skp_path).entities
          end

          # Run the same checks as audit_model_names but against these entities
          issues  = []
          checked = [0]

          scan_entities_for_naming(entities, issues, checked)

          pass = issues.empty?
          all_pass = false unless pass
          results[model_id] = { pass: pass, issues: issues, checked: checked[0] }

          status = pass ? "  PASS" : "  FAIL"
          puts "\n#{status}  #{model_id}  (#{checked[0]} entities checked)"
          issues.each { |msg| puts msg } unless pass

          model.definitions.purge_unused rescue nil

        rescue => ex
          all_pass = false
          msg = "  ERROR  #{model_id}: #{ex.message}"
          puts msg
          results[model_id] = { pass: false, issues: [msg], checked: 0 }
        end
      end

      puts "\n#{'─' * 66}"
      puts all_pass ? "ALL TEMPLATES PASS naming audit." : "BLOCKED — fix naming issues above."
      puts "#{'─' * 66}\n"

      { pass: all_pass, results: results }
    end

    # Shared naming scan used by both audit_model_names and audit_all_template_names.
    # Walks entities recursively; appends issue strings to +issues+; increments count[0].
    def self.scan_entities_for_naming(entities, issues, count)
      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        count[0] += 1

        nm     = e.name.to_s
        tag    = entity_tag_name(e)
        nm_lc  = nm.downcase
        tag_lc = tag.downcase

        STALE_TAG_MAP.each do |old, replacement|
          if tag_lc == old || nm_lc == old
            issues << "  STALE    name='#{nm}'  tag='#{tag}'  →  rename to '#{replacement}'"
          end
        end

        if nm_lc.start_with?('track') || tag_lc.start_with?('track')
          issues << "  TRACK    name='#{nm}'  tag='#{tag}'  →  rename prefix to 'gw_'"
        end

        if nm_lc.start_with?('gw_') && tag_lc == 'layer0'
          issues << "  LAYER0   name='#{nm}'  →  assign tag in Entity Info"
        end

        if tag.include?(', ')
          issues << "  COMMA    tag='#{tag}'  →  replace ', ' with '_'"
        end

        if nm_lc.start_with?('gw_') && tag_lc.start_with?('gw_') &&
           tag_lc != 'layer0' && nm_lc != tag_lc
          issues << "  MISMATCH name='#{nm}'  tag='#{tag}'  →  name and tag should match"
        end

        if tag_lc.start_with?('gw_')
          unless GW_KNOWN_FAMILIES.any? { |f| tag_lc.start_with?(f) }
            issues << "  UNKNOWN  tag='#{tag}'  →  not in naming taxonomy"
          end
        end

        child = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        scan_entities_for_naming(child, issues, count)
      end
    end
    private_class_method :scan_entities_for_naming

    # ── Export Feature JSON ────────────────────────────────────────────────────
    #
    # Harvests Track groups from each template model.skp and writes feature.json.
    # BLOCKED if any template still has Layer0 (untagged) tracks — fix them first.
    #
    def self.export_feature_jsons(model)
      require 'json'
      formations_dir = File.join(__dir__, 'templates', 'track_formations')
      unless Dir.exist?(formations_dir)
        puts "JPods ExportFeatureJSON: #{formations_dir} not found"
        return
      end

      # ── Gate 1: validate tags ──────────────────────────────────────────────
      puts "\n[JPods] Running tag validation before export..."
      unless validate_template_tags(model)
        UI.messagebox(
          "Export blocked — one or more templates have untagged (Layer0) tracks.\n\n" \
          "Fix in SketchUp:\n" \
          "  1. Open the template model.skp\n" \
          "  2. Select each untagged Track (shown in Ruby Console)\n" \
          "  3. Entity Info → Tag → assign the correct tag name\n" \
          "  4. Save and re-run Validate Template Tags\n\n" \
          "See Ruby Console for the full checklist.",
          MB_OK, "JPods — Export Blocked"
        )
        return
      end

      # ── Gate 2: naming convention audit ───────────────────────────────────
      puts "\n[JPods] Running naming audit before export..."
      audit = audit_model_names(model)
      unless audit[:pass]
        top  = audit[:issues].first(8).join("\n")
        more = audit[:issues].size > 8 ? "\n  ... (see Ruby Console for full list)" : ""
        msg  = "Export blocked — #{audit[:issues].size} naming issue(s) found.\n\n" \
               "#{top}#{more}\n\n" \
               "Fix the names in SketchUp (Entity Info → Name and Tag), then re-run Audit Model Names."
        UI.messagebox(msg, MB_OK, "JPods — Export Blocked")
        return
      end

      skp_files = Dir.glob(File.join(formations_dir, '*', 'model.skp')).sort
      puts "\n#{'=' * 62}"
      puts "JPods Export Feature JSON — #{Time.now.strftime('%Y-%m-%d')}"
      puts "#{'=' * 62}"
      puts "#{skp_files.size} template(s) found\n\n"

      skp_files.each do |skp_path|
        model_id = File.basename(File.dirname(skp_path))
        puts "── #{model_id}"

        begin
          defn   = model.definitions.load(skp_path)
          tracks = {}
          harvest_track_groups(defn.entities, Geom::Transformation.new, tracks, 0)

          # Merge harvested tracks with existing roles/flags from lines.computed.json.
          lc_path = File.join(formations_dir, model_id, 'lines.computed.json')
          unless File.exist?(lc_path)
            puts "   SKIP — lines.computed.json not found (run Compute first)"
            next
          end
          lc = JSON.parse(File.read(lc_path, encoding: 'utf-8'))
          existing_feat = lc['feature'].is_a?(Hash) ? lc['feature'] : {}
          (existing_feat['tracks'] || {}).each do |id, old|
            next unless tracks.key?(id)
            tracks[id]['role']        = old['role']        if old['role'] && old['role'] != 'unknown'
            tracks[id]['noelle_flag'] = old['noelle_flag'] if old['noelle_flag']
          end

          feature_out = {
            'schema'       => 'jpods-feature-v1',
            'feature_id'   => existing_feat['feature_id']   || 'TEMPLATE',
            'feature_type' => existing_feat['feature_type'] || 'unknown',
            'formation'    => model_id,
            'generated_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
            'tracks'       => tracks,
            'cps'          => existing_feat['cps']    || {},
            'routes'       => existing_feat['routes'] || []
          }

          lc['feature']              = feature_out
          lc['_feature_note']        = 'Track role assignments. tracks[tag].role = routing|parking|slop. ' \
                                       'noelle_flag = validation override. Carried forward across Compute; ' \
                                       'update via Export Feature JSON tool or direct edit of lines.computed.json.'
          File.write(lc_path, JSON.pretty_generate(lc), encoding: 'utf-8')
          puts "   #{tracks.size} track(s) → lines.computed.json['feature']"

        rescue => ex
          puts "   ERROR  #{ex.message}"
        end
        puts
      end

      model.definitions.purge_unused rescue nil

      puts "#{'─' * 62}"
      puts "Export complete. Review lines.computed.json['feature'] for each template:"
      puts "  1. Confirm feature_type  (station_1cp | station_2cp | circle_Ncp)"
      puts "  2. Confirm role          (routing | parking | slop) for each track"
      puts "#{'─' * 62}\n"
    end

    # Recursively collect Track groups from a definition's entity tree.
    # Writes into +out+ hash keyed as "TEMPLATE.<tag>" (or positional fallback).
    #
    # Length strategy (in priority order):
    #   1. Parse mm from the identity string — SketchUp embeds the length in the
    #      track name (e.g. "Track, 12.9866 m (JPod, c_bezier)" → 12986.6 mm).
    #      Both period and comma decimal separators are handled (European locale).
    #   2. Sum all edges recursively inside the group (inches × 25.4 → mm).
    #      Edges may be nested several levels deep in sub-groups.
    #   3. nil — no length recoverable; flags the track for manual measurement.
    def self.harvest_track_groups(entities, parent_xf, out, depth)
      return if depth > 6
      seen_tags = Hash.new(0)

      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        name  = e.name.to_s
        tag   = e.layer&.name.to_s
        child = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        xf    = parent_xf * e.transformation

        # Identify a guideway entity.
        # 'gw' prefix is the standard (renamed from 'Track' 2026-05-16).
        # 'track' prefix still accepted during the model-rename transition.
        # A non-Layer0 tag alone also qualifies — catches entities whose
        # instance name has not yet been updated.
        name_lc = name.downcase
        is_gw   = name_lc.start_with?('gw') ||
                  name_lc.start_with?('track') ||
                  (!tag.empty? && tag != 'Layer0')

        if is_gw
          # Derive a stable key: prefer the SketchUp tag; fall back to
          # identity-derived slug when tag is Layer0 or blank.
          key_tag = if tag.empty? || tag == 'Layer0'
            slug = name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '')
            "#{slug}_#{seen_tags[slug]}"
          else
            tag
          end
          seen_tags[key_tag] += 1

          # 1. Parse length from identity string (primary — most reliable source).
          length_mm = parse_length_mm_from_identity(name)

          # 2. Fallback: sum all edges recursively (inches × 25.4 → mm).
          if length_mm.nil?
            total_inches = collect_all_edges(child, 0).sum(&:length)
            length_mm = total_inches > 0 ? (total_inches * 25.4).round(1) : nil
          end

          id = "TEMPLATE.#{key_tag}"
          # Stamp the semantic ID onto the entity instance so the live model
          # can always locate this track by ID regardless of name changes.
          e.set_attribute('JPods', 'track_id', id) rescue nil

          out[id] = {
            'id'        => id,
            'tag'       => tag,
            'role'      => 'unknown',
            'length_mm' => length_mm,
            'identity'  => name
          }
          puts "[JPods harvest] #{id}  tag=#{tag.inspect}  length_mm=#{length_mm.inspect}  identity=#{name.inspect}"
        else
          harvest_track_groups(child, xf, out, depth + 1)
        end
      end
    end
    private_class_method :harvest_track_groups

    # Parse a length in mm from a SketchUp track identity string.
    # SketchUp embeds the track length in the group name, e.g.:
    #   "Track, 12.9866 m (JPod, c_bezier)"  → 12986.6
    #   "Track, ~ 63,56m (JPod, c_bezier)"   → 63560.0  (European comma decimal)
    #   "Track, platform, ~ 23,86m"           → 23860.0
    # Returns nil when no parseable length is found.
    def self.parse_length_mm_from_identity(identity)
      # Match: optional ~, digits, decimal separator (. or ,), more digits, optional
      # space, then 'm' at a word boundary. Also handles whole-number meters.
      m = identity.match(/~?\s*([\d]+[.,][\d]+|[\d]+)\s*m\b/i)
      return nil unless m
      num_str = m[1].tr(',', '.')   # normalize European comma to decimal point
      meters  = num_str.to_f
      return nil if meters == 0.0
      (meters * 1000.0).round(1)
    end
    private_class_method :parse_length_mm_from_identity

    # Return every Sketchup::Edge that lives anywhere inside +entities+,
    # descending into nested Groups and ComponentInstances without limit.
    def self.collect_all_edges(entities, depth)
      return [] if depth > 10
      edges = []
      entities.each do |e|
        if e.is_a?(Sketchup::Edge)
          edges << e
        elsif e.is_a?(Sketchup::Group)
          edges.concat(collect_all_edges(e.entities, depth + 1))
        elsif e.is_a?(Sketchup::ComponentInstance)
          edges.concat(collect_all_edges(e.definition.entities, depth + 1))
        end
      end
      edges
    end
    private_class_method :collect_all_edges

    # Count all entities (recursive) whose tag name matches +tag+ (downcase).
    def self.count_tagged_entities(entities, tag, depth)
      return 0 if depth > 8
      n = 0
      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        t = entity_tag_name(e)
        n += 1 if t == tag || t.start_with?("#{tag}_")
        child_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        n += count_tagged_entities(child_ents, tag, depth + 1)
      end
      n
    end

    def self.recompute_all_cps(model)
      if model.active_path && !model.active_path.empty?
        puts "JPods recompute_all_cps: Exit the open group/component edit before recomputing connection points."
        return
      end

      structures = model.entities.select { |e| jpods_structure_candidate?(e) }

      if structures.empty?
        puts "JPods recompute_all_cps: No JPods structures found in this model. Use JPods Place Structure or ensure entities carry JPods structure metadata."
        return
      end

      # Flag any caps still named "ending" before modifying anything.
      flag_legacy_endings(model)

      # ── In-place CP detection for ALL structures ─────────────────────────────
      # Never erase or re-place instances. Structures stay exactly where the user
      # put them; only their CP attribute data is refreshed.
      # Labels are rebuilt ONCE at the end via refresh_cp_labels — the single
      # mechanism for Text label management.  This guarantees labels survive even
      # when detection fails for a structure (old stored data is preserved).
      #
      # Detection priority per structure (same as place_at):
      #   1. info file → placement_data → resolve_connection_points  (ene_railroad authored stubs)
      #   2. stub_pair tags on the existing definition

      model.start_operation("Recompute JPods Connection Points", true)
      begin
        updated = 0

        structures.each do |inst|
          fid       = inst.get_attribute("JPods", "model_id").to_s
          old_id    = inst.get_attribute("JPods", "structure_id").to_s
          struct_id = old_id.to_s.empty? ? next_structure_id(model) : old_id
          inst.set_attribute("JPods", "structure_id", struct_id)

          defn = inst.respond_to?(:definition) ? inst.definition : nil
          pairs      = nil
          source_msg = nil

          # ── 1. cp_marker_* detection — authoritative (Axiom 10 + 15) ───
          # cp_marker_N components are placed by the model author at each CP.
          # detect_cps_from_top_level_cp assigns :index from the N suffix, so
          # we sort by that index directly — do NOT call order_connection_points,
          # which re-sorts CW by angle and discards the authored numbering.
          if defn
            from_tags = detect_cps_from_cp_markers(defn)
            if from_tags && !from_tags.empty?
              from_tags = apply_line_end_guard(from_tags, fid, "cp_marker_*")
              pairs      = from_tags.sort_by { |cp| cp[:index] }
              source_msg = "#{pairs.size} CPs from cp_marker_* (marker indices preserved)"
            end
          end

          # ── 2. Info file → placement_data (fallback when no cp_markers) ──
          if (pairs.nil? || pairs.empty?) && !fid.empty? && defn
            info = load_formation_info(fid)
            pd   = info && (info[:placement_data] || info["placement_data"])
            if pd.is_a?(Array) && !pd.empty?
              pairs, source_msg = resolve_connection_points(fid, defn, pd)
              source_msg = "#{pairs.size} CPs from info/placement_data" if pairs
            end
          end

          # ── 3. No CPs found ────────────────────────────────────────────
          if pairs.nil? || pairs.empty?
            puts "  #{struct_id}: no cp_marker_* found — place cp_marker_* at each CP in the template model"
          end

          if pairs && !pairs.empty?
            store_connection_points(inst, pairs)
            puts "JPods recompute: #{struct_id} (#{fid.empty? ? 'no model_id' : fid}) — #{source_msg}"
            updated += 1
          else
            old_raw = inst.get_attribute("JPods", "connection_points")
            if old_raw && !old_raw.empty?
              puts "JPods recompute: #{struct_id} — detection failed; keeping #{JSON.parse(old_raw).size} stored CPs"
            else
              puts "JPods recompute: #{struct_id} — no CPs detected and none stored"
            end
          end
        end

        # Single authoritative label refresh — reads from stored connection_points
        # for every structure regardless of whether detection succeeded this run.
        # Runs inside the operation so labels + CP data are one undoable step.
        refresh_cp_labels(model)

        model.commit_operation

        # ── Purge stale feature.json connections ─────────────────────────────────
        # Any connection that references a structure_id no longer in the model is
        # dead weight — it will never resolve and silently blocks the overlay.
        # Remove it now so the user starts with a clean slate.
        begin
          feat_path = JPods::NetworkEditor.default_network_json_path(model) rescue nil
          if feat_path && File.exist?(feat_path)
            valid_sids = structures.map { |inst|
              inst.get_attribute("JPods", "structure_id").to_s
            }.reject(&:empty?)
            raw  = JSON.parse(File.read(feat_path, encoding: 'utf-8'))
            conns = raw['connections'] || {}
            flat  = JPods::NetworkEditor.feature_connections_to_flat_array(conns)
            stale = flat.select { |c|
              fsid = (c['from'] || {})['structure_id'].to_s
              tsid = (c['to']   || {})['structure_id'].to_s
              !valid_sids.include?(fsid) || !valid_sids.include?(tsid)
            }
            if stale.any?
              stale.each { |c| puts "JPods CP Calculate: purging stale connection #{c['id']} (references missing structure)" }
              kept  = flat.reject { |c| stale.include?(c) }
              begin
                raw['connections'] = JPods::NetworkEditor.flat_array_to_feature_connections(kept, conns)
              rescue
                # Fallback: rebuild connections hash from kept array
                new_conns = {}
                kept.each { |c| new_conns[c['id']] = c if c['id'] }
                raw['connections'] = new_conns
              end
              # Purge stale station_names
              if raw['station_names'].is_a?(Hash)
                raw['station_names'].delete_if { |sid, _| !valid_sids.include?(sid) && !valid_sids.include?(sid.downcase) }
              end
              # Set build-required flag
              raw['build_required'] = true
              File.write(feat_path, JSON.pretty_generate(raw), encoding: 'utf-8')
              puts "JPods CP Calculate: #{stale.size} stale connection(s) purged — BUILD REQUIRED"
            end
          end
        rescue => e2
          puts "JPods CP Calculate purge warning: #{e2.message}"
        end

        JPods::JPodNetworkTool.refresh_entities(model) if defined?(JPods::JPodNetworkTool)
        @cps_shown = true
        puts "JPods recompute_all_cps: Recomputed CPs for #{updated}/#{structures.size} structure(s). Network Editor circles refreshed."
      rescue => e
        model.abort_operation
        puts "JPods recompute error: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      end
    end

    # ── Structure report ──────────────────────────────────────────────────────

    # Print all placed structure IDs and their connection-point counts to the
    # Ruby Console so the user knows what to put in the network_definition block of followme.json.
    def self.list_structures(model)
      structures = model.entities.select { |e| jpods_structure_candidate?(e) }

      if structures.empty?
        puts "JPods list_structures: No JPods Structures in this model. Use Plugins › JPods › Place Structure first."
        return
      end

      puts "\n─── JPods Structures ────────────────────────────────"
      structures.each do |s|
        sid  = s.get_attribute("JPods", "structure_id", "?")
        fid  = s.get_attribute("JPods", "model_id", "?")
        raw  = s.get_attribute("JPods", "connection_points")
        cps  = raw ? JSON.parse(raw).size : 0
        puts "  #{sid}  (#{fid})  —  #{cps} connection point(s)"
        if raw && cps > 0
          JSON.parse(raw).each do |cp|
            puts "        .#{cp["index"]}  half_offset=#{cp["half_offset"].to_f.to_m.round(3)} m"
          end
        end
      end
      puts "─────────────────────────────────────────────────────\n"

      puts "JPods list_structures: #{structures.size} structure(s) found."
    rescue => e
      puts "JPods list_structures error: #{e.message}"
    end

    # ── Model name audit ──────────────────────────────────────────────────────
    #
    # Scans every Group and ComponentInstance in the active model (including all
    # component definitions) and flags names or tags that violate current naming
    # rules:
    #   - Stale tag strings (stub_pair, Track*)
    #   - Tag = Layer0 on a guideway-prefixed group
    #   - Comma-space in tag names (e.g. "platform, in")
    #   - Name/tag mismatch on guideway groups
    #
    # Usage (Ruby console):
    #   JPods::StructurePlacer.audit_model_names(Sketchup.active_model)
    #
    # Known valid gw_ prefixes under the naming taxonomy.
    # Any gw_ tag not matching one of these families is flagged as unknown.
    # Stale tag map — only compound/specific names that are unambiguously old
    # JPods routing segment names.  Generic single words (platform, parking, dip)
    # are intentionally excluded: they appear legitimately on structural components
    # and would produce false positives.
    STALE_TAG_MAP = {
      'stub_pair'           => 'gw_cp_in_N or gw_cp_out_N',
      'gw_stub_pair'        => 'gw_cp_in_N or gw_cp_out_N',
      'platform_in_ramp'    => 'gw_platform_in or gw_platform_in1',
      'gw_platform_in_ramp' => 'gw_platform_in or gw_platform_in1',
      'gw_far_ramp_out'     => 'gw_far_out',
      'uturn0'              => 'gw_uturn_0',
      'uturn1'              => 'gw_uturn_1',
      'dip_connector'       => 'gw_dip_connector',
    }.freeze

    GW_KNOWN_FAMILIES = %w[
      gw_cp
      gw_lift
      gw_platform
      gw_uturn
      gw_near
      gw_far
      gw_dip
      gw_parking
      gw_c_
    ].freeze

    def self.audit_model_names(model)
      issues  = []
      count   = [0]

      puts "\n#{'=' * 62}"
      puts "JPods Model Name Audit — #{Time.now.strftime('%Y-%m-%d')}"
      puts "#{'=' * 62}"

      scan_entities_for_naming(model.entities, issues, count)

      puts "  Checked: #{count[0]} entities"
      if issues.empty?
        puts "  ✅  All names and tags are clean."
      else
        puts "  #{issues.size} issue(s) found:\n\n"
        issues.each { |msg| puts msg }
      end
      puts "#{'=' * 62}\n"

      { pass: issues.empty?, issues: issues, checked: count[0] }
    end

    # ── Paste / duplicate observer ────────────────────────────────────────────

    # Watches model.entities for new instances that carry a structure_id that
    # already belongs to another instance in the model. When detected (i.e. a
    # copy-paste or ctrl-drag duplicate), the incoming instance gets a fresh
    # unique ID and new CP labels, so two structures never share the same ID.
    class PasteObserver < Sketchup::EntitiesObserver

      def initialize(model)
        @model = model
        # Ignore callbacks fired in the first 1s after installation.
        # SketchUp sometimes replays existing entities when an observer is added.
        @ready_at = Time.now + 1.0
      end

      def onElementAdded(_entities, entity)
        return if Time.now < @ready_at   # still in replay window
        return unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        return unless JPods::StructurePlacer.jpods_structure_candidate?(entity)

        new_sid = entity.get_attribute("JPods", "structure_id").to_s
        return if new_sid.empty?

        # Collect all structure_ids currently in the model except this instance.
        existing_ids = @model.entities.select { |e|
          (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) &&
          JPods::StructurePlacer.jpods_structure_candidate?(e) &&
          e.persistent_id != entity.persistent_id
        }.map { |e| e.get_attribute("JPods", "structure_id").to_s }.compact

        return unless existing_ids.include?(new_sid)

        # Defer one tick — SketchUp's paste is still in progress at callback time.
        UI.start_timer(0, false) do
          begin
            fresh_id = JPods::StructurePlacer.next_structure_id(@model)
            @model.start_operation("Assign Structure ID #{fresh_id}", true)

            entity.set_attribute("JPods", "structure_id", fresh_id)

            # Remove old CP label texts for this instance and regenerate.
            old_labels = @model.entities.select { |e|
              e.is_a?(Sketchup::Text) &&
              e.text.to_s.start_with?("#{new_sid}.CP")
            }
            old_labels.each { |l| @model.entities.erase_entities(l) }

            raw = entity.get_attribute("JPods", "connection_points")
            if raw
              pairs = JSON.parse(raw).map { |cp|
                center  = JPods::StructurePlacer.point3d_from_any(cp["center"])
                tangent = JPods::StructurePlacer.vector3d_from_any(cp["tangent"])
                next nil unless center && tangent
                {
                  index:       cp["index"].to_i,
                  point:       center,
                  center:      center,
                  tangent:     tangent,
                  half_offset: cp["half_offset"].to_f,
                }
              }.compact
              JPods::StructurePlacer.add_connection_labels(@model, entity, pairs, entity.transformation)
            end

            @model.commit_operation
            puts "JPods: pasted structure reassigned #{new_sid} → #{fresh_id}"
          rescue => ex
            @model.abort_operation rescue nil
            puts "JPods PasteObserver error: #{ex.message}"
          end
        end
      rescue => ex
        puts "JPods PasteObserver.onElementAdded error: #{ex.message}"
      end

    end  # class PasteObserver

    # Install the observer on model.entities. Safe to call multiple times —
    # previous observer is removed first to avoid stacking duplicates.
    def self.install_paste_observer(model)
      if @paste_observer
        begin; model.entities.remove_observer(@paste_observer); rescue; end
      end
      @paste_observer = PasteObserver.new(model)
      model.entities.add_observer(@paste_observer)
      puts "JPods: PasteObserver installed (duplicate structure-ID prevention active)"
    end

    # Silently remove structure_id from any entity that has one but has no CPs
    # and no known station type. Returns the count of purged phantoms.
    # Called automatically at the start of Structure Place and CP Calculate.
    def self.purge_phantoms(model)
      model = Sketchup.active_model if model.nil? || model.entities.nil?
      return 0 unless model
      purged = 0
      model.start_operation("Purge Phantom JPods Stations", true)
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        next if e.deleted?
        sid = e.get_attribute("JPods", "structure_id").to_s
        next if sid.empty?
        raw = e.get_attribute("JPods", "connection_points").to_s
        next unless raw.empty? || (JSON.parse(raw) rescue []).empty?
        next unless e.get_attribute("JPods", "structure_type", "").to_s.empty?
        next unless e.get_attribute("JPods", "model_id", "").to_s.empty?
        e.delete_attribute("JPods", "structure_id")
        e.delete_attribute("JPods", "connection_points")
        puts "JPods: purged phantom #{sid} (#{e.is_a?(Sketchup::ComponentInstance) ? e.definition.name : 'group'})"
        purged += 1
      end
      model.commit_operation
      puts "JPods: purge_phantoms — #{purged} phantom(s) removed" if purged > 0
      purged
    end

  end  # module StructurePlacer


  # ── Interactive placement tool ──────────────────────────────────────────────

  class JPodStructureTool

    def self.activate_with_prompt(model)
      formations = StructurePlacer.formation_options   # { id => label }
      if formations.empty?
        UI.messagebox(
          "No formation templates are available.\n\n" \
          "Expected folders under:\n#{StructurePlacer.track_formations_dir}\n\n" \
          "Each formation folder must contain model.skp.",
          MB_OK, "JPods — Place Structure"
        )
        return
      end

      # Defer via timer so this runs outside any HtmlDialog action_callback context.
      # show_modal is prohibited inside an HtmlDialog callback (SketchUp raises
      # "SU cannot be accessed"). The timer exits the callback before the picker opens.
      UI.start_timer(0, false) do
        chosen_id = show_formation_picker(formations)
        next unless chosen_id

        model.select_tool(new(chosen_id))
      end
    end

    # Show an HtmlDialog image-picker. Returns the chosen model_id or nil.
    def self.show_formation_picker(formations)
      chosen_id = nil

      dlg = UI::HtmlDialog.new(
        dialog_title:    "JPods — Place Structure",
        preferences_key: "jpods_place_structure",
        scrollable:      true,
        width:           620,
        height:          460,
        min_width:       400,
        min_height:      300
      )

      # Build one card per formation.
      cards_html = formations.map do |fid, label|
        img_path = File.join(StructurePlacer.track_formations_dir, fid, 'image.png')
        if File.exist?(img_path)
          # Convert OS path to a file:// URL SketchUp's HtmlDialog can load.
          img_url = 'file://' + img_path.gsub(' ', '%20')
          img_tag = "<img src=\"#{img_url}\" alt=\"#{label}\">"
        else
          img_tag = "<div class=\"no-img\">No image</div>"
        end
        <<~CARD
          <div class="card" data-id="#{fid}" onclick="select(this)">
            #{img_tag}
            <div class="lbl">#{label}</div>
          </div>
        CARD
      end.join("\n")

      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; font-family: system-ui, sans-serif; }
          body { background: #1e1e1e; color: #eee; display: flex; flex-direction: column;
                 height: 100vh; overflow: hidden; }
          #grid { display: flex; flex-wrap: wrap; gap: 12px; padding: 14px;
                  overflow-y: auto; flex: 1; }
          .card { width: 170px; border: 2px solid #444; border-radius: 6px;
                  cursor: pointer; background: #2a2a2a; text-align: center;
                  transition: border-color 0.15s; user-select: none; }
          .card:hover { border-color: #888; }
          .card.selected { border-color: #4caf50; background: #1a3a1a; }
          .card img { width: 100%; height: 120px; object-fit: contain;
                      border-radius: 4px 4px 0 0; background: #111; display: block; }
          .no-img { height: 120px; display: flex; align-items: center;
                    justify-content: center; color: #555; font-size: 12px; }
          .lbl { padding: 6px 4px; font-size: 12px; font-weight: 500; line-height: 1.3; }
          #bar { display: flex; justify-content: flex-end; gap: 8px; padding: 10px 14px;
                 border-top: 1px solid #333; background: #252525; flex-shrink: 0; }
          button { padding: 6px 18px; border-radius: 4px; border: none; cursor: pointer;
                   font-size: 13px; }
          #btn-ok { background: #4caf50; color: #fff; }
          #btn-ok:disabled { background: #444; color: #888; cursor: default; }
          #btn-cancel { background: #555; color: #eee; }
        </style>
        </head>
        <body>
        <div id="grid">
        #{cards_html}
        </div>
        <div id="bar">
          <button id="btn-cancel" onclick="cancel()">Cancel</button>
          <button id="btn-ok" onclick="ok()" disabled>Place</button>
        </div>
        <script>
          var selectedId = null;
          function select(card) {
            document.querySelectorAll('.card').forEach(function(c){ c.classList.remove('selected'); });
            card.classList.add('selected');
            selectedId = card.getAttribute('data-id');
            document.getElementById('btn-ok').disabled = false;
          }
          function ok() {
            if (selectedId) sketchup.picked(selectedId);
          }
          function cancel() {
            sketchup.cancel();
          }
        </script>
        </body>
        </html>
      HTML

      dlg.set_html(html)

      dlg.add_action_callback('picked') do |_ctx, fid|
        chosen_id = fid.to_s
        dlg.close
      end

      dlg.add_action_callback('cancel') do |_ctx|
        dlg.close
      end

      dlg.show_modal
      chosen_id
    end

    CP_RING_PX   = 22   # screen-space CP ring radius — matches Connect Guideways tool
    CP_RING_SEGS = 32
    COL_CP_IDLE  = Sketchup::Color.new(0, 200, 80)  # green — visible on SU background

    def initialize(model_id)
      @model_id = model_id
      @ip           = Sketchup::InputPoint.new
      @existing_cps = []
    end

    def activate
      @ip = Sketchup::InputPoint.new
      label = StructurePlacer.formation_label(@model_id)
      Sketchup.status_text = "Click terrain to place #{label}.  ESC to cancel."
      collect_existing_cps(Sketchup.active_model)
    end

    def deactivate(view)
      view.invalidate
    end

    def onMouseMove(flags, x, y, view)
      @ip.pick(view, x, y)
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      @ip.pick(view, x, y)
      clicked = @ip.position
      return unless clicked

      # Ray-cast downward to snap to terrain surface
      origin = Geom::Point3d.new(clicked.x, clicked.y, clicked.z + 500.0.m)
      hit    = view.model.raytest([origin, Geom::Vector3d.new(0, 0, -1)])
      pt     = hit ? hit[0] : Geom::Point3d.new(clicked.x, clicked.y, 0)

      id = StructurePlacer.place_at(view.model, @model_id, pt)
      if id
        Sketchup.status_text = "Placed #{id}.  Click again for another, or ESC to finish."
        collect_existing_cps(view.model)   # refresh so new CPs appear immediately
      else
        Sketchup.status_text = "Placement failed — see Ruby Console.  Try again or ESC."
      end
    end

    def draw(view)
      @ip.draw(view) if @ip.valid?

      # Draw CP rings for all existing structures — same style as Connect Guideways tool,
      # so users can see existing CPs while orienting the new structure.
      return if @existing_cps.empty?
      view.line_width    = 2
      view.line_stipple  = ""
      view.drawing_color = COL_CP_IDLE
      @existing_cps.each do |cp|
        sc = view.screen_coords(cp[:center]) rescue nil
        next unless sc
        ring_pts = (0...CP_RING_SEGS).map do |i|
          a = 2.0 * Math::PI * i / CP_RING_SEGS
          Geom::Point3d.new(sc.x + Math.cos(a) * CP_RING_PX,
                            sc.y + Math.sin(a) * CP_RING_PX, 0)
        end
        view.draw2d(GL_LINE_LOOP, ring_pts)

        # Tangent whisker
        view.line_width = 1
        w_end = cp[:center].offset(cp[:tangent].normalize, 2.m)
        view.draw(GL_LINE_STRIP, [cp[:center], w_end])

        # Label
        lpt = Geom::Point3d.new(sc.x + CP_RING_PX + 4, sc.y - 6, 0)
        cp_label = JPods::ConnectionPoint.new(structure_id: cp[:struct_id], index: cp[:stub]).to_key
        view.draw_text(lpt, cp_label,
                       { size: 11, bold: false, color: COL_CP_IDLE }) rescue
          view.draw_text(lpt, cp_label)
      end
    end

    private

    def collect_existing_cps(model)
      @existing_cps = []
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        next if e.hidden?
        sid = e.get_attribute("JPods", "structure_id").to_s
        next if sid.empty?
        raw = e.get_attribute("JPods", "connection_points")
        next if raw.nil? || raw.empty?
        begin
          t = e.respond_to?(:transformation) ? e.transformation : Geom::Transformation.new
          JSON.parse(raw).each do |d|
            center  = StructurePlacer.point3d_from_any(d["center"])
            tangent = StructurePlacer.vector3d_from_any(d["tangent"])
            next unless center && tangent
            @existing_cps << {
              struct_id: sid,
              stub:      d["index"],
              center:    t * center,
              tangent:   t * tangent,
            }
          end
        rescue => ex
          puts "JPodStructureTool: CP parse error on #{sid}: #{ex.message}"
        end
      end
    end

    def getExtents
      Geom::BoundingBox.new
    end

    def onCancel(_reason, _view)
      Sketchup.active_model.select_tool(nil)
    end

  end  # class JPodStructureTool

end  # module JPods

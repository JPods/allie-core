# JPods Terrain Utilities
#
# Handles terrain detection, ray-cast elevation lookups, and the
# "Import Terrain Features" workflow that guides the user to bring
# georeferenced terrain into the SketchUp model before routing.

module JPods
  module Terrain

    # Groups whose names contain any of these keywords are treated as terrain.
    TERRAIN_KEYWORDS = [
      "terrain", "google earth", "geo-location",
      "location snapshot", "topography", "topo"
    ].freeze

    # Minimum face-count for a nameless group to qualify as a terrain fallback.
    MIN_TERRAIN_FACES = 20

    # ── Public API ────────────────────────────────────────────────────────────

    # Scan the model for a terrain group.  Returns the Sketchup::Group or nil.
    def self.detect(model)
      find_terrain_in(model.entities)
    end

    # Return a Geom::Point3d on the terrain directly below (x, y).
    # Shoots a vertical ray downward from a safe height above the scene.
    # Falls back to z=0 if no terrain hit.
    def self.elevation_at(model, x, y)
      origin = Geom::Point3d.new(x, y, 2000.0.m)
      hit    = model.raytest([origin, Geom::Vector3d.new(0, 0, -1)])
      hit ? hit[0] : Geom::Point3d.new(x, y, 0)
    end

    # Like elevation_at, but skips JPods entities (guideways, markers, stations)
    # so the result is always actual terrain, not a beam surface.
    # When a JPods entity is hit, skips below its entire bounding box in one step.
    def self.ground_z_at(model, x, y, max_steps: 12)
      ray_z  = 2000.0.m
      dir    = Geom::Vector3d.new(0, 0, -1)
      max_steps.times do
        origin = Geom::Point3d.new(x, y, ray_z)
        hit    = model.raytest([origin, dir])
        return Geom::Point3d.new(x, y, 0) unless hit
        hit_pt    = hit[0]
        hit_ents  = hit[1] || []
        jpods_ent = hit_ents.find do |e|
          name_match = e.respond_to?(:name) &&
                       e.name.to_s.match?(/\AJPod/i)
          attr_match = e.respond_to?(:get_attribute) && (
            !e.get_attribute("JPods", "structure_id",  nil).nil? ||
            !e.get_attribute("JPods", "connection_id", nil).nil? ||
            !e.get_attribute("JPods", "marker_number", nil).nil? ||
            !e.get_attribute("JPods", "seg_guideway",  nil).nil?
          )
          name_match || attr_match
        end
        return hit_pt unless jpods_ent
        # Skip below the ENTIRE JPods entity's bounding box in one step.
        if jpods_ent.respond_to?(:bounds)
          ray_z = jpods_ent.bounds.min.z - 0.01.m
        else
          ray_z = hit_pt.z - 0.01.m
        end
        return Geom::Point3d.new(x, y, 0) if ray_z < -500.0.m
      end
      Geom::Point3d.new(x, y, 0)
    end

    # Snap an array of Geom::Point3d values to the terrain surface.
    # After snapping, any point that fell back to z=0 (typically under
    # a waypoint marker) is interpolated from nearest valid neighbors.
    def self.snap_to_terrain(model, points)
      results = points.map { |pt| ground_z_at(model, pt.x, pt.y) }

      # Detect z=0 fallbacks on paths where terrain is clearly not at z=0.
      zs = results.map(&:z)
      z_min = zs.min; z_max = zs.max
      if (z_max - z_min) > 5.0.m
        n = results.size
        (0...n).each do |i|
          next unless zs[i].abs < 0.001.m  # z ≈ 0
          left_z = nil; right_z = nil; left_d = 0; right_d = 0
          (i - 1).downto(0) do |j|
            if zs[j].abs > 0.001.m
              left_z = zs[j]; left_d = i - j; break
            end
          end
          ((i + 1)...n).each do |j|
            if zs[j].abs > 0.001.m
              right_z = zs[j]; right_d = j - i; break
            end
          end
          interp_z = if left_z && right_z
                       t = left_d.to_f / (left_d + right_d)
                       left_z + (right_z - left_z) * t
                     elsif left_z then left_z
                     elsif right_z then right_z
                     else next
                     end
          results[i] = Geom::Point3d.new(results[i].x, results[i].y, interp_z)
        end
      end
      results
    end

    # Run the Import Terrain Features user workflow:
    #   • If terrain is found → report stats and confirm ready.
    #   • If not found        → guide user to File > Geo-location > Add Location.
    def self.import_features(model)
      group = detect(model)

      if group
        b    = group.bounds
        area = ((b.width.to_m) * (b.depth.to_m)).round(0)
        elev_min = b.min.z.to_m.round(1)
        elev_max = b.max.z.to_m.round(1)

        msg = "Terrain detected: \"#{group.name}\"\n\n" \
              "Approx. area : #{area} m²\n"                \
              "Elevation range : #{elev_min} – #{elev_max} m\n\n" \
              "JPods marker and guideway tools will snap to this terrain.\n" \
              "Place markers next using Plugins › JPods › Place Markers on Terrain."

        puts msg
      else
        msg = "No terrain mesh found in this model.\n\n" \
              "To add georeferenced terrain:\n" \
              "  File  ›  Geo-location  ›  Add Location\n\n" \
              "This imports satellite imagery and an elevation mesh " \
              "from Trimble's location service.\n\n" \
              "After importing, run  Import Terrain Features  again."

        puts msg
      end
    end

    # ── Private helpers ───────────────────────────────────────────────────────
    private

    # Recursively search an Entities collection for the best terrain group.
    def self.find_terrain_in(entities)
      fallback       = nil
      fallback_faces = 0

      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)

        name = (e.respond_to?(:name) ? e.name : "").downcase
        sub  = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities

        # Named match wins immediately
        return e if TERRAIN_KEYWORDS.any? { |kw| name.include?(kw) }

        # Recurse into the sub-entities
        found = find_terrain_in(sub)
        return found if found

        # Track by face count as name-independent fallback
        fc = sub.grep(Sketchup::Face).count
        if fc > fallback_faces
          fallback_faces = fc
          fallback = e
        end
      end

      fallback_faces >= MIN_TERRAIN_FACES ? fallback : nil
    end

  end
end

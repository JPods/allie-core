# ── Build Helpers — entity lookup, CP resolution ──────────────────────────────
#
# Migrated from codearchive/jpod_network.rb entity lookup methods.
# Used by build.rb to find stations, markers, and resolve CPs.

require 'json'

module JPods
  module Network

    # Find a structure entity by structure_id
    def self.find_structure(struct_id, model)
      sid = struct_id.to_s.strip.downcase
      model.entities.find do |e|
        next false unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
        e.get_attribute('JPods', 'structure_id', '').to_s.strip.downcase == sid
      end
    end

    # Find a marker entity by number
    def self.find_marker(number, model)
      model.entities.find do |e|
        e.is_a?(Sketchup::Group) && e.name == 'JPod Marker' &&
        e.get_attribute('JPods', 'marker_number', -1).to_i == number
      end
    end

    # Resolve a CP from entity attributes into a world-space hash.
    # Uses SketchUp's native Transformation operators (same as old jpod_network.rb):
    #   t * Point3d  → world point (translation + rotation + scale)
    #   t * Vector3d → world vector (rotation only, no translation)
    # Returns { center: Point3d, tangent: Vector3d, half_offset: Float } or nil
    def self.resolve_cp(entity, stub_idx)
      raw = entity.get_attribute('JPods', 'connection_points')
      return nil unless raw
      cps = JSON.parse(raw)
      return nil unless cps.is_a?(Array)
      cp_data = cps.find { |cp| cp['index'].to_i == stub_idx }
      return nil unless cp_data

      # Parse local coordinates — handle both flat and nested formats
      local_center = _parse_point(cp_data, 'center')
      return nil unless local_center
      local_tangent = _parse_vector(cp_data, 'tangent') || Geom::Vector3d.new(1, 0, 0)

      # Transform to world using SketchUp's native operators
      t = entity.transformation
      world_center  = t * local_center
      world_tangent = begin; (t * local_tangent).normalize; rescue; local_tangent; end
      half_offset   = (cp_data['half_offset'] || cp_data['half_off'] || 0).to_f

      { center: world_center, tangent: world_tangent, half_offset: half_offset }
    rescue => ex
      puts "[Build] resolve_cp error: #{ex.message}"
      nil
    end

    def self._parse_point(data, key)
      if data["#{key}_x"]
        Geom::Point3d.new(data["#{key}_x"].to_f, data["#{key}_y"].to_f, data["#{key}_z"].to_f)
      elsif data[key].is_a?(Hash)
        Geom::Point3d.new(data[key]['x'].to_f, data[key]['y'].to_f, data[key]['z'].to_f)
      elsif data[key].is_a?(Array)
        Geom::Point3d.new(*data[key])
      end
    end

    def self._parse_vector(data, key)
      if data["#{key}_x"]
        Geom::Vector3d.new(data["#{key}_x"].to_f, data["#{key}_y"].to_f, (data["#{key}_z"] || 0).to_f)
      elsif data[key].is_a?(Hash)
        Geom::Vector3d.new(data[key]['x'].to_f, data[key]['y'].to_f, (data[key]['z'] || 0).to_f)
      elsif data[key].is_a?(Array)
        Geom::Vector3d.new(*data[key])
      end
    end

    # Prepare CP cache for all structures
    def self.prepare_build_cp_cache(model)
      cache = {}
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
        sid = e.get_attribute('JPods', 'structure_id', '').to_s.strip
        next if sid.empty?

        # Recompute CPs if possible
        JPods::StructurePlacer.recompute_cps_for_entity(e) if defined?(JPods::StructurePlacer) &&
          JPods::StructurePlacer.respond_to?(:recompute_cps_for_entity)

        raw = e.get_attribute('JPods', 'connection_points')
        cps = raw ? JSON.parse(raw) : []
        cache[sid.downcase] = { entity: e, cps: cps } if cps.is_a?(Array)
      end
      cache
    end

    # Is this entity a traffic circle?
    def self.traffic_circle?(entity)
      fid = entity&.get_attribute('JPods', 'model_id', '').to_s.downcase
      fid.include?('traffic_circle')
    end

  end
end

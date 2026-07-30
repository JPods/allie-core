# ── Pod Helpers — entity creation utilities ───────────────────────────────────
#
# Small utility functions for placing and managing pod entities in the model.
# Used by console station tests, Populate, and any code that creates pod instances.
# These are NOT animation logic — just SketchUp entity manipulation.

module JPods
  module PodHelpers

    # Load (or reuse) a pod ComponentDefinition from templates/pods/<id>/model.skp.
    def self.load_pod_definition(model, pod_template_id)
      comp_name = "JPod_vehicle:#{pod_template_id}"
      existing  = model.definitions[comp_name]
      return existing if existing

      skp = File.join(File.dirname(__FILE__), 'templates', 'pods', pod_template_id, 'model.skp')
      unless File.exist?(skp)
        puts "[PodHelpers] pod template not found: #{skp}"
        return nil
      end

      defn      = model.definitions.load(skp)
      defn.name = comp_name
      defn
    rescue => e
      puts "[PodHelpers] failed to load pod SKP — #{e.message}"
      nil
    end

    # Build a Transformation that places a pod at pt facing fwd.
    def self.pod_transform(pt, fwd)
      angle    = Math.atan2(fwd.y, fwd.x)
      z_axis   = Geom::Vector3d.new(0, 0, 1)
      rotate   = Geom::Transformation.rotation(Geom::Point3d.new, z_axis, angle)
      Geom::Transformation.translation(pt) * rotate
    end

    # Find the next available NORA number in the model.
    def self.next_nora_num(model)
      max_num = 0
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::ComponentInstance)
        num = e.get_attribute('JPods', 'vehicle_num', 0).to_i
        max_num = num if num > max_num
      end
      max_num + 1
    rescue
      1
    end

    # Assign a SketchUp tag (layer) to a pod instance for show/hide control.
    def self.assign_nora_tag(inst, nora_id, model)
      tag = model.layers[nora_id] || model.layers.add(nora_id)
      inst.layer = tag
    rescue => ex
      puts "[PodHelpers] assign_nora_tag #{nora_id}: #{ex.message}"
    end

  end
end

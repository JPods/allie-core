module JPods
  # ── LayerManager ─────────────────────────────────────────────────────────────
  #
  # Single source of truth for every SketchUp tag (layer) used by the JPods
  # plugin.  All Build, Validate, and display operations call ensure_tags once
  # at the start of their transaction, then get_tag to assign individual groups.
  #
  # Adding a new tag: add one entry to TAGS, then call get_tag(model, :key)
  # at the point where geometry is placed.
  #
  module LayerManager

    # Key → display name used in SketchUp's Tags panel.
    remove_const(:TAGS) if const_defined?(:TAGS)
    TAGS = {
      guideway_beam: 'JPods Guideway Beams',
      support:       'JPods Support Columns',
      solar:         'JPods Solar',
      formation:     'JPods Formations',
    }.freeze

    # Create all managed tags in model if they are absent.  Idempotent — safe
    # to call at the start of any Build or Validate transaction, and on model open.
    # Also retagss any Solar_* groups that are on Untagged (e.g. built before the
    # tag-assignment fix was applied).
    def self.ensure_tags(model)
      TAGS.each_value do |name|
        model.layers.add(name) unless model.layers[name]
      end
      retag_existing_solar(model)
    end

    # Walk top-level and one level of nested groups for anything named "Solar_*"
    # or matching the solar naming rule, and assign it to the Solar tag.
    # Safe to call repeatedly — only touches Untagged entities.
    def self.retag_existing_solar(model)
      solar_tag    = get_tag(model, :solar)
      untagged_name = 'Layer0'  # SketchUp's internal name for Untagged
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        name = e.is_a?(Sketchup::Group) ? e.name.to_s : e.definition.name.to_s
        next unless name.start_with?('Solar_') || solar_name?(name)
        e.layer = solar_tag if e.layer.name == untagged_name
        # Also tag instances inside the solar group
        if e.is_a?(Sketchup::Group)
          e.entities.each do |child|
            next unless child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
            child.layer = solar_tag if child.layer.name == untagged_name
          end
        end
      end
    rescue => ex
      puts "[JPods LayerManager] retag_existing_solar warning: #{ex.message}"
    end

    # Return the Layer object for key, creating it if necessary.
    # Falls back to model.active_layer if key is unknown.
    def self.get_tag(model, key)
      name = TAGS[key]
      unless name
        puts "[JPods LayerManager] unknown tag key: #{key.inspect}"
        return model.active_layer
      end
      model.layers[name] || model.layers.add(name)
    end

    # Walk a component definition and assign any solar-related sub-groups or
    # component instances to the 'JPods Solar' tag.  Called once after the
    # station and solar-column template SKPs are first loaded.
    #
    # Identification rule: entity name or component definition name contains
    # "solar" or "panel" (case-insensitive).  This relies on the template
    # authors naming solar geometry predictably — update the pattern if a
    # template uses a different convention.
    def self.retag_solar_in_definition(model, defn)
      return unless defn.is_a?(Sketchup::ComponentDefinition)
      solar_tag = get_tag(model, :solar)
      walk_entities_for_solar(defn.entities, solar_tag)
    end

    def self.walk_entities_for_solar(entities, solar_tag)
      entities.each do |e|
        case e
        when Sketchup::Group
          if solar_name?(e.name)
            e.layer = solar_tag
          else
            walk_entities_for_solar(e.entities, solar_tag)
          end
        when Sketchup::ComponentInstance
          if solar_name?(e.definition.name) || solar_name?(e.name)
            e.layer = solar_tag
          else
            walk_entities_for_solar(e.definition.entities, solar_tag)
          end
        end
      end
    rescue => ex
      puts "[JPods LayerManager] retag_solar warning: #{ex.message}"
    end

    def self.solar_name?(name)
      s = name.to_s.downcase
      s.include?('solar') || s.include?('panel')
    end
    private_class_method :walk_entities_for_solar, :solar_name?

  end
end

# SNIPPET: su-retag-existing-geometry
# When:    after adding tag assignment to a build pipeline — existing built geometry
#          predates the fix and is still on Untagged (Layer0). Must handle both:
#          (1) pipeline fix — new geometry gets the right tag going forward
#          (2) retag pass  — existing geometry built before the fix gets reassigned on open
# Why:     Without (2), the tag fix is correct but invisible until a full rebuild.
#          "What geometry predates this fix?" must always be asked alongside the pipeline fix.
# Axiom:   (emerging — two-category tag fix pattern, 2026-05-18)
# TFTS:    process/inbox/20260518T230734-tfts.md
# File:    jpod_layer_manager.rb retag_existing_solar

# Called from ensure_tags — runs on every model open, idempotent.
def self.retag_existing_solar(model)
  solar_tag     = get_tag(model, :solar)
  untagged_name = 'Layer0'   # SketchUp internal name for Untagged

  model.entities.each do |e|
    next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    name = e.is_a?(Sketchup::Group) ? e.name.to_s : e.definition.name.to_s
    next unless name.start_with?('Solar_') || solar_name?(name)

    # Tag the container
    e.layer = solar_tag if e.layer.name == untagged_name

    # Tag children (one level deep is sufficient for most structures)
    if e.is_a?(Sketchup::Group)
      e.entities.each do |child|
        next unless child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
        child.layer = solar_tag if child.layer.name == untagged_name
      end
    end
  end
rescue => ex
  puts "[JPods LayerManager] retag warning: #{ex.message}"
end

# Pattern: for any new tag assignment, write ensure_tags + retag_existing_X as a pair.
# Naming: retag_existing_<geometry_type>(model) — one method per tag category.

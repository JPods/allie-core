# JPods Utilities — shared helpers used across the plugin.
#
# Three modules:
#   JPods::ModelTransaction  — wraps model operations with start/commit/abort
#   JPods::EntityAttributes  — typed accessors for the 'JPods' attribute dict
#   JPods::EntityLookup      — named finders to replace inline entity scan patterns

module JPods

  # ── ModelTransaction ─────────────────────────────────────────────────────────
  # Wraps any block in a SketchUp undoable operation.  On success the operation
  # is committed; on any exception it is aborted and the exception re-raised.
  #
  # Usage:
  #   JPods::ModelTransaction.wrap(model, "Build Guideway") do
  #     ... model edits ...
  #   end
  module ModelTransaction
    def self.wrap(model, description, &block)
      model.start_operation(description, true)
      begin
        block.call
        model.commit_operation
      rescue => e
        model.abort_operation
        raise
      end
    end
  end

  # ── EntityAttributes ─────────────────────────────────────────────────────────
  # Typed accessors for the 'JPods' attribute dictionary.
  # Eliminates scattered .get_attribute('JPods', ...) / .set_attribute('JPods', ...)
  # calls and enforces consistent type coercion.
  module EntityAttributes
    DICT = 'JPods'.freeze

    def self.get_str(entity, key, default = '')
      entity.get_attribute(DICT, key, default).to_s
    end

    def self.get_int(entity, key, default = 0)
      entity.get_attribute(DICT, key, default).to_i
    end

    def self.get_float(entity, key, default = 0.0)
      entity.get_attribute(DICT, key, default).to_f
    end

    def self.set(entity, key, value)
      entity.set_attribute(DICT, key, value)
    end

    def self.present?(entity, key)
      !entity.get_attribute(DICT, key, nil).nil?
    end
  end

  # ── EntityLookup ─────────────────────────────────────────────────────────────
  # Named finders to replace inline model.entities.find/select scan patterns.
  # All methods accept a SketchUp::Model and return Group(s) or ComponentInstance(s).
  module EntityLookup
    def self.guideways(model)
      model.entities.select { |e|
        e.is_a?(Sketchup::Group) && e.name == 'JPods Guideway'
      }
    end

    def self.find_guideway(model, connection_id:, track_index:)
      model.entities.find { |e|
        e.is_a?(Sketchup::Group) && e.name == 'JPods Guideway' &&
        EntityAttributes.get_str(e, 'connection_id') == connection_id.to_s &&
        EntityAttributes.get_int(e, 'track_index') == track_index.to_i
      }
    end

    def self.find_vehicle(model, nora_id:)
      model.entities.find { |e|
        e.is_a?(Sketchup::ComponentInstance) &&
        EntityAttributes.get_str(e, 'vehicle_id') == nora_id.to_s
      }
    end

    def self.vehicles(model)
      model.entities.select { |e|
        e.is_a?(Sketchup::ComponentInstance) &&
        EntityAttributes.present?(e, 'vehicle_id')
      }
    end
  end

end # module JPods

# TODO: Step 8 migration — replace inline .get_attribute('JPods', ...) and
# .set_attribute('JPods', ...) calls across all files with JPods::EntityAttributes
# typed accessors.  461 callsites identified (2026-05-06) across jpod_animator.rb
# (166), jpod_vehicle_runtime.rb (82), jpod_network.rb (63), jpod_structure_tool.rb
# (30), jpod_network_editor.rb (22), jpod_conflict_detector.rb (21), jpod_platform.rb
# (16), jpod_console.rb (15), jpod_natalie_bridge.rb (10), jpod_followme_exporter.rb
# (10) and others.  Migrate incrementally — read each file before editing.
#
# TODO: Step 6 migration — replace inline model.start_operation/commit/abort
# patterns with JPods::ModelTransaction.wrap where the rescue block is clean
# (re-raises or has no side effects).  Callsites with puts/swallowed errors
# should stay as-is until the error-handling strategy is decided.

# ── Build Shims — namespace fixes for archived build pipeline ─────────────────
#
# The old build pipeline is proven code. These shims fix namespace resolution
# issues that arise from loading archived modules without editing them.
#
# Rule: NEVER edit codearchive files. Fix namespace issues here.

module JPods
  module Network
    class PathResolver
      # PathResolver references bare 'PathBuilder' which Ruby resolves as
      # JPods::Network::PathResolver::PathBuilder (doesn't exist).
      # The actual module is JPods::PathBuilder. This alias fixes it.
      PathBuilder = JPods::PathBuilder if defined?(JPods::PathBuilder)
    end
  end

  # JPodGuideway.build and place_solar_columns are now in build/build_entities.rb
  # No shims needed for these methods.
end

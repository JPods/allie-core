# SNIPPET: su-pair-stubs-empty-guard
# When:    any function that aggregates points from a component scan and divides by count
# Why:     Non-station components (terrain tile, Geolocation Content, decorative groups)
#          may pass the outer scan filter but contain no gw_stub_pair geometry.
#          all_pts.empty? → division by zero → ZeroDivisionError with no useful message.
#          SketchUp has no type system to prevent this — every component is a candidate.
# Axiom:   CLAUDE.md § "Non-Station Components Must Not Enter the CP Pipeline"
# File:    jpod_structure_tool.rb pair_stubs (line ~1266)

def pair_stubs(defn, model)
  all_pts = collect_stub_points(defn)   # whatever your collection method is

  # GUARD — must be before any division or centroid calculation
  return [] if all_pts.empty?

  # safe to divide now
  cx = all_pts.sum(&:x) / all_pts.size
  cy = all_pts.sum(&:y) / all_pts.size
  # ... rest of function
end

# The broader rule: every function that divides by a count must guard the empty case.
# Fail fast with [] or nil — never divide blindly.

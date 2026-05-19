# SNIPPET: su-cap-pt-tangent-validation
# When:    computing CP tangent direction in scan_stub_pair_tips (jpod_structure_tool.rb)
#          — or any time tangent direction must be determined from station geometry
# Why:     Cluster centroids and bounding-box radial distance both fail for asymmetric
#          or unusual station templates (S050 proved this after two failed fix attempts).
#          cap_pt (dead_cap_end entity) is placed explicitly by the model author — it IS
#          the gate face. If tangent points away from cap_pt, it is wrong. Reverse it.
# Axiom:   CLAUDE.md § "Explicit Model Datum Beats Derived Reference"
# Scar:    scars.md § "S050.CP0 Inward Tangent — Explicit Datum Beats Derived Reference"
# Hierarchy: 1. cap_pt (explicit tagged entity) — use this
#            2. Hard physical edge endpoint
#            3. Radial distance from formation center — last resort

# stub_cx, stub_cy = stub pair centroid X/Y
# cap_pt           = the dead_cap_end Point3d entity (nil if not found on template)
# tangent          = Geom::Vector3d computed so far (may be wrong direction)

if cap_pt
  to_cap = Geom::Vector3d.new(cap_pt.x - stub_cx, cap_pt.y - stub_cy, 0)
  if to_cap.length > 0.001 && tangent.dot(to_cap) < 0
    tangent = tangent.reverse
    puts "    [CP fix] reversed tangent via cap_pt validation"
  end
end

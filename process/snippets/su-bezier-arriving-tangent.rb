# SNIPPET: su-bezier-arriving-tangent
# When:    computing Hermite-to-Bezier control points at the TO (destination) endpoint
#          specifically in bezier_pts_via (jpod_connect_tool.rb)
# Why:     Hermite terminal tangent = curve velocity at that point.
#          FROM endpoint: velocity is outward (departing) — use tangent as-is.
#          TO endpoint:   velocity is inward (arriving)  — must REVERSE the tangent.
#          jpod_network.rb bezier_spline_pts already had .reverse; connect tool preview did not.
# Axiom:   CLAUDE.md § "Hermite Terminal Tangent is the Curve Velocity"
# Scar:    scars.md § "S050.CP0 Inward Tangent" (corollary section)
# Warning: ene_railroad handle convention (bezier_pts / tangent_curve_pts) uses OUTWARD handles
#          at BOTH ends — opposite sign convention. Never mix the two in the same function.

# FROM endpoint — velocity outward, use as-is:
t0 = from_cp[:tangent].normalize
tangents[0] = Geom::Vector3d.new(t0.x * dn, t0.y * dn, t0.z * dn)

# TO endpoint — velocity INWARD (arriving), reverse:
t1 = to_cp[:tangent].normalize.reverse
tangents[m - 1] = Geom::Vector3d.new(t1.x * dn, t1.y * dn, t1.z * dn)

# JPods CP Calculation — Regression Guard

**Date written:** 2026-04-29
**Updated:** 2026-05-30 — cp component instances are now the primary detection method.
**Enforced in:** `jpod_structure_tool.rb`

---

## Current Approach (2026-05-30)

CP position is read from a placed `cp` component instance in the formation template.
The hub vertex (intersection of 222 mm tang_edge + 1750 mm rail edges) is the CP center.
No geometry inference, no stub pairing, no offset calculation.

See `readmes/jpods-connection-point-rule.md` for the full rule.

**The cp component is the explicit datum. No offset correction should ever be applied after
the hub vertex is read. If any shift appears, that is a regression.**

---

## Anchor Z for Guideway Endpoints at CP — CONFIRMED 2026-05-14

> **Change control:** Do not change the anchor_zs formula in `build_segment` without a written plan.
> Three alternatives were tested on 2026-05-14 and all failed.

**Code location:** `jpod_network.rb → Network.build_segment → anchor_zs block`

**Working formula:**
```ruby
is_traffic_circle = lambda do |ent|
  fid = ent&.get_attribute("JPods", "formation_id", "").to_s.downcase
  fid.include?("traffic_circle")
end
from_z = from_cp[:center].z + (is_traffic_circle.call(from_entity) ? Constants::BEAM_DEPTH / 2.0 : Constants::BEAM_DEPTH)
to_z   = to_cp[:center].z   + (is_traffic_circle.call(to_entity)   ? Constants::BEAM_DEPTH / 2.0 : Constants::BEAM_DEPTH)
cp_anchor_zs = [from_z, to_z]
```

`from_cp[:center].z` = hub vertex Z from the cp component (beam bottom-centerline at gate face).
PathBuilder path runs at beam TOP face; beam depth hangs downward so the bottom face lands flush.

**Failed alternatives (2026-05-14, do not retry without written plan):**
- `Terrain.elevation_at(CP_xy) + CLEARANCE_HEIGHT` — inconsistent per-station (0.6–1.2 m errors)
- `Terrain.ground_z_at(CP_xy) + CLEARANCE_HEIGHT` — skips station geometry, same magnitude errors
- `from_cp[:center].z` alone (no + BEAM_DEPTH) — beam lands 0.5 m below stub seam

---

## Diagnostic Check — After Every CP Calculate

After running CP Calculate, verify in the console output:

**Check A — Detection method**
Look for: `JPods CP detection: N top-level cp instance(s) — using placed positions`
If instead you see `arm_pair`, `pair_stubs`, or `vertex clustering`, the cp instances were not found.
Cause: cp definition name or tag doesn't match the scanner. Check naming against the rule.

**Check B — Index ordering**
If console shows `stub_pair count 0 ≠ cp count N — using atan2 fallback`, indices were assigned
by angular sort. Verify CP0 in the output matches CP0 in lines.json. If they don't match,
add gw_stub_pair_N_in groups to the template or verify the cp component placement order.

**Check C — Visual inspection after Build**
Zoom to a station gate. Both parallel guideways should meet the station without gap or overlap.
The CP ring must be centered between the two guideways.

---

## Corrective Action by Symptom

| Symptom | Most likely cause | Action |
|---------|------------------|--------|
| `No cp instances found` | Wrong naming | Check cp definition name (`cp`, `cpN`, `cp#N`) or tag (`cp_marker_N`) |
| atan2 fallback WARN | No gw_stub_pair_N_in groups | Add groups OR verify atan2 order matches lines.json |
| CP ring off-center after Build | Hub vertex wrong | Re-examine cp component — tang_edge and rail edges must share a hub vertex |
| Bezier connects to wrong gate | CP index mismatch | CP index from detection doesn't match lines.json — fix index ordering |
| Gap/overlap at seam | anchor_zs wrong | See anchor Z section above — do not change without written plan |

---

## Archived: stub_pair Geometry Detection Failures (pre-2026-05-30)

The following failures all applied to the old `scan_stub_pair_tips` / `pair_stubs` detection
method, which is now the legacy fallback (Priority 2+ in `resolve_connection_points`).
Retained for historical context and in case old models are encountered.

### Failure 1 — `inward_ref` at world origin (0,0,0)
**Bug:** `inward_ref` used to determine outward CP direction was `Geom::Point3d.new(0,0,0)`.
**Symptom:** CP direction correct only when model was origin-centered.
**Fix:** `inward_ref` changed to centroid of all stub_pair outer_pts.

### Failure 2 — `out_dir = cross_v.cross(Z)` (scan-order-dependent sign)
**Bug:** `cross_v = tip_b - tip_a`; sign of `cross_v × Z` depended on Ruby's entity iteration order.
**Symptom:** Every station had CP0 tangent inverted; CP1 happened to be correct.
**Fix:** `out_dir` = normalized average of the two stubs' own tangents.

### Failure 3 — BEAM_WIDTH/2 cross-track shift applied after midpoint
**Bug:** After computing `gate_ctr = midpoint(ta, tb)`, code shifted by `BEAM_WIDTH / 2`.
**Reality:** Stub_pair centroid IS the beam CL. No correction needed.
**Fix:** Cross-track shift removed entirely.

### Failure 4 — Along-track gap compensated by shifting CP center
**Bug:** CP center shifted forward to compensate for dead_end_cap removal gap.
**Fix:** CP center never shifted. `extend_path_ends` in `jpod_network.rb` handles any along-track
gap by extending path endpoints after PathBuilder, not by moving CP.

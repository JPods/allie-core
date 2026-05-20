# JPods CP Calculation — Regression Guard

**Date written:** 2026-04-29  
**Status:** Authoritative — update if algorithm changes  
**Enforced in:** `jpod_structure_tool.rb` → `scan_stub_pair_tips` + `detect_cps_from_stub_pair_tags`

---

## stub_pair Geometry Model

**One `stub_pair` component = one complete gate = BOTH parallel beam stubs.**

Not one side. A station with two gates has two `stub_pair` component instances. A station with one gate (line-end) has one.

Inside the `stub_pair` component definition:
- Geometry for both parallel beam stubs (left and right, ~3.5 m apart / `DUAL_TRACK_SPACING`)
- `dead_end_cap` entities as **direct children** of the stub_pair definition — not nested inside sub-groups or sub-components

The `stub_pair` tag is applied to the component **instance** inside the station component definition. The definition itself carries no special tag. Sub-entities inside the stub_pair component carry no `stub_pair` tag — tagging at multiple levels stops the scanner at the outermost match.

```
Station Component (no stub_pair tag)
  ├── StubPair_Gate0 (instance, tag="stub_pair")   ← gate 0: both beams
  │     [definition contains:]
  │     ├── left stub beam geometry
  │     ├── right stub beam geometry
  │     ├── dead_end_cap  ← direct child, left beam seam
  │     └── dead_end_cap  ← direct child, right beam seam
  └── StubPair_Gate1 (instance, tag="stub_pair")   ← gate 1: both beams
        [definition contains:]
        ├── left stub beam geometry
        ├── right stub beam geometry
        ├── dead_end_cap  ← direct child, left beam seam
        └── dead_end_cap  ← direct child, right beam seam
```

---

## The Invariant

**A CP must sit at the midpoint between the two guideway bottom-centerlines at the gate seam.**

In numbers: if the two parallel stubs are 3.5 m apart (DUAL_TRACK_SPACING), the CP center must be 1.75 m from each stub centerline, at the Z datum of the bottom face of the beam.

That midpoint is computed directly from stub geometry and requires **no correction offset** of any kind. If any offset is applied after the midpoint is computed, that is a regression.

---

## Why the `stub_pair` Tag Gives Correct Position Directly

`scan_stub_pair_tips` computes `outer_pt` for each tagged stub entity as:

1. Collect all vertices from the stub's mesh (in LOCAL coords, with transform applied).
2. Find the maximum XY distance from local origin → this is the gate-end face cluster.
3. Take the **centroid** of all vertices within `BEAM_WIDTH²` of that maximum.
4. Use `min(z)` of that cluster (bottom-seam datum).

The centroid of the gate-end face is the beam centerline of that stub at the gate. It is **not** a corner, not a top face, not an averaged full mesh — it is the beam CL point at the seam.

Therefore: `gate_ctr = midpoint(ta[:point], tb[:point])` is already the correct CP position. No correction needed.

---

## History of CP Calculation Failures

These bugs have each been fixed and must not be reintroduced.

### Failure 1 — `inward_ref` at world origin (0,0,0)

**When:** Multiple sessions before 2026-04-29  
**Bug:** The inward reference used to determine "which way is outward from the gate" was `Geom::Point3d.new(0,0,0)` — the world origin. A formation model's local origin bears no relationship to the station interior.  
**Symptom:** CP direction was correct only when the model happened to be origin-centered. After rotation or offset, direction flipped inconsistently.  
**Fix:** `inward_ref` changed to the centroid of all `stub_pair` outer_pts. This is always inside the formation (near the station loop center) regardless of world placement.  
**Current code:** Line ~407 in `jpod_structure_tool.rb`:
```ruby
inward_ref = Geom::Point3d.new(sx / tips.size.to_f, sy / tips.size.to_f, 0)
```

---

### Failure 2 — `out_dir = cross_v.cross(Z)` (scan-order-dependent sign)

**When:** 2026-04-29, Bill's test: "all the stations CP0 end have the CP offset"  
**Bug:** `cross_v = tip_b - tip_a` (the cross-track vector between the two stub tips). Then `out_dir = cross_v × Z`. The sign of this cross product depends entirely on which tip is `a` and which is `b` — i.e., on Ruby's iteration order over the entity list. For one gate the result pointed outward; for the other gate (visited in opposite scan order) it pointed inward.  
**Symptom:** Every station had CP0 with a rotated/inverted tangent. CP1 happened to be correct (its scan order happened to give the outward sign). Totally consistent failure: same gate index wrong every time.  
**Fix:** `out_dir` is now the normalized average of the two stubs' own tangents:
```ruby
avg_tan = Geom::Vector3d.new(
  (ta[:tangent].x + tb[:tangent].x) / 2.0,
  (ta[:tangent].y + tb[:tangent].y) / 2.0, 0
)
out_dir = avg_tan.normalize
```
Each stub's tangent is `(outer_pt - inner_pt).normalize`, computed independently for that stub. It always points outward from that stub's gate end regardless of which is `a` or `b`.

**Regression check:** After Recompute CPs, the two CP tangents for a station with two gates must point in **opposite** directions. If they point the same way, this failure has returned.

---

### Failure 3 — BEAM_WIDTH/2 cross-track shift applied after midpoint

**When:** 2026-04-29 (same session as Failure 2)  
**Bug:** After computing `gate_ctr = midpoint(ta, tb)`, the code shifted `gate_ctr` by `BEAM_WIDTH / 2` in the cross-track direction (perpendicular to beam axis). The justification was that the stub tag resolves to a "lateral face plane" rather than the beam CL.  
**Reality:** The centroid of the gate-end face cluster IS the beam CL (see above). No correction was needed. The shift moved the CP off-center by 0.25 m in the cross-track direction.  
**Symptom:** At CP1 (which had a correct tangent due to Failure 2 happening to work for it), the seam showed a consistent 0.25 m overlap or gap. At CP0 (wrong tangent), both bugs compounded.  
**Fix:** Cross-track shift removed entirely. `gate_ctr` is used as computed from the midpoint.

**Regression check:** Visual inspection — CP circle must be centered between the two stubs, equidistant from each guideway CL. If it is flush with one guideway's outer edge, the shift has been reintroduced.

---

### Failure 4 — Along-track gap compensated by shifting CP center

**When:** Earlier session (before 2026-04-29)  
**Bug:** After removing `dead_end_cap` geometry, a gap appeared at the seam because the path endpoint was built from the CP position, which was now shorter than the stub length. The workaround was to shift the CP center forward by the estimated cap length.  
**Problem:** Shifting CP center invalidates the position invariant. Downstream code that uses CP as a position anchor (guideway pair midpoint, FollowMe endpoint) gets the wrong seam datum.  
**Fix:** CP center is never shifted for cap compensation. Instead, `extend_path_ends` in `jpod_network.rb` extends the centerline path endpoints by `cap_extension` (estimated dead_end_cap depth) after PathBuilder completes. CP position stays at the true gate seam.

---

## Diagnostic Check — Run After Every Recompute CPs

Paste these checks into Ruby Console or read from the output after clicking Recompute CPs:

### Check A — Tangent direction symmetry (Failure 2 guard)

```
JPods stub_pair: CP0 paired -> (...) m  tangent=(tx0, ty0)
JPods stub_pair: CP1 paired -> (...) m  tangent=(tx1, ty1)
```

**Pass:** `tx0` and `tx1` have opposite signs (or `ty0` and `ty1` have opposite signs if the stubs run N-S). The two gates of one station always face outward in opposite directions.  
**Fail:** Both tangents have the same sign in the dominant axis → scan-order bug has returned. Check `avg_tan` computation.

### Check B — CP equidistant from both stub outer_pts (Failure 3 guard)

After Recompute CPs, in Ruby Console:
```ruby
ents = Sketchup.active_model.entities
st = ents.select { |e| e.is_a?(Sketchup::ComponentInstance) && e.get_attribute("JPodStructure","structure_id") }.first
cps = st ? JSON.parse(st.get_attribute("JPodStructure","connection_points","[]")) : []
cps.each { |cp| puts "CP#{cp['index']}: center=(#{cp['center'].map{|v| (v/25.4*1000).round(3)}} m)" }
```

Then compare each CP center against the two stub outer_pt positions shown in the Recompute CPs output. Each CP center should be exactly halfway between its two stub tips (within 1 mm). If it is offset by ~0.25 m in the cross-track direction, the BEAM_WIDTH/2 shift has been reintroduced.

### Check C — Visual inspection (all failures)

After clicking Build:
1. Zoom to a station gate. The two parallel guideways should meet the station stubs without gap or overlap.
2. The CP circle (drawn by the network editor) must be centered between the two guideways, not flush with one outer edge.
3. If gap/overlap exists at one gate but not the other → Failure 2 (tangent sign error).
4. If both gates have equal gap or overlap → Failure 3 (cross-track shift) or Failure 4 (cap compensation at wrong layer).

---

## Corrective Action by Symptom

| Symptom | Most likely failure | First action |
|---|---|---|
| CP0 wrong, CP1 correct, consistent across all stations | Failure 2 — `cross_v × Z` sign | Check `avg_tan` in `detect_cps_from_stub_pair_tags`. Both stub tangents must point outward. |
| Both gates show equal 0.25 m cross-track error | Failure 3 — BEAM_WIDTH/2 shift | Search for `BEAM_WIDTH / 2` in `detect_cps_from_stub_pair_tags`. Remove any cross-track offset applied after `gate_ctr` is computed. |
| Gap at seam but CP circle is centered correctly | Failure 4 — cap compensation | Check `extend_path_ends` in `jpod_network.rb`. Cap extension should be applied to path endpoints only, not to `gate_ctr`. |
| CP direction flips after model save/reload | Failure 1 — `inward_ref` at wrong location | Print `inward_ref` during Recompute. It must be the centroid of stub tips, not `(0,0,0)`. |
| `Recompute CPs` shows `CPs from cap seams` not `stub_pair tags` | Tag missing or misspelled | Open the station SKP, check every gate stub entity for `stub_pair` tag (exact name, lowercase, no spaces). |

---

## Anchor Z for Guideway Endpoints at CP — CONFIRMED 2026-05-14

> **Change control:** Do not change the anchor_zs formula in `build_segment` without a written plan.
> Three alternatives were tested on 2026-05-14 and all failed. See Rule 10 in
> `readmes/sketchup/jpods-plugin.md` for the failure log.

**Code location:** `jpod_network.rb` → `Network.build_segment` → anchor_zs block

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

`from_cp[:center].z` = stub bottom face Z from `centroid_min_z` in `scan_stub_pair_tips`
(`jpod_structure_tool.rb`). PathBuilder path runs at beam TOP face; beam depth hangs downward
so the bottom face lands flush with the stub bottom seam.

**Failed alternatives (2026-05-14, do not retry without written plan):**
- `Terrain.elevation_at(CP_xy) + CLEARANCE_HEIGHT` — inconsistent per-station (0.6–1.2 m errors)
- `Terrain.ground_z_at(CP_xy) + CLEARANCE_HEIGHT` — skips station geometry, same magnitude errors
- `from_cp[:center].z` alone (no + BEAM_DEPTH) — beam lands 0.5 m below stub seam

---

## The Algorithm in One Paragraph (Authoritative)

For each pair of `stub_pair` tagged entities within `DUAL_TRACK_SPACING * 0.5..1.5` of each other: compute `outer_pt` for each as the XY centroid of the gate-end vertex cluster (bottom Z). Compute stub tangent as `(outer_pt - inner_pt).normalize`. Gate CP center = `midpoint(outer_pt_a, outer_pt_b)`. Gate CP outward tangent = `normalize(avg(tangent_a, tangent_b))`. No offsets, no cross-track shifts, no axis corrections. The `cap_extension` path-end extension in `jpod_network.rb` handles any along-track seam gap independently.

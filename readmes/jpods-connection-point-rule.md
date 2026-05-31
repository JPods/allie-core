# JPods Connection Point Rule — updated 2026-05-30

## Color Standard — Red Inbound, Blue Outbound

**All JPods tools (SketchUp plugin, Route-Time GUI, any future visualizations) follow this rule:**

| Color | Meaning |
|-------|---------|
| 🔴 **Red** | Inbound — hot end — vehicle or flow arriving |
| 🔵 **Blue** | Outbound — cool end — vehicle or flow departing |

This applies to guideway lines, CP rings, station siding lines, and any future directional indicators. Never reverse. Never monochrome for directional elements.

---

## The Rule

> **The Connection Point (CP) is defined by a placed `cp` component instance in the formation template. The hub vertex of that component is the CP center; the 222 mm edge gives the outward tangent.**

This is an explicit model-author datum (Axiom 10 — explicit beats derived). No geometry inference, no stub pairing, no offset calculation.

---

## The cp Component

Every formation template contains one `cp` component instance per gate. The definition contains three edges:

| Edge | Length | Purpose |
|------|--------|---------|
| Tang edge | 222 mm | Outward tangent from CP center |
| Rail edges (×2) | 1750 mm | Half of DUAL_TRACK_SPACING (3500 mm) — one to each guideway CL |

**Hub vertex** = the vertex shared by the tang edge and both rail edges. This is the CP center — the midpoint between the two guideway bottom-centerlines at the gate face.

**Naming convention:**
- Definition name: `cp`, `cp0`, `cp1`, `cp2`, `cp3` (or `cp#0`, `cp#1` …)
- Tag or instance name: `cp_marker_0`, `cp_marker_1` … (also recognized)

The scanner matches: `tag == 'cp'`, `tag.start_with?('cp_marker')`, definition name `cp`, `cpN`, or `cp#N`.

---

## Why This Matters

1. **At structure placement** (`jpod_structure_tool.rb`): CPs are read from the placed cp instance, stored as JSON on the structure entity, and rendered as colored rings in the viewport.

2. **At network build** (`jpod_network.rb → build_segment`): CP center + tangent tells the build system where to remove the ending cap geometry and where the seam point is for joining two guideway segments.

3. **In the Connect Guideways tool**: CP rings drawn from stored CP data. User clicks rings to wire connections. Bezier curves flow from one CP's outward tangent to the next CP's inward approach.

4. **In the formation map** (`formations/{formation}.json`): CP data stored in definition-local coordinates once per template (debug-once-use-many). BUILD reads from the map; never re-detects at build time.

---

## Detection Priority

`detect_cps_from_stub_pair_tags` (called from `resolve_connection_points`) runs this chain:

| Priority | Method | When it fires |
|----------|--------|---------------|
| 1 | `detect_cps_from_top_level_cp` — cp instances at any depth ≤ 4 | **Current approach — all templates** |
| 2 | `detect_cps_from_cp_instances` — cp nested inside gw_stub_pair_N_in | Legacy templates |
| 3 | `detect_cps_from_arm_pairs` — gw_N_in / gw_N_out pairs | Traffic circle legacy |
| 4 | Vertex clustering | Oldest fallback |

Priority 1 fires for all current templates (traffic_circle7, station_line_end, JPods_station_parking, station_thru_dip). The lower priorities are fallbacks for older models that predate cp component placement.

---

## CP Index Assignment

After cp instances are found, indices are assigned by one of two methods:

1. **Proximity to gw_stub_pair_N_in groups** (preferred) — if the template has `gw_stub_pair_N_in` groups, each cp is matched to the nearest one. The stub_pair N becomes the CP index.

2. **atan2 angular sort** (fallback) — if no gw_stub_pair groups exist, cp instances are sorted by angle from the formation center. This fires a WARN in the console: `stub_pair count 0 ≠ cp count N`.

**Implication for model authors:** To get deterministic CP index ordering that matches lines.json, either add `gw_stub_pair_N_in` groups (one per gate), or name cp components `cp0`, `cp1`, etc. and place them in the order lines.json expects. The atan2 sort produces CCW order from South (−90°) which may not match the intended CP0.

---

## Formation Map

`formations/{formation}.json` (schema `jpods-formation-map-v1`) stores verified CP data in definition-local coordinates.

**BUILD always uses the formation map — never regenerates it.**

To update: open the template model → Console → Models → Generate Formation Map. This overwrites the map from the current cp instance positions.

---

## Implementation

**Key methods in `jpod_structure_tool.rb`:**

| Method | Purpose |
|--------|---------|
| `collect_cp_instances` | Recursive scan (depth ≤ 4) — finds cp instances by tag or definition name |
| `detect_cps_from_top_level_cp` | Reads hub vertex (center) and 222 mm edge (tangent); assigns indices |
| `detect_cps_from_stub_pair_tags` | Priority chain dispatcher |
| `resolve_connection_points` | Outer router: tries cp detection first, falls back to pair_stubs |

**Recognized names (in `collect_cp_instances`):**
```ruby
ct == 'cp' || ct.start_with?('cp_marker') ||
dname == 'cp' || dname.match?(/\Acp(#?\d+)?\z/)
```

---

## Legacy: pair_stubs + 9 m Offset (archived)

Prior to 2026-05-30, the primary detection used `pair_stubs` — geometric stub endpoint pairing from placement_data. For traffic circles it applied a hardcoded 9 m radial offset to compensate for a phantom ring-junction stub artifact.

This approach is still in the code as the `resolve_connection_points` Priority 2 fallback (after all cp-instance methods fail). It is not used by any current template. Do not remove it — it handles models built before cp components were added.

Historical problem log: `readmes/sketchup/jpods-cp-regression-guard.md`.

---

## Anchor Z for Guideway Endpoints at CP — CONFIRMED 2026-05-14

> **Change control:** Do not change the anchor_zs formula in `build_segment` without a written plan.
> Three alternatives were tested on 2026-05-14 and all failed.

**Code location:** `jpod_network.rb → Network.build_segment → anchor_zs block`

```ruby
is_traffic_circle = lambda do |ent|
  fid = ent&.get_attribute("JPods", "formation_id", "").to_s.downcase
  fid.include?("traffic_circle")
end
from_z = from_cp[:center].z + (is_traffic_circle.call(from_entity) ? Constants::BEAM_DEPTH / 2.0 : Constants::BEAM_DEPTH)
to_z   = to_cp[:center].z   + (is_traffic_circle.call(to_entity)   ? Constants::BEAM_DEPTH / 2.0 : Constants::BEAM_DEPTH)
```

`from_cp[:center].z` = hub vertex Z from the cp component (bottom-centerline of beam at gate face). PathBuilder path runs at beam TOP; beam depth hangs downward so the bottom face lands flush with the stub seam.

**Failed alternatives (2026-05-14, do not retry without written plan):**
- `Terrain.elevation_at(CP_xy) + CLEARANCE_HEIGHT` — 0.6–1.2 m errors per station
- `Terrain.ground_z_at(CP_xy) + CLEARANCE_HEIGHT` — skips station geometry, same magnitude
- `from_cp[:center].z` alone (no + BEAM_DEPTH) — beam lands 0.5 m below stub seam

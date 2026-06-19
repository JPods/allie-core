# Template Validation Log
**Goal:** Compute + animate all 4 track formation templates, then apply each to networks.
**Started:** 2026-06-19
**Fix applied:** noelle.rb:3762 — skip rigid body frame transform for traffic_circle formations

---

## Templates

| # | Template | Compute | Animate | Defects | Status |
|---|----------|---------|---------|---------|--------|
| 1 | `traffic_circle7` | ✓ 2026-06-19 | ✓ 2026-06-19 | 0 | PASS |
| 2 | `station_thru_dip` | — | — | — | pending |
| 3 | `station_line_end` | — | — | — | pending |
| 4 | `station_parking` | — | — | — | pending |

---

## traffic_circle7 — PASS (2026-06-19T03:25Z)

**Compute output (lines.computed.json generated 2026-06-19T03:25Z):**
- Ring center: `[-15881.7, 0.0]` — true centroid of all 4 CP gates ✓
- N_N arc midpoints all 7500.0mm from center (cardinal points) ✓
- Connectors: 4 pts, 1000.7mm each (equal, nonzero) ✓
- Z: 7956.8mm (template-local elevation, correct) ✓

**Trajectory (20260619T032503):**
- All 4 pods: `maneuver_end` reached ✓
- Ring center from pod pair midpoints: `[-15881.7, 0.0]` at every tick — zero Y drift ✓
- Segment length: 46,674mm per pod (CCW symmetry confirmed) ✓

**Trip reports (20260619T032509):**
- All 4 pods: `completed: true`, `natalie_verdict: authorized`, `total_defects: 0` ✓
- Speed: 8.05–8.12 m/s vs. authorized 8.3 m/s — within tolerance ✓

**Bug fixed this session:**
- FAULT: 20260618T185919 — ring center 1250mm off in X (centered on CP0/CP2 only)
- Root cause: rigid body frame transform in `write_lines_computed_from_geometry` computed `arc_hub = gate + stub_half*tangent` (1250mm past gate center), producing spurious -1250mm X shift
- Fix: `if !tmpl_key.match?(/\Atraffic_circle/) && cps_for_xf.size >= 2` (noelle.rb:3762)
- TFTS: 20260619T032047

---

## station_thru_dip — pending

Open `station_thru_dip/model.skp`, run Compute, run animation.

**Watch for:**
- All gw_cp_in/out stubs correct length (2500mm)
- gw_uturn arcs: status will show `ARC` (expected — arc geometry, not edge-walkable)
- gw_lift / gw_lift_in: prior baseline showed WARN at 362.6mm delta — confirm unchanged
- All pods complete, no cp_gap_count

---

## station_line_end — pending

Open `station_line_end/model.skp`, run Compute, run animation.

---

## station_parking — pending

Open `station_parking/model.skp`, run Compute, run animation.

---

## Network application — pending

After all 4 templates pass:
- Apply to network models (TBD)
- Verify template geometry composites correctly into network frame
- Check cp_marker pinning in network context

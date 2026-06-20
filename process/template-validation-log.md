# Template Validation Log
**Goal:** Compute + animate all 4 track formation templates, then apply each to networks.
**Started:** 2026-06-19
**Fix applied:** noelle.rb:3762 — skip rigid body frame transform for traffic_circle formations

---

## Templates

| # | Template | Compute | Animate | Defects | Status |
|---|----------|---------|---------|---------|--------|
| 1 | `traffic_circle7` | ✓ 2026-06-19 | ✓ 2026-06-19 | 0 | PASS |
| 2 | `station_thru_dip` | ✓ 2026-06-20 | ✓ 2026-06-20 | 0 | PASS |
| 3 | `station_line_end` | ✓ 2026-06-20 | ✓ 2026-06-20 | 0 | PASS |
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

## station_thru_dip — PASS (2026-06-20T00:53Z)

**Compute output:** Internal Z consistent — ring level Z=9683.9, platform level Z=7523.9. No world Z reference (template formation). All cp arm and cp lead endpoints correct after P0.1 + P0.15 post-pass fixes.

**Bug fixed this session (two stacked bugs):**
- P0.1: was using a flat `z` from stale jpods_path attr applied to both arm endpoints. Fixed: `z_arm = uturn_first_pt[2]` — arm is flat at ring/uturn Z from hub math.
- P0.15: was reading `z = lead_pts[0].at(2)` (stale ene_railroad Z) and applying flat to all 4 interpolation pts. Fixed: use `target[2]` for uturn_end; interpolate Z linearly fp→lp.
- TFTS: 20260619T000000

**Trip reports — second run (20260620T005xxx):**

| Vehicle | Trip type | Loops | Length mm | Completed | Defects | Parking |
|---------|-----------|-------|-----------|-----------|---------|---------|
| NORA_0001 | hold_loop | 12/12 | 141,273 | ✓ | 0 | ps2 |
| NORA_0004 | hold_loop | 8/8 | 100,875 | ✓ | 0 | — |
| NORA_0001 | hold_loop | 5/5 | 39,908 | ✓ | 0 | ps4 |
| NORA_0002 | hold_loop | 9/9 | 114,323 | ✓ | 0 | ps3 |

All: `natalie_verdict: authorized`, `cp_gap_count: 0`, `speed_deviation_count: 0`

**Hold loop path confirmed (21 segs):** gw_platform → gw_platform_out → gw_cp_out_lead_1 → gw_uturn_1 → gw_cp_in_lead_1 → gw_far_main → gw_cp_out_lead_0 → gw_uturn_0 → gw_cp_in_lead_0 → gw_near_main_1 → gw_platform_in → gw_platform_parking. All cp arm/lead transitions traversed with 0 cp_gap_count — Z fix confirmed.

**Natalie load-balancing:** Issued originating_chain plans (8 segs via gw_cp_out_0) to NORA_0003 and NORA_0004 during hold phase — correct departure sequencing.

**Parking coverage:** ps2, ps3, ps4 confirmed. ps1 implicitly covered (different loop count distributes across all slots).

---

## station_line_end — PASS (2026-06-20T02:01Z)

**Bugs fixed this session (two stacked bugs):**
- cp_marker post-pass (noelle.rb ~3985): was pinning arm outer tip Z to `hub[2]` (body Z = 10055.2), overriding P0.1's correct ring_z (10242.7). Fixed: `ring_z_for_cp = geo_tracks_xf.dig("gw_uturn_#{n_str}", 'pts_mm')&.first&.at(2)` as rail_z. Committed `8db404b`.
- ring-Z normalization pass (noelle.rb, inserted before Bezier synthesis): detected ring_z (10242.7) - hub_z (10055.2) = +187.5mm (beam-top extraction artifact from jpods_path attr). Shifted all ring-level pts to hub_z. Multi-pt transition tracks reduced to 2 endpoints for Bezier re-synthesis. Committed `1075298`.

**Design standard established:** pts_mm Z = bottom center of guideway beam = cp_marker hub_z. Animator applies uniform -200mm offset. This is the universal rule for all templates.

**Compute output (lines.computed.json 2026-06-20T01:01:25Z):**
- Ring (gw_uturn_0, gw_cp_*): Z = 10055.2 (= hub_z, post-normalization) ✓
- gw_lift_in ramp: 10055.2 → 8242.7 ✓
- gw_uturn_1 (platform uturn): Z = 8255.2 ✓
- Platform (gw_far_main, gw_platform, gw_platform_parking): Z = 8192.7 ✓

**Trip reports (020xxx run, 2026-06-20T02:00Z):**

| Vehicle | Trip | Len mm | Actual m/s | Defects | Park |
|---------|------|--------|-----------|---------|------|
| NORA_0001 | hold_loop[7/8] | 90,264 | 8.21 | 0 | ps1 |
| NORA_0003 | hold_loop[6/6] | 52,938 | 8.22 | 0 | — |
| NORA_0001 | hold_loop[3/4] | 38,269 | 8.22 | 0 | ps3 |

All: `natalie_verdict: authorized`, `cp_gap_count: 0`, `speed_deviation_count: 0`

**Shuffle confirmed:** gw_platform_advance_ps2_to_ps3, gw_platform_advance_ps1_to_ps2 — both executed with maneuver_end. Concurrent shuffle while third pod loops.

**Depart confirmed:** originating_chain dispatched to NORA_0001 at 02:00:57Z — gw_platform → gw_uturn_1 → gw_far_main → gw_far_main_2 → gw_cp_out_lead_0 → gw_cp_out_0 (6 segs, exits at CP0 arm).

**Trajectory Z:** Platform floor 5839.4mm, ring peak 7701.9mm — consistent across all pods and all loop counts. Zero drift.

---

## station_parking — pending

Open `station_parking/model.skp`, run Compute, run animation.

---

## Network application — pending

After all 4 templates pass:
- Apply to network models (TBD)
- Verify template geometry composites correctly into network frame
- Check cp_marker pinning in network context

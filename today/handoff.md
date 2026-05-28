# Handoff — 2026-05-27

## Where We Stopped

Working on lines.json for station templates — math declaration, not scan output.

station_line_end scan returned nil: zero gw_* tagged entities in model.skp.
Model was fixed today (structural changes, 19:15) but tags were never applied to the geometry.
Next step before anything else: apply gw_* tags to station_line_end geometry in SketchUp.

## State of Each Template

### cpu / cps (structures/)
- Written from math. 5497.8mm uturns, 3500mm Y separation, 2500mm leads.
- **Pending:** Bill needs to verify coordinates against actual model geometry.
- TF checklist: `process/inbox/20260527T024859-tf.md`

### JPods_station_parking (track_formations/)
- Topology fully understood: CCW oval, CP0 at BOTTOM, CP1 at TOP.
- Naming convention: suffix _0/_1 (e.g., gw_cp_in_0, gw_uturn_0).
- **Not yet written.** Ready to write immediately — topology is resolved.
- Existing lines.json has MODEL_ERRORs from scan; uturn corrected to 5497.8mm in prior session.

### station_line_end (track_formations/)
- Old lines.json deleted (was world-space scan from S005 in station_test.skp — wrong).
- Model fixed today but zero gw_* tags on geometry.
- **Blocked:** needs tagging before scan or math declaration can proceed.
- Known segments: gw_platform, gw_platform_parking, gw_platform_in, gw_lift, gw_lift_in,
  gw_lift_parking, gw_far_main, gw_far_out, gw_uturn_0, gw_uturn_1,
  gw_stub_pair_0_in/out, gw_stub_pair_1_in/out.

### traffic_circle7 (track_formations/)
- MODEL_ERRORs from scan: connector arcs (gw_c_0_1 etc.) are 1000mm, chord 996mm < PROX_TOL_MM=1500mm.
- Root cause understood. Needs lines.json written from math.
- **Not yet written.** Bill needs to describe topology using TRBL before writing.

### station_thru_dip (track_formations/)
- Not touched this session. Old predecessors/successors schema. Needs rewrite.

## Naming Convention Established

Multi-CPU templates use suffix _N on segment names:
- gw_cp_in_0, gw_cp_in_lead_0, gw_uturn_0, gw_cp_out_lead_0, gw_cp_out_0
- User (model author) assigns 0/1 via CPU component instance name (cpu_0, cpu_1).
- Noelle reads instance name suffix and propagates to segment names.
- **Noelle code change required** — current code matches exact segment names.

## Key Principle — Math Over Scan

TFTS: process/inbox/20260527T025100-tfts.md
README: readmes/jpods-path-geometry.md

For fixed-geometry structures: lines.json is a mathematical declaration, not a scan output.
gw_uturn = pi x 1750mm = 5497.8mm. Always.

## Open Tasks (Priority Order)

1. Apply gw_* tags to station_line_end geometry
2. Write JPods_station_parking/lines.json (topology ready)
3. Write traffic_circle7/lines.json (need Bill's TRBL topology description)
4. Bill verify cpu/cps coordinates
5. Noelle code: handle _N suffix in multi-CPU segment names
6. station_thru_dip schema conversion

## WhatIf

C-W22-6 through C-W22-9 posted to readmes/wisdom/whatif-weekly/2026-W22.md.

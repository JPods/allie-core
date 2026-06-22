# Handoff — 2026-06-22

## Where We Are

v2 rewrite complete. 3+circle network animating. Zero codearchive files in boot.rb.
All station tests passing. Domain authority enforced. Console Network Display working.

## TODO — Next Session

### Priority 1: Vehicles Display page
Sally has all the data (pods[], ps[], states). Console Vehicles tab needs to show:
- Pod list with station, slot, state (parked/traveling), destination
- Real-time updates during animation
- Trip detail on click
Wire Sally's data to the existing console HTML vehicle table.

### Priority 2: Fix 4 non-planar build segments
Connections s001↔s003 and s001↔s005 fail FollowMe extrude on long paths with Z change.
The rescue skips degenerate steps (beam has gaps). Real fix: pre-filter path to
reduce point density in flat sections, or reset floating-point accumulation at intervals.
Compare with old pipeline's output for same connections.

### Priority 3: Crew Health Check dashboard
Currently outputs to Ruby console only. Wire to console HTML — show agent status
panel visible to students. Each agent's checks + faults displayed.

### Priority 4: Console v2 rewrite (careful)
Bill wants to keep the current console. Any rework should be a duplicate window.
~90 old module references remaining (mostly stubs that work but return empty data).
Systematic replacement as features are needed.

## What Was Built This Session

### Codearchive Migration (13/13 complete)
| Codearchive | → v2 | Lines |
|---|---|---|
| jpod_connection_point.rb | compute/connection_point.rb | 72 |
| upright_extruder.rb | build/build_extrude.rb | 263 |
| jpod_path_builder.rb | build/build_path.rb | 398 |
| jpod_entities_builder.rb | build/build_entities.rb | 629 |
| jpod_network.rb | build/build_bezier.rb + build_helpers.rb + build.rb | 1861 |
| jpod_noelle_bridge.rb | absorbed into build.rb | 940 |
| jpod_network_editor.rb | network/network_editor.rb | 2520→120 |
| jpod_connect_tool.rb | tools/connect_tool.rb | 1628 |
| my_geom.rb, jpod_platform.rb, jpod_followme_tool.rb, jpod_path_json.rb, noelle.rb | removed (dead) | 9634 |

### Station Tests (station_tests.rb)
- Shuffle: runner departs, probes advance, runner returns to Sally-assigned slot
- Departure: sequential from ps_max, Sally enforces order, conveyor between
- Arrival: landing chain + Sally clips gw_platform to assigned slot
- Transit: CCW circle traversal

### Build Pipeline (build/)
- build_bezier.rb — Catmull-Rom C1 bezier, 50m control point cap
- build_path.rb — terrain following, grade limits, Gaussian smoothing
- build_extrude.rb — FollowMe upright extrusion with non-planar rescue
- build_entities.rb — beam draw, column/solar placement, ground_z_at
- build_helpers.rb — CP resolution using native SketchUp operators
- build.rb — orchestrator with station bounds fence, connection dedup

### Animation + Domain Authority
- Sally authorizes departure FIRST → Natalie routes → Nora executes
- Sally.advance_conveyor after each departure
- Random dispatch from highest_occupied_slot only
- Populate uses Sally.place_pod (Sally decides)

### Console
- Network Display: connections list visible, expandable Workflow Guide + CP/Waypoints help
- Trip Simulator: pick origin/dest, Sally authorizes, camera follows
- Populate toolbar wired
- vehicle_trip_rows returns real data
- Crew Health Check on toolbar + menu

### New Modules
- jpod_log.rb — :quiet/:normal/:detailed/:debug
- pod_helpers.rb — entity creation utilities
- jpod_guideway_compat.rb — class shim (JPodGuideway + JPodVehicleAnim)
- sally_compat.rb — JPods::Sally over SallyV2
- crew_health.rb — each agent checks their domain
- migration/ — manifest + README

### Physical Systems Plan
- readmes/physical-systems-improvement-plan.md — 50 items, 9 categories
- Section I: Device Intelligence (every processor learns)
- su-real comments on all 8 v2 modules
- Curve-radius speed cap, rich ezone logging, session summary output

## Scars

- Don't rewrite code you don't understand — study first
- class vs module — check before defining (JPodGuideway is a class)
- main.rb had its own load list — one authority (boot.rb), always
- Sally's ps[]/pods[] are the ONLY truth — no copies
- Trip includes gw_platform — Sally clips to ps.N
- Sally authorizes departure FIRST, not after
- Bezier control points need distance cap (50m) on long connections
- FollowMe extrude fails on long paths — rescue each step
- Terrain raycast hits built geometry — use ground_z_at
- iframe timing — don't trigger tasks after showing a pane
- No memory → no cumulative experience → no wisdom

# JPods SketchUp Plugin — Feature List
**Last Updated:** 2026-06-14
**Purpose:** Planned features and enhancements, not yet implemented. Separate from the
ouch-list (safety/risk) and the gap-log (known defects). These are deliberate additions
to the student workflow tool.

---

## Format

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-nn | what | why it matters | file/tool | High / Med / Low | Idea / Specced / In Progress / Done |

---

## Guideway Geometry

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-01 | User-configurable minimum XY turn radius per model | `MIN_TURN_RADIUS` is currently a global constant (30 m). Campus and urban deployments need tighter turns; rural or high-speed corridors need looser ones. Exposed sharp horizontal bends where the constant was the wrong value for the site. | `jpod_constants.rb`, `jpod_path_builder.rb`, Network Editor Constraints panel | High | Idea |
| F-02 | User-configurable minimum Z (vertical) curve radius per model | `MIN_Z_CHANGE_DIAMETER` is currently a global constant. Fixing legacy 7.6 m waypoint Z values exposed that the vertical profile produces grade transitions that are too sharp when a significant vertical drop occurs over a short horizontal distance. Students need to be able to smooth this out without touching code. | `jpod_constants.rb`, `jpod_path_builder.rb`, Network Editor Constraints panel | High | Idea |
| F-03 | Per-connection XY and Z radius override | Beyond the model-wide default, individual connections (especially tight urban segments) may need their own radius settings. Would appear as fields in the Network Editor connection card. | `jpod_network_editor.rb`, `jpod_network.rb`, followme JSON schema | Medium | Idea |

| F-07 | Update station structure templates to place stubs at 4.6 m, and add `platform_in` guideway | Station .skp models (station_thru_lift, station_line_end, traffic_circle) were designed with stubs at 7.5 m (old clearance). Build now anchors guideway to terrain + CLEARANCE_HEIGHT = 4.6 m, so the physical stub geometry no longer aligns with the built beam. Students see a vertical gap at the station connection. Fix requires redesigning the .skp templates. Additionally: each station template needs a second guideway tagged `platform_in` (vehicles waiting to depart) alongside the existing `platform` guideway (loading/unloading). Current models have 1 platform per station; correct design has 2. The code already supports both tags — `PLATFORM_TAGS = %w[platform platform_in]` in `jpod_structure_tool.rb`. | Station template .skp files | High | Idea |

**Root cause note for F-01 / F-02 (2026-05-13):**
Both constants are already in `PRIMARY_CONSTRAINT_DEFAULTS` and exposed in the Network
Editor Constraints panel — but they are model-wide only and require a Build to take
effect. The user experience needed is: adjust the radius slider, see the green Bezier
preview update in real time in the Connect Guideways tool, then Build.

The sharp Z radius defect was revealed when the build pipeline was fixed to use
`terrain + CLEARANCE_HEIGHT` instead of the legacy marker Z (7.5 m stored in old
waypoint groups). Once the vertical drop was computed correctly, the grade transitions
at waypoints became visible as tight kinks.

---

## Connect Guideways Tool

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-04 | Live Bezier preview updates when Constraints panel sliders change | Currently the green preview only updates when the tool is re-activated or a waypoint is moved. If a student adjusts MIN_Z_CHANGE_DIAMETER in the Constraints panel, they should see the Bezier reshape immediately. | `jpod_connect_tool.rb`, `jpod_network_editor.rb` | Medium | Idea |
| F-05 | Waypoint elevation readout in status bar | When placing or dragging a waypoint, show the current terrain Z and the resulting guideway Z (terrain + CLEARANCE_HEIGHT) in the status bar so students understand what height the beam will be at that point. | `jpod_connect_tool.rb` | Low | Idea |
| F-10 | Guideway Connect Tool — select two stubs, extrude solid connection | Arc-to-line joins in SketchUp leave a 49–63 mm gap at the junction (SketchUp connects arc to straight at different reference points). Current workaround: Proof Lines accepts delta < 75 mm as OK. Proper fix: user selects two guideway stub endpoints, tool extrudes a connecting solid with a clean tangent join — same pattern as ene_railroad. Eliminates the arc-join gap at source; Proof Lines can revert to strict tolerance. | `jpod_connect_tool.rb`, new `jpod_guideway_connect_tool.rb` | High | Idea |

**Design notes for F-10 (2026-06-06):**
- Select mode: user clicks two `gw_cp_in_*` or `gw_cp_out_*` stub faces in sequence.
- Tool reads the outward tangent vector from each selected stub (same `cap_pt` / `vector_in` datum used by CP detection — Axiom 10).
- Extrudes a connecting solid using FollowMe along a Hermite-splined centerline between the two tangent-aligned endpoints. Same Bezier math as `bezier_pts_via` in `jpod_connect_tool.rb`.
- Result: a single solid component tagged with the correct `gw_seg_*` tag; no arc-to-line join; Proof Lines delta ≈ 0.
- Interim mitigation: Proof Lines OK threshold raised to 75 mm (was 50 mm) — clears the 63 mm arc-join WARN entries while F-10 is pending.

---

## Network Editor

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-06 | Per-connection grade profile graph | Show a small elevation cross-section in the connection card: terrain line, grade-limit envelope, and beam Z line. Helps students identify where columns will be tall or where the grade is at its limit. | `jpod_network_editor.rb` | Medium | Idea |

---

## Console — Trip Analytics

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-09 | JPods Console trip-category graph | Bar or pie chart of trips by mission: `passenger`, `dead_head`, `station_loop`, `rebalance` (graphed) + `shuffle` count displayed separately. The `passenger:dead_head` ratio is the primary network health signal — high dead_head means stations are in the wrong places or demand is asymmetric. Valuable for both simulation and real network design: guides station placement, platform count, and connection sizing before construction. Shuffle excluded from graph — too frequent on busy networks (outnumbers passenger trips 2:1+), would collapse the signal into noise. | `jpod_console.rb` | High | Idea |

**Design notes for F-09 (2026-05-16):**
- Read mission field from all trip.json files in the trips/ directory.
- Aggregate counts by mission. Display `passenger`, `dead_head`, `station_loop`, `rebalance` on graph.
- Show `shuffle` count as a plain number below the graph: "Shuffle moves: N".
- Update live during animation — poll every 2–3 seconds or hook into Natalie trip-write events.
- Schema: `readmes/sketchup/jpods-trip-schema.md`.

## Animation — Parking

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-08 | Parking guideway animation — enter, lower, back out | Parking guideways are currently excluded from routing (status='internal' in followme). When a vehicle is dispatched to park: (1) it travels the parking guideway to the end, (2) lowers vertically from beam height (4.6 m) to ground level, (3) backs out in reverse along the same guideway to return to the mainline. Two spaces per parking guideway end — vehicles park sequentially. | `jpod_animator.rb`, `jpod_vehicle_runtime.rb`, `natalie.rb` | Medium | Idea |

**Design notes for F-08 (2026-05-14):**
- Vehicles back out — no separate exit guideway needed. Reverse the feature sequence and animate the vehicle component backward along the bezier path.
- Vertical descent/ascent: linear Z interpolation on the vehicle transform matrix from 4.6 m to `Terrain.ground_z_at(parking_end_xy)`. ~30 lines of Ruby.
- Two spaces: sequential. Pod 1 parks at the far end (lowers), pod 2 parks at the near end (lowers). On departure, reverse order: pod 2 raises and backs out first, then pod 1.
- Parking guideways remain excluded from `Natalie.route()` BFS — they are dispatched only by explicit Natalie parking commands, never discovered through path search.
- Dependency: parking guideways must have a correctly-tagged internal connection in the followme so Natalie can look them up by station ID.


---

## Speed & Collision Avoidance

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-EZ-01 | Natalie exclusive zone (EZ) protocol | Natalie has no inter-vehicle safety mechanism at intersections. The correct design: Natalie creates EZ objects in `network.json` at compute time, padded by math (vehicle_length + personal_space), intersection geometry, and accumulated experience. Before dispatching a junction maneuver, Natalie checks whether any Nora is inside or approaching the EZ within the safety window; if so, she holds the trailing Nora. After each grant, she records the observed clearance in `ez_experience.json` (maintained by Allie). Over runs, the EZ tightens from experience but never loosens below the math floor. Reference: `readmes/sketchup/speed.md` — Exclusive Zones section. | `natalie.rb`, `network.json`, `~/Allie/process/ez_experience.json` | High | Idea |
| F-SP-01 | Per-track g-limit speed enforcement | Current SU simulator uses a single `speed_ms` (8.3 m/s) for all tracks. The 3.5 m U-turn centerline (r = 1.75 m) has a physical limit of ~2.1 m/s at 0.25g. Implementation: (1) add `lateral_g_limit` to `defaults.json`; (2) Noelle computes `speed_limit_ms` per track from each track's minimum arc radius and stores it in `lines.computed.json`; (3) Natalie issues per-segment `authorized_speed_ms` in trip plans rather than a single trip-wide value; (4) Nora enforces per-segment speed in the animator. Physical Noras already enforce this via accelerometers — SU simulator does not need to replicate hardware dynamics, but per-segment authorization gives Natalie correct data for spacing calculations. Reference: `readmes/sketchup/speed.md`, `jpod_constants.rb::curve_speed_limit_mps`. | `defaults.json`, `noelle.rb`, `natalie.rb`, `jpod_vehicle_anim.rb`, `jpod_constants.rb` | Medium | Idea |
| F-NAT-01 | Natalie inter-Nora intersection pre-clearance and personal-space enforcement | Two gaps in the SU simulator: (1) **Intersection conflict** — Noras on converging tracks can enter a CP junction simultaneously. Current gap regulation (`MIN_SPACING_IN`) fires on the same track only; it does not check cross-track merges. Natalie needs to hold a Nora at the approach to a CP until the junction is clear. (2) **Personal space cross-track** — a Nora about to merge into a track occupied near the merge point is not detected until it is on the track and the gap fires. Fix: Natalie pre-checks occupancy of the target track within `min_spacing_m` of the merge point before dispatching the junction maneuver. Physical deployment handles this via ezone pre-clearance protocol (already in `readmes/22-jpods-control-system.md`). The SU simulator needs an equivalent software ezone. | `jpod_vehicle_anim.rb`, `natalie.rb`, `jpod_vehicle_anim.rb` | High | Idea |

**Design notes (added 2026-06-20):**

- F-EZ-01 is the physical system's primary inter-vehicle safety mechanism. EZ objects are richer than a simple hold-flag — they carry geometry, padding math, experience, and notes. Each EZ is a living object that Natalie updates after every run. Allie holds `ez_experience.json` so EZ knowledge survives plugin reloads and power cycles.
- F-EZ-01 and F-NAT-01 are related but distinct. F-NAT-01 is the SU simulator's software equivalent (software ezone). F-EZ-01 is the physical system's full EZ protocol with experience accumulation. Both are needed.
- F-SP-01 does not change the SU animation visually — pods will still appear to run U-turns at full speed in the display. The value is that Natalie gets correct authorized speeds for spacing math and the trip report `actual_ms` vs `authorized_ms` ratio becomes meaningful on per-track basis.
- Physical Noras use accelerometers for g-limit enforcement — SU does not need to replicate hardware dynamics. The simulator's job is to validate geometry and routing, not vehicle physics.
- Full speed and EZ architecture: `readmes/sketchup/speed.md`.

---

## Console — Unit Tests

**Design principle (Rule 10, su_jpods/CLAUDE.md):** One behavior. One unit. Pass/fail
unambiguous. Each agent gets its own isolated test before wiring into network animation.
Populate is setup (not a test). Start Animation is the integration check — run last.

| # | Feature | Why | Domain | Priority | Status |
|---|---------|-----|--------|----------|--------|
| F-UT-01 | Route unit test button | Test Natalie in isolation: place two pods at two stations, dispatch one trip, verify it arrives at the correct destination with correct path. Currently the only way to test routing is Start Animation (full network integration) — a single Natalie bug produces a confusing multi-agent failure. Isolated route test gives a binary result for one routing decision. | `jpod_console.rb`, `jpod_vehicle_anim.rb` | High | Idea |
| F-UT-02 | Hold Loop unit test button | Test Nora + Sally hold loop: place one pod at a station with a hold_loop formation, dispatch it for N loops, verify it returns and parks at psmax. Tests the loop-count-down, hl_from_platform → hl_loop → hl_to_platform sequence, and Sally's slot assignment on return — all isolated from routing and other stations. | `jpod_console.rb`, `jpod_sally.rb`, `jpod_vehicle_anim.rb` | High | Idea |
| F-UT-03 | CP Handoff unit test button | Test Nora through a single CP transition: place one pod on an approach track, dispatch it through one CP, verify the maneuver completes with no position jump and correct exit track selection. Tests the cp_center synthesis, inbound/outbound arc matching, and Z continuity in one isolated pass. Eliminates guessing whether a Z glitch at a CP is Nora, Natalie, or the build pipeline. | `jpod_console.rb`, `jpod_vehicle_anim.rb` | Medium | Idea |

**Design notes (added 2026-06-14):**

- Each unit test button gets its own `cmd_ut_route`, `cmd_ut_hold_loop`, `cmd_ut_cp_handoff` callback in `jpod_console.rb`.
- Each test is **self-setting-up**: it places exactly the pods it needs, runs the behavior, reports pass/fail in the console output panel, then cleans up (erases test pods). The model state before and after is identical.
- Pass/fail criteria are explicit numbers (not visual): trip count, final slot number, final position distance from expected ≤ threshold.
- Results feed a run log: `process/inbox/YYYYMMDDTHHMMSS-ut-result.json` — one file per test run. Allie harvests these nightly for regression tracking.

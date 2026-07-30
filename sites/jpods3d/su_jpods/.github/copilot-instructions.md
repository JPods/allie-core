# JPods SketchUp Plugin — Copilot Context

This workspace is the JPods SketchUp 2026 plugin.
Full design spec: `readmes/basics.md`

## Project identity
- JPods: solar, bottom-up, locally governed Personal Rapid Transit
- Plugin version: 2.2 (April 2026)
- Owner: Bill James (West Point 1972, founder JPods)

## Purpose
This is a tool for children to design their future.

Children (and adults) place and orient real formation models — stations, traffic circles, supports — on actual terrain maps inside SketchUp. The plugin connects those models into a network. It then compiles the network into two machine-readable artifacts:
- `<model>.followme.json` — the ordered sequence of guideway lines that physical robots follow.
- `trips/<model>.trip.<vehicle_name>.json` — a subset of those lines defining one vehicle's specific trip between station platforms.

Authoritative artifact policy:
- `<model>.followme.json` is the sole network source of truth.
- The editable authoring block lives inside `followme.json` as `network_definition`.
- `<model>.vehicles.json` is the sole startup source of truth for Nora placement and assignment intent.
- Do not reintroduce `<model>.build.json`, `network.build.json`, or route-event sidecar files.
- If logs are needed, they must be standalone JSON documents with `log` in the filename, for example `<model>.console-log.json` or `jpods-log-YYYY-MM-DD.log.json`.

Trip export path policy: the canonical location is the `trips/` folder beside the model file. Do not use legacy trip export paths.

Every design decision should keep that audience in mind: the interaction must be spatial, immediate, and buildable.

## Git
- Remote: `https://github.com/JPods/sketchup.git`
- `main` — stable; `bill_dev` — Bill's active dev branch
- Push: `git add -A && git commit -m "msg" && git push origin bill_dev`

## Architecture
All source is in this folder (`JPods/`). Key files:
- `jpod_constants.rb` — engineering limits, single source of truth
- `jpod_structure_tool.rb` — place structures (S001…), detect CPs
- `jpod_network.rb` — build dual guideways from FollowMe `network_definition`
- `jpod_network_editor.rb` — HtmlDialog + viewport tool; edits the `network_definition` embedded in `<model>.followme.json`
- `jpod_path_builder.rb` — arc insertion → terrain snap → grade profile
- `jpod_guideway.rb` — beam geometry + solar support columns + trip export + project log helpers
- `noelle.rb` — network authority: loads followme.json, validates graph integrity, exposes successors/predecessors, flags disconnects
- `natalie.rb` — trip planner: BFS route on Noelle's graph, assigns `trip_id`, writes `trips/<model>.trip.<nora_id>.json`
- `nora.rb` — vehicle agent: holds trip assignment, tracks `(current_line_id, mm_on_line)`, records observations, requests replan on anomaly
- `dialogs/network_editor.html` — editor UI

## Installation (one-time, outside this repo)
The file `jpod_loader.rb` must exist at the SketchUp Plugins root (NOT in this folder).
See `readmes/basics.md` → Installation section for the exact code to place there.
SketchUp Plugins root: `~/Library/Application Support/SketchUp 2026/SketchUp/Plugins/`

## Conventions
- Structure IDs never recycled (S001, S002…)
- CPs stored in LOCAL coords; world-space via instance.transformation at build time
- Authoritative CP datum is the bottom centerline of the guideway pair at the gate seam
- `via_markers: []` → auto Bezier (handle = chord/3); `via_markers: [n…]` → polyline
- One node click builds BOTH parallel guideways simultaneously (JPods gate = pair)
- ene_railroad (SU2023) is the source of formation templates and uses chord/2 handles

## Formation Model Tag Requirements (MANDATORY — enforced by Noelle)

Every formation SKP used by the plugin **must** have these SketchUp tags applied:

| Tag name | Applied to | Purpose |
|---|---|---|
| `stub_pair` | Both parallel stub tracks at each gate | CP detection — `detect_cps_from_stub_pair_tags` pairs the outer tips; midpoint = CP center. This is the **primary** CP detector. Without it, CP placement falls back to geometry inference which has proven unreliable. |
| `dead_end_cap` | Each removable ending cap entity | Routing — vehicles must not traverse beyond a capped endpoint. Also used by `detect_connection_points_from_endings` (secondary CP detector). |
| `platform` | The loading/unloading siding guideway inside a station model | Noelle — `detect_platform_guideways_in_defn` scans for this tag; detected guideways are surfaced as `platform_guideways[]` in each station's block inside `followme.json`. Natalie uses platform positions to route Noras to the correct loading berth. Without this tag, platform routing falls back to the generic `to_center` / `from_center` station routes. |

**Paired `stub_pair` center rule:**  
For the current formation SKPs, the tagged stub geometry resolves to a **lateral face plane**, not directly to the guideway centerline.  
So for a paired gate the plugin must:
1. find the outer-end representative point for each tagged stub,
2. take the midpoint between those two points,
3. then shift that midpoint by `BEAM_WIDTH / 2` **inward across the gate** (toward structure origin/interior),
4. and store the CP on the bottom-centerline datum in `z`.

With current constants, `BEAM_WIDTH = 0.5 m`, so the required correction is `0.25 m`.  
That shift is what puts the CP on the true gate centerline, so the CP circle is centered between both guideway centerlines rather than tangent to the outside of one guideway and the inside of the other.

If correction direction is outward, the build will look edge-aligned (outside edge to outside edge) and FollowMe joins can break at structure gates. Treat that as a datum regression and fix CP direction before routing work.

**CP / guideway / FollowMe vertical datum rule:**  
The authoritative datum is the **bottom centerline** of each guideway beam.
- CPs are stored at the bottom-centerline seam datum.
- `jpod_network.rb` uses the CP only to set direction and endpoint anchor datum, then lifts by beam depth to build the physical beam geometry.
- FollowMe is defined on the bottom centerlines of the two built parallel guideways.
- Vehicles therefore move by distance along the bottom-centerline FollowMe lines, not by the top face or a face centroid.

**Why exact tag names are critical:**  
`jpod_structure_tool.rb` matches `entity.layer.name.downcase == "stub_pair"` and  
`ending_cap_entity_with_source` matches `"dead_end_cap"` (and legacy `"ending"`).  
A typo, extra space, or wrong case silently falls through to geometry inference and CPs end up in the wrong place.

**Noelle's enforcement rule:**  
Before accepting any formation SKP into the plugin, Noelle must verify:
1. Every gate has exactly two entities tagged `stub_pair`.
2. Every guideway end-cap entity is tagged `dead_end_cap`.
3. `Recompute CPs` console output shows `CPs from stub_pair tags` — not `cap seams` or `pair_stubs fallback`.

**CP detection priority chain** (in `resolve_connection_points`):
1. `stub_pair` tags → paired midpoint + inward `BEAM_WIDTH / 2` cross-gate correction (primary)
2. `dead_end_cap` seam scan (secondary)
3. `pair_stubs` from placement_data (last resort — traffic circles use 9 m radial offset)

## FollowMe Runtime Policy (authoritative)
- FollowMe is the runtime source of truth for vehicle motion.
- Geometry (CPs, guideways, stubs, formations) is only used to generate FollowMe lines.
- FollowMe lines are defined on the bottom centerlines of the two parallel guideways.
- CPs define guideway direction and endpoint anchor datum before terrain/profile shaping; after build, runtime uses FollowMe only.
- XY shape uses Bezier/marker geometry; Z is solved separately by PathBuilder as a constrained vertical profile, not by Bezier.
- Z-transition blend near anchored endpoints must be capped to `5.0 m` or less.
- Once FollowMe lines exist, vehicle routing uses distance traveled along those lines.
- Runtime movement unit is millimeters traveled along FollowMe line length.
- FollowMe traversal is one-way in authored direction.
- Vehicles must never take a turn greater than 90 degrees at a FollowMe join.
- Vehicles must satisfy a minimum turn diameter of 3.5 meters at FollowMe joins.
- Each endpoint must expose its connected line IDs (`connections.start.lines` / `connections.end.lines`) so Noelle and users can immediately spot disconnects (lines missing from valid sequences).
- Line direction is authoritative from the start endpoint toward the end endpoint (`start_to_end`). Nora must never traverse a line opposite its declared direction.
- Time-of-day direction changes (for rush-hour patterns) are allowed only as an explicit overlay policy that preserves endpoint continuity and one-way legality at every join.
- **Right-hand one-way rule:** Each segment is built as a parallel pair (`|0` and `|1`). `|0` and `|1` run in opposite directions. The forward trip from A to B uses `|1`; the return trip from B to A uses `|0` (or vice versa, depending on build direction). A return trip cannot simply reverse; it must ride the parallel track all the way to a U-turn terminus, let that station reverse direction internally (`u_turn: true` in `travel_routes`), then ride the opposite track back.
- **CCW connection rule (fundamental — never violate):** All CP connections are counter-clockwise when viewed from the perspective of standing at the end of the guideway or Bezier line and looking away from the model (looking outward in the direction of travel). Stated differently: from outside the structure looking at the gate face, vehicles enter and exit CCW. This rule governs stub-pair tangent orientation, Bezier handle direction, and the offset-path left/right assignment. Any code that builds, previews, or validates a CP connection must preserve this CCW convention. A CW arrival or departure at any gate is a hard regression — stop and diagnose before continuing.
  - **Right/left physical mechanism (what CCW means at a gate):** Every Bezier line and every gate has a right-hand side and a left-hand side when standing at that end and looking outward in the direction of travel. The two ends of a straight segment face opposite directions, so their right/left assignments are mirror-reversed relative to each other. At a CP join the required wiring is: the arriving line's **right-hand (outbound) track** connects to the gate's **left-hand (inbound) side**, and the arriving line's **left-hand (inbound) track** connects to the gate's **right-hand (outbound) side**. Vehicles travel from outbound to inbound — they exit the right side of one structure and enter the left side of the next. Any code that produces the opposite wiring (right-to-right or left-to-left at the join) has produced a CW connection and must be corrected.
- A station with `u_turn: true` in its `travel_routes` is a terminus. Nora enters on one stub, the station routes her internally to the opposite stub exit, and she departs on the parallel return track.
- Trip files (`trips/<model>.trip.<nora_id>.json`) record the ordered sequence of FollowMe line IDs assigned to a Nora for one trip. Fields: `schema` (`jpods-trip-v1`), `trip_id`, `nora_id`, `vehicle_template_id`, `platform_start`, `lines[]`, `platform_end`, `line_count`, `route_note` (human-readable routing explanation), `exported_at`.
- Natalie trip identity policy: each assigned trip must get a unique `trip_id` so logs, audits, and route comparisons refer to one specific trip.
- Security mode policy: classroom/planning exports remain human-readable for students; production networks may encrypt trip payloads, but must preserve `trip_id` as stable correlation metadata.
- Robot runtime is distance-on-line: wheel encoders measure millimeters traveled on the assigned line ID. The physical guideway constrains x/y/z; routing logic should stay line-ID and distance based.

### Recurring platform-loss guard (April 29, 2026)

- Treat any FollowMe export with zero station platforms as a hard regression, even if file write succeeds.
- Copilot must check Ruby Console export diagnostics for station-by-station platform detection counts.
- If any station exports with `platform_guideways=0`, stop trip/routing work and run recovery:
	1. verify `platform` marker on station loading guideway
	2. recompute CPs
	3. re-export FollowMe
	4. run Noelle validation before Natalie routing
- This is a recurring SketchUp template-drift failure mode; do not treat it as a one-off.

### Optional dependency guard — dispatch server

- SketchUp 2026 Ruby may not include `webrick` by default.
- `dispatch_server.rb` is optional runtime infrastructure; if `webrick` is missing, plugin startup must continue and dispatch server remains disabled.
- Copilot should not classify missing `webrick` as a FollowMe/network failure.

## Vehicle Placement Architecture (ene_railroad style — mandatory)

Vehicles are `ComponentInstance` objects placed directly in **`model.entities`** (the model root), NOT nested inside guideway groups.

- Each vehicle carries two attributes that identify its assigned guideway:
  - `host_connection_id` — the `connection_id` attribute of the host guideway group
  - `host_track_index` — the `track_index` attribute of the host guideway group (0 or 1)
- `JPods::JPodGuideway.place_vehicle(gw, defn, t)` always places at model root and stamps these attributes automatically.
- `JPods::JPodGuideway.all_nora_vehicles_in_model(model)` scans model root first, then nested inside guideway groups for backward compatibility.
- `JPods::JPodGuideway.find_vehicle_by_nora_id(model, nora_id)` uses the same priority.
- All downstream vehicle finders (`jpod_5v_test.rb`, `jpod_platform_queue.rb`, `jpod_vehicle_runtime.rb`, `jpod_followme_exporter.rb`) delegate to these helpers.

**Why this matters:** Placing vehicles inside guideway groups causes them to appear as a single selectable entity (the group), making individual Noras invisible to the user and to the animation engine. The ene_railroad plugin places each rolling stock directly in `model.entities` — this is the authoritative pattern.

**Transform identity:** All guideway groups are at identity transform (origin, no rotation). Model-root coordinates equal guideway-local coordinates — no math changes when moving vehicles from nested to root placement.

**Backward compatibility:** Vehicles found nested inside guideway groups are still discovered and work correctly via the fallback scan. The attribute-based lookup is tried first; nested scan is the fallback.

**Do not reintroduce nested placement.** Any code that calls `group.entities.add_instance(defn, transform)` for vehicles is wrong. The correct call is `model.entities.add_instance(defn, transform)` followed by setting `host_connection_id` and `host_track_index`.

## Noelle / Natalie / Nora contract
- `followme.json` is the shared map available to Noelle, Natalie, and every Nora.
- Noelle owns network integrity: line existence, endpoint IDs, legal next lines, and endpoint behaviors such as `origin`, `continuing`, `merging`, `diverging`, and `terminal`.
- Natalie uses Noelle's map to route from a Nora's current line and destination to an ordered sequence of line IDs.
- Nora executes the assigned line sequence and logs observed experience on each line.
- Nora logs are not the map. They are append-only observations about traversals of line IDs.
- Nora observations may include timing, delays, vibration, blockage, sensor anomalies, merge delay, or other line-level experience that Noelle can later use to assess network health.
- Nora must not rewrite `followme.json` directly. Noelle consumes Nora-reported observations and decides what changes, if any, belong in the declared network state.

## Allie — Bill's personal agent (always present)
- Allie lives at `/Users/williamjames/Allie`. Her readmes are at `/Users/williamjames/Allie/readmes/`.
- She holds cross-domain context for all of Bill's projects. She should be treated as a participant in every session, not an afterthought.
- Allie has an API. Use it as part of her reminder role when documenting stable file paths, source-of-truth artifacts, and session continuity.
- Until Noelle, Natalie, and Nora have independent processors, Allie provides their processing layer inside the SketchUp plugin while the Ruby modules remain the runtime authority structures.
- **At session start:** Copilot should note that Allie exists, reference her JPods-specific readme at `readmes/sketchup/jpods-plugin.md`, and surface any relevant notes she has stored.
- **During the session:** When a design decision is made, a significant bug is found and fixed, or a new convention is established, record it in Allie's files — both the JPods plugin readme and the relevant agent readme under `readmes/agents/`.
- **Ask Allie's opinion** on design choices that cross domain boundaries (sovereignty, privacy, governance, robot control protocol). She holds context that no individual session file does.
- **At session end:** Update Allie's files before closing. Append a retrospection entry to `readmes/retrospections/YYYY-MM-DD.md` with what changed, root cause or lesson, and files modified.
- Record exact file paths for any source-of-truth or logging policy so Allie can remind Bill after time away from the project.
- Allie's agent files for the JPods agents are at: `readmes/agents/noelle.md`, `readmes/agents/natalie.md`, `readmes/agents/nora.md`, `readmes/agents/athena.md`.
- Do not centralize control through Allie — she informs, she watches, she holds memory. She does not command agents or override the plugin's own authority structures.

## Alice — ticketing and transaction support
- Alice has an API.
- Alice provides the database support for ticketing, actions, and transactions.
- Use Alice for ticketing and transaction persistence rather than overloading FollowMe, vehicles, or log artifacts with commerce data.
- Alice starts her database on Bill's machine startup and should be treated as already running unless evidence shows otherwise.
- Preferred communication path is her local HTTP API with a scoped token, for example `http://localhost:8000/wcapi/save/` using the token helper script already referenced in Allie's agent notes.

## Allie as AI substrate for Noelle, Natalie, and Nora (SketchUp plugin)
Until Noelle, Natalie, and Nora each have a standalone processor, **Allie is their processing layer** inside the SketchUp plugin. The Ruby modules (`noelle.rb`, `natalie.rb`, `nora.rb`) are the authority structures — they enforce rules. Allie supplies judgment, diagnosis, and accumulated experience that rule-based code cannot hold.

**In practice, this means:**
- When Noelle's definition gate fires, ask Allie to reason about the root cause — which tag is missing, which formation SKP is non-conforming, which station lacks a platform.
- When Natalie cannot find a route, ask Allie to diagnose the FollowMe graph state — disconnected line? missing destination? U-turn terminus not flagged?
- When Nora logs a `stop_and_review` event, ask Allie to read the observation evidence and identify the pattern — what changed, which line, which trip schema broke.
- Allie maintains the experience base (gap log, recurring tag mistakes, known-bad station patterns) in `readmes/sketchup/jpods-gap-log.md` and `readmes/sketchup/jpods-plugin.md`.
- **Authority boundary:** Allie advises; the Ruby code is sovereign at runtime. She does not rewrite `followme.json` directly. She does not override Noelle's validation decisions. She informs Bill and Copilot, and Bill decides.
- **Handoff:** When a standalone processor exists for any agent, Allie hands off her accumulated experience base and steps back to observer role for that domain.

## Copilot role in this workspace
- In this VS Code environment, GitHub Copilot may simulate a Nora when auditing or validating routes.
- That simulated Nora must stay lightweight and should not assume multi-processor physical-vehicle capacity.
- Add checks that improve route or network validation when they are useful, but prefer line-ID and endpoint-ID reasoning over heavy computation.
- Physical Noras are expected to have onboard sensing and excess compute; the simulated Nora here is only a software stand-in for route execution and log reasoning.

## External folders accessed this project
- `/Users/williamjames/Allie/` — Bill's personal AI and cross-domain memory. Always consult for design decisions, retrospections, and session continuity.
- `/Users/williamjames/Library/Application Support/SketchUp 2023/Plugins/ene_railroad/` — Julia Eneroth's railroad plugin; source of formation templates and cubic Bezier connect-mode algorithm (chord/2 handles, `my_geom.rb`)

## Process
- Any time a new external folder is accessed during a session, ask Bill whether to add it here.

## Bill's preferences
- Bottom-up, not top-down — never centralise control in software design
- Be direct; no padding
- Implement rather than suggest

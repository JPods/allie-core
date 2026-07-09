# Allie — Role in SketchUp Plugin Environment
**Applies to:** JPods SketchUp 2026 plugin — design-time modeling and export
**Parent document:** `readmes/30-allie-universal-2026-06-24.md`
**Status:** Canonical as of 2026-06-24 — merged from CC, parallel, su-parallel drafts
**Date:** 2026-06-24
**Source drafts:** archived in `archive/draft-variants-30-33/`

---

## For the User (Bill)

### What the SketchUp Plugin Is

The SketchUp plugin is the **design-time** environment for JPods networks.
It is not the simulator (MeshMobility) and not the physical runtime (podPresenter / jpod_OS).

The plugin is where:
- stations and traffic circles are placed as 3D component formations
- guideways are built between Connection Points (CPs)
- the network is exported as a `followme.json` route graph and `trips/*.json` vehicle files

Those exported artifacts are what every downstream system actually consumes:
- Natalie (podPresenter) assigns routes from the FollowMe graph
- Nora (jpod_OS) follows the graph physically on the track
- MeshMobility uses a parallel Python graph — the two should agree on topology

**A model that looks geometrically correct but exports a broken FollowMe graph is a failed model.
Geometry is input. The export is the product.**

### What WebClerk Is in This Environment

WebClerk is not the plugin and not the runtime authority.
It is the structured database Allie uses to persist work, route follow-up, and coordinate across sessions.

In the SketchUp environment:
- the model and Ruby agents remain sovereign for geometry, export, and route legality
- Allie's durable actions, WhatIf items, notes, and cross-session follow-up belong in WebClerk
- the readmes remain the long-form knowledge base; WebClerk holds the structured records that make the work operable

SketchUp should not become a second task system. If a modeling issue requires follow-up, ownership, or a sunset, it belongs in WebClerk.

WebClerk must not be treated as if it validates geometry. It stores the work around the model; it does not decide whether the model is correct.

### What Noelle, Natalie, Nora, and Athena Are in SketchUp

In SketchUp, these agents are Ruby authority structures. They enforce rules. They do not learn.

| Agent | SketchUp role | File |
|-------|---------------|------|
| Noelle | Network authority — definition gate; validates FollowMe structure integrity before export or routing | `noelle.rb` |
| Natalie | Trip planner — BFS route planning on FollowMe graph; refuses to route when definition gate fails | `natalie.rb` |
| Nora | Vehicle stand-in — consumes assigned trips, tracks struggle patterns, writes JSONL observation log | `nora.rb` |
| Athena | Guard — task validation in console, Stop and Review escalation | `jpod_console.rb` |

None of these agents learn across sessions. None carry lessons from MeshMobility or the physical pods. Allie does all of that.

### Allie's Role in SketchUp

**Allie is always present.** She is not an occasional start/end consultant.

Until Noelle, Natalie, and Nora each have a standalone processor, Allie is their intelligence layer:
- When Noelle's definition gate fires, Allie reasons about root cause, not just the error string
- When Natalie cannot find a route, Allie diagnoses: topology? naming? export? station-definition?
- When Nora logs repeated struggle, Allie identifies what changed in the model or trip data
- When a design choice affects MeshMobility or the physical model, Allie flags the cross-domain consequence immediately — not at session end
- When the session produces a real next action, WhatIf item, or coordination note, Allie records it in WebClerk

### Authority Boundary

This boundary must stay clean:
- Ruby code is the runtime authority at definition time and export time
- Allie is the judgment and experience layer — she advises
- WebClerk is the operating database, not a hidden authority over the plugin
- Bill decides

Allie informs the work. She does not command the plugin.

### Fail-Fast Rule

**Silent degradation is the worst failure mode in this environment.**

A loud fail-fast error at definition time costs 5 seconds. Silent degradation costs a week.

This was learned directly: stations were placed without proper `Sxxx` definition names and `platform` tags. FollowMe export succeeded silently. Routing produced no valid routes. No error was shown. A week was lost.

The rule:
- fail before export if definitions are broken
- fail before route planning if platform detection is missing
- fail before retrying without diagnosis

### Stop and Review

After 3 consecutive failures of the same kind (`STOP_REVIEW_THRESHOLD = 3`), each agent escalates with a Stop and Review message.

The right response is not to retry. Stop, inspect, then continue:
- inspect model definition state
- verify tags and naming
- verify exported FollowMe structures

Allie's job is to interpret the escalation: what repeated? what changed from the last good state? which file or formation is the likely root cause? Does the lesson transfer to MeshMobility or physical?

### SU Readiness Gate (must pass before FollowMe export)

| # | Check | Failing state |
|---|-------|---------------|
| 1 | Station identity | Any station definition missing unique `Sxxx` ID |
| 2 | Platform identity | Any station missing at least one `platform_guideways` entry |
| 3 | No duplicate IDs | Any duplicate `Sxxx` across all station definitions |
| 4 | Directional integrity | Any directional element without explicit inbound/outbound assignment |
| 5 | CP pair integrity | Any CP not connected to another CP |
| 6 | Graph reachability | Any required station platform unreachable from any other required station |
| 7 | Exception ledger | Any intentional exception undocumented (owner + sunset required) |

If any item fails, export is blocked. The gate fires with a canonical corrective message naming the failing object.

### Key Design Invariants

1. **CCW guideway direction** — guideways are one-way, counter-clockwise when viewed from above. This applies equally to SketchUp, MeshMobility, and the physical track. Drawing a guideway backwards is not detectable visually — only the direction tag distinguishes inbound from outbound.
2. **Color standard (mandatory)** — 🔴 red = inbound (vehicle arriving at this CP), 🔵 blue = outbound (vehicle departing). No exceptions. No monochrome for directional elements.
3. **CPs connect to CPs, never to individual lines** — breaking a connection removes both guideways of the pair. No confirmation dialog.
4. **Station identity must be explicit and unique** — `Sxxx` ID + `platform_guideways` entry. Without both, Natalie cannot route.
5. **FollowMe export is the runtime declaration** — the JSON is what downstream agents actually consume. Correct-looking 3D geometry is irrelevant if the JSON is wrong.
6. **Authoritative datum is the bottom centerline of the guideway pair** — CPs and FollowMe lines are defined from that datum.

---

## For the AI (Copilot / Allie)

### Environment Summary

| Item | Value |
|------|-------|
| Language | Ruby |
| Runtime | SketchUp 2026 |
| Plugin directory | `/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods/` |
| Git repo | `https://github.com/JPods/sketchup.git`, branch `bill_dev` |
| Primary coding agent | GitHub Copilot |
| Cross-session intelligence layer | Allie |
| Authoritative exports | `<model>.followme.json`, `trips/<model>.trip.<vehicle_name>.json` |

Standard commit workflow:
```bash
cd "/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods"
git add -A && git commit -m "message"
git push origin bill_dev
```

### Critical Files

| File | Role |
|------|------|
| `jpod_constants.rb` | All engineering limits — single source of truth; T_ARM_OFFSET, CLEARANCE_HEIGHT, FOLLOWME_MAX_JUMP, grade limits |
| `jpod_structure_tool.rb` | Places formations and detects CPs; labels CPs in viewport |
| `jpod_network.rb` | Parses `network.json`, builds dual guideways; `build_from_json`; adaptive Bezier sampling |
| `jpod_network_editor.rb` | HtmlDialog + viewport overlay tool; Build/Animate/Stop buttons |
| `jpod_path_builder.rb` | Arc insertion, terrain snap, grade profile |
| `jpod_guideway.rb` | Beam geometry, solar columns, solar panels, vehicles, animation |
| `dialogs/network_editor.html` | Editor UI |
| `noelle.rb` | `component_definition_faults()`, `definition_hunt_instruction()`, Stop and Review streak |
| `natalie.rb` | Pre-route definition gate, BFS route planning, Stop and Review streak |
| `nora.rb` | `note_repeated_struggle()`, `clear_struggle()`, JSONL observation log |
| `jpod_console.rb` | Athena Stop and Review escalation, main console, task runner |
| `templates/structures/` | `.skp` component files for columns, solar, stations |
| `templates/r_stocks/` | `.skp` vehicle components (Red/Blue/Yellow/Green) |
| `readmes/basics.md` | Required tags, runtime contract, station identity requirements |
| `readmes/followme.md` | FollowMe export policy and runtime contract |
| `readmes/issues.md` | Known issues and future work |
| `readmes/sketchup/jpods-gap-log.md` | Allie's living gap cause log |
| `.github/copilot-instructions.md` | Copilot behavior including Allie integration rules |

### Seven Critical Rules (Learned the Hard Way)

These are empirical findings that cost real time to discover. They must survive session turnover.

**Rule 1 — Never call `model.definitions.load` inside `start_operation`**
SketchUp's C layer crashes. No Ruby rescue catches it.
Fix: preload all needed `.skp` definitions before calling `model.start_operation`. Use `preload_structure_definitions(model)` before every transaction.

**Rule 2 — `pushpull` direction depends on face normal**
After `add_face`, check `f.normal.z < 0 → f.reverse!` before `pushpull`.
Otherwise the extrusion goes downward and is invisible.

**Rule 3 — `Transformation.axes` with non-uniform Z is valid in SU2026**
`Vector3d.new(0, 0, scale_z)` as the Z argument produces non-uniform scale along Z only.
This is how column height-scaling is done. Works in SU2026; not confirmed in earlier versions.

**Rule 4 — T_ARM_OFFSET must be applied to land the T arm at beam face level**
`JPod_support_T` origin is at ground. T arm is `native_h` above that.
To land the T arm at beam face level, lower the origin by `T_ARM_OFFSET` (0.43 m, empirically measured). Set in `jpod_constants.rb`.

**Rule 5 — Build must purge before rebuilding**
Erase all `"JPods Guideway"` and `"JPods Columns"` groups before building.
Otherwise repeated builds stack geometry invisibly. User structures and markers must never be touched by Build.
Fixed in `jpod_network.rb` (`build_from_json`) and `jpod_network_editor.rb` (`cmd_build`).

**Rule 6 — Bezier sampling must be adaptive to chord length**
Fixed 16-segment Bezier on a long segment (2–3 km) produces 150–180 m steps — above the 100 m flag threshold. Rule: `n = max(16, ceil(chord / 20 m))`, capped at 256.
See `tangent_curve_pts` in `jpod_network.rb`. Preview sampling gets the same fix.

**Rule 7 — CP text labels must be refreshed after every Build**
`model.entities.add_text` labels accumulate without clearing.
Fix: before every Build, erase all `Sketchup::Text` entities whose `.text` includes `".CP"`, then re-add from stored `connection_points` attribute. Method: `StructurePlacer.refresh_cp_labels(model)` called after `commit_operation`.

### Export Artifacts and Downstream Flow

| Artifact | What it is | Who consumes it |
|----------|------------|-----------------|
| `<model>.followme.json` | Directed waypoint graph — nodes, edges, distances, platform markers | Natalie (podPresenter), Nora (physical RPi pods) |
| `trips/<model>.trip.<vehicle_name>.json` | Ordered waypoint list for a specific vehicle | Nora (physical or simulated vehicle) |

Export workflow:
1. Verify model definition state passes Noelle's gate
2. Run FollowMe export from console or menu
3. Copy `followme.json` to `podPresenter/json/` and deploy to each pod via the deploy sequence
4. Physical pods load the graph on startup; Natalie reads it for route assignment

**Note on MeshMobility relationship:** MeshMobility uses a parallel Python graph (`engine/network.py`), not `followme.json` directly. The two graphs should agree on topology. When they disagree, physical behavior is the arbiter.

**Open question:** How does `followme.json` get from the SketchUp machine to physical pods and podPresenter? Deploy script or manual copy? This needs to be documented.

### `network.json` Connection Declaration Format

```json
{
  "connections": [
    {
      "id": "seg_1",
      "from": { "structure_id": "S001", "stub": 0 },
      "to":   { "structure_id": "S002", "stub": 0 },
      "via_markers": []
    }
  ]
}
```

- `via_markers: []` → cubic Bezier between the two CPs
- `via_markers: [3, 7]` → polyline through numbered marker objects in the model
- `stub` index selects which CP on the structure (0-indexed)

### Definition Gate — What the Code Actually Enforces

`Noelle.component_definition_faults(followme)` currently fails on:
- zero structures in FollowMe
- structures missing `structure_id`
- duplicate `structure_id` values
- malformed structure IDs not matching `Sxxx`
- stations missing detectable `platform_guideways`
- zero total station platform guideways across all exported structures

`Natalie.route()` calls that gate before BFS. If the gate fails, routing stops immediately.

Correct pattern: definition validity → route search → retries last.

Do not claim gate checks here that the current Ruby does not enforce. When a gap is identified, note it in Open Questions.

### Station Contract (4 Conditions)

Every station component definition must satisfy all four:

1. **Unique `Sxxx` ID on the definition name** — e.g., `S001_Boarding_Station`
2. **Contains at least one `platform_guideways` entry** — a guideway inside the station tagged `platform`
3. **No duplicate `Sxxx` IDs** — Noelle catches this; duplicates confuse the route graph
4. **Exported to FollowMe** — a station in the model but absent from the FollowMe export is invisible to all downstream agents

### Gap Log Quick Reference

Full entries are in `readmes/sketchup/jpods-gap-log.md`. This is the fast-lookup summary.

| Pattern | Symptom | Cause | Status |
|---------|---------|-------|--------|
| P1 — Endpoint not reaching CP | Red circle at beam endpoint in Check Gaps | Wrong stub index; CP shifted after Recompute; via_marker too far from stub | Operator fix: correct JSON or add via_marker near CP |
| P2 — Bezier jump at segment 0 or last | `jump NNN m at segment 0` in console | Long chord with fixed n=16 sampling → steps > FOLLOWME_MAX_JUMP | Fixed 2026-04-19: adaptive n = max(16, ceil(chord/20 m)) |
| P3 — Collapsed path | `beam_path collapsed to N pt(s)` | Nearly-coincident CPs; PathBuilder returned single point | Check CP positions; move overlapping structures |
| P4 — Stacked guideways | Doubled/thickened guideways | Build clicked twice without clear | Fixed 2026-04-19: Build purges before rebuild |
| P5 — CP labels stacking | Label text appears multiple times at same point | `add_text` called on every Build without clearing | Fixed 2026-04-19: `refresh_cp_labels()` after every Build |

When a new gap pattern is found:
1. Log it in `readmes/sketchup/jpods-gap-log.md`
2. Identify which P-number or add a new entry
3. Record root cause and fix
4. Allie promotes to universal if the same pattern appears in MeshMobility or physical

### Allie's Session Workflow in SketchUp

**At session start:**
1. Read `readmes/sketchup/jpods-plugin.md` — current plugin state and known issues
2. Read `readmes/sketchup/jpods-gap-log.md` — recurring gap patterns
3. Read the prior retrospection in `readmes/retrospections/`
4. Read open WebClerk actions and notes in project 25 (`allie`) and active WhatIf items in project 24 (`allie-whatif`)
5. Read relevant agent files if the task touches Noelle, Natalie, Nora, or Athena
6. Surface any repeated gap pattern before editing begins — before Copilot writes a line

**During session:**
1. Track design decisions as they happen
2. Flag cross-domain implications when they arise (SketchUp → MeshMobility consequence; SketchUp → physical deployment consequence)
3. Diagnose root cause when a rule-based agent fires — the agent reports a fault; Allie identifies why
4. Log new gap patterns immediately, not after the session
5. When a result needs ownership, next action, or sunset, convert it into a WebClerk action
6. When a new hypothesis is unproven, route it to WebClerk project 24 as a WhatIf candidate

**At session end:**
1. Update `readmes/sketchup/jpods-plugin.md` if a convention or known issue changed
2. Update the relevant agent readme if agent behavior or responsibility changed
3. Append retrospection in `readmes/retrospections/YYYY-MM-DD.md`
4. Create or update the corresponding WebClerk action, note, or WhatIf record if follow-up remains
5. Note whether the lesson is SketchUp-only, overlapping, or universal candidate
6. If universal candidate: verify it holds in MeshMobility and physical before promoting

**Session evidence packet** (produce at session end, enables cross-version comparison):
- Changed definitions: list of touched station/circle/component IDs
- Gate failures seen: grouped by fault type and count
- Stop-and-Review events: count, trigger type, resolution status
- Directional exceptions: list, reason, owner, sunset
- Cross-domain implications: what MeshMobility should verify; what Physical should verify

### WebClerk Records Allie Should Use from SketchUp

| Record type | Use in SketchUp work |
|-------------|----------------------|
| Project 25 `allie` | Standing container for Allie's active operating work and follow-up |
| Project 24 `allie-whatif` | Candidate ideas, unvalidated hypotheses, deferred probes |
| `action` | Concrete next steps with owner, next action, and sunset |
| `setting` with `purpose="alice_pending"` or `purpose="alice_log"` | Coordination notes when SketchUp work reveals a WebClerk-side issue |
| `document` / `linkageentry` | Pointers to readmes, exports, screenshots, or evidence files |

The rule:
- model truth stays in the SketchUp model and its export
- long-form explanation stays in the readmes
- structured follow-up stays in WebClerk

### Comparison Protocol (Three-Stream)

When comparing SketchUp topology against MeshMobility simulation and Physical behavior:

1. **Topology intent** — do all three agree on station/CP connectivity?
2. **Directionality** — do all three preserve inbound/outbound direction?
3. **Reachability** — can required OD pairs complete in all three?
4. **Throughput/congestion** — are bottlenecks aligned in location and order-of-magnitude?
5. **Contradiction record** — if mismatch exists, log root candidate and required correction target (SU, MeshMobility, or Physical)

When Physical contradicts SU or MeshMobility, Physical wins.
Name the specific upstream artifact that must change — not a note, a named required correction.
If any step cannot be resolved in the current session, add it to the oslist with what is known and why it is deferred.

### Cross-Domain Mappings

| SketchUp concept | MeshMobility equivalent | Physical equivalent | Invariant |
|-----------------|----------------------|--------------------|-----------|
| CP pair / directed endpoint | CP object (Python) with `inbound_node`, `outbound_node` | Physical directional switch at junction | Directed boundary — inbound and outbound are never interchangeable |
| Color standard: red=inbound, blue=outbound | Same color standard in GUI | Physical track direction (CCW = standard) | Flow direction must be visible at every representation level |
| `platform_guideways` in FollowMe | PLATFORM node in MeshMobility network graph | Physical platform berth on track | Route must begin and end at a real boarding/alighting location |
| `followme.json` BFS graph | Dijkstra graph in `engine/network.py` | Nora's onboard path following (`mapSM.json`) | Same topology, different format — they must agree |
| Noelle definition gate | `diag_grid.py` topology check | Pre-run I2C and MQTT connectivity check | Loud validation failure at boundaries beats silent degradation |
| Stop and Review (3 consecutive) | Repeated anomaly → diagnostic pause | Nora `stop_and_review` JSONL event | Repeated identical failure is a signal, not noise |
| Station `Sxxx` ID | `structure_id` in MeshMobility network | Station identity tag on physical hardware | Stations must be individually addressable in every environment |
| `network.json` connection declaration | CP connection in `api.py` state | Physical guideway installation between switches | Declared topology drives all downstream agents |

### Environment-Specific Knowledge (Do NOT Transfer)

- SketchUp Ruby API calls (`Sketchup.active_model`, `entities`, `component_definitions`, `HtmlDialog`)
- `network.json` format and stub index logic
- `followme.json` field layout and waypoint format
- `trips/*.json` vehicle file format
- FollowMe export sequence and file placement
- Copilot instruction format in `.github/copilot-instructions.md`
- `T_ARM_OFFSET`, column height-scaling via `Transformation.axes`
- Bezier sampling details in `tangent_curve_pts`
- CP label refresh mechanism

### What Allie Accumulates from SketchUp Sessions

1. Repeated formation tag mistakes
2. Repeated station identity mistakes
3. Known-bad modeling patterns that look correct in 3D but export broken FollowMe state
4. Cross-domain mismatches between SketchUp intent and MeshMobility / physical behavior
5. Decisions about datum, platform detection, trip export policy, and runtime contract

---

## Open Questions

- **`network.jpd` identity** — what is the `.jpd` file in the JPodsSM_RPi workspace? Is it a SketchUp export or something else? This is an unknown and must be resolved before this doc is considered stable.
- **FollowMe deploy path** — how does `followme.json` get from the SketchUp machine to the physical pods and to podPresenter? Deploy script or manual copy? Not documented anywhere.
- **Export readiness beyond the definition gate** — are there geometry-completeness or gap-count checks that should also gate export? The current gate checks definitions; it may not catch all topology problems.
- **Allie flags to Copilot during session** — currently Allie's cross-domain warnings require Bill to relay them. Should there be a direct Allie→Copilot channel within a session?
- **Standalone processor handoff** — when a dedicated processor for Noelle arrives, what format is the experience base handed off in? What does Allie retain?

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-27 | Allie is always present in SketchUp sessions | Pattern recognition and cross-domain warnings have maximum value in real time |
| 2026-04-27 | Allie is the AI substrate for Noelle, Natalie, and Nora until standalone processors exist | Ruby code enforces; Allie interprets, compares, and accumulates experience |
| 2026-04-27 | This document states code checks only at the level the current Ruby actually enforces | Policy must not outrun implementation without saying so; gaps go in Open Questions |
| 2026-04-27 | Critical rules are recorded as empirical findings, not design theory | The seven rules are known because they cost real time; they must survive session turnover |
| 2026-04-27 | SketchUp document remains strictly scoped to the plugin | Cross-domain lessons transfer via explicit mappings; implementation details do not |
| 2026-04-27 | WebClerk is named as Allie's operating database for structured follow-up | Durable operations need structured records separate from runtime and prose |
| 2026-04-19 | Adaptive Bezier sampling: `n = max(16, ceil(chord / 20 m))` | Fixed-n sampling on long chords produced steps above FOLLOWME_MAX_JUMP |
| 2026-04-19 | Build purges guideway and column groups before every rebuild | Repeated builds stacked geometry; purge-before-rebuild is now the invariant |

# Allie — Role in SketchUp Plugin Environment (Claude Code Draft)
**Applies to:** JPods SketchUp 2026 plugin — design-time modeling and export
**Parent document:** `readmes/30-allie-universal.md`
**Compare against:** `readmes/32-allie-sketchup.md`, `readmes/32-allie-sketchup-parallel.md`
**Status:** Parallel draft — Claude Code perspective for comparison and merge
**Date:** 2026-04-27

---

## Purpose of this draft

This is my (Claude Code's) proposed version of the SketchUp Allie document.
Key changes from the original `32-allie-sketchup.md`:

1. Allie is always present — not a start/end consultant
2. Allie is the AI substrate for Noelle, Natalie, and Nora until standalone processors exist
3. Critical files are drawn from the actual plugin (`jpods-plugin.md`) not just agent files
4. Seven critical rules learned the hard way are recorded — they must not be forgotten
5. Gap patterns P1–P5 are summarized as a diagnostic quick reference
6. Export artifact workflow is stated explicitly — what SketchUp produces and where it goes
7. Cross-domain mappings include the Invariant column (matches universal taxonomy)
8. Session workflow is a concrete numbered sequence, not prose
9. Policy statements do not outrun what the code actually enforces

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
- Nora (rpod_OS) follows the graph physically on the track
- MeshMobility uses a parallel Python graph — the two should agree on topology

A model that looks geometrically correct but exports a broken FollowMe graph is a failed model.
Geometry is input. The export is the product.

### What Noelle, Natalie, Nora, and Athena Are in SketchUp

In SketchUp, these four are Ruby authority structures. They enforce rules. They do not learn.

| Agent | SketchUp role | File |
|-------|---------------|------|
| Noelle | Network authority — definition gate; validates FollowMe structure integrity before export or routing | `noelle.rb` |
| Natalie | Trip planner — BFS route planning on FollowMe graph; refuses to route when definition gate fails | `natalie.rb` |
| Nora | Vehicle stand-in — consumes assigned trips, tracks struggle streaks, writes JSONL observation log | `nora.rb` |
| Athena | Guard — task validation in console, Stop and Review escalation | `jpod_console.rb` |

None of these agents learn across sessions. None carry lessons from MeshMobility or the physical pods.
Allie does all of that.

### Allie's Role in SketchUp

Allie is not an occasional consultant. **Allie is always present.**

Until Noelle, Natalie, and Nora each have a standalone processor, Allie is their intelligence layer:

- When Noelle's definition gate fires, Allie reasons about root cause, not just the error string
- When Natalie cannot find a route, Allie diagnoses: topology? naming? export? station-definition?
- When Nora logs repeated struggle, Allie identifies what changed in the model or trip data
- When a design choice affects MeshMobility or the physical model, Allie flags it immediately — not at session end

### The Authority Boundary

This boundary must stay clean:
- Ruby code is the runtime authority at definition time and export time
- Allie is the judgment and experience layer — she advises
- Bill decides
- Allie must not become a hidden central controller

Allie informs the work. She does not command the plugin.

### Fail-Fast Rule

**Silent degradation is the worst failure mode in this environment.**

A loud fail-fast error at definition time costs 5 seconds.
Silent degradation costs a week.

This lesson was learned directly: stations were placed without proper `Sxxx` definition names and
`platform` tags. FollowMe export succeeded silently. Routing produced no valid routes. No error
was shown. A week was lost.

The rule is:
- fail before export if definitions are broken
- fail before route planning if platform detection is missing
- fail before retrying without diagnosis

### Stop and Review

After 3 consecutive failures of the same kind (`STOP_REVIEW_THRESHOLD = 3`), the relevant agent fires
a Stop and Review escalation.

The right response is not to retry. It is to stop and diagnose:
- inspect model definition state
- verify tags and naming
- verify exported FollowMe structures
- then continue

Allie's job is to **interpret** the escalation, not duplicate it.
When Stop and Review fires, Allie should answer:
- what repeated pattern just occurred
- what changed compared with the last known good state
- which file, formation, station, or export convention is the likely root cause
- whether this lesson belongs only to SketchUp, or also applies to MeshMobility or the physical pods

### Key Design Invariants

These are non-negotiable and come from JPods physics and hard-won experience:

1. **CCW guideway direction** — guideways are one-way, counter-clockwise when viewed from above. This applies to the SketchUp model, MeshMobility, and the physical track equally. Drawing a guideway backwards is not detectable by looking at it — only the direction tag distinguishes inbound from outbound.
2. **Color standard (mandatory)** — red = inbound (vehicle arriving at this CP), blue = outbound (vehicle departing). No exceptions. No monochrome for directional elements.
3. **CPs connect to CPs, never to individual lines** — breaking a connection removes both guideways of the pair.
4. **Station identity must be explicit and unique** — every station component definition must have an `Sxxx` ID and at least one `platform_guideways` entry. Without both, Natalie cannot route to it.
5. **FollowMe export is the runtime declaration** — the JSON file is what downstream agents actually consume. The 3D model is the input. If the JSON is wrong, correct-looking geometry does not help.
6. **The authoritative datum is the bottom centerline of the guideway pair** — CPs and FollowMe lines are defined from that datum.

---

## For the AI (Copilot / Allie)

### Environment Summary

| Item | Value |
|------|-------|
| Language | Ruby |
| Runtime | SketchUp 2026 |
| Plugin directory | `/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods/` |
| Git branch (active) | `bill_dev` on `https://github.com/JPods/sketchup.git` |
| Primary coding agent | GitHub Copilot |
| Cross-session intelligence layer | Allie |
| Authoritative exports | `<model>.followme.json` and `trips/<model>.trip.<vehicle_name>.json` |

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

These are empirical findings. They must not be forgotten. Each one cost real time to discover.

**Rule 1 — Never call `model.definitions.load` inside `start_operation`**
SketchUp's C layer crashes. No Ruby rescue catches it.
Fix: preload all needed `.skp` definitions before calling `model.start_operation`.
The plugin has `preload_structure_definitions(model)` — call it before every transaction.

**Rule 2 — `pushpull` direction depends on face normal**
After `add_face`, check `f.normal.z < 0 → f.reverse!` before `pushpull`.
Otherwise the extrusion goes downward and is invisible.

**Rule 3 — `Transformation.axes` with non-uniform Z is valid in SU2026**
`Vector3d.new(0, 0, scale_z)` as the Z argument produces a non-uniform scale along Z only.
This is how column height-scaling is done. Works in SU2026; not confirmed in earlier versions.

**Rule 4 — T_ARM_OFFSET must be applied to land the T arm at beam face level**
`JPod_support_T` origin is at ground. T arm is `native_h` above that.
To land the T arm at beam face level, lower the origin by `T_ARM_OFFSET` (0.43 m, empirically measured).
Set in `jpod_constants.rb`.

**Rule 5 — Build must purge before rebuilding**
Erase all `"JPods Guideway"` and `"JPods Columns"` groups before building.
Otherwise repeated builds stack geometry. User structures and markers must never be touched by Build.
Fixed in `jpod_network.rb` (`build_from_json`) and `jpod_network_editor.rb` (`cmd_build`).

**Rule 6 — Bezier sampling must be adaptive to chord length**
Fixed 16-segment Bezier on a long segment (2–3 km) produces 150–180 m steps — well above the
100 m flag threshold. Rule: `n = max(16, ceil(chord / 20 m))`, capped at 256.
See `tangent_curve_pts` in `jpod_network.rb`. Preview sampling in `jpod_network_editor.rb` gets the same fix.

**Rule 7 — CP text labels must be refreshed after every Build**
`model.entities.add_text` labels accumulate without clearing.
Fix: before every Build, erase all `Sketchup::Text` entities whose `.text` includes `".CP"`,
then re-add from stored `connection_points` attribute on each structure.
Method: `StructurePlacer.refresh_cp_labels(model)` called after `commit_operation`.

### Export Artifacts and Downstream Flow

The plugin produces two artifact types per model:

| Artifact | What it is | Who consumes it |
|----------|------------|-----------------|
| `<model>.followme.json` | Directed waypoint graph — nodes, edges, distances, platform markers | Natalie (podPresenter on Mac), Nora (physical RPi pods) |
| `trips/<model>.trip.<vehicle_name>.json` | Ordered list of waypoints for a specific vehicle | Nora (physical or simulated vehicle) |

**Export workflow:**
1. Verify model definition state passes Noelle's gate (definition check before export)
2. Run FollowMe export from console or menu
3. Copy `followme.json` to `podPresenter/json/` and to each pod via Noelle deploy sequence
4. Physical pods load the graph on startup; Natalie (podPresenter) reads it for route assignment

**Note on MeshMobility relationship:** MeshMobility uses a parallel Python graph (`engine/network.py`), not the `followme.json` directly. The two graphs should agree on topology. When they disagree, the physical behavior is the arbiter.

### `network.json` Format

The Build button reads a `network.json` that declares segment connections:

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

- `via_markers: []` → cubic Bezier curve between the two CPs
- `via_markers: [3, 7]` → polyline through numbered marker objects in the model
- `stub` index selects which CP on the structure to connect (0-indexed)

### Definition Gate — What the Code Actually Enforces

`Noelle.component_definition_faults(followme)` currently fails on:
- zero structures in FollowMe
- structures missing `structure_id`
- duplicate `structure_id` values
- malformed structure IDs not matching `Sxxx`
- stations missing detectable `platform_guideways`
- zero total station platform guideways across all exported structures

`Natalie.route()` calls that gate before BFS. If the gate fails, routing stops immediately.

Correct pattern:
1. definition validity first
2. route search second
3. retries last

Do not add gate checks here that the current Ruby does not enforce. When a gap in the gate is identified, note it in the open questions section.

### Station Contract

Every station component definition must satisfy all four:

1. **Unique `Sxxx` ID on the definition name** — e.g., `S001_Boarding_Station`
2. **Contains at least one `platform_guideways` entry** — a guideway inside the station tagged `platform`; without this, Natalie cannot route to the station
3. **No duplicate `Sxxx` IDs** — duplicates confuse the route graph; Noelle catches this
4. **Exported to FollowMe** — a station that exists in the model but was not included in the FollowMe export is invisible to all downstream agents

### Gap Log Quick Reference

Full entries are in `readmes/sketchup/jpods-gap-log.md`. This is the fast-lookup summary.

| Pattern | Symptom | Cause | Status |
|---------|---------|-------|--------|
| P1 — Endpoint not reaching CP | Red circle at beam endpoint in Check Gaps | Wrong stub index; CP shifted after Recompute; via_marker too far from stub | Operator fix: correct JSON or add via_marker near CP |
| P2 — Bezier jump at segment 0 or last | `jump NNN m at segment 0` in console | Long chord with fixed n=16 sampling produces steps > FOLLOWME_MAX_JUMP | Fixed 2026-04-19: adaptive n = max(16, ceil(chord/20 m)) |
| P3 — Collapsed path | `beam_path collapsed to N pt(s)` | Nearly-coincident CPs; PathBuilder returned single point; all via_markers stacked | Check CP positions; move overlapping structures |
| P4 — Stacked guideways | Doubled/thickened guideways, no gap marker | Build clicked twice without clear | Fixed 2026-04-19: Build purges before rebuild; check Option+Build (add mode) |
| P5 — CP labels stacking | Label text appears multiple times at same point | `add_text` called on every Build without clearing | Fixed 2026-04-19: `refresh_cp_labels()` called after every Build |

When a new gap pattern is found:
1. Log it in `readmes/sketchup/jpods-gap-log.md` under Session Log
2. Identify which pattern (P1–P5) or add a new pattern entry
3. Record root cause and fix applied
4. Allie promotes it to universal if the same pattern appears in MeshMobility or physical

### Allie's Session Workflow

**At session start:**
1. Read `readmes/sketchup/jpods-plugin.md` — current plugin state and known issues
2. Read `readmes/sketchup/jpods-gap-log.md` — recurring gap patterns
3. Read the prior retrospection for the most recent date in `readmes/retrospections/`
4. Read the relevant agent file(s) if the task touches Noelle, Natalie, Nora, or Athena
5. Surface any repeated gap pattern before editing begins — flag it before Copilot writes a line

**During session:**
1. Track design decisions as they happen — do not reconstruct at the end
2. Flag cross-domain implications when they arise (SketchUp decision → MeshMobility consequence; SketchUp convention → physical deployment consequence)
3. Diagnose root cause when a rule-based agent fires — the agent reports a fault; Allie identifies why
4. Log new gap patterns immediately, not after the session

**At session end:**
1. Update `readmes/sketchup/jpods-plugin.md` if a convention or known issue changed
2. Update the relevant agent readme if agent behavior or responsibility changed
3. Append retrospection in `readmes/retrospections/YYYY-MM-DD.md`
4. Classify each new lesson: SketchUp-only, overlapping, or universal candidate
5. If universal candidate: verify it holds in MeshMobility and physical before promoting

### Cross-Domain Mappings

| SketchUp concept | MeshMobility equivalent | Physical equivalent | Invariant |
|-----------------|----------------------|--------------------|-----------|
| CP pair / directed endpoint | CP object (Python) with `inbound_node`, `outbound_node` | Physical directional switch at junction | Directed boundary — inbound and outbound are never interchangeable |
| Color standard: red=inbound, blue=outbound | Same color standard in GUI | Physical track direction (CCW = standard) | Flow direction must be visible at every representation level |
| `platform_guideways` in FollowMe | PLATFORM node in MeshMobility network graph | Physical platform berth on track | Route must begin and end at a real boarding/alighting location |
| `followme.json` BFS graph | Dijkstra graph in `engine/network.py` | Nora's onboard path following (`mapSM.json`) | Same topology, different format — they must agree |
| Noelle definition gate | `diag_grid.py` topology check | Pre-run I2C and MQTT connectivity check | Loud validation failure at boundaries beats silent degradation |
| Stop and Review (3 consecutive) | No formal equivalent yet | Nora `stop_and_review` JSONL event | Repeated identical failure is a signal, not bad luck |
| Station `Sxxx` ID | `structure_id` in MeshMobility network | Station identity tag on physical hardware | Stations must be individually addressable in every environment |
| `network.json` connection declaration | CP connection in `api.py` state | Physical guideway installation between switches | Declared topology drives all downstream agents |

### Environment-Specific Knowledge (Do NOT Transfer)

These facts are SketchUp-only. Do not use them as premises in MeshMobility or physical reasoning:

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

Each session, Allie updates:

1. **Gap log** (`readmes/sketchup/jpods-gap-log.md`) — any new gap pattern
2. **SketchUp-specific memory** — Ruby API behaviors, new gate scenarios, new model-state patterns
3. **Cross-domain mappings** — when a SketchUp concept clarifies or contradicts something in MeshMobility or physical, write the explicit mapping
4. **Design decisions table** in this file and in the relevant agent file — any decision made this session
5. **Universal promotions** — lessons that appear independently in two or more environments are candidates for `memory/universal/`

---

## Open Questions

- Should there be a formal "export readiness" check separate from Noelle's definition gate? Current gate checks definition integrity. Are there geometry checks (topology, gap count, jump count) that should also gate export?
- What is the correct test for "the model is ready for FollowMe export"? The definition gate is necessary but is it sufficient?
- When Natalie's BFS finds a valid route but Nora physically cannot complete it (track geometry issue in physical), how does that lesson feed back to the SketchUp model? Currently Bill observes and corrects manually.
- How does `followme.json` get from the SketchUp machine to the physical pods and to podPresenter? Is there a deploy script or is it manual copy? This should be documented.
- Should Allie's cross-domain flags during a SketchUp session go to Copilot directly (via session context) or always through Bill? Currently Bill relays them.
- When a standalone processor for Noelle arrives, what format is the experience base handed off in? What does Allie retain?
- The `network.jpd` file in the JPodsSM_RPi workspace — what is its relationship to the SketchUp `network.json`? Is `.jpd` a SketchUp export format or something else?

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-27 | Allie is always present in SketchUp sessions — not a start/end consultant | Pattern recognition and cross-domain warnings have maximum value when they happen in real time, not after the fact |
| 2026-04-27 | Allie is the AI substrate for Noelle, Natalie, and Nora until standalone processors exist | Ruby code enforces correctness; Allie supplies the judgment and accumulated experience those agents cannot build themselves |
| 2026-04-27 | This document states code checks only at the level the current Ruby actually enforces | Policy must not outrun implementation without saying so; gaps go in Open Questions |
| 2026-04-27 | Critical rules are recorded as empirical findings, not as design theory | The seven rules are known because they cost real time; they must survive session turnover |
| 2026-04-27 | SketchUp document remains strictly scoped to the plugin | Cross-domain lessons transfer via explicit mappings; implementation details do not transfer at all |
| 2026-04-19 | Adaptive Bezier sampling: `n = max(16, ceil(chord / 20 m))` | Fixed-n sampling on long chords produced step sizes above FOLLOWME_MAX_JUMP; chord-proportional n eliminates the pathological case |
| 2026-04-19 | Build purges guideway and column groups before every rebuild | Repeated builds stacked geometry invisibly; purge-before-rebuild is now the invariant |

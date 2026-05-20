# Allie — SketchUp Plugin Role and Knowledge Architecture (Merged)

**Applies to:** SketchUp 2026 JPods plugin
**Merge source:** 32-allie-sketchup.md + 32-allie-sketchup-CC.md + 32-allie-sketchup-su-parallel.md + 32-allie-sketchup-parallel.md
**Status:** Merged candidate — ready for Bill's review and rename to replace original
**Date:** 2026-04-27

---

> **One open decision for Bill before this replaces the original:**
>
> How present is Allie during a SketchUp session?
>
> - **CC draft position:** "Allie is always present — pattern recognition and cross-domain warnings have maximum value in real time."
> - **SU-parallel position:** "Required at start + end; optional but preferred at in-session checkpoints at decision boundaries."
>
> Both are defensible. One must be chosen. Mark your choice and the open decision closes.

---

## For the User (Bill)

### What the SketchUp Plugin Does

The plugin is the design-authoring environment. It declares topology intent:
- station identity and platform identity
- guideway direction and CP boundary orientation
- export graph integrity

The plugin is not runtime truth.
Physical behavior is truth.
Route-Time is analytic truth for the modeled assumptions.
SU must provide unambiguous intent so downstream agents can validate or reject it.

**Plugin directory:** `/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods/`
**Git workflow:** `git add -A && git commit -m "message" && git push origin bill_dev`
**Branch:** `bill_dev` on `https://github.com/JPods/sketchup.git`

### What WebClerk Is in This Environment

WebClerk is the structured operating database for SketchUp work.
It is not the runtime authority and not a hidden authority over the plugin.

That means:
- topology decisions and gate results are the plugin's authority
- long-form explanation and retrospection belong in readmes
- open gap patterns, design decisions, unresolved exports, WhatIf experiments, and follow-up actions belong in WebClerk

Allie uses WebClerk in SketchUp work to:
- create `action` records for design decisions that need follow-up
- route WhatIf items to project 24 when a candidate approach should be held but not yet committed
- surface coordination items via `alice_pending` settings
- maintain an audit trail in `alice_log` for significant plugin decisions

### Agent Roles in This Environment

| Agent | Role |
|-------|------|
| Noelle | Definition authority and precondition gate |
| Natalie | Route-feasibility authority on exported graph |
| Nora | Operational behavior observer (via physical behavior and repeated-failure patterns) |
| Athena | Stop-and-Review escalation authority |
| Allie | Intelligence layer for cross-session and cross-domain pattern recognition |

### Authority Boundary

- Ruby authority code decides pass/fail
- Allie advises, diagnoses, and records cross-domain implications
- Copilot edits plugin code when instructed
- Bill decides

Allie augments. She does not override.
The gate either passes or blocks. Allie does not bypass it.

---

## For the AI (Copilot / Allie)

### Critical Plugin Files

| File | What it owns |
|------|-------------|
| `jpod_network.rb` | Core network build, Bezier sampling (`tangent_curve_pts`), FollowMe export |
| `jpod_network_editor.rb` | Preview geometry, user-facing editor |
| `jpod_structure.rb` | Station and column component definitions, CP placement |
| `jpod_structure_placer.rb` | `StructurePlacer.refresh_cp_labels()`, CP label management |
| `noelle.rb` | `Noelle.component_definition_faults(followme)` — definition gate |
| `natalie.rb` | Route-finding, BFS on exported graph |
| `jpod_constants.rb` | Engineering limits — T_ARM_OFFSET, thresholds |
| `templates/` | Component templates |
| `r_stocks/` | Stock Ruby components |
| `readmes/sketchup/jpods-plugin.md` | Current plugin state and known issues |
| `readmes/sketchup/jpods-gap-log.md` | Recurring gap patterns — the Session Log |

### Seven Critical Rules (Empirical — Hard-Won)

These rules are known because they cost real time. They must survive every session turnover.

**Rule 1 — Never call `model.definitions.load` inside `start_operation`**
SketchUp's C layer crashes without rescue. The crash is silent at the Ruby level.
Always load component definitions before starting the operation, not inside it.

**Rule 2 — Check face normal before pushpull**
`pushpull` direction depends on face normal.
Pattern: `f.normal.z < 0 → f.reverse!` before pushing.
Skipping this produces geometry pushed in the wrong direction with no error.

**Rule 3 — `Transformation.axes` with non-uniform Z is valid in SU2026**
`Transformation.axes(origin, x_axis, y_axis, z_axis)` with a non-unit Z vector scales uniformly in the Z direction.
This is supported in SU2026 and is the correct way to scale column height without affecting XY.

**Rule 4 — T_ARM_OFFSET = 0.43 m (empirical)**
Apply this offset to land the T-arm at beam face level.
The value is empirical — it was measured, not calculated.
Do not derive it from geometry theory.
See `jpod_constants.rb`.

**Rule 5 — Purge before every Build**
Erase all "JPods Guideway" and "JPods Column" groups before rebuilding.
Failure to purge stacks geometry invisibly — identical guideways pile up at the same location.
Option+Build (add mode) is the only exception; it must be used deliberately.

**Rule 6 — Bezier sampling must be adaptive to chord length**
Fixed 16-segment Bezier on a long segment (2–3 km) produces 150–180 m steps — well above the 100 m flag threshold.
Rule: `n = max(16, ceil(chord / 20 m))`, capped at 256.
Applies to `tangent_curve_pts` in `jpod_network.rb` and to Preview sampling in `jpod_network_editor.rb`.

**Rule 7 — CP text labels must be refreshed after every Build**
`model.entities.add_text` labels accumulate without clearing.
Fix: before every Build, erase all `Sketchup::Text` entities whose `.text` includes `".CP"`,
then re-add from `connection_points` attribute stored on each structure.
Method: `StructurePlacer.refresh_cp_labels(model)` called after `commit_operation`.

### Station Contract

Every station component definition must satisfy all four conditions:

1. **Unique `Sxxx` ID on the definition name** — e.g., `S001_Boarding_Station`
2. **Contains at least one `platform_guideways` entry** — a guideway inside the station tagged `platform`; without this, Natalie cannot route to the station
3. **No duplicate `Sxxx` IDs** — duplicates confuse the route graph; Noelle catches this
4. **Exported to FollowMe** — a station in the model that was not included in the FollowMe export is invisible to all downstream agents

**The silent-degradation lesson:** A station without a `Sxxx` ID and `platform_guideways` tags exported silently — no error, no warning. Routing failed. A week of debugging followed. This is why the rule is: fail before export if station definitions are broken.

### Definition Gate — What the Code Actually Enforces

`Noelle.component_definition_faults(followme)` currently fails on:
- zero structures in FollowMe
- structures missing `structure_id`
- duplicate `structure_id` values
- malformed structure IDs not matching `Sxxx`
- stations missing detectable `platform_guideways`
- zero total station platform guideways across all exported structures

`Natalie.route()` calls that gate before BFS. If the gate fails, routing stops immediately.

Correct sequence:
1. definition validity first
2. route search second
3. retries last

Do not add gate checks here that the current Ruby does not enforce.
When a gap in the gate is identified, note it in the open questions section.

### SU Readiness Gate (Blocking Checklist)

This checklist must pass before FollowMe export. It extends the code-level gate:

1. **Station identity** — every station definition has a unique `Sxxx` ID
2. **Platform identity** — every station has at least one platform-tagged guideway
3. **Directional integrity** — every directional element has unambiguous inbound/outbound assignment (red = inbound, blue = outbound)
4. **CP pair integrity** — CP connects only to CP; disconnect removes both guideways of the pair
5. **Graph reachability** — every station platform can route to every required destination class under the current topology
6. **Exception ledger** — any intentional exception is listed with reason, owner, and sunset date

If any item fails, export is blocked. Emit one corrective message naming the exact failing objects.

### Stop and Review Rule

After 3 consecutive failures of the same kind, stop.
Do not retry a fourth time.
Diagnose model or system state.

When triggered, emit: "Stop and Review — [description]" and record the event in the retrospection.
Count: `STOP_REVIEW_THRESHOLD = 3`. Athena owns escalation.

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

### Export Artifacts and Downstream Flow

| Artifact | What it is | Who consumes it |
|----------|-----------|----------------|
| `<model>.followme.json` | Directed waypoint graph — nodes, edges, distances, platform markers | Natalie (podPresenter on Mac), Nora (physical RPi pods) |
| `trips/<model>.trip.<vehicle_name>.json` | Ordered list of waypoints for a specific vehicle | Nora (physical or simulated vehicle) |

**Export workflow:**
1. Verify model definition state passes the readiness gate (all 6 checklist items)
2. Run FollowMe export from console or menu
3. Copy `followme.json` to `podPresenter/json/` and to each pod via the Noelle deploy sequence
4. Physical pods load the graph on startup; Natalie (podPresenter) reads it for route assignment

**Topology note:** Route-Time uses a parallel Python graph (`engine/network.py`), not `followme.json` directly.
The two graphs should agree on topology. When they disagree, the physical behavior is the arbiter.

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
4. Allie promotes it to universal if the same pattern appears in Route-Time or physical

### Allie's Session Workflow

**At session start:**
1. Read `readmes/sketchup/jpods-plugin.md` — current plugin state and known issues
2. Read `readmes/sketchup/jpods-gap-log.md` — recurring gap patterns
3. Read the prior retrospection for the most recent date in `readmes/retrospections/`
4. Check WebClerk project 25 (`allie`) and project 24 (`allie-whatif`) for open SketchUp actions and WhatIf items
5. Read the relevant agent file(s) if the task touches Noelle, Natalie, Nora, or Athena
6. Surface any repeated gap pattern before editing begins — flag it before Copilot writes a line

**During session** *(see Bill's participation decision at top of this file)*:
1. Track design decisions as they happen — do not reconstruct at end
2. Flag cross-domain implications when they arise (SketchUp decision → Route-Time consequence; convention → physical deployment consequence)
3. Diagnose root cause when a rule-based agent fires — the agent reports a fault; Allie identifies why
4. Log new gap patterns immediately, not after the session
5. Convert real follow-up into WebClerk `action` or WhatIf items as they arise

**At session end — always required:**
1. Emit the session evidence packet (see below)
2. Update `readmes/sketchup/jpods-plugin.md` if a convention or known issue changed
3. Update the relevant agent readme if agent behavior or responsibility changed
4. Append retrospection in `readmes/retrospections/YYYY-MM-DD.md`
5. Classify each new lesson: SketchUp-only, overlapping, or universal candidate
6. If universal candidate: verify it holds in Route-Time and physical before promoting
7. Record remaining follow-up in WebClerk

### Required Session Evidence Packet

At session end, publish this packet in the retrospection:

- **Changed definitions** — list of touched station/circle/component IDs
- **Gate failures seen** — grouped by fault type and count
- **Stop-and-Review events** — count, trigger type, resolution status
- **Directional exceptions** — list, reason, owner, sunset date
- **Cross-domain implications:**
  - what Route-Time should verify
  - what Physical should verify

This packet is the comparison substrate when reconciling SU topology with Route-Time and physical results.

### Comparison Protocol (Three-Stream)

When comparing SketchUp topology against Route-Time simulation and Physical behavior:

1. **Topology intent** — do all three agree on station/CP connectivity?
2. **Directionality** — do all three preserve inbound/outbound direction?
3. **Reachability** — can required OD pairs complete in all three?
4. **Throughput/congestion** — are bottlenecks aligned in location and order-of-magnitude?
5. **Contradiction record** — if mismatch exists, log root candidate and required correction target (SU, Route-Time, or Physical)

When Physical contradicts SU or Route-Time, Physical wins.
Name the specific upstream artifact that must change — not a note, a named required correction.

### Cross-Domain Mappings

| SketchUp concept | Route-Time equivalent | Physical equivalent | Invariant |
|-----------------|----------------------|--------------------|-----------|
| CP pair / directed endpoint | CP object (Python) with `inbound_node`, `outbound_node` | Physical directional switch at junction | Directed boundary — inbound and outbound are never interchangeable |
| Color: red=inbound, blue=outbound | Same color standard in GUI | Physical track direction (CCW = standard) | Flow direction must be visible at every representation level |
| `platform_guideways` in FollowMe | PLATFORM node in Route-Time network graph | Physical platform berth on track | Route must begin and end at a real boarding/alighting location |
| `followme.json` BFS graph | Dijkstra graph in `engine/network.py` | Nora's onboard path following (`mapSM.json`) | Same topology, different format — they must agree |
| Noelle definition gate | `diag_grid.py` topology check | Pre-run I2C and MQTT connectivity check | Loud validation failure at boundaries beats silent degradation |
| Stop and Review (3 consecutive) | Stop and Review (same threshold) | Nora `stop_and_review` JSONL event | Repeated identical failure is a signal, not bad luck |
| Station `Sxxx` ID | `structure_id` in Route-Time network | Station identity tag on physical hardware | Stations must be individually addressable in every environment |
| `network.json` connection declaration | CP connection in `api.py` state | Physical guideway installation between switches | Declared topology drives all downstream agents |

### Environment-Specific Knowledge — Do NOT Transfer

These facts are SketchUp-only. Do not use them as premises in Route-Time or physical reasoning:

- SketchUp Ruby API calls (`Sketchup.active_model`, `entities`, `component_definitions`, `HtmlDialog`)
- `network.json` format and stub index logic
- `followme.json` field layout and waypoint format
- `trips/*.json` vehicle file format
- FollowMe export sequence and file placement
- Copilot instruction format in `.github/copilot-instructions.md`
- `T_ARM_OFFSET`, column height-scaling via `Transformation.axes`
- Bezier sampling details in `tangent_curve_pts`
- CP label refresh mechanism in `StructurePlacer`

### WebClerk Records for SketchUp Work

| Record type | When to use |
|-------------|-------------|
| Project 25 `allie` | Active SketchUp design decisions and open gap items |
| Project 24 `allie-whatif` | Candidate approaches to hold but not yet commit |
| `action` | Named follow-up with owner, what, why, when, next |
| `setting` `alice_pending` | Items Alice needs to act on |
| `setting` `alice_log` | Audit trail for significant plugin decisions |
| `document` / `linkageentry` | Pointers to readmes, exports, gap log entries |

### What Allie Accumulates From SketchUp Sessions

1. **Gap log** (`readmes/sketchup/jpods-gap-log.md`) — any new gap pattern
2. **SketchUp-specific memory** — Ruby API behaviors, new gate scenarios, new model-state patterns
3. **Cross-domain mappings** — when a SketchUp concept clarifies or contradicts something in Route-Time or physical, write the explicit mapping
4. **Design decisions table** — any decision made this session, in this file and in the relevant agent file
5. **Universal promotions** — lessons that appear independently in two or more environments are candidates for `memory/universal/`

---

## Open Questions

- In-session Allie participation: always present (CC position) or required start/end + optional checkpoints (SU position)? **Bill must decide.**
- Should there be a formal export readiness check separate from Noelle's definition gate? (The 6-item readiness gate above extends it, but code does not yet enforce all 6.)
- What is the correct minimum OD route set for mandatory reachability tests before export?
- When Natalie's BFS finds a valid route but Nora physically cannot complete it, how does that lesson feed back to the SketchUp model? Currently Bill observes and corrects manually.
- How does `followme.json` get from the SketchUp machine to the physical pods and to podPresenter? Is there a deploy script or manual copy?
- Should the session evidence packet be markdown, JSON, or both?
- The `network.jpd` file in the JPodsSM_RPi workspace — what is its relationship to the SketchUp `network.json`? Is `.jpd` a SketchUp export format or something else?
- Should Stop-and-Review thresholds differ by fault class (identity fault vs. routing fault)?
- Should Allie's cross-domain flags during a SketchUp session go to Copilot directly (via session context) or always through Bill?

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-27 | **[OPEN]** In-session Allie participation — see top of this file | CC: always present; SU: required start/end + optional checkpoints. Bill decides. |
| 2026-04-27 | Allie is the AI substrate for Noelle, Natalie, and Nora until standalone processors exist | Ruby code enforces correctness; Allie supplies judgment and accumulated experience |
| 2026-04-27 | This document states code checks only at the level the current Ruby actually enforces | Policy must not outrun implementation without saying so; gaps go in Open Questions |
| 2026-04-27 | Critical rules are recorded as empirical findings, not as design theory | The seven rules are known because they cost real time; they must survive session turnover |
| 2026-04-27 | SketchUp document remains strictly scoped to the plugin | Cross-domain lessons transfer via explicit mappings; implementation details do not transfer at all |
| 2026-04-27 | SU readiness gate is a blocking checklist artifact | Prevents silent degradation and ambiguous export quality |
| 2026-04-27 | Session evidence packet is required at every session end | Enables cross-stream comparison without narrative ambiguity |
| 2026-04-27 | Contradictions must declare correction target and the specific artifact to change | Avoids unresolved "someone else should fix it" drift |
| 2026-04-27 | WebClerk is the operating database for SketchUp follow-up and coordination | Durable follow-up needs structured records; not a hidden authority over the plugin |
| 2026-04-19 | Adaptive Bezier sampling: `n = max(16, ceil(chord / 20 m))` | Fixed-n sampling on long chords produced step sizes above FOLLOWME_MAX_JUMP |
| 2026-04-19 | Build purges guideway and column groups before every rebuild | Repeated builds stacked geometry invisibly; purge-before-rebuild is now the invariant |

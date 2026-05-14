# JPods SketchUp 2026 Plugin
Last updated: 2026-05-01  
Plugin version: 2.4  
Plugin location: `/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods/`

---

## Git repository

Remote: `https://github.com/JPods/sketchup.git`  
Branches:
- `main` — stable / reviewed code
- `bill_dev` — Bill's active development branch

Working directory is the plugin folder itself (git init'd inside `JPods/`).  
`.gitignore` excludes: `hold/`, `*.bak`, `*.bak_*`, `.DS_Store`

Standard commit workflow:
```bash
cd "/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods"
git add -A && git commit -m "message"
git push origin bill_dev   # or main
```

---

## What this is

A SketchUp 2026 Ruby plugin that lets Bill design, visualize, and simulate JPods
transit networks inside a 3D model.  The goal is a tool anyone — city planner, 
developer, investor — can use to see a JPods network in their actual neighborhood
before a dollar is spent.

---

## What it does today (April 2026)

### Place structures
- Tool: `jpod_structure_tool.rb`
- Places JPods station/gate structures (S001, S002…) in the model
- Detects connection points (CPs) automatically from the .skp template
- Labels each CP with a teal circle and "S001.CP0" tag in the viewport

### Build the network
- Tool: Network Editor dialog (`jpod_network_editor.rb` + `dialogs/network_editor.html`)
- Open via Plugins › JPods › Network Editor
- Edit or load a `network.json` file defining which structure stubs connect to which
- Click **▶ Build** — builds dual parallel guideways between all connections
- Option+Build = add mode (keeps existing guideways)
- The JSON format:
```json
{
  "connections": [
    { "id": "seg_1",
      "from": { "structure_id": "S001", "stub": 0 },
      "to":   { "structure_id": "S002", "stub": 0 },
      "via_markers": [] }
  ]
}
```
- `via_markers: []` → cubic Bezier curve between the two CPs (smooth S or C curve)
- `via_markers: [3, 7]` → polyline through numbered marker objects in the model

### Guideways
- Two parallel beams, ±1.75 m from centerline
- Rectangular cross-section 0.5 m wide × 0.5 m deep
- Path follows terrain grade; grade warnings if >15%
- `jpod_path_builder.rb` handles arc insertion, terrain snap, grade enforcement

### Solar support columns
- `JPod_support_T` template placed every 25 m along the centerline
- Column height scales to terrain — always reaches from ground to beam
- T arm aligns exactly with beam top face (T_ARM_OFFSET constant)

### Solar panels
- `JPod_solar` template placed every 2.5 m along the same centerline
- Sits flat on the beam top face
- Fallback: flat blue rectangle if template file missing

### Vehicles
- 4 vehicle types: Red, Blue, Yellow, Green (templates in `templates/r_stocks/`)
- Place vehicles from the Network Editor vehicle bar — set qty per type, click Place Vehicles
- Click **▶ Animate** — vehicles move along beam path at configurable speed (default 8.3 m/s = ~30 km/h)
- **⏸ Stop** saves position; next Animate resumes from same spot

---

## Architecture — key files

| File | Purpose |
|------|---------|
| `jpod_constants.rb` | All engineering limits — single source of truth |
| `jpod_structure_tool.rb` | Place + label structures, detect CPs |
| `jpod_network.rb` | Parse network.json, build dual guideways |
| `jpod_network_editor.rb` | HtmlDialog + viewport overlay tool |
| `jpod_path_builder.rb` | Arc insertion → terrain snap → grade profile |
| `jpod_guideway.rb` | Beam geometry, solar columns, solar panels, vehicles, animation |
| `dialogs/network_editor.html` | Editor UI |
| `templates/structures/` | .skp component files for columns, solar, stations |
| `templates/r_stocks/` | .skp vehicle components (Red/Blue/Yellow/Green) |
| `readmes/basics.md` | Full design spec — read this first |
| `readmes/issues.md` | Known issues and future work list |

---

## Critical rules learned the hard way

### FollowMe authoring convention — platform siding name
- In SketchUp Entity Info, the real loading/unloading guideway instance should keep `track` in its instance name.
- Preferred instance name: `Track-platform`.
- Use SketchUp tag `platform` to mark its role.
- Do not rename the actual berth guideway to bare `platform` only; that is how FollowMe seam/export drift starts during template edits.

### Tag usage policy — CP and platform reliability
- Tag-first authority: `stub_pair`, `dead_end_cap`, and `platform` define intent.
- Instance/definition names are fallback guardrails, not runtime authority.
- Keep `track` in names of runnable guideway entities for readability and drift resistance.
- Runtime movement/routing stays on declared line identity (`connection_id`, `track_index`, FollowMe line ids), not on SketchUp name strings.

### Network authoring convention — connection ids
- New network segments should use simple sequential ids: `seg_1`, `seg_2`, `seg_3`, ... .
- Do not mint time-based ids for new connections.
- Keep ids stable once assigned so trips, audits, and FollowMe references remain readable.

### 1. Never call `model.definitions.load` inside `start_operation`
SketchUp's C layer crashes — no Ruby rescue catches it.  
**Rule:** always preload all needed .skp definitions *before* calling `model.start_operation`.  
The plugin has `preload_structure_definitions(model)` for this — call it before every transaction.

### 2. `pushpull` direction depends on face normal
After `add_face`, check `f.normal.z < 0 → f.reverse!` before `pushpull`.  
Otherwise the extrusion goes downward into the ground and is invisible.

### 3. `Transformation.axes` with non-uniform Z is valid in SU2026
`Vector3d.new(0, 0, scale_z)` as the Z argument to `Transformation.axes` produces
a non-uniform scale along Z only — this is how column height-scaling is done.
Works cleanly in SU2026; was not confirmed in earlier versions.

### 4. T_ARM_OFFSET
The `JPod_support_T` component has its origin at ground level and the T arm at
`native_h` above that. To land the T arm exactly at beam face level, the origin
must be lowered by `T_ARM_OFFSET` (currently 0.43 m, measured empirically).
Set in `jpod_constants.rb`.

### 5. Build button must purge before rebuilding
The Build button (both the menu command and the editor dialog) must erase all
`"JPods Guideway"` and `"JPods Columns"` groups before building — otherwise
repeated builds stack geometry on top of itself.  User structures (`"JPods Structure"`)
and markers (`"JPod Marker"`) must never be touched by Build.
Fixed in `jpod_network.rb` (`build_from_json`) and `jpod_network_editor.rb` (`cmd_build`).

### 6. Bezier sampling must be adaptive to chord length
A fixed 16-segment Bezier on a long segment (e.g. 2–3 km) produces 150–180 m steps.
`draw_beam` deduplicates points closer than 0.5 m but does not split long ones —
so the followme sweep skips huge distances at segment 0 and n-1, producing invisible
or crash-inducing geometry.
**Rule:** sample count = `max(16, ceil(chord / 20 m))`, capped at 256.
See `tangent_curve_pts` in `jpod_network.rb`.

### 7. `Vector3d * Float` is illegal in SketchUp Ruby — always use explicit components

SketchUp's `Geom::Vector3d` does **not** register a `coerce` method, so the `*` operator
with a Float scalar always raises `ArgumentError: Cannot convert argument to Geom::Vector3d`.

```ruby
# WRONG — crashes silently in SketchUp:
vec.normalize * 2.5
unit * dot_product

# RIGHT — always expand to components:
n = vec.normalize
Geom::Vector3d.new(n.x * 2.5, n.y * 2.5, n.z * 2.5)
```

This pattern appears in bezier tangent correction and offset_path miter clamping.
Both `jpod_connect_tool.rb` and `jpod_network.rb` contain independent copies of
these methods — any fix must be applied to **both** files.
Fixed: 2026-05-13 (3 sites in jpod_network.rb, 3 in jpod_connect_tool.rb, 1 in jpod_animator.rb).

### 8. CP text labels must be refreshed after every Build
`model.entities.add_text("S001.CP0", pt)` labels accumulate — Build does not
automatically clear old ones.  The fix: before every Build, erase all
`Sketchup::Text` entities whose `.text` includes `".CP"`, then re-add from
the stored `connection_points` attribute on each structure.
Method: `StructurePlacer.refresh_cp_labels(model)` called after `commit_operation`.

---

## Planned Features

See `readmes/sketchup/jpods-feature-list.md` for the full feature list.

High-priority items as of 2026-05-13:
- **F-01** — User-configurable minimum XY (horizontal) turn radius per model
- **F-02** — User-configurable minimum Z (vertical) curve radius per model
  *(both currently global constants; sharp Z transitions exposed after legacy waypoint Z fix)*

---

## Known open issues (as of April 2026)

See `readmes/issues.md` for full detail.  
See `readmes/sketchup/jpods-gap-log.md` on Allie for the living gap-cause log.

1. **terrain_z = 0 with no terrain mesh** — columns are full CLEARANCE_HEIGHT (8 m)
   from z=0 when no sandbox terrain exists in the model. Fine for now.

---

## UI Design — Console vs Network Editor (established May 1, 2026)

### The sharp line

**Network Editor** is a **document editor with a viewport.**
Its job is to author and inspect `followme.json` — the map.
Use it when looking at the 3D model and wanting to understand what lines connect to what.
Spatial, visual, tied to the geometry.
Commands that belong here: edit JSON, build network, highlight connections, check continuity, set constraints.

**JPods Console** is a **command panel with parameters.**
Its job is to execute named operations that take inputs, do work, and return a result.
Not spatial. No viewport relationship.
The right place for anything that has a form, a confirmation, or an output report.

**Decision rule:**
- Command *shows something in the viewport* or *edits the JSON map* → **Network Editor**
- Command *executes an operation with parameters and returns a status* → **Console**

### Three user roles

Every Console command belongs to exactly one role. The Console header shows a
role selector (`Operator` is the default). Commands outside the active role are
hidden — not removed.

| Role | Who | Categories shown | They care about |
|---|---|---|---|
| **Operator** | Runs the simulation | Vehicles, Animation, Nora | Place vehicles, assign trips, animate, camera follow, export trip JSONs |
| **Builder** | Network designer | Network, Noelle | Structures, gates, guideways, CPs, FollowMe export, constraints |
| **Tester** | Validator | Network Check, Safety, Noelle | Noelle integrity, platform checks, conflict audits, 5V test, continuity |
| **Advanced** | Developer/diagnostics | All categories | Everything including Developer diagnostics |

These map onto the three agents: Builder feeds Noelle, Tester runs Noelle/Natalie
checks, Operator runs Noras.

### Role selector implementation

File: `dialogs/console.html`

The `ROLE_CATEGORIES` constant in the JS maps each role to the list of
`category:` strings from the Ruby `TASKS` registry. `renderSidebar(role)`
re-draws the sidebar filtered to those categories. `initTasks(grouped)` stores
the full task registry and calls `renderSidebar` on first load. The `<select>`
change event calls `renderSidebar` with the new role. No Ruby changes were needed.

---

## JPods Console + Athena Guard (added April 20, 2026; menu consolidated May 1, 2026)

### What it is
A user-facing task runner that replaces raw Ruby Console paste-work for end users.  
Open it from **Plugins › JPods** — that single item opens both the Network Editor tool
and the Console dialog simultaneously.

### Single menu entry point (established May 1, 2026)
The `Extensions > JPods` menu has exactly **one item** — `JPods`.  
Clicking it activates the Network Editor viewport tool and opens the Console dialog.
No submenus. No duplication. All commands live inside one of the two dialogs.

### Files
| File | Purpose |
|------|---------|
| `jpod_console.rb` | Task registry, `JPods::Athena` guard, `JPods::Console` dialog manager |
| `dialogs/console.html` | Dark-theme UI: sidebar, Athena strip, param inputs, output pane |

### Design principle — No eval
Users pick from a predefined list of 11 tasks. No raw Ruby string ever executes.
All task procs are registered at load time in `JPods::TASKS` (frozen array).

### Athena — the security guard
`JPods::Athena.review(task, params, model)` runs **twice**:
1. On task selection — shows colored review strip immediately (green / yellow / red)
2. Again server-side immediately before execution — even if the client was manipulated

Athena checks:
- **Selection requirement** — task needs a specific group type selected (e.g. "JPods Guideway")
- **Param bounds** — float params clamped to declared min/max; violation blocks execution
- **Whitelist validation** — vehicle IDs checked against `available_vehicles` before use

### Risk levels
| Risk | Color | Behavior |
|------|-------|----------|
| `:safe` | Green | Execute button enabled if Athena passes |
| `:caution` | Yellow | Modifies model but is undoable |
| `:destructive` | Red | Requires explicit checkbox before Execute activates |

### The 11 tasks (categories)
**Setup:** Reload Plugin  
**Network:** Open Network Editor, Build Network from JSON, Erase All Guideways  
**Vehicles:** List Vehicle Templates, Place Vehicle on Guideway  
**Animation:** Start Animation, Stop Animation  
**Diagnostic:** CP Vehicle Monitor, Stop CP Monitor, Inspect Structure CPs, Inspect Guideway Endpoints  

### Stdout capture
Each task proc runs with `$stdout` redirected to `StringIO`. All `puts` calls
are captured and returned to the dialog's output pane. The user sees exactly
what would appear in the Ruby Console — no separate window needed.

### Adding a new task
Add an entry to `JPods::TASKS` in `jpod_console.rb`:
```ruby
{ id: "my_task",
  label: "Human Label",
  category: "Category",
  description: "Plain English explanation for users.",
  risk: :safe,            # :safe | :caution | :destructive
  requires_selection: nil, # or "JPods Guideway" etc.
  params: [],
  run: lambda { |model, params| "return value or puts output" }
}
```
No changes to the HTML are needed for tasks with no params.
For params, add entries with `id:, label:, type: :float|:string|:select, default:, min:, max:`.

---

## Allie's role in this plugin (established May 9, 2026)

Allie is the processing layer for Noelle, Natalie, and Nora until each has a
dedicated physical or cloud processor.  The Ruby modules are sovereign at
runtime — they enforce the rules.  Allie supplies judgment, diagnosis, and
accumulated experience that rule-based code cannot hold.

### Allie must be proactive, not reactive

**The key failure mode:** Allie waits to be asked.  She must not.

When `followme.json` is exported, Allie should automatically:
1. Detect the file change (file watcher on the model's `followme.json`)
2. Run `Noelle.review_recommendations` against it
3. Surface any `:warn` or `:block` findings to Bill unprompted

This is not a courtesy — it is her job.  If a connection between two stations
(e.g. S010 and S012) has no `via_markers`, Allie should flag it before Bill
has to ask "why does the Bezier look wrong?"

**What Allie holds that the Ruby code cannot:**
- Which formation tags are missing on which station templates (recurring failures)
- Why BFS cannot find a route between specific station pairs
- Pattern-matching across `stop_and_review` events in Nora logs over time
- Cross-session memory of which connections were problematic before

### File watcher — required, not yet implemented

Allie needs a file watcher on the model's `followme.json`.  When the file
changes she should:
```
1. load followme.json
2. call Noelle.review_recommendations (or its Python equivalent)
3. log findings to readmes/sketchup/jpods-gap-log.md
4. notify Bill via whatever channel is open (console note, voice, chat)
```
The SketchUp plugin already calls `Noelle.review_recommendations` automatically
after every export (wired May 9, 2026).  Allie's watcher provides the
out-of-band audit that catches changes made outside SketchUp.

### Plugin-side automatic review (already wired)

`jpod_followme_exporter.rb` calls `Noelle.review_recommendations` immediately
after writing `followme.json`.  The Ruby Console will always show Noelle's
findings after export — the operator does not need to invoke review manually.

### Handoff protocol

When a standalone Natalie or Noelle processor comes online:
- Allie hands off `readmes/sketchup/jpods-gap-log.md` as the experience base
- Allie hands off `readmes/agents/noelle.md` and `natalie.md` as the contracts
- Allie steps back to observer role for that domain — she does not command

---

## What's next (future sessions)

- [ ] `detect_guide_circle_z` — use `CenterCP` tag to auto-calibrate T_ARM_OFFSET per template
- [ ] Real terrain import / elevation data so columns scale to actual ground
- [ ] Station platforms and passenger amenities
- [ ] Network statistics: total track length, solar capacity, vehicle count, capacity
- [ ] Vehicle pitch on slopes (currently only rotates around Z; needs pitch along grade)
- [ ] Export to KML/IFC for GIS and engineering workflows
- [ ] Multi-level / elevated intersections

---

## Session decisions (April 27, 2026) — SketchUp plugin only

**Scope note:** This file covers the **SketchUp 2026 plugin** (`JPods/` folder). It is not the scale model (`jpod_OS/`), Route-Time GUI, WebClerk, or any other JPods project. Keep decisions scoped accordingly.

### Mandatory formation tag requirements (enforced)
Three SketchUp tags are now required on every formation SKP. The plugin fails fast if any are missing:

| Tag | Applied to | Purpose |
|-----|-----------|---------|
| `stub_pair` | Both parallel stub tracks at each gate | Primary CP detector — paired midpoint + BEAM_WIDTH/2 correction |
| `dead_end_cap` | Each removable end cap entity | Routing — vehicles must not traverse beyond capped endpoints |
| `platform` | Loading/unloading siding guideway inside station | Natalie uses platform positions for berth routing; Noelle flags stations missing this tag |

### Station identity contract
- Instance name: `station` (lowercase, exact)
- Definition name: unique `Sxxx` ID (e.g. `S097`) — this is how Noelle and Natalie identify the structure
- `station` tag: optional (show/hide visibility only; not required for routing)
- A station without a `platform`-tagged guideway inside it will cause Noelle's definition gate to fail fast with an explicit message

### April 29, 2026 — Guideway alignment + FollowMe bridge lesson (do not lose)

What went wrong:
- Built guideways were initially aligning like outside-edge to outside-edge at station gates.
- FollowMe omitted the short bridge segment between station loop and extruded guideway at stub_pair gates.

Root causes:
1. Paired `stub_pair` correction used `BEAM_WIDTH / 2` magnitude but direction could resolve outward.
2. FollowMe structure collector was too strict:
  - only accepted instance name `JPods Structure`
  - only accepted entities whose names included `track`
  This skipped valid structure candidates and `stub_pair`-tagged bridge entities.

Fixes applied:
- Enforced inward `BEAM_WIDTH / 2` correction toward structure origin/interior for paired `stub_pair` CP midpoint.
- Expanded FollowMe structure scanning to JPods structure candidates (attribute/tag based), not just literal name.
- Treated `stub_pair`-tagged entities as valid FollowMe path sources in structure collectors.

Hard rule to retain:
- CP datum and FollowMe join are bottom-centerline to bottom-centerline at the gate seam.
- Any outside-edge join appearance is a regression.

### Fail-fast definition gate (Noelle + Natalie)
`Noelle.component_definition_faults(followme)` checks:
- Zero structures present
- Missing structure IDs
- Duplicate Sxxx IDs
- Malformed IDs (not matching `/^S\d+$/i`)
- Stations with no `platform_guideways` array

Natalie calls this gate before every BFS route. If the gate fires, Natalie refuses to plan and returns the definition fault message directly to the user. Root cause: a lost week because stations were not properly defined before routing was attempted.

### Stop and Review protocol (all five agents)
All five agents — Athena (`jpod_console.rb`), Noelle (`noelle.rb`), Natalie (`natalie.rb`), Nora (`nora.rb`), and Allie — escalate to a mandatory "Stop and Review" message after **3 consecutive failures of the same kind**. Threshold constant: `STOP_REVIEW_THRESHOLD = 3`.
- Athena: per-task block streak
- Noelle: per-validation-run streak
- Natalie: per-route streak (keyed by `origin->destination`)
- Nora: per-struggle-kind streak; writes `stop_and_review` JSONL event to observation log
- Expected operator action: stop, read the protocol section in `readmes/followme.md`, verify component definitions, verify tags, re-export FollowMe, then retry

### Allie's role in this project
- Allie's JPods SketchUp readme: `/Users/williamjames/Allie/readmes/sketchup/jpods-plugin.md` (this file)
- Allie's agent files for SketchUp agents: `readmes/agents/noelle.md`, `natalie.md`, `nora.md`, `athena.md`
- copilot-instructions.md now mandates that Copilot consult Allie at session start and end, record decisions here, and ask Allie's opinion on cross-domain choices
- Until Noelle, Natalie, and Nora have independent processors, Allie provides their processing layer in this SketchUp work.
- Allie informs and holds memory; she does not command agents or override plugin authority structures

### Allie as AI substrate for Noelle, Natalie, and Nora (added April 27, 2026)

The three SketchUp plugin agents are Ruby modules, not AI. Until each has a standalone processor, **Allie is their processing, intelligence, and experience**:

| Agent | Rule-based code does | Allie does |
|-------|---------------------|-----------|
| **Noelle** | Runs `component_definition_faults()`, validates FollowMe graph | Reasons about WHY the fault fired, which SKP is non-conforming, which station pattern keeps breaking; updates gap log |
| **Natalie** | BFS route on FollowMe graph; refuses if definition gate fails | Diagnoses why no route was found — disconnected line? missing destination? wrong U-turn terminus? Recommends the fix |
| **Nora** | Executes trip itinerary, logs observations, tracks struggle streaks | Reads JSONL observation log after `stop_and_review` events; identifies recurring patterns across trips; advises on what changed |

**Experience base Allie maintains for these agents:**
- `readmes/sketchup/jpods-gap-log.md` — recurring tag mistakes, formation SKP non-conformance patterns
- `readmes/sketchup/jpods-plugin.md` — session design decisions (this file)
- `readmes/agents/noelle.md`, `natalie.md`, `nora.md` — accumulated design decisions, open questions, cross-session patterns

**Authority boundary:** The Ruby code is sovereign at runtime. Allie advises. She does not rewrite `followme.json`. She does not override Noelle's gate. Bill decides.

**Handoff:** When a standalone processor exists for any of these agents, Allie hands off her accumulated experience base and steps back to observer for that domain.

### Alice's support role

- Alice has an API.
- Alice provides the database support for ticketing, actions, and transactions.
- Alice starts her database on machine startup and is expected to be available locally when Bill begins work.
- Ticketing and transaction records belong with Alice's API/database support layer, not in `followme.json`, `vehicles.json`, or runtime logs.

### How to communicate with Alice's API

Use Alice through the local wcapi HTTP interface.

Base assumption:
- Alice's database starts on machine startup.
- Alice is up and running on Bill's machine unless a local health check proves otherwise.

Current local API pattern:
1. Get a scoped token.
2. POST JSON to the local wcapi endpoint.

Example action write:

```bash
TOKEN=$(python3 /Volumes/Allie/scripts/allie_wc_token.py --agent alice)
curl -s -X POST http://localhost:8000/wcapi/save/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model_name":"action","title":"<title>","status":"open","description":{"from":"jpods","to":"alice","request":"...","category":"pending"}}'
```

Use this channel for:
- ticketing support records
- action persistence
- transaction persistence
- cross-agent notes that belong in the database layer

---

## Session notes — 2026-04-27 (formation naming)

### Formation instance naming confirmed harmless

Bill named each `stub_pair` sub-component instance explicitly on the traffic circle: `pair_stub_0` … `pair_stub_3`. This is **good practice** for Outliner clarity and future stub-index logic. It has **no effect on CP detection** — `scan_stub_pair_tips` reads tag name only, never instance name. Tag `stub_pair` is still mandatory on every stub entity.

Inner geometry names (e.g., `"Track, 2,00m (JPod, arc)"`) are also not read anywhere in the plugin. Only tags and definition names drive logic.

### Next session — 2026-04-28

Goal: trips running platform to platform. Allie should check at session start:
1. Does the current FollowMe export have `platform_guideways` on both origin and destination stations?
2. Does Natalie's BFS successfully resolve origin platform → destination platform?
3. Does Nora traverse the full line sequence without triggering Stop and Review?
4. If not — run `Noelle.component_definition_faults()` output first before anything else.
5. Get Nora and Natalie parking management working — Noras park at a platform when idle; Natalie tracks which platforms are occupied and routes incoming Noras to a free berth. Check whether platform occupancy state is currently tracked anywhere in `natalie.rb` or `nora.rb`, and whether the FollowMe export includes enough platform data for berth-level addressing.

---

## Session notes — 2026-04-29 (FollowMe regression, recurring)

### What broke

FollowMe exported with valid line geometry but zero station platform metadata:
- top-level `platforms` empty
- station blocks present, but every station had `platform_guideways: []`

Result: Noelle definition gate correctly failed, Natalie refused routing (by design), and platform-to-platform trips were blocked.

### Estimated root cause

This is a recurring SketchUp template-drift issue: station geometry survives edits, but platform marker detectability drifts (tag/name placement or nested visibility path). Export still wrote a file, so failure looked like runtime routing instead of model-definition drift.

### Recovery/hardening implemented

1. Added strict export-time diagnostics in `jpod_guideway.rb`:
  - station-by-station warning when `platform_guideways=0`
  - explicit Ruby Console recovery instructions
2. Kept Noelle definition gate strict (missing platforms = hard stop).
3. Added startup dependency guard for optional dispatch server:
  - if `webrick` missing in SketchUp Ruby, plugin startup continues and dispatch server is disabled.

### Recurrence protocol (mandatory)

1. Verify `platform` marker on each station loading/unloading guideway.
2. Recompute CPs.
3. Re-export FollowMe.
4. Confirm strict platform diagnostics show non-zero detections for every station.
5. Run Noelle validation before Natalie routing.

---

## Session notes — 2026-05-01 (vehicle parking resolved)

### Problem

The 5V standard vehicle placement test placed 0 vehicles over multiple sessions.
The symptom was silent: the operation reported `28 warnings` and committed,
but no Noras appeared in the model.

Earlier attempts used a backoff/shift-and-retry loop to handle conflicts. That
approach masked the root bugs and produced no actionable diagnostic information.

### Resolution strategy

Replaced the retry loop with a hard stop + full diagnostic dump:
- On any occupancy conflict, abort the test immediately.
- Print a structured table to Ruby Console: function, call chain, slot index/count/role,
  all platform record fields, guideway attributes, computed path total, vehicle world
  position, spawn_t, and the conflict complaint verbatim.
- Pop a `UI.messagebox` alert directing the user to the Ruby Console.

One run with this strategy exposed four distinct bugs simultaneously.

### Bug 1 — `vehicle_path_for` stitching corrupted platform host guideways

**Symptom:** `path_total_m: 0.422 m (16 pts)` on a platform that should be 23.9 m (2 pts).  
**Root cause:** `stitch_structure_followme_paths` is called by `vehicle_path_for` to prepend/append
station internal FollowMe paths to mainline guideways. Platform host guideways are synthetic
2-point groups built from the platform's `start_m`/`end_m` endpoints. Their endpoints happen
to land near the station's internal FollowMe terminus, so the stitcher matched them and
appended 14 extra station-interior points — collapsing 23.9 m to 0.422 m.  
**Result:** `spawn_t` was computed as `target_pos / 0.422m` → overflow → `t=1.0` for every slot.
All vehicles landed at the same point.  
**Fix:** Overrode `vehicle_path_for` in `jpod_platform.rb` (loads after `jpod_guideway.rb`) to
return `base_vehicle_path_for(group)` directly when `platform_host: true`, skipping stitching.  
**Rule:** Any synthetic guideway that should not be extended by stitching must either override
`vehicle_path_for` or set a guard attribute checked before stitching.

### Bug 2 — `distance_to` does not exist in SketchUp Ruby

**Symptom:** `occupancy validation error: undefined method 'distance_to' for Point3d`.  
**Root cause:** `jpod_conflict_detector.rb` called `pt.distance_to(other_pt)` — that method does
not exist in SketchUp's `Geom::Point3d`. The correct method is `.distance`.  
**Secondary error:** The unit conversion used `/ 0.3048` (feet → meters). SketchUp internal
unit is inches; the correct conversion is `/ 1.m`.  
**Fix:** Changed both call sites to `pt.distance(other_pt) / 1.m`.  
**Rule:** When a distance comparison produces values that seem off by ~3.28×, check whether
`/ 0.3048` (feet) was used instead of `/ 1.m` (inches). SketchUp stores everything in inches.

### Bug 3 — Personal-space threshold fired on correctly-spaced slots

**Symptom:** Slot 1 and slot 2 reported as conflicting: `3.0m apart, need 3m`.  
**Root cause:** Slots are designed to be exactly 3.0 m apart (center to center). The conflict
threshold was `< 3.0`, which fired on floating-point values like `2.9999…`.  
**Fix:** Lowered threshold to `< 2.5` m. This is a real stacking violation (two ~2 m vehicles
physically overlapping). The designed 3 m slot spacing is not an emergency.
**Rule:** Conflict thresholds must be less than the minimum physical overlap distance,
not equal to the designed spacing.

### Bug 4 — False merge conflicts from empty `current_line_id`

**Symptom:** Every newly placed vehicle triggered a merge conflict against every other vehicle.  
**Root cause:** Freshly placed vehicles have no `current_line_id` attribute yet. The check was
`own_segment == other_segment && distance < 5.0`. In Ruby, `"" == ""` is `true`, so every
vehicle matched every other vehicle as being on the same (empty) line segment.  
**Fix:** Added `!own_segment.empty?` guard. Merge conflict is only meaningful when both
vehicles are on an assigned, non-empty line segment.  
**Rule:** Any equality check on optional SketchUp attributes must guard against the empty/nil
case before comparing. Never assume an attribute is set on a newly created entity.

### Architecture decision — platform host guideway is not a routable mainline

Platform host guideways (connection_id prefixed `__platform__`) are parking scaffolding only.
They are not part of the FollowMe network graph and must not be treated as mainline segments
by any path-following or stitching code. The `platform_host: true` attribute is the
authorative flag. Any code that iterates over `JPods Guideway` groups and does path math
must check this flag if it might behave differently for synthetic vs. real guideways.

### Files changed (2026-05-01)

| File | Change |
|------|--------|
| `jpod_vehicle_runtime.rb` | Hard stop + full diagnostic dump on conflict; removed backoff accumulator |
| `jpod_platform.rb` | `vehicle_path_for` override to skip stitching for `platform_host: true` |
| `jpod_conflict_detector.rb` | `distance_to`→`distance`; `/ 0.3048`→`/ 1.m`; threshold 3.0→2.5 m; empty-id guard |

---

## AI-Watching Console Pattern (2026-05-02)

**Concept:** When running JPods Console commands, instead of copy-pasting output to Copilot, enable a mode where Copilot watches the live log and interprets results in real time.

**How it works now (manual):**
- `tail -f jpod_console.log` runs in a VS Code terminal
- Copilot polls `get_terminal_output` after each command run in SketchUp
- Bill states what he expected; Copilot compares to actual output and diagnoses gaps

**Target architecture — "Copilot watching" checkbox:**
Add a checkbox labeled **"AI watching"** (or "Copilot watching") to the header area of every JPods console surface:
| Surface | Console file |
|---------|-------------|
| SketchUp plugin | `dialogs/network_editor.html` + `jpod_console.rb` |
| Physical robot | robot console (Pi-side) |
| Route-Time GUI | browser front-end |
| WebClerk3 | WC3 admin console |

**When checked:**
- Console output is appended to a shared structured log (e.g. `jpod_console.log` or a WC3 alice_log entry)
- A lightweight SSE/WebSocket endpoint streams new log lines
- Copilot (or Allie) subscribes, interprets each result, and posts a brief comment back to the console log or a side panel
- No copy-paste; no context switching

**Immediate implementation path for SketchUp:**
1. `jpod_console.log` already exists and is `tail -f` ready
2. Add a `POST /jpods/console-watch` SSE endpoint to Allie's local API that streams new log lines to a VS Code extension or browser panel
3. Copilot subscribes via `tail -f` (current workaround) or the SSE stream

**Design rule:** AI watching is advisory only. It does not write back to `followme.json` or issue commands. It reads, interprets, and posts observations. Bill decides.


# JPods SketchUp 2026 Plugin
Last updated: 2026-04-20  
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

### 7. CP text labels must be refreshed after every Build
`model.entities.add_text("S001.CP0", pt)` labels accumulate — Build does not
automatically clear old ones.  The fix: before every Build, erase all
`Sketchup::Text` entities whose `.text` includes `".CP"`, then re-add from
the stored `connection_points` attribute on each structure.
Method: `StructurePlacer.refresh_cp_labels(model)` called after `commit_operation`.

---

## Known open issues (as of April 2026)

See `readmes/issues.md` for full detail.  
See `readmes/sketchup/jpods-gap-log.md` on Allie for the living gap-cause log.

1. **terrain_z = 0 with no terrain mesh** — columns are full CLEARANCE_HEIGHT (8 m)
   from z=0 when no sandbox terrain exists in the model. Fine for now.

---

## JPods Console + Athena Guard (added April 20, 2026)

### What it is
A user-facing task runner that replaces raw Ruby Console paste-work for end users.
Open it from **Plugins › JPods › JPods Console**.

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
- Allie informs and holds memory; she does not command agents or override plugin authority structures

### Allie as AI substrate for Noelle, Natalie, and Nora (added April 27, 2026)

The three SketchUp plugin agents are Ruby modules, not AI. Until each has a standalone processor, **Allie is their intelligence and experience**:

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

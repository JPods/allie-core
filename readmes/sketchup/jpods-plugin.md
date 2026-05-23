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

### 8. Edge-driven geometry — no calculated centerlines as authoritative references

SketchUp processes geometry on **edges**. FollowMe walks edges. Transformations operate on edges. When a centerline is computed and treated as the authoritative position reference, SketchUp loses the thread — the calculated point does not correspond to any real edge, so face sweeps, offsets, and animation paths drift or collapse.

**The rule:** Every position reference in the JPods plugin anchors to a hard geometric edge:
- Guideway beam elevation = bottom face edge of beam (not centerline)
- Connection point location = stub edge endpoint (not stub midpoint)
- Clearance height = from terrain surface to beam bottom edge
- Waypoint Z = zeroed before PathBuilder; PathBuilder assigns the edge-referenced floor

**In PathBuilder:** `center_pts` Z values are zeroed before the build so PathBuilder's
`floor_z = terrain_z + CLEARANCE_HEIGHT` establishes every point from a real surface edge.
The anchor_zs = `[terrain + CLEARANCE_HEIGHT at from_CP, terrain + CLEARANCE_HEIGHT at to_CP]` pin
the endpoints to the exact beam-bottom-face elevation above the terrain edge at each CP.

**Do not:** compute a centerline and store it as a position; derive a "midpoint" of a CP stub as the connection reference; use `bounding_box.center` Z as a beam height.

**Do:** read the edge endpoint directly (`edge.start.position`, `edge.end.position`); use `bounds.min.z` or `bounds.max.z` to get a face level; raycast to terrain surface edge.

This is a cross-domain axiom — see `readmes/agents/noelle.md` Universal Rules, and each agent file Design Decisions entry for 2026-05-13.

### 9. Waypoint marker Z behavior — CONFIRMED 2026-05-14

> **Change control:** Do not modify marker Z placement, geometry, or attribute storage without a
> written plan reviewed against this rule. The approach below was confirmed working after a session
> of failures from alternative approaches. The two failure modes to avoid: (1) using `elevation_at`
> instead of `ground_z_at` → marker stems cause double-CLEARANCE_HEIGHT stacking; (2) passing
> marker `beam_z` attribute as absolute Z without reading `terrain_z` → circles appear at wrong level.

Waypoint markers default to `terrain_z + CLEARANCE_HEIGHT`. The user can drag the marker up/down
to adjust Z. The `beam_z` attribute is the authoritative routing elevation.

**Code locations:**
| What | File | Method |
|------|------|--------|
| Initial drop | `jpod_connect_tool.rb` | `drop_marker_at_cursor` |
| Live drag | `jpod_connect_tool.rb` | `onMouseMove` |
| Drag commit | `jpod_connect_tool.rb` | `commit_marker_move` |
| Routing read | `jpod_connect_tool.rb` | `collect_markers_live` |
| Terrain detection (skips stems) | `jpod_terrain.rb` | `Terrain.ground_z_at` |
| Span floor_z (skips stems) | `jpod_terrain.rb` | `Terrain.snap_to_terrain` |

**Placement algorithm (`drop_marker_at_cursor`, `onMouseMove`):**
```ruby
# jpod_connect_tool.rb
terrain_pt = Terrain.ground_z_at(view.model, pt.x, pt.y)
pt = Geom::Point3d.new(pt.x, pt.y, terrain_pt.z + Constants::CLEARANCE_HEIGHT)
```
`ground_z_at` (not `elevation_at`) is mandatory — marker stems are solid geometry from terrain to
beam level. `elevation_at` hits the stem top face and returns beam_z instead of terrain_z, causing
the next marker placed nearby to stack an additional CLEARANCE_HEIGHT above the stem.

**Attributes stored on every marker group (`jpod_connect_tool.rb → drop_marker_at_cursor`):**
- `JPods / beam_z` (inches) — routing elevation; used by `collect_markers_live` and PathBuilder
- `JPods / terrain_z` (inches) — terrain level; used by draw overlay for reference circle Z
- `JPods / marker_number` — identity key; also signals `ground_z_at` to skip this marker in future raycasts

**Geometry layers, bottom to top:**
- 1 m circle at terrain_pt — anchor reference
- 5 m circle at terrain_pt — curve radius visual aid
- 10 m circle at terrain_pt — curve radius visual aid
- Dark thin stem from terrain_pt to beam_pt
- Orange cap post at beam_pt

**`snap_to_terrain` along spans (`jpod_terrain.rb → Terrain.snap_to_terrain`):**
Calls `ground_z_at` (not `elevation_at`) so marker stems along a span do not corrupt
PathBuilder's `floor_z` computation when the beam path runs near existing markers.

---

### 10. CP anchor height — CONFIRMED 2026-05-14

> **Change control:** Do not modify the anchor_zs calculation in `build_segment` without a
> written plan reviewed against this rule and `readmes/sketchup/jpods-cp-regression-guard.md`.
> Three alternative approaches were tested and failed in this session before the committed code
> was restored. The working algorithm is: `from_cp[:center].z + BEAM_DEPTH` (non-traffic-circle)
> or `+ BEAM_DEPTH / 2` (traffic circle). Do not replace this with terrain raycasts.

**Code location:** `jpod_network.rb` → `Network.build_segment` → anchor_zs block (~line 514)

```ruby
# jpod_network.rb — build_segment
is_traffic_circle = lambda do |ent|
  fid = ent&.get_attribute("JPods", "formation_id", "").to_s.downcase
  fid.include?("traffic_circle")
end
from_z = from_cp[:center].z + (is_traffic_circle.call(from_entity) ? Constants::BEAM_DEPTH / 2.0 : Constants::BEAM_DEPTH)
to_z   = to_cp[:center].z   + (is_traffic_circle.call(to_entity)   ? Constants::BEAM_DEPTH / 2.0 : Constants::BEAM_DEPTH)
cp_anchor_zs = [from_z, to_z]
```

**How it works:**
- `from_cp[:center].z` = stub bottom face Z, computed by `centroid_min_z` in
  `jpod_structure_tool.rb → scan_stub_pair_tips` (minimum Z of gate-end vertex cluster)
- Non-traffic stations: stub bottom + `BEAM_DEPTH` (0.5 m) = beam top face Z — PathBuilder
  path runs along beam top; beam extrusion hangs downward so bottom face lands at stub bottom
- Traffic circles: stub bottom + `BEAM_DEPTH / 2` (0.25 m) — historical seam-height compensation
  for the traffic circle template geometry

**What was tried and failed (2026-05-14):**
1. `Terrain.elevation_at(CP_xy) + CLEARANCE_HEIGHT` — hits different station geometry at each CP;
   S012.CP1 off by 0.6 m, S044.CP0 off by 1.2 m depending on station template and terrain slope
2. `Terrain.ground_z_at(CP_xy) + CLEARANCE_HEIGHT` — skips station geometry entirely, returns
   raw terrain; same error magnitudes, different direction
3. `from_cp[:center].z` directly (no + BEAM_DEPTH) — places beam 0.5 m below stub bottom

**Source of from_cp[:center].z:**
```ruby
# jpod_structure_tool.rb — centroid_min_z
def self.centroid_min_z(verts)
  n = verts.size.to_f
  Geom::Point3d.new(verts.sum(&:x) / n, verts.sum(&:y) / n, verts.map(&:z).min)
end
# called at: scan_stub_pair_tips → outer_pt = centroid_min_z(clusters[:outer])
# CP center Z = midpoint(outer_pt_a.z, outer_pt_b.z) ≈ outer_pt.z (they share beam bottom Z)
```

**F-07 note:** When station templates are redesigned at 4.6 m stub height, revisit this calculation.
Until then: `from_cp[:center].z + BEAM_DEPTH` is the only confirmed-working anchor.

---

### 11. CP text labels must be refreshed after every Build
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

### Template Model Specification — Required Naming (Noelle reads these)

Every template `model.skp` in `templates/track_formations/<formation_id>/` must carry
the following naming so Noelle can identify `structure_type` without guessing:

| What to set | Where | Value | Example |
|-------------|-------|-------|---------|
| **Tag (layer name)** on the top-level component | SketchUp Tags panel → assign to the outer component | `station` or `traffic_circle` | tag = `station` |
| **Instance name** | Entity Info → Name field on the top-level component | Same as tag | name = `station` |
| **Definition name** | Must start with the type | `station_*` or `traffic_circle*` | `station_line_end`, `traffic_circle7` |

These three are redundant by design. Noelle reads them in priority order:

1. `JPods.structure_type` attribute on the placed instance (written at placement by StructurePlacer)
2. Entity tag (layer name) on the placed instance itself
3. Instance name of the placed instance
4. Definition name prefix (`station` or `traffic_circle`)

**Why redundant:** A placed instance created before the placement fix will not have the
JPods attribute. Noelle still reads the entity tag and instance name from what SketchUp
provides. The model author controls the truth — Noelle reads it, does not invent it.

**Adding a new structure type** (e.g., `junction`, `depot`):
1. Set the tag, instance name, and definition name prefix in `model.skp`
2. Add the type to the priority-read list in `noelle.rb` (`%w[station traffic_circle junction depot]`)
3. Add the template entry to `noelle_features.json`
4. Define the routing behaviors (landing/originating/pass) in the entry

**Noelle never writes `structure_type` — she reads it from what the model author placed.**

**Testing this — close template models first:**
`Sketchup.active_model.definitions.load(path)` fails or returns stale data if the
target `model.skp` is currently open in SketchUp. Before running any structure_type
verification script, close all template models (`File > Close` or quit and reopen with
only the network model open). The traffic_circle7 load failure in earlier tests was
caused by the model being open at the time.

### Station identity contract
- Tag: `station` (set on the top-level component in the template model.skp)
- Instance name: `station` (set in Entity Info on the top-level component)
- Definition name: starts with `station_` (e.g. `station_line_end`, `station_thru_dip`)
- On placement, StructurePlacer writes `structure_type='station'` to the JPods attribute
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


---

## skp_jpods — Project Folder Management (added 2026-05-15)

### Purpose

Students working on JPods networks tend to scatter files across Downloads, Desktop,
and random project folders. The plugin guides them toward a single, consistent layout:

```
~/Documents/skp_jpods/
  README.md                      ← agreement doc / user guide
  utilities/
    projects.json                ← registry of all known project locations
    organize.sh                  ← last-used file-move script (inspectable)
  CA_Gilroy_Casino2/             ← one folder per .skp, named to match
    CA_Gilroy_Casino2.skp
    CA_Gilroy_Casino2.followme.json
    CA_Gilroy_Casino2.vehicles.json
    CA_Gilroy_Casino2.map.json
    trips/
```

### First-run agreement — two chances, then hands off

The plugin stores the user's choice in SketchUp preferences
(`Sketchup.read_default("JPods", "skp_jpods_setup")`).

| Moment | Status before | Action |
|---|---|---|
| Plugin loads (3 s timer) | nil | First offer: YES sets up folder; NO records "offered_once" |
| First Build click | "offered_once" | Second offer: YES sets up; NO records "declined" + creates utilities/ only |
| Any model open | "agreed" + outside skp_jpods | Prompt to move (see below) |
| Any subsequent open | "declined" | Silent; registry updated only |

After two NO answers the plugin never prompts again. "Declined" users still get their
file locations recorded in `utilities/projects.json` on every Connect Guideways commit.

### Open-model location check

Fires via the AppObserver `onOpenModel` / `onNewModel` hook (1.5 s deferred timer).
Conditions for prompt:
- Status = "agreed"
- Model has a saved path
- `File.dirname(model.path)` does not start with `SKP_JPODS_ROOT`

Dialog offers three choices:
- **YES** — Write `utilities/organize.sh`, launch it in background, quit SketchUp.
  Script waits for SketchUp to exit, moves all project files, reopens the model.
- **NO** — Quit SketchUp. User moves files manually.
- **CANCEL** — Keep working here; no action.

### Finder button (Network Editor toolbar)

| Model location | Button behavior |
|---|---|
| Already in skp_jpods | `open -R followme.json` — Finder opens with file selected |
| Outside skp_jpods | Shows move dialog (same YES/NO/CANCEL as open-model check) |
| Model unsaved | Message: save first |

### organize.sh

Written to `~/Documents/skp_jpods/utilities/organize.sh` (not /tmp).
Persistent and inspectable. Content pattern:
```bash
#!/bin/bash
# JPods project organizer — generated YYYY-MM-DD HH:MM
# Moves: <base> → <dest_dir>
while pgrep -x "SketchUp" > /dev/null 2>&1; do sleep 1; done
sleep 1
mkdir -p <dest_dir>
mv <file1> <dest_dir>/
mv <file2> <dest_dir>/
...
open -a 'SketchUp' <dest_dir>/<base>.skp
```

### Standing Rule — Every Track Formation Template Must Have line.json

`templates/track_formations/<folder>/line.json` is required for every template.
It is the authoritative declaration of what Track groups exist and their routing role.

**Schema: `jpods-template-lines-v1`**

Each entry in `"lines"` has:
- `name` — SketchUp group entity name
- `layer` — SketchUp tag (layer) name (the actual distinguishing field for identically-named groups)
- `role` — `"routing"` | `"parking"` | `"slop"`
- `notes` — optional explanation

The routing engine reads `role` from line.json to decide which structure tracks to
include in route/trip overlays. Never use heuristic name-pattern filters as a
substitute — the layer name is the ground truth.

| Role | Meaning |
|------|---------|
| `routing` | Vehicle travel path — included in route and trip overlays |
| `parking` | Vehicle storage bay or approach — excluded from routing |
| `slop` | Dead-end transition piece — excluded from routing |

**Checklist for new templates:**
1. Create `line.json` in the template folder using the schema above
2. Populate `name` + `layer` from SketchUp Entity Info (select each Track group)
3. Set `role` for every track
4. Run Create > Export Template Library to verify and add `length_m`
5. Commit `line.json` with the `.skp`

See `templates/track_formations/README.md` for the full schema and folder index.

---

### Connect Guideways commit — canonical JSON path rule

`commit()` in `jpod_connect_tool.rb` uses `default_json_path(model)` (canonical path
beside the .skp) unless `saved_json_path` is in the **same directory** as the model.
This prevents copy-saved models from silently writing back to the original model's
followme.json. On first commit, `CA_Gilroy_Casino2.followme.json` is created beside
the .skp automatically.

### Key files

| File | Role |
|---|---|
| `jpod_project.rb` | `SKP_JPODS_ROOT`, `offer_setup`, `perform_setup`, `check_model_location`, `collect_project_files`, `note_unmanaged_project` |
| `jpod_network_editor.rb` | Finder button callback, `show_in_finder_or_organize`, `launch_organize_script`; `collect_project_files` delegated to `jpod_project.rb` |
| `boot.rb` | 3 s startup offer timer; AppObserver `check_model_location_deferred` call |
| `jpod_connect_tool.rb` | `commit()` canonical JSON path rule; `note_unmanaged_project` call |


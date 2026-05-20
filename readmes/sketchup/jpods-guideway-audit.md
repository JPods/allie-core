# jpod_guideway.rb — Code Audit
**Date:** 2026-05-01
**Status:** Pending re-review after SketchUp UI rework
**Action:** Re-run Prompt 1–7 audit sequence after UI refactor is complete

---

## Context

Full independent audit of `jpod_guideway.rb` (7,082 lines) run 2026-05-01 before any refactoring.
Bill is reworking the SketchUp user interface. This audit should be re-run after that work is complete
to check whether the UI changes altered responsibility boundaries or coupling.

**Trigger:** When Bill says "re-run the guideway check" or "review guideway after UI rework."

---

## File Location

```
/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods/jpod_guideway.rb
```
7,082 lines as of 2026-05-01.

---

## 14 Responsibilities Identified

| # | Responsibility | Approx lines | Notes |
|---|---------------|-------------|-------|
| A | Beam geometry construction | 94–110, 2745–2960 | Self-contained, no class vars |
| B | Support column + solar panel placement | 3177–3430 | Calls A helpers |
| C | Structure template loading & scaling | 3019–3175 | Calls B |
| D | Dead-end cap management | 2815–3018 | Reads/writes `@@cap_points` |
| E | FollowMe path collection & GL visualizer | 3492–3870 + inner class | Reads/writes `@@structure_followme_paths_cache` |
| F | FollowMe JSON export | 163–1004 | Calls E + G; writes .followme.json; writes `@@noelle_objection` |
| G | Platform management | 1509–1790 | Calls F (reads platforms[]) |
| H | Vehicle placement | 1789–2300 | Calls G, F, L |
| I | Trip assignment | 2295–2530, 5185–5480 | Calls F, K |
| J | Animation runtime (tick loop) | 6010–6363 | Hub — reads ALL class vars; calls E,F,K,D,L,M,N |
| K | Route graph (legacy topology) | 4160–4895 | Writes `@@route_graph`, `@@gw_index`, `@@uturn_terminals` |
| L | Trip validation & path building | 5569–5960 | Zero class var deps — safest extraction |
| M | Camera follow | 2612–2690 | Reads `@@camera_follow_vehicle_id`, `@@anim_state` only |
| N | Logging & diagnostics | 4616–4695, 5061–5140 | Reads state snapshots only |

---

## Class Variable Map

| Variable | Written by | Read by |
|----------|-----------|---------|
| `@@anim_state` | `start_animation` (init), tick (update), `stop_animation` (clear) | tick, `stop_animation`, `update_camera_follow`, diagnostics |
| `@@gw_index` | `start_animation` → `build_gw_index`, `stop_animation` | tick, `graph_successor_for`, `graph_endpoint_continuous?` |
| `@@seg_cache` | `seg_data_for` (on demand), `stop_animation` | `seg_data_for`, tick |
| `@@route_graph` | `start_animation` → `build_route_graph`, `stop_animation` | tick, diagnostics snapshot |
| `@@cap_points` | `start_animation` → `build_dead_end_cap_points`, `stop_animation` | `outbound_capped?`, tick |
| `@@uturn_terminals` | `start_animation` → `load_declared_uturn_terminals`, `stop_animation` | `declared_uturn_terminal_for_outbound?`, `reverse_successor_for_declared_uturn` |
| `@@structure_followme_paths_cache` | `build` (nil), `build_structure_followme_paths`, `stop_animation` (nil) | `structure_followme_paths` (cached getter) |
| `@@noelle_objection` | `load_followme_json_graph` (set/clear) | `start_animation` pre-flight guard |
| `@@anim_ticks` | tick (increment) | tick (periodic summary gate) |
| `@@camera_follow_vehicle_id` | `start_camera_follow`, `stop_camera_follow`, `stop_animation` | `update_camera_follow`, tick |
| `@@anim_timer` | `start_animation`, `stop_animation` | `animating?`, `stop_animation` |
| `@@vehicle_monitor_timer` | `start_vehicle_followme_monitor`, `stop_vehicle_followme_monitor` | `stop_vehicle_followme_monitor` |

**Key insight:** All 12 class variables are initialized in `start_animation` and cleared in `stop_animation`.
They form one coherent runtime state block, not 12 independent pieces.

---

## Dependency Map

```
A  Beam Geometry          — no dependencies (safe to extract first)
B  Support Columns        → calls A
C  Structure Templates    → calls B
D  Dead-end Caps          ↔ @@cap_points
E  FollowMe Collection    ↔ @@structure_followme_paths_cache
F  FollowMe JSON Export   → calls E, G; writes .followme.json
G  Platform Management    → calls F (reads platforms[])
H  Vehicle Placement      → calls G, F, L
I  Trip Assignment        → calls F, K
J  Animation Runtime      ← THE HUB → calls E,F,K,D,L,M,N; reads ALL @@
K  Route Graph            ↔ @@route_graph, @@gw_index, @@uturn_terminals
L  Trip Validation        — no dependencies (safe to extract second)
M  Camera Follow          → reads @@camera_follow_vehicle_id, @@anim_state
N  Logging & Diagnostics  → reads state snapshots only
```

---

## Extraction Priority (when ready to refactor)

| Priority | Extract | Target file | Rationale |
|----------|---------|-------------|-----------|
| 1st | L — Trip Validation & Path Building | `jpod_trip_builder.rb` | Zero class vars, pure functions, independently testable |
| 2nd | M — Camera Follow | merge into `jpod_vehicle_runtime.rb` | Tiny, read-only on class vars |
| 3rd | A — Beam Geometry | `jpod_guideway_geometry.rb` | No class vars, ~400 lines |
| 4th | F + E together | `jpod_followme_export.rb` | Tightly coupled pair, extract together |
| Last | J + K together | `jpod_animation_runtime.rb` | Must be extracted as one unit; all class vars become instance vars |

---

## What to Check After UI Rework

When re-running this audit:

1. **Has `start_animation` grown?** It was the hub for all initialization. UI changes may have added more init paths.
2. **Are there new class variables?** Check the top of the class for new `@@` declarations.
3. **Did the UI rework touch responsibility L?** Trip validation is the safest first extraction. If UI added display logic to it, that changes the calculus.
4. **Did any UI callbacks get embedded in the animation tick?** That would be a new coupling to note.
5. **Line count delta:** Was at 7,082. If now >7,500, the file has continued growing and extraction is more urgent.

Re-run Prompts 1–7 from the audit sequence (saved in session 2026-05-01) against the updated file.

---

## Audit Prompts (re-run after UI rework)

Save these for re-use:

**Prompt 1 (this analysis):** Responsibilities, class var map, dependency map, extraction boundary.

**Prompt 2:** Audit animation runtime state — list every `@@` and `$` variable, where written/read, whether reset cleanly on reload.

**Prompt 3:** Audit constants mutation — `apply_primary_constraint_overrides`, `remove_const`/`const_set` call sites.

**Prompt 4:** Compare `vehicle_json_schema.md` spec to what is actually written to `vehicles.json`.

**Prompt 5:** Audit error handling consistency across `jpod_network.rb`, `jpod_structure_tool.rb`, `jpod_noelle_bridge.rb`.

**Prompt 6:** Map HTML dialog / Ruby task sync problem in `jpod_console.rb` + `dialogs/console.html`.

**Prompt 7:** Identify safest first refactor — load order, dependency on `jpod_network.rb`, minimum viable extraction.

# JPods Console — Command Inventory and Consolidation Plan
**Date:** 2026-05-08
**Scope:** `jpod_console.rb`, `dialogs/console.html`
**Goal:** Reduce 32 commands to 25 by removing redundant entries, merging near-duplicates, and relocating misplaced commands.

---

## Current Command Inventory (32)

All commands are registered in `TASKS` in `jpod_console.rb`. Categories appear in the left panel of the console dialog.

### Network (3)

| ID | Label | Purpose |
|----|-------|---------|
| `open_network_editor` | Open Network Editor | Activates the Network Editor viewport tool from the console. |
| `list_constraints` | List Active Constraints | Prints JPods network constraints (cost-per-km, energy rates) with current vs. default values. |
| `erase_guideways` | Erase All Guideways | Deletes every guideway and column group. Destructive; confirmation required. |

### Network Check (5)

| ID | Label | Purpose |
|----|-------|---------|
| `list_platform_tagged_items` | List Platform Tagged Items | Scans placed structures; lists everything tagged `platform`. Confirms tags before vehicle placement. |
| `mark_platform_endpoints` | Mark Platform Endpoints | Places red (inbound) and blue (outbound) cones at each platform. Visual direction check. |
| `clear_platform_markers` | Clear Platform Markers | Removes those cones. Companion to Mark Platform Endpoints. |
| `inspect_model_geometry` | Inspect Model Geometry | Prints structure IDs + CP coordinates; checks dead-end cap placement. Pre-build sanity check. |
| `inspect_structure` | Inspect Structure CPs | Selected structure only — prints CP positions and tangent vectors. Requires selection. |
| `inspect_guideway` | Inspect Guideway Endpoints | Selected guideway only — prints first/last beam-path points and point count. Requires selection. |

*Note: table above shows 6, not 5. Current category count in code is 5 because Inspect Structure CPs and Inspect Guideway Endpoints are both under Network Check.*

### Builder (6)

| ID | Label | Purpose |
|----|-------|---------|
| `restore_dead_end_caps` | Restore Dead-End Caps | Scans all structures for open stubs (segment deleted after connection); places synthetic cap plates on all found. |
| `restore_dead_end_cap_at` | Restore Dead-End Cap at CP | Same, but for one specific CP (structure ID + CP index). |
| `calculate_cps` | Calculate CPs | Re-detects connection points on all structures; replaces instances to reflect current template SKP. |
| `build_network_noelle` | Build Network | Builds guideway geometry from `network_definition.connections` in followme.json; exports fresh followme.json. |
| `show_route_overlay` | Show Routes Between Stations | Draws forward (blue) and return (red) route lines between two selected stations. |
| `clear_route_overlay` | Clear Route Overlay | Removes the route overlay geometry. Companion to Show Routes. |

### Noelle (1)

| ID | Label | Purpose |
|----|-------|---------|
| `validate_and_show` | Validate Network + Show | Full diagnostic pass: Noelle integrity check → Natalie routing oversight → FollowMe overlay → platform endpoint cones. |

### Vehicles (9)

| ID | Label | Purpose |
|----|-------|---------|
| `list_network_resources` | List Vehicles & Platforms | Lists available vehicle template IDs and all platform IDs from followme.json. Reference lookup. |
| `place_vehicle_platform` | Place 5V at Platform | Places the 5-vehicle sequence at one origin platform routed to one destination. Manual, targeted. |
| `assign_directed_route` | Assign Directed Route to Nora | Assigns a manually typed line sequence to a selected vehicle. Developer/debug use. |
| `show_trip_path` | Show Trip Path | Draws the selected Nora's route as an orange overlay in the 3D model. |
| `show_trip_detail` | Show Trip Detail | Shows the same Nora's route as JSON in the console modal (lengths, structures, merging/diverging lines). |
| `clear_all_vehicles` | Clear All Vehicles | Removes all vehicle components and wipes trip data. Destructive. |
| `run_5v_platform_test` | Run 5V | Full automated test: clears all, places 5 Noras at every platform, assigns one-way trips, auto-starts animation after 5 s. |
| `shuffle_to_departure` | Shuffle to Departure End | Manually advances idle (parked) vehicles toward the departure slots. Normally automatic; this is the manual trigger. |
| `station_platform_demo` | Station Platform Demo | Places one vehicle at slot 1 and steps it through the queue on a timer. Teaching/demo tool. |

### Animation (7)

| ID | Label | Purpose |
|----|-------|---------|
| `camera_follow_selected_nora` | Camera Follow Selected Nora | Locks the SketchUp camera to a specific vehicle during animation. Requires selection. |
| `camera_follow_stop` | Stop Camera Follow | Releases the camera. Companion to Camera Follow. |
| `show_followme_paths` | Show FollowMe Paths | Activates the FollowMe viewport overlay AND re-exports followme.json. |
| `export_followme_json` | Export FollowMe Network JSON | Writes `<model>.followme.json` only. Does not activate the overlay. |
| `export_trip_jsons` | Export Trip JSONs | Writes one `trips/<model>.trip.<nora_id>.json` per vehicle. Superseded by the JSON button in the trip table. |
| `start_animation` | Start Animation | Starts vehicle animation on all guideways. |
| `stop_animation` | Stop Animation | Stops all vehicle animation. |

### Developer (2)

| ID | Label | Purpose |
|----|-------|---------|
| `export_debug_bundle` | Export Debug Bundle | Packages logs, network JSON, vehicle JSON, and route diagnostics into a timestamped folder. |
| `audit_network_log` | Audit Network + Export Log | Validates every vehicle itinerary step-by-step (Noelle/Natalie/Nora checks) and writes a `.log` file. |

---

## Overlaps and Redundancies

### Group 1 — Three "show the network" commands (Show FollowMe Paths, Export FollowMe JSON, Validate Network + Show)

All three write or use followme.json. Their differences:

| Command | Writes JSON | Activates overlay | Runs Noelle validation | Marks platforms |
|---------|:-----------:|:-----------------:|:----------------------:|:---------------:|
| Export FollowMe Network JSON | ✓ | — | — | — |
| Show FollowMe Paths | ✓ | ✓ | — | — |
| Validate Network + Show | ✓ | ✓ | ✓ | ✓ |

**Show FollowMe Paths** is fully contained inside **Validate Network + Show**. It adds no capability that the full validate command does not already provide.

### Group 2 — Two "trip visualization" commands (Show Trip Path, Show Trip Detail)

Both take a Nora ID and show its route. One draws the orange 3D overlay; the other opens the JSON modal. These are complementary views of the same data. The `JSON` button already appears in the trip table for every vehicle with an assigned trip — clicking it opens the same modal as Show Trip Detail. The task command is therefore a duplicate entry point.

### Group 3 — Two "restore cap" commands (Restore Dead-End Caps, Restore Dead-End Cap at CP)

Both do exactly the same thing — scan for open stubs and place a dead_end_cap. The only difference is scope: all stubs vs. one specific stub. This can be a single command with an optional `structure_id` parameter (blank = all stubs).

### Group 4 — Two "inspect selection" commands (Inspect Structure CPs, Inspect Guideway Endpoints)

Both print diagnostic data for a selected entity to the Ruby Console. They differ only in the entity type. A single **Inspect Selection** command that auto-detects the selection type (Structure vs. Guideway) handles both with zero loss of function.

### Group 5 — Export Trip JSONs is superseded

The `JSON` button in the trip table now calls `build_trip_detail` on-the-fly, including line lengths, structures, and merging/diverging connections. It requires no file export. Export Trip JSONs writes the same data (less rich) to disk. Its only remaining use is external file sharing, which is a developer console operation, not a menu item.

### Group 6 — Shuffle to Departure End is a manual fallback

Run 5V triggers the parking shuffle automatically (Natalie, every 3 s). Shuffle to Departure End exists to manually trigger the same step after a stopped or failed animation. It is a debug/recovery tool, not a primary workflow step. It is worth keeping but should be moved out of the main list or clearly marked as a recovery command.

---

## Consolidation Plan

### Step 1 — Remove (3 commands)

| Command | Reason |
|---------|--------|
| **Show FollowMe Paths** | Fully contained inside Validate Network + Show. |
| **Export Trip JSONs** | Superseded by the on-the-fly JSON button in the trip table. Keep the underlying `export_all_trip_jsons` Ruby method for external sharing, but remove the console task entry. |
| **Show Trip Detail** (task entry only) | The trip table's JSON button does the same thing. Remove the task; the button stays. |

### Step 2 — Merge (2 pairs → 2 commands)

| Merge | Result | Change |
|-------|--------|--------|
| Restore Dead-End Caps + Restore Dead-End Cap at CP | **Restore Dead-End Caps** | Add an optional `structure_id` parameter. Blank = all stubs. Filled = one structure only. |
| Inspect Structure CPs + Inspect Guideway Endpoints | **Inspect Selection** | Auto-detect whether selection is a JPods Structure or JPods Guideway and run the appropriate diagnostic. No parameters. |

### Step 3 — Relocate (3 commands)

| Command | From | To | Reason |
|---------|------|----|--------|
| Show Routes Between Stations | Builder | Noelle | Visualization/validation tool, not a build step. |
| Clear Route Overlay | Builder | Noelle | Companion to Show Routes. |
| Shuffle to Departure End | Vehicles | Developer | Manual fallback/recovery only. Not a primary workflow step. |

### Step 4 — Rename (1 command)

| Old label | New label | Reason |
|-----------|-----------|--------|
| Validate Network + Show | **Validate + Inspect** | "Show" is too generic. The command runs Noelle validation, Natalie oversight, overlay activation, and platform markers. "Inspect" better describes the diagnostic intent. |

---

## After Consolidation — 25 Commands

| Category | Commands |
|----------|----------|
| **Network (3)** | Open Network Editor · List Active Constraints · Erase All Guideways |
| **Network Check (5)** | List Platform Tagged Items · Mark Platform Endpoints · Clear Platform Markers · Inspect Model Geometry · Inspect Selection *(merged)* |
| **Builder (3)** | Restore Dead-End Caps *(merged)* · Calculate CPs · Build Network |
| **Noelle (4)** | Validate + Inspect *(renamed)* · Show Routes Between Stations *(relocated)* · Clear Route Overlay *(relocated)* |
| **Vehicles (7)** | List Vehicles & Platforms · Place 5V at Platform · Assign Directed Route to Nora · Show Trip Path · Clear All Vehicles · Run 5V · Station Platform Demo |
| **Animation (4)** | Camera Follow Selected Nora · Stop Camera Follow · Export FollowMe Network JSON · Start Animation · Stop Animation |
| **Developer (3)** | Shuffle to Departure End *(relocated)* · Export Debug Bundle · Audit Network + Export Log |

Net change: **32 → 25** (7 removed or merged). All underlying Ruby methods are preserved — only the console task entries change.

---

## Implementation Checklist

- [ ] Remove `show_followme_paths` task from TASKS array
- [ ] Remove `export_trip_jsons` task from TASKS array
- [ ] Remove `show_trip_detail` task from TASKS array
- [ ] Merge `restore_dead_end_caps` + `restore_dead_end_cap_at` — add optional `structure_id` param
- [ ] Merge `inspect_structure` + `inspect_guideway` → `inspect_selection` — auto-detect selection type
- [ ] Move `show_route_overlay` and `clear_route_overlay` to category: "Noelle"
- [ ] Move `shuffle_to_departure` to category: "Developer"
- [ ] Rename `validate_and_show` label to "Validate + Inspect"
- [ ] Update `console.html` category filter list if categories are rendered statically

---

## What Does NOT Change

- All underlying Ruby methods (`export_all_trip_jsons`, `show_followme_paths`, etc.) are preserved — they remain callable from the Ruby Console and from other code.
- The trip table `JSON` button (`cmd_show_trip_json`) is not changed.
- The `Show Trip Path` orange overlay command stays — it is the 3D view, distinct from the JSON view.
- The `Export Debug Bundle` and `Audit Network + Export Log` developer commands are unchanged.
- `Shuffle to Departure End` is preserved; only its category changes.

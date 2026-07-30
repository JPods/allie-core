# JPods Console — Archived Tasks

**Archived:** 2026-05-18  
**Reason:** Console cleanup. These 27 tasks were removed to achieve a lean, map.json-centric  
workflow. The full run lambdas are preserved in `su_jpods/jpod_console_archive.rb` so any  
task can be restored by moving it back into the `TASKS` array in `jpod_console.rb`.

---

## Current Workflow (16 tasks kept)

| ID | Label | Category |
|----|-------|----------|
| `open_network_editor` | Network Editor | Network |
| `calculate_cps` | Calculate CPs | Builder |
| `place_marker` | Place Marker | Builder |
| `export_followme_json` | Export FollowMe Network JSON | Animation |
| `build_network_noelle` | Build Network | Builder |
| `validate_and_show` | Validate Network + Show | Noelle |
| `generate_map_json` | Generate map.json | Network |
| `show_followme_overlay` | Show FollowMe Overlay | Network |
| `clear_followme_overlay` | Clear FollowMe Overlay | Network |
| `show_route_overlay` | Show Route Between Stations | Builder |
| `clear_route_overlay` | Clear Route Overlay | Builder |
| `show_trip_path` | Show Trip Path | Vehicles |
| `list_vehicles` | List Vehicles | Vehicles |
| `set_vehicle_destination` | Set Vehicle Destination | Vehicles |
| `start_animation` | Start Animation | Animation |
| `stop_animation` | Stop Animation | Animation |

---

## Archived Tasks (27)

### 1. `list_constraints` — List Active Constraints
**Category:** Network  
**Why archived:** NetworkEditor constraint inspection is an editor concern, not a console workflow step. Re-add if constraint debugging becomes a regular need.  
**Ruby impl:** See `jpod_console_archive.rb` → `list_constraints`

Prints active primary constraints and rates of change for the model, including current values, defaults, and override status. Calls `JPods::NetworkEditor.constraint_payload(model)`.

---

### 2. `list_platform_tagged_items` — List Platform Tagged Items
**Category:** Developer  
**Why archived:** Platform tag scanning was a pre-map.json diagnostic. map.json + feature.json is now the single geometry authority — platform tags are validated at Build time, not inspected manually.  
**Ruby impl:** See `jpod_console_archive.rb` → `list_platform_tagged_items`

Calls `JPods::StructurePlacer.list_platform_tagged_items(model)`. Reports structure count, stations with platforms, platform item count.

---

### 3. `mark_platform_endpoints` — Mark Platform Endpoints
**Category:** Developer  
**Why archived:** Red/blue cone markers were useful while platform directionality was being debugged. map.json `direction` field now carries that information permanently.  
**Ruby impl:** See `jpod_console_archive.rb` → `mark_platform_endpoints`

Places red cones at platform entrances, blue cones at exits. Calls `JPods::JPodGuideway.mark_platform_endpoints(model)`.

---

### 4. `clear_platform_markers` — Clear Platform Markers
**Category:** Network Check  
**Why archived:** Companion to `mark_platform_endpoints` — archived together.  
**Ruby impl:** See `jpod_console_archive.rb` → `clear_platform_markers`

Calls `JPods::JPodGuideway.clear_platform_endpoint_markers(model)`.

---

### 5. `register_selected_as_structure` — Register Selected as Structure
**Category:** Developer  
**Why archived:** `calculate_cps` auto-registers all unregistered entities before running. Manual registration is now only needed in unusual edge cases. The Developer-category duplicate `register_selected_as_structure_dev` is also archived.  
**Ruby impl:** See `jpod_console_archive.rb` → `register_selected_as_structure`

Stamps selected Group/ComponentInstance with `structure_id` and optional `model_id`. Calls `JPods::StructurePlacer.next_structure_id(model)`.

---

### 6. `inspect_model_geometry` — Inspect Model Geometry
**Category:** Developer  
**Why archived:** Pre-Build geometry audit. Replaced by `validate_and_show` (Noelle integrity check) + map.json gap flags at animation time.  
**Ruby impl:** See `jpod_console_archive.rb` → `inspect_model_geometry`

Calls `JPods::StructurePlacer.list_structures(model)` and `JPods::StructurePlacer.check_cap_ends(model)`.

---

### 7. `restore_cap_end_at` — Restore Dead-End Cap at CP
**Category:** Diagnostics  
**Why archived:** Surgical cap restoration is handled automatically by `calculate_cps` pre-flight. Uncommon enough that a one-off console task adds clutter without proportional value.  
**Ruby impl:** See `jpod_console_archive.rb` → `restore_cap_end_at`

Params: `structure_id` (string), `cp_index` (integer). Calls `JPods::JPodGuideway.restore_cap_end_at(model, sid, idx)`.

---

### 8. `list_network_resources` — List Vehicles & Platforms
**Category:** Vehicles  
**Why archived:** `list_vehicles` covers the live vehicle state. Platform IDs are now read from map.json `features`. Combo list was pre-map.json.  
**Ruby impl:** See `jpod_console_archive.rb` → `list_network_resources`

Calls `JPods::JPodGuideway.available_vehicles` and `JPods::JPodGuideway.load_followme_platforms(model)`.

---

### 9. `assign_directed_route` — Assign Directed Route to Nora
**Category:** Vehicles  
**Why archived:** Direct line-sequence assignment bypasses Natalie's trip planner. `set_vehicle_destination` is the correct workflow — Natalie resolves the route from origin/destination via map.json.  
**Ruby impl:** See `jpod_console_archive.rb` → `assign_directed_route`

Requires vehicle selection. Calls `JPods::JPodGuideway.assign_trip_to_vehicle(model, veh, seq)`. Param: `line_sequence` (comma-separated closed loop e.g. `L12,L18,L22,L12`).

---

### 10. `show_trip_detail` — Show Trip Detail
**Category:** Vehicles  
**Why archived:** JSON trip detail dump is useful for debugging but clutters the day-to-day console. Re-add if trip-planning debugging becomes a recurring need.  
**Ruby impl:** See `jpod_console_archive.rb` → `show_trip_detail`

Calls `JPods::JPodGuideway.build_trip_detail(model, vid)` and returns JSON.

---

### 11. `camera_follow_selected_nora` — Camera Follow Selected Nora
**Category:** Animation  
**Why archived:** Camera-follow was speculative and untested in production. Re-add when the feature is confirmed working.  
**Ruby impl:** See `jpod_console_archive.rb` → `camera_follow_selected_nora`

Requires vehicle selection. Calls `JPods::JPodGuideway.start_camera_follow(model, veh)`.

---

### 12. `camera_follow_stop` — Stop Camera Follow
**Category:** Animation  
**Why archived:** Companion to `camera_follow_selected_nora` — archived together.  
**Ruby impl:** See `jpod_console_archive.rb` → `camera_follow_stop`

Calls `JPods::JPodGuideway.stop_camera_follow(model)`.

---

### 13. `clear_all_vehicles` — Clear All Vehicles
**Category:** Vehicles  
**Why archived:** Destructive reset that was used to set up 5V test runs. With 5V test archived, this is no longer needed in normal workflow. Re-add if batch vehicle management returns.  
**Ruby impl:** See `jpod_console_archive.rb` → `clear_all_vehicles`

Calls `JPods::JPodGuideway.clear_all_vehicles(model, clear_trips: true)`. Risk: `:destructive`.

---

### 14. `run_5v_platform_test` — Run 5V
**Category:** Vehicles  
**Why archived:** 5V was a platform slot stress test that required the old platform slot infrastructure. With map.json as the geometry authority, vehicle placement follows `set_vehicle_destination` → `start_animation` workflow instead.  
**Ruby impl:** See `jpod_console_archive.rb` → `run_5v_platform_test`

Params: `speed_ms`, `origin_platform_id`, `destination_platform_id`, `slot_count`. Calls `JPods::JPodGuideway.run_5v_standard_test` or `place_vehicle_at_platform`. Auto-starts animation after 5s.

---

### 15. `shuffle_to_departure` — Shuffle to Departure End
**Category:** Vehicles  
**Why archived:** Station slot shuffling was part of the 5V platform test protocol — archived with it.  
**Ruby impl:** See `jpod_console_archive.rb` → `shuffle_to_departure`

Calls `JPods::JPodGuideway.run_5v_shuffle_forward(model)`.

---

### 16. `station_platform_demo` — Station Platform Demo
**Category:** Vehicles  
**Why archived:** Slot-by-slot advancement demo was a teaching aid for the platform queue concept. No longer needed once map.json animation is working end-to-end.  
**Ruby impl:** See `jpod_console_archive.rb` → `station_platform_demo`

Params: `station_id`, `vehicle_id`, `slot_count`, `interval_s`. Calls `JPods::JPodGuideway.station_platform_demo(...)`.

---

### 17. `show_followme_paths` — Show FollowMe Paths
**Category:** Animation  
**Why archived:** Old GL viewport overlay approach using `JPodFollowMeTool`. Replaced by `show_followme_overlay` which draws permanent geometry from map.json.  
**Ruby impl:** See `jpod_console_archive.rb` → `show_followme_paths`

Calls `JPods::JPodGuideway.show_followme_paths(model)`. Required tool activation (press Esc to dismiss) — not permanent geometry.

---

### 18. `export_trip_jsons` — Export Trip JSONs
**Category:** Animation  
**Why archived:** Per-vehicle trip JSON files were an intermediate artifact before map.json. Trip state now lives in vehicle attributes + map.json; separate trip files are redundant.  
**Ruby impl:** See `jpod_console_archive.rb` → `export_trip_jsons`

Calls `JPods::JPodGuideway.export_all_trip_jsons(model)`. Writes `trips/<model>.trip.<nora_id>.json`.

---

### 19. `random_trips` — Random Trips
**Category:** Animation  
**Why archived:** Random closed-loop route assignment (ene_railroad style) was exploration code. The current workflow is deliberate: origin + destination → Natalie → trip. Random trips belong in a test harness, not the production console.  
**Ruby impl:** See `jpod_console_archive.rb` → `random_trips`

Params: `min_hops`, `max_hops`, `speed_ms`, `force`. Calls `JPods::JPodGuideway.assign_random_trips_to_all_vehicles(...)`.

---

### 20. `export_debug_bundle` — Export Debug Bundle
**Category:** Developer  
**Why archived:** Useful for bug reports but not part of routine workflow. Re-add if a support/bug-reporting workflow is formalized.  
**Ruby impl:** See `jpod_console_archive.rb` → `export_debug_bundle`

Creates timestamped bundle at `<model_dir>/debug_bundles/bundle-<ts>/` with JSON artifacts and log tail. Calls `JPods::Logging.tail(...)` if available.

---

### 21. `inspect_structure` — Inspect Structure CPs
**Category:** Developer  
**Why archived:** CP inspection was essential during CP detection development. Now that detection is stable, it's a diagnostic tool rather than a workflow tool. Re-add for CP regression debugging.  
**Ruby impl:** See `jpod_console_archive.rb` → `inspect_structure`

Requires selection of a `JPods Structure` group. Prints CP world positions and tangent vectors from `connection_points` attribute.

---

### 22. `inspect_guideway` — Inspect Guideway Endpoints
**Category:** Developer  
**Why archived:** Guideway endpoint inspection was essential while the Build pipeline was being tuned. Stable now. Re-add for Build regression debugging.  
**Ruby impl:** See `jpod_console_archive.rb` → `inspect_guideway`

Requires selection of a `JPods Guideway` group. Prints `connection_id`, `track_index`, `from_key`, `to_key`, `next_cid`, beam path point count, start/end positions.

---

### 23. `run_all_checks` — Run All Checks
**Category:** Network Check  
**Why archived:** Combined diagnostic pass over structure geometry, cap ends, and platform tags. These checks run automatically at Build/Validate. Manual re-run is no longer needed in normal workflow.  
**Ruby impl:** See `jpod_console_archive.rb` → `run_all_checks`

Calls `list_structures`, `check_cap_ends`, `list_platform_tagged_items`, `mark_platform_endpoints` in sequence.

---

### 24. `audit_network_log` — Audit Network + Export Log
**Category:** Developer  
**Why archived:** Detailed step-by-step Noelle/Natalie/Nora itinerary audit. Valuable for debugging trip-planning bugs but too verbose for routine use. Re-add when trip-planning regressions need diagnosis.  
**Ruby impl:** See `jpod_console_archive.rb` → `audit_network_log`

Indexes all guideway groups by `connection_id`/`track_index`, loads vehicle itineraries, validates entry/exit/next_cid/connectivity per step. Writes `<model>_network_audit_<ts>.log`.

---

### 25. `connect_guideways` — Connect Guideways (Developer)
**Category:** Developer  
**Why archived:** `calculate_cps` automatically activates the Connect Guideways tool on completion. The standalone Developer-category duplicate is redundant.  
**Ruby impl:** See `jpod_console_archive.rb` → `connect_guideways`

Calls `model.select_tool(JPods::JPodConnectTool.new)`.

---

### 26. `register_selected_as_structure_dev` — Register Selected as Structure (Dev)
**Category:** Developer  
**Why archived:** Same functionality as task #5 (`register_selected_as_structure`) — Developer-category duplicate archived with the original.  
**Ruby impl:** See `jpod_console_archive.rb` → `register_selected_as_structure_dev`

Identical behavior to `register_selected_as_structure`.

---

### 27. `erase_guideways_dev` — Erase All Guideways
**Category:** Developer  
**Why archived:** Destructive developer tool with no place in production workflow. Edit → Undo is the correct recovery path, not a console erase.  
**Ruby impl:** See `jpod_console_archive.rb` → `erase_guideways_dev`

Erases all `JPods Guideway` and `JPods Columns` groups. Risk: `:destructive`.

---

## How to Restore an Archived Task

1. Open `su_jpods/jpod_console_archive.rb`
2. Find the task by its `id:` key
3. Copy the entire `{ id: ..., ... }` hash
4. Paste it into the `TASKS` array in `jpod_console.rb` at the appropriate position
5. Reload: `load '/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/jpod_console.rb'`

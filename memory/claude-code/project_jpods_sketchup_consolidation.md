---
name: JPods SketchUp Plugin Consolidation 2026-05-13
description: Consolidating su_jpods, su_mostly, su_j1week into single canonical plugin; su_jpods is the target; others archived
type: project
---

su_jpods is the canonical plugin. su_mostly and su_j1week are archived (moved out of Plugins folder, zipped).

**Why:** Bill wants a student-friendly network design tool. Students should be able to geolocate terrain, place structures, connect CP nodes via Bezier, adjust with markers, deploy guideways, run animation.

**Workflow sequence (confirmed):**
1. Geolocate + terrain (SketchUp built-in)
2. Place structures (stations, traffic circles) — jpod_structure_tool.rb
3. Orient models
4. Activate CP nodes (Calculate CPs menu item)
5. Connect CP pairs via Bezier — Connect Guideways tool (jpod_connect_tool.rb)
6. Adjust with Markers (W key or Place Markers tool); markers sort by coordinate number; x/y/z influence; add to connection via Network Editor marker panel
7. Deploy guideways (3m spread, 4.6m clearance above terrain) — Build button
8. Animation (TBD)

**Completed this session (2026-05-13):**
- CLEARANCE_HEIGHT changed from 5.5m → 4.6m in jpod_constants.rb
- Fixed `clear_drafts` method (comment was misplaced inside method body)
- Fixed production JSON crash in jpod_network.rb (undefined `from_sid`/`to_sid` at lines 1435-1436 → replaced with `start_key`/`end_key`)
- Added 4-button toolbar to main.rb: Place Structure | Connect Guideways | Place Markers | Network Editor (icons from toolbar_icons/)
- Added marker panel to Network Editor: click connection card → click marker button → appended to via list
- Marker panel backed by `push_markers_to_dialog(model)` Ruby method + `cmd_refresh_markers` callback
- Duplicate CP violation: clears all connections + alerts in red, writes empty JSON, calls JPodConnectTool.clear_drafts
- Marker→Waypoint rename throughout all status bar/menu strings (group name "JPod Marker" kept for file compat)
- W key works WHILE CP is active (green), before clicking second CP — waypoints accumulate in @pending_via_pts/@pending_via_nums and the dashed blue preview bezier bends through them live
- On second CP click, pending waypoints are passed into commit() → JSON via_markers populated from the start
- Re-clicking a committed CP loads its existing waypoints back into pending so you can add more
- update_via_markers_in_dialog: after any W-key drop or drag-move, pushes via list to Network Editor dialog → green plan path and via input field update within 500ms
- update_json_via_markers: now falls back to default_json_path so Build always reads waypoints even if editor wasn't opened
- ene_railroad best practices applied: onSetCursor (crosshair 671) on ConnectTool + MarkerTool; resume(view) on MarkerTool
- Toolbar: 4 buttons in main.rb (Place Structure, Connect Guideways, Place Markers, Network Editor)

**Connect Tool waypoint/cursor work (same session, later):**

SketchUp Vector3d does NOT support `vector * Float` — crashes with ArgumentError.
Must use explicit: `Geom::Vector3d.new(v.x * scalar, v.y * scalar, v.z * scalar)`

Fixed locations so far:
- `offset_path` ~line 1113: `avg.normalize * miter` → explicit component multiply
- `bezier_pts_via` ~line 1332: `unit * tangents[i].dot(unit)` → `proj = Vector3d.new(unit.x*dot, unit.y*dot, unit.z*dot)`
- `bezier_pts_via` ~line 1337: `bis.normalize * s` → `bn = bis.normalize; Vector3d.new(bn.x*s, bn.y*s, bn.z*s)`

**Cursor states (onSetCursor):**
- Dragging marker → cursor 648 (4-arrow move)
- Hovering near marker → cursor 643 (hand/grab)
- Gold/Cyan with pending waypoints → cursor 671 (crosshair)
- Gold/Cyan no pending → cursor 280 (pencil)
- Idle → cursor 671 (crosshair)

`@hover_marker` (bool) set in onMouseMove by checking @markers cache within 2m radius.

**Draw method — source of truth:**
- ALL connections use `@@draft_connections` as live source; no JSON read in draw loop.
- `d[:center_pts]` = dashed center bezier (rebuilt by `rebuild_draft_paths`)
- `d[:paths]` = dual track lines (rebuilt by `rebuild_draft_paths`)
- `visible_draft_connections` excludes the active @from_cp/@edit_cp draft
- Cyan edit state: draws `d[:center_pts]` (dim teal) + `d[:paths]` (bright cyan) — NOT @edit_preview_pts, so drag updates flow through rebuild_draft_paths
- `@edit_preview_pts` is still computed in onMouseMove but no longer used in draw (redundant)

**update_draft_via_pt flow (drag):**
1. onMouseMove → drag branch → raycast to terrain → `update_draft_via_pt(num, pt)`
2. `draft[:via_pts][i] = pt` + `rebuild_draft_paths(idx)`
3. `rebuild_draft_paths` → `d[:paths]` + `d[:center_pts]` rebuilt
4. draw reads `d[:center_pts]` and `d[:paths]` → curve follows marker in real time

**Pending test:**
- User testing cursor + live drag curve update in SketchUp as of 2026-05-13

**How to apply:** Reference when continuing JPods SketchUp plugin work; always verify changes compile by loading in SketchUp Ruby console

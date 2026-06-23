---
name: Network operations must never modify station instances or tags
description: Build, Animate, Populate must never change entity names, tags, or component definitions on station instances; templates are read-only during network ops
type: feedback
---

Network operations (Build, Animate, Populate, CP Calculate) must NEVER modify station component instance names, SketchUp tags/layers, or component definitions.

**Why:** Session 2026-06-23 — every guideway in the model was renamed to `gw_lift_in` (an internal track name from the station_parking template). Root cause not definitively identified but likely a SketchUp component definition collision when replacing station types. All station instances were contaminated.

**How to apply:**
- Build creates NEW groups (seg_, Support_, Solar_) — never modifies existing station geometry
- Animation writes pod tracking attributes only (destination_station_id, parking_slot, station_authority) — never touches station identity
- `ensure_followme_json` must skip template folders (track_formations)
- `retag_solar` in LayerManager must only tag entities it created, not station internal geometry
- Any code that walks model.entities and writes .name or .layer must verify the entity is one WE created, not a station internal entity
- Template definitions are read-only during network operations

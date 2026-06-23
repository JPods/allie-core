# Handoff — 2026-06-23

## Status: Build profile smoothing, BOM, capacity estimator, camera follow

### What Works
- Waypoint beam_z flows through build profile (reads attribute, no Z flattening)
- Piecewise grade envelopes between waypoint anchors (not CP endpoints)
- Smooth guideways primary: hard_floor_z removed from profile, columns absorb terrain
- XY radius 5m, Z radius 60m defaults, Z span 80m (background)
- Build Profile controls in Network Display (Apply persists to model)
- BOM button in Network Display — scans built geometry, writes {model}.bom.json
- Capacity button in Pods tab — Current/5×/NetMax with pax/pod, load time, ADA lifts
- Camera follow: click pod row → snaps 25m behind, 20m right, 5m above (editable)
- Console cleanup: Result bar + Log level dropdown + SU Console button (one line)
- Runtime Console removed from NE iframe, Validate button removed
- Console 1 is the console — c2 not actively maintained

### What Needs Work
- Travel app: callbacks archived in codearchive/jpod_trip_dialog.rb, not wired to dialog
- Terrain raycast: skip-based approach works but z=0 fallback still possible at waypoints; interpolation patch covers it; proper fix (terrain group filtering) attempted, hit SketchUp API limitations (Entities has no raytest)
- BOM: vehicle counts not populated (needs animation data), systems/power counts static
- Two-stage Z profile (sharp local + smooth long-distance) — on ouch list
- 4 non-planar build segments still need fix

### Key Commits
- `1df1a60` — Smooth guideways, BOM, capacity, camera, console cleanup
- `bc8dcdf` — Waypoint Z: beam tracks through beam_z, piecewise grade envelopes

### Terrain Raycast TFTS
- Problem: raycast hits marker geometry, exhausts steps, returns z=0
- Tried: Entities.raytest → Entities has no raytest method
- Tried: Symbol sentinel :no_terrain → Point3d.z requires Float
- Working: bounding-box skip + z=0 interpolation from neighbors
- Principle: the working simple approach beats the elegant broken one

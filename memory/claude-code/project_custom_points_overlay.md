---
name: Custom Points overlay tool
description: Generic coordinate overlay in MeshMobility — load JSON/CSV/GeoJSON of any points; presets dropdown; DART stations first use; persists with .jpd
type: project
---

Custom Points overlay built 2026-07-18. General-purpose point overlay tool in MeshMobility.

Three input methods: presets dropdown (auto-detected from overlays/ folder), file upload (JSON/CSV/GeoJSON), or paste.

First preset: `dart_stations.json` — 86 DART rail stations across all 6 lines (Blue, Green, Orange, Red, Silver, TRE), extracted from DART GTFS feed.

**Why:** Existing transit infrastructure (DART, MARTA, MBTA, etc.) is the demo anchor. Show JPods feeder networks extending their reach. Also works for any point data — UPS depots, grocery chains, competitor stations.

**How to apply:** Custom Points button in Overlays panel under "Other" section. Presets populate on first panel open. Points persist with .jpd save/load. Code: `overlays.js` (CustomPoints module) + `overlays.py` (4 API endpoints). Readme at `readmes/60-custom-points-overlay.md`.

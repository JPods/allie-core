---
name: MeshMobility data overlays
description: 7 cities with AADT + fatal crashes + all-crash density; census overlays (pop density, property values, jobs); embedded in .jpd
type: project
---

**Overlay system established 2026-07-05/06:**

Per-city overlay files in mesh_mobility/overlays/:
- `aadt_{city}.geojson` — state DOT traffic counts
- `accidents_{city}.geojson` — NHTSA FARS fatal crashes
- `crash_density_{city}.geojson` — all-severity aggregated to 200m grid

City keys: ok (Tulsa), mn (Bloomington), ma (Weymouth), nj (Secaucus), sc (Greenville), tx (Arlington), wa (Spokane)

**Why:** All-crash density is the primary placement signal. Fatal-only is too sparse for small cities (20 crashes vs 121K). Shopping areas and dangerous intersections light up in the all-crash view.

**How to apply:** Auto-detect city from network centroid on .jpd load. Overlay data embedded in .jpd — one file, no external dependencies.

Census overlays added 2026-07-06: population density, property values, jobs — from Census API via scripts/census_overlays.py.

**Why:** Population density + property values + jobs = demand model. Combined with crash data = safety + demand signal.

Custom Points overlay added 2026-07-18: generic coordinate overlay tool. Load any JSON/CSV/GeoJSON point data. Presets dropdown auto-populated from overlays/ folder. First preset: dart_stations.json (86 DART rail stations). Persists with .jpd save. See readmes/60-custom-points-overlay.md.

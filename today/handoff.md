# Handoff — 2026-07-05

## Where We Left Off
Built Tulsa JPods network using Noelle's data-driven workflow. Pulled Oklahoma AADT (736 features, ODOT ArcGIS) and FARS accident data (389 fatal crashes, NHTSA 2020-2022). Discovered that local arterials are 9x more dangerous per unit of traffic than interstates (87.7 vs 9.3 crashes/10K AADT). Established Noelle's Draft pattern: stations only on the arterial grid, highways as boundaries, crash rate as primary signal. Bill confirmed 1x2 mile grid optimal based on FHWA road density (14 mi/sq mi) and 1:14 JPods-to-road ratio. Built Noelle Draft button + printable report in Route-Time GUI. Placed 68 stations on Tulsa grid (v2). Bill saved v1 (333 structures following highways) and is working v2 circles and arrangement. All patterns documented in noelle.md, readmes/48, and vector store (49,356 chunks).

## Do This First Next Session
1. **Load Bill's Tulsa network** — he's adding circles and arranging. Open his saved .jpd, run simulation, snapshot with `noelle_propose.py snapshot "Bill v1"`.
2. **Wire CityTool** — embed Census + Claude keys from `config/wc_credentials.json`. File at `~/Documents/08_JPods/000_websiteReWork/citytool.html`. For library.jpods.com (Hostinger).
3. **Pedestrian density overlay** — still empty (`overlays/mobility.geojson`). Try WalkScore API or Strava Metro free tier for Tulsa.
4. **Noelle Draft generalization** — current grid detection clusters from AADT data automatically, but could benefit from explicit city-name parameter and road-name labeling (Tulsa grid = "Memorial Dr @ 71st St" not "Grid (36.059, -95.900)").
5. **Discuss Allie Mac Mini** — Bill asked to discuss dedicated always-on hardware at next session start.

## Open Problems
- Noelle Draft grid detection uses AADT clustering — works for Tulsa's regular grid but may not detect irregular street patterns in non-grid cities.
- `route_time.py` and `__main__.py` are duplicate entry points — cleanup deferred.
- Pedestrian density overlay still empty — no WalkScore API key yet.
- Allie MCP returning empty responses (ask_allie returned no output twice this session).
- SC overlay files renamed to `aadt_sc.geojson` / `accidents_sc.geojson` — need per-city overlay selector in GUI.

## What Was Decided (and Why)
- **Stations only, no circles in Draft** — Noelle can see corridors from data but cannot determine where they branch/loop. Circles require local knowledge. Greenville v1 placed circles and they were mostly wrong.
- **Highways are boundaries, not corridors** — people don't walk to interstates. Crash rate data proved it: 87.7/10K on local streets vs 9.3/10K on interstates. Stations belong on the walkable grid.
- **1x2 mile grid is optimal mesh** — FHWA HM-72 says Tulsa has 14 road mi/sq mi. Bill's payback target is 1 mi JPods per 12-18 mi road. 1x2 = 1:14, dead center of range.
- **Crash rate per 10K AADT is primary signal** — not raw crash count, not raw AADT. The normalized rate reveals where trips are deadliest per unit of traffic. This is where JPods saves the most lives per dollar.
- **Overlay files swapped per city** — SC files renamed with `_sc` suffix, OK files copied to `aadt.geojson`/`accidents.geojson`. Need proper per-city selector eventually.

## Files Changed This Session
- `route_time/gui/api.py` — added `/api/noelle/draft` and `/api/noelle/report` endpoints (data-driven proposal + printable HTML report)
- `route_time/gui/static/index.html` — added Noelle palette section (Draft + Report buttons), noelle.js script tag
- `route_time/gui/static/noelle.js` — NEW: Noelle Draft JS module (panel UI, confirm dialog, API calls)
- `route_time/overlays/aadt_ok.geojson` — NEW: 736 Oklahoma AADT features from ODOT ArcGIS (2023)
- `route_time/overlays/accidents_ok.geojson` — NEW: 389 fatal crashes from NHTSA FARS (2020-2022)
- `route_time/overlays/aadt.geojson` — now OK data (was SC); SC saved as `aadt_sc.geojson`
- `route_time/overlays/accidents.geojson` — now OK data (was SC); SC saved as `accidents_sc.geojson`
- `~/Allie/readmes/agents/noelle.md` — 6 new design decisions (stations-only, highways-as-boundaries, crash rate signal, road ratio, 1x2 grid, Draft button)
- `~/Allie/readmes/48-noelle-data-driven-design.md` — added "Established Pattern" section with full Tulsa methodology
- `~/Allie/.chroma_db_noelle/` — 6 new vector store chunks (4 rules + 2 data sets)

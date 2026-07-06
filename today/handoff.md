# Handoff — 2026-07-05

## Where We Left Off
Massive Route-Time + Noelle data-driven network design session. Fixed RT server (Werkzeug CSS bug, leaflet-arrowheads). Built Noelle's entire design pipeline: vector store (49K+ chunks), MCP server (6 tools), proposal workflow, AADT/accident overlays. Noelle proposed Greenville network from SCDOT AADT data, Bill designed v4 (110 structures, 1 component, 0 orphans). Validated 60% mode shift / 2.1-year payback model. Loaded extensive evidence (Harvard $64B study, Morgantown PRT, Praetor Capital, Glydways, Bolden Street, JPods valuation, walkability data, 40+ city models) into all four vector stores. Stress-tested the 60% claim with 18 ranked objections. Noelle MCP registered. CityTool reviewed — Census API key saved, needs wiring.

## Do This First Next Session
1. **Build Tulsa network** — run `noelle_propose.py` with Oklahoma DOT AADT data. Bill has existing `OK_Tulsa_2026-05-04.jpd` (249 structures) as reference. Pull OK AADT from odot.org.
2. **Read `readmes/48-noelle-data-driven-design.md`** — the full process doc for the Noelle workflow.
3. **Read `readmes/49-60pct-mode-shift-stress-test.md`** — 18 objections ranked by importance, data gaps to fill.
4. **Wire CityTool** — embed Census key, test Claude narrative with Bill's key from `config/wc_credentials.json`. File at `~/Documents/08_JPods/000_websiteReWork/citytool.html`.
5. **Query Noelle MCP** — `ask_noelle` is registered. Test it works in new session.

## Open Problems
- Lost Bill's 1-hour Greenville edit when server restarted mid-session. SCAR: never restart RT server without confirming save captured the right state.
- CityTool needs Census + Claude keys wired for public use on library.jpods.com (Hostinger).
- Pedestrian density overlay still empty (`overlays/mobility.geojson`) — needs WalkScore API key or Strava Metro data.
- 3 interior dead ends found and fixed in Greenville v4, but designer should verify edge terminals are intentional.
- `route_time.py` and `__main__.py` are duplicate entry points — cleanup deferred.

## What Was Decided (and Why)
- **Circles are connective tissue** — ~1:1 ratio with stations. Stations have 2 CPs (linear), circles have 4 (junctions). Without enough circles, networks fragment into islands.
- **Primary network = AADT-driven, secondary = accident-driven.** Dense accident sites on moderate-AADT roads define where parallel processor mesh must run.
- **Closest-open-CP connect** — server finds nearest available pair between two structures. Prevents user from accidentally connecting wrong CPs.
- **Static file serving bypasses Werkzeug** — `send_from_directory` has Content-Length bug with compressed encoding. Direct file reads instead.
- **Save remembers file handle** — `showSaveFilePicker` handle stored in `App._saveHandle`, cleared on New. Open also sets it.
- **60% mode shift is the target, not 3-5%** — matches European levels. Backed by Paris (12.8%→6% car share), Culdesac Tempe (zero parking), Morgantown (53 years operational). Gates+Khosla investing $420M in Glydways validates the concept.
- **JPods costs $7.4M/mile not $15M** — from Bill's 5YearPLBS spreadsheet. Spans $75K each, piers $10K, stations $1M.

## Files Changed This Session
- `route_time/gui/app.py` — static file serving fix, bypasses Werkzeug bug
- `route_time/gui/static/index.html` — collapsible sections, city search moved, keyboard shortcuts in help, overlay buttons, leaflet-arrowheads local
- `route_time/gui/static/app.js` — keyboard shortcuts 1-6, closest-CP connect, save handle, dirty flag, unsaved warning, flash messages, Alt+drag fix
- `route_time/gui/static/simulator.js` — orphan (green) + dead end (yellow) circles on Run
- `route_time/gui/static/overlays.js` — AADT point rendering, accident tooltip fix, red gradient colors
- `route_time/gui/static/style.css` — collapsible palette sections
- `route_time/gui/static/leaflet-arrowheads.js` — downloaded locally (was broken CDN)
- `route_time/gui/static/leaflet-geometryutil.js` — dependency for arrowheads
- `route_time/gui/api.py` — closest-CP connect, /api/network/describe endpoint
- `route_time/noelle_propose.py` — NEW: propose/snapshot/diff/history workflow
- `route_time/overlays/aadt.geojson` — NEW: 84 SC DOT traffic count stations
- `route_time/overlays/accidents.geojson` — NEW: 1,019 NHTSA FARS SC crashes
- `route_time/noelle_history/*.jpd` — 5 snapshots of Greenville iterations
- `route_time/readmes/setup.md` — was README.md, moved and updated
- `route_time/readmes/keyboard-shortcuts.md` — NEW: all shortcuts documented
- `route_time/README.md` — NEW: index pointing to readmes/
- `~/Allie/scripts/noelle-vectorstore.py` — NEW: seed/index/ingest-network/search
- `~/Allie/scripts/noelle-mcp-server.py` — NEW: 6-tool MCP server registered
- `~/Allie/.chroma_db_noelle/` — NEW: 49K+ chunks vector store
- `~/Allie/readmes/48-noelle-data-driven-design.md` — NEW: full process doc
- `~/Allie/readmes/49-60pct-mode-shift-stress-test.md` — NEW: 18 objections + data gaps
- `~/Allie/readmes/agents/noelle.md` — design decisions table updated
- `~/Allie/readmes/27-route-time.md` — keyboard shortcuts, closest-CP connect added
- `~/Allie/config/wc_credentials.json` — Census API key added
- `route-time_maps/SC_Greenville_Noelle_v3.jpd` — Noelle's connected mesh
- `route-time_maps/SC_Greenville_Noelle_v4_designer.jpd` — Bill's final edit

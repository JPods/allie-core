# Handoff — 2026-07-12

## Where We Left Off
Built CrashHarvester as a standalone data supply chain app (`00_working_code/CrashHarvester/`, pushed to `JPods/CrashHarvester`). MeshMobility reads ALL overlay data from the CH library only — 566 lines of government API code removed from `api.py`. Drawing tools built (Cmd+click corridors, Option+click adjust, Shift delete). Build on Lines places stations along designer-drawn corridors. Bill drew DC corridors and built a network from them. All three repos pushed: mesh_mobility `e4d0e52`, CrashHarvester `9c94e69`, allie-core `bc7741b`. Target: Tuesday July 15 release.

## Do This First Next Session

### If MeshMobility Release (PRIORITY — Tuesday July 15):
1. **Populate CrashHarvester library** — run FARS harvester all 50 states county-level, run HPMS all 50 states. Bill has a full prompt for this task.
2. **Move `mobility_data/` into `CrashHarvester/`** — consolidate. Update import in `mesh_mobility/gui/api.py`.
3. **Remove fake crash data** — crashes:fatal ratio < 3:1 = FARS repackaged. Real states: AK, CO, DC, DE, IA, ID, IL, MA, OK, OR, PA, TN, UT, VA, WA.
4. **Test end-to-end** — DC, Greenville SC, Tulsa OK. Drawing tools + Build on Lines.
5. **Tighten traffic circle detection** at corridor crossings.

### If WC3 Polish:
1. Wire BrowserDetail row-click cascade — `detail_route` + `detail_mode` Settings
2. Keyboard modifiers — Cmd+Shift+Click (BrowserDetail), Cmd+Shift+Option+Click (ModelDetail)
3. Polish Dashboard — Action POLISH-DASHBOARD (#339)

## Open Problems
- `mobility_data/` exists both as sibling and copied into `CrashHarvester/` — needs consolidation
- Snap radius on drawing tools (~200m) may need tuning for dense urban areas
- Traffic circles not detected at line crossings when angle is wide
- Most states lack real all-severity crash data — need state DOT harvesting
- Census auto-fetch still in Fetch Data endpoint — should move to CH
- Drawn lines not saved in .jpd format — only in `drawn_lines/` directory
- Router.tsx duplicate routes (WC3)
- DataBrowser detail cascade not wired (WC3)

## What Was Decided (and Why)
- **No legacy fallbacks in api.py** — library or nothing. Break and fix. No `_overlay_path`, no government API calls from MeshMobility.
- **County-level library files** — `{type}/{state}_{county}.geojson`. Consumer decides granularity.
- **Modifier keys for drawing** — Cmd=draw, Option=adjust, Shift=delete. No toggle mode.
- **Overlays non-interactive by default** — tooltips OFF for work, ON for presentations.
- **Noelle owns slot count** — sets from data, user overrides only with explicit instruction.
- **Highway policies roadkill people** — not highways. Morgantown 1972 in overlay panel.
- **Algorithm library** — City Mesh, Crash Mesh, Build on Lines, Line, Custom. Never lose one.
- **More doors > bigger doors** — V ∝ n²/p. 50 slots handles 10K/hr. 15-min walk fine.

## Files Changed This Session
- `mesh_mobility/gui/api.py` — removed govt code, added library reader, crash_mesh, build_on_lines, line, drawn lines endpoints
- `mesh_mobility/gui/static/index.html` — DrawTool, CrashMesh, LineTool, threshold slider, Morgantown panel, tooltips, modifier keys
- `mesh_mobility/gui/static/overlays.js` — spatial params, threshold, crash cache, Morgantown stats, clearAll, setInteractive
- `mesh_mobility/gui/static/app.js` — unsaved check on Find City, clear overlays on city switch
- `mesh_mobility/gui/static/style.css` — ov-signal button
- `CrashHarvester/README.md` — full architecture doc
- `mobility_data/*.py` — library package (reader, schemas, registry, harvesters)

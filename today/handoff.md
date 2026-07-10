# Handoff — 2026-07-09

## Where We Left Off
Renamed Route-Time → MeshMobility across the full stack: Python package (`mesh_mobility/`), 12 Allie scripts, 5 Claude Code memory files, Noelle vector store (re-seeded + re-indexed, 50K chunks). Added grid rotation to the Mesh Network Estimate dialog — users set angle in degrees or click two map points to measure street grid angle. Austin tested at 25°, grid aligns perfectly to Congress/Lamar. Crash data registry built at `/Volumes/Allie/data/overlays/crash_data_registry.json` — 51 states FARS complete, 2 all-severity (OK, MA), 7 harvestable via ArcGIS, 39 need source hunting. Designed the Student Kit Program (Design → Survey → Build → Ride) and PiratesAndPatriots.com branding. All committed and pushed to both repos.

## Do This First Next Session
1. **Build the score endpoint** — `/api/network/score` computing 5 dimensions (coverage, safety, connectivity, efficiency, revenue) from existing overlay data. This is the foundation for gamification.
2. **Harvest the 7 ready states** — VA, FL, IA, TN, IL, OR, AK have confirmed ArcGIS endpoints for all-severity crash data. Run `allie-crash-convert.py --arcgis` for each. Add field mappings to FIELD_MAPS.
3. **Session-keyed state** — refactor `_state` in `api.py` from single dict to session-keyed dict. Enables multiple teams/individuals simultaneously.
4. **GPS survey capture** — HTML5 geolocation page: drop pin, photo, obstruction tag, POST to session. Minimal viable version.
5. **Kit bill of materials** — document the 4 tiers (Survey $20, Cargo $50, Scale $150, Rider $300) with specific parts and weekend build guides.

## Open Problems
- All 51 `crash_density_*.geojson` files are FARS fatals repackaged, not true all-severity. Only `crashes_all_ok.geojson` and `crashes_all_ma.geojson` have real state DOT data.
- 39 states have no known public all-severity crash data source — need Bill's help to find state DOT portals. Flagged in `crash_data_registry.json` with `hunt_with_bill: true`.
- Texas CRIS (richest crash data) locked behind interactive web app — no API.
- `route-time_maps/` sibling folder renamed to `mesh_mobility_maps/` but the git repo for mesh_mobility still tracks as `times.git` on GitHub — repo name unchanged.
- MeshMobility server restart still destroys in-memory network (never restart without confirming save).

## What Was Decided (and Why)
- **Up-Down / Left-Right instead of N-S / E-W** — city grids are rarely aligned to compass. Austin is 25°. Labels should describe the grid's own axes, not the compass.
- **Grid rotation in metres, not degrees** — 1° lat ≠ 1° lon. First implementation mixed lat/lon degrees during rotation and produced unrotated grids. Fix: rotate in uniform metre space, convert to lat/lon after.
- **No git for students** — git is a developer tool. Students need save/fork/share/timeline, which we build simpler. Design event logs go to our git for Noelle training.
- **Keep domain code "RT"** — short codes (RT, SU, PH) are internal. Renaming to MM everywhere adds confusion for no user benefit. User-facing text says MeshMobility; internal tags stay RT.
- **PiratesAndPatriots.com** — Bill owns the domain. Public face of the student program. Framing: "Want a sustainable future, create it. Government produces more of what is failing."

## Files Changed This Session

**mesh_mobility/ (32 files) — committed 365a9d3, pushed to JPods/times bill_dev:**
- All `.py` files — `from route_time.` → `from mesh_mobility.` imports
- `route_time.py` → `mesh_mobility.py` — standalone entry point renamed
- `gui/static/index.html` — N-S→Up-Down, E-W→Left-Right, grid angle input + measure button
- `gui/static/app.js` — Grid module: angle param, two-click measure tool, rotation in generate()
- `gui/static/style.css` — `.btn-small` class for measure button
- `gui/api.py` — `angle_deg` parameter, `_rotated()` function using metre-space rotation
- `runserver.sh`, `README.md`, `readmes/setup.md` — command references updated

**~/Allie/ (12 scripts) — committed 6f62eba, pushed to JPods/allie-core main:**
- `scripts/noelle-mcp-server.py` — paths, docstrings, tool descriptions
- `scripts/noelle-vectorstore.py` — paths, domain guesser, seed content
- `scripts/allie-crash-convert.py` — overlay path
- `scripts/allie-{mcp-server,reflect,capture,whatif,api}.py` — domain names
- `scripts/allie_{ask_claude,corpus_log,wc_client}.py` — domain lists
- `scripts/wc_mcp_server.py` — dispatch target name

**New files:**
- `/Volumes/Allie/data/overlays/crash_data_registry.json` — 51-state crash data status
- `~/Allie/readmes/50-student-kit-program.md` — full student program writeup
- Memory: `project_student_kit_program.md`, `project_pirates_and_patriots.md`

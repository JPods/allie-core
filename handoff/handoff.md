# Handoff — 2026-06-07

## Where We Stopped

JPods_station_parking is fully extracted and approved by all three agents (Noelle/Natalie/Sally).
Proof is clean. vector_in detection resolved after a long arc. Session ended on a clean state.

## What was completed this session

### vector_in detection — complete
The 172mm `vector_in` indicator edge in `gw_cp_in_*` components could not be found by any
of several recursive search strategies (sub-group nesting, face outer_loop scanning, tag checks).

Resolution: Bill made the vector_in indicator a **standalone component placed OUTSIDE `gw_cp_in_*`
but inside its bounding envelope** — visible to designers, does not affect path extraction.

Code path:
1. `_scan_vi` lambda builds `vi_entities` list from model.entities (tag = 'vector_in')
2. For each `gw_cp_in_N`: proximity match (<5m) to track endpoint in vi_entities list
3. `_vi_component_direction` extracts direction — FROM vertex = closer to component world
   insertion point; no local-origin constraint (SketchUp may offset component origin)
4. Fixed `Geom::ORIGIN` → `Geom::Point3d.new(0,0,0)` in lambda scope (constant lookup issue)

### Noelle RED FLAG policy
Missing vector_in is now a hard RED FLAG blocking approval (not a standing demand).
`vector_in_found: true/false` stored in extracted.json per `gw_cp_in_N` track.
Noelle reads it: true → passed, false → 🚩 flag.

### Agent learning layer (from prior session, completed this session)
All three validators write JSONL observations; record passed AND failed checks; guard
against empty data (false positives become learning points); trace successor graph on
broken connections.

### Final state — JPods_station_parking
- extracted.json rev 17
- vector_in_found: true for CP0 and CP1
- Noelle ✓ Natalie ✓ Sally ✓ Proof: 0 OK / 0 WARN / 0 SEVERE

## Open items for next session

1. **vector_in components needed** — station_line_end, station_thru_dip, traffic_circle7
   each need `gw_cp_in_*` vector_in indicator components added (same approach as parking station)
   then Extract Template run on each.

2. **`allie-agent-brief.py`** — first teaching brief ready to generate:
   `python3 ~/Allie/scripts/allie-agent-brief.py --formation JPods_station_parking`

3. **trial5** — stale template folder with no lines.json; appeared in batch Extract Template run.
   Check and remove if not intentional.

4. **Session-start reminder** — `load Sketchup.find_support_file('jpod_path_json.rb', 'Plugins/su_jpods')`
   if working with any template extraction (file changes often in this arc).

## Key commits (su_jpods_claude, this session)
- `921a929` — fix Geom::ORIGIN in lambdas; remove diagnostics
- `df33a58` — external vi_entity scan at model level
- `c35cbdb` — Noelle RED FLAG + vector_in_found in extracted.json
- `4daaf6e` — face outer_loop scanning + gw_cp_in_* scoping
- `82512f1` — recursive direction search
- `cd44c32` — legacy 222mm warning
- `5f75846` — VECTOR_IN_EDGE_MM = 172.0 constant

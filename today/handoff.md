# Handoff — 2026-06-04

## What Was Done This Session

Primary goal: complete `Models › Extract Template` on all 6 station templates.
All 6 now have clean `extracted.json` and `cp.json`. The goal is done.

### 1. station_thru_dip — extracted clean (✓ 27 ok, 0 warn, 0 severe)

Six severe junction gaps on first run. Three SketchUp fix passes:
- Snapped gw_platform → gw_platform_out endpoint (39mm gap)
- Snapped gw_platform_parking → gw_platform endpoint (89mm gap)
- Extended gw_far_main by 362mm to close gw_far_main → gw_cp_out_lead_0 gap (380mm → 0)
- Snapped gw_cp_in_lead_0 → gw_near_main_1 endpoint (17mm gap)

### 2. traffic_circle7 — extracted clean (✓ 112 ok, 0 warn, 0 severe)

Significant repair work across multiple issues:
- **Code: pass_chains topology** — `_validate_connectivity` in `jpod_path_json.rb` only knew platform-station topology. Added `has_pass_chains` branch for traffic-circle templates; pass_chains replace hold_loop + landing/exit chains entirely.
- **Code: landing_chains.note skip** — `"note"` key in `landing_chains` dict was being processed as a chain entry, producing format-error warnings. Fixed with `next if cp == 'note'`.
- **Code: early return on empty chains** — added `return` when no chains found instead of hitting the junction-check code with empty input.
- **Tag renaming in SketchUp** — Bill retagged 16 components (8 gw_cp_in_N and 8 connector tracks) to align CP numbering with cp.json positions. Also renamed `gw_N_in`/`gw_N_out` → `gw_in_N`/`gw_out_N` convention throughout lines.json.
- **JSON syntax fix** — stray double-quote at line 269 of lines.json (`"gw_out_1"",`) from text-replacement artifact.
- **Axis unification** — Ruby script to bake instance rotation into definition geometry. Changed absolute world positions but preserved all relative positions.

### 3. Designer risk list

`readmes/sketchup/jpods-template-designer-risks.md` — 9 real defects from this extraction session, formatted as a reference for future template authors.

### 4. All work committed

Commit `869e68d` — 74 files changed. All 6 templates:
| Template | Status |
|---|---|
| station_parking | ✓ |
| cps | ✓ |
| cpu | ✓ |
| station_line_end | ✓ |
| station_thru_dip | ✓ 27 ok |
| traffic_circle7 | ✓ 112 ok |

## Status

All 6 templates extracted. Migration not yet confirmed. The `[MIGRATION] Check Templates`
console command exists and should be run to get an official READY/FAIL status on each.

## Still Open

1. **[MIGRATION] Check Templates** — run in SketchUp console to confirm all 6 READY.
   Once all READY, archive: `mv _migrations/migration_check_templates.rb _migrations/archive/migration_check_templates.DONE.rb`
   and remove the console command registration.

2. **Three floating log lines** — "direction corrected (222mm indicator reversed sp↔ep)"
   from non-gw_cp_in entities during traffic_circle7 extraction. Minor logging cosmetic.
   These entities use the 222mm heuristic, not the vector_in tag, and they pass validation.
   Not blocking — investigate when touching that code path next.

3. **Arc undersampling in station_parking** — gw_uturn_0/gw_uturn_1 are 2-pt chord.
   Fix: open station_parking template → Workflow > Generate Template Data. No code needed.
   (Carried from 2026-06-03 handoff — still not done.)

4. **Hold Loop trip panel** — Hold Loop task run lambda does not emit `__TRIPSEQ__:` yet.
   (Carried from 2026-06-03.)

5. **S007 / S008 geometry drift** — proof shows SEVERE on multiple tracks. Not addressed.
   (Carried from 2026-06-03.)

## Next Session Start

```
load Sketchup.find_support_file('jpod_path_json.rb', 'Plugins/su_jpods')
```

1. Run `[MIGRATION] Check Templates` in the console
2. If all 6 READY → archive migration file (see command above)
3. Open station_parking template → Workflow > Generate Template Data → verify 56-pt arcs
4. Carry on with prior handoff items (Hold Loop trip panel, S007/S008)

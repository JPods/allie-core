# Handoff — 2026-06-16

## Status: station_thru_dip Shuffle + Departure PASS

Both station_thru_dip station tests now pass. The template is fully validated.

---

## What Was Fixed This Session

### Departure Test (pod at psmax disappeared)

Fixed in commit `57c3aa7` — blank `station_test_phase` fell into else branch →
`_dispatch_station_exit` fired immediately at whatever slot the pod was at.
Fix: set `shuffle_parked` during departure test tag loop so Sally's advance queue
processes pods to ps_max first. Also added `notify_station_activity` after `release_slot`
in `_dispatch_hold_loop_for_pod` and `_dispatch_station_exit` to trigger immediate advance.

### Shuffle Test (pod jumping from gw_cp_in_lead_1 to gw_platform)

Commit `d0b4a6d` — restructured `hold_loop_chain` to direct-park pattern (same as station_line_end).

**Root cause:** `hold_loop_chain.loop` ended at `gw_uturn_1` (outer ring). On promotion,
Sally dispatched an 8-track intersection-approach maneuver via `_final_approach_tracks` +
`_enqueue_hold_loop_return_park`. This two-dispatch sequence was failing — pod jumped
from the approach's first track to gw_platform.

**Fix:**
- `loop`: now 8 tracks ending at `gw_platform_parking` — traverses outer ring then takes
  platform approach at `gw_cp_in_lead_0 → gw_near_main_1 → gw_platform_in → gw_platform_parking`
- `to_platform: []` — `on_maneuver_complete` fires direct-park code path. One dispatch, no race.
- Removed from loop: `gw_near_main_2`, `gw_cp_out_lead_1`, `gw_uturn_1`

---

## Key Decision

**Direct-park is the one pattern for all templates.** "There needs to be only one sally
animation function." station_line_end proved it 2026-06-03; station_thru_dip now matches.
Intersection approach (`_final_approach_tracks`) stays in code but is not used for either
current template.

---

## Next Steps (ordered)

1. **Apply same framework to station_parking** — run Shuffle Test and Departure Test.
   Check if station_parking's hold_loop_chain needs the same direct-park treatment.

2. **Network animation on 2_thru_dip model** — station_thru_dip is validated at template
   level; test it in a full network Build + Animate run.

3. **Sally advance "path too short" fault** (filed 20260616T054917-fault.md) — advance
   ps3→ps4 on gw_platform_parking clips to zero-length path. Blocks queue compaction
   in full network runs. Not blocking template tests.

4. **Step 5:** remove map.json fallback from jpod_vehicle_anim.rb once network runs clean.

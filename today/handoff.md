# Handoff — 2026-06-11 (session 2)

## Status
Platform_shuffle test fixes applied and pushed (6f69a7e). Ready to re-run the test.

## What was fixed this session

**Root cause:** `station_test_phase=''` is the dispatch gate for originating chain. Pods arriving at the platform with empty phase would fire originating chain on their first dwell expiry — before Sally had a chance to advance them.

**Five fixes applied to jpod_vehicle_anim.rb + jpod_sally.rb:**

1. `_park_ps` arrival: initial landing sets `shuffle_parked` (prevents originating chain on first dwell)
2. `_advance_ps` arrival: sets `shuffle_parked` after each advance step
3. `shuffle_parked` dwelling branch — new semantics:
   - `slot < cap` → remove from `@@dwelling` only; pod stays in `@@pods` for Sally to advance
   - `slot >= cap` → phase='', @dwell_until=nil, `next` → next tick fires originating chain
4. `hold_loop_parked` dwelling branch: transitions to `shuffle_parked` lifecycle (was terminal — V1 never exited, `remaining` never reached 0)
5. `confirm_slots`: guard `model&.entities` nil to prevent crash

## Re-run platform_shuffle test

Reload both files in SketchUp Ruby console:
```
load Sketchup.find_support_file('jpod_vehicle_anim.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_sally.rb', 'Plugins/su_jpods')
```

Then: Workflow → Station Test → JPods_station_parking → platform_shuffle

**Expected behavior:**
- V2 (loops=0) and V3 (loops=0) land, get slots, Sally advances them forward each cycle
- V1 (loops=1) does 1 loop, returns, parks, then also enters shuffle lifecycle
- Each pod exits via originating chain when it reaches the highest slot
- Test polls `remaining == 0` → PASS

**Watch for:**
- `shuffle_parked ps{N}/{cap} — awaiting advance` log lines (pods holding correctly)
- `shuffle_parked ps{cap}/{cap} — at highest slot, queueing exit` (transition to originating chain)
- `originating chain → gw_cp_out_0` (departure)
- `erased at ... — originating chain complete` (entity gone, remaining drops)
- `confirm_slots error` should be gone (nil guard added)

## If test passes: 6-template regression
Re-run platform_shuffle for all 6 templates. station_thru_dip confirmed prior session.
Templates to confirm clean:
- JPods_station_parking ← current focus
- station_line_end
- station_thru_dip ✓
- traffic_circle7
- JPods_station_parking (network path, step 2)

## Pre-network audit (still pending from morning handoff)
Check JPods_station_parking and traffic_circle7 landing_chains:
- Rule: last track must be gw_platform_parking (or equivalent), NOT gw_platform
- station_thru_dip fixed last session ✓
- station_line_end confirmed correct ✓
- JPods_station_parking — CHECK lines.json in_cp0/in_cp1
- traffic_circle7 — CHECK lines.json

## Known risk
`hold_loop_return` dwelling handler (jpod_vehicle_anim.rb ~line 3021) still uses
`pod.entity.bounds.center` as seed_pos for park maneuver. Should be fine if landing
chains are correct (end at gw_platform_parking, not gw_platform). If park clips wrong,
fix: use `JPods::Sally.slot_position(sid, t_slot)` as seed anchor.

## Key files
```
su_jpods/jpod_vehicle_anim.rb  — shuffle_parked lifecycle (arrival handlers + dwelling branch)
su_jpods/jpod_sally.rb         — confirm_slots nil guard
```

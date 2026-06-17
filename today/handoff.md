# Handoff — 2026-06-17

## Status: transit_test implemented for traffic_circle7; station_parking Shuffle/Departure PENDING

---

## What Was Built This Session

### Transit Test — traffic_circle7 (no station platform)

Commit `1451c0f`. Three changes:

**build_fleet (jpod_vehicle_anim.rb):**
New transit route intercept between Sally hold_loop block and normal Natalie routing.
Checks `sally_transit_tracks` entity attribute (JSON array of fully-qualified track keys).
Stitches pts from all tracks into one maneuver and dispatches directly. Handles the case
where there's no `parked_station_id` or `sally_hold_loop_sid`.

**Console transit_test handler (jpod_console.rb):**
Added `when 'transit_test'` in the template path. Guarded parking_chain check so
it only runs for platform tests (transit_test has no platform). 4 vehicles placed at
gw_cp_in_N, each tagged with `sally_transit_tracks` = from_cpN_to_cp(N+3)%4 route.
`station_test_phase = 'exiting'` → vehicle erased when maneuver completes.

**HTML (dialogs/console.html):**
Replaced `ccw_traverse` with `transit_test` card for traffic_circle formations.
Binary pass/fail: all 4 vehicles exit = PASS.

**How the erase works:**
Vehicle with `station_test_phase='exiting'` enters dwelling after maneuver completes.
Dwelling handler fires `elsif phase == 'exiting'` → erase. Same path used by
station exit tests. No new code needed in vehicle_anim.rb for the erase.

### Two-file architecture (committed same session)
Deleted all legacy per-template files: cp.json, geometry.json, feature.json,
extracted.json, *.retired. lines.computed.json is now the single computed output.

---

## Current Template Status

| Template | Show Tracks | Shuffle Test | Departure Test | Arrival Test |
|----------|------------|-------------|----------------|--------------|
| station_line_end | ✓ | ✓ | ✓ | ✓ |
| station_thru_dip | ✓ | ✓ | ✓ | ✓ |
| station_parking | ✓ | PENDING | PENDING | - |
| traffic_circle7 | ✓ | — | — | Transit Test PENDING |

---

## Next Steps (ordered)

1. **Run station_parking Shuffle Test** — Console → Models → station_parking.
   Configuration ready: hold_loop_chain (direct-park, to_platform=[]), exit_chains.
   Expect: pods arrive at psmax, queue compacts toward ps1.

2. **Run station_parking Departure Test** — Console → Models → station_parking.
   Expect: all pods advance to psmax, exit via out_cp0/out_cp1, all erased.

3. **Run traffic_circle7 Transit Test** — Console → Models → traffic_circle7.
   4 vehicles, in_N → out_(N+3)%4. Expect all 4 exit cleanly.
   Reload needed: `load '.../jpod_vehicle_anim.rb'` and `load '.../jpod_console.rb'`

4. **Network animation on 2_thru_dip model** — station_thru_dip validated at template
   level; test in full network Build + Animate run.

5. **Sally advance "path too short" fault** (20260616T054917-fault.md) — ps3→ps4 at
   built-network stations. Root cause: _platform_pts_entry_first orientation failure
   in world space. Deferred (not blocking template tests).

---

## Key Design Decisions (this session)

**transit_test pattern:** No station platform = no Sally, no parking_chain.
Vehicle gets direct maneuver from build_fleet via `sally_transit_tracks`. Erase on
completion via `station_test_phase='exiting'`. One behavior, no special cases in
the animator for transit vehicles.

**Two-file rule:** lines.json + lines.computed.json only. No cp.json, geometry.json,
extracted.json, or model.followme.json as separate files.

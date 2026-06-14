# Handoff — 2026-06-13 (session 3)

## Where We Left Off

station_line_end template test suite: all three tests PASS.

- platform_shuffle: NORA_0001 (ps3) departs → NORA_0002 advances ps2→ps3,
  NORA_0003 advances ps1→ps2 → NORA_0001 returns and parks ps1.
  verdict=authorized, defects=0, TickLog deltas ≈ -25 (timing variance), -2.
- arrival_test: NORA_0001 placed at gw_cp_in_0 entry, traverses landing chain
  [4/4], parks at ps3. verdict=authorized, defects=0, TickLog delta=-1.
- departure_test: NORA_0003 (ps3) departs immediately, NORA_0002 after 4s,
  NORA_0001 after 8s. All 3 erased on exit. verdict=authorized × 3.

**Files changed this session (su_jpods_claude branch):**
- `jpod_sally.rb`: Pass 2.5 capacity correction (sequencer parking_slots authoritative)
- `jpod_vehicle_anim.rb`: init order swapped (sequencers before from_model);
  also comment update to init_sequencers_from_model
- `templates/track_formations/station_line_end/geometry.json`: added gw_platform_in
  (reconstructed 2-point ramp from neighboring track endpoints)
- `jpod_console.rb`: three departure_test fixes:
  1. cp_num in tag loop — already done prior session
  2. cp_num in dispatch loop (was still using old idx.odd? ? 0 : 1)
  3. Staggered departure: exit-slot first, 4s apart

## What To Do First Next Session

1. **Move to station_parking (JPods_station_parking = S003 in station_test.skp).**
   Run all three tests: platform_shuffle, arrival_test, departure_test.
   Expect: station_parking has dual CPs (cp0 + cp1), 9-slot platform.
   The single-CP guards in departure_test/arrival_test will NOT fire — both CP paths active.

2. **Watch for:** station_parking's gw_platform_parking behavior differs from
   station_line_end — it IS the primary capacity track (not an approach track).
   Pass 2.5 will not fire if parking_slots.max_slot already matches geometric capacity.

3. **After all station_parking tests pass:** station_thru_dip is the last template
   (S004). It was already tested in session 1 (the session that preceded this one)
   and passed platform_shuffle. Confirm arrival_test and departure_test also pass.

4. **Commit final:** once all three templates' all three tests pass, update
   readmes/agents/nora.md design decisions and write TFTS for the full arc.

## Architectural Decision This Session

Init order: `init_sequencers_from_model` BEFORE `init_from_model`.
Why: Pass 2.5 in init_from_model reads @@sequencers[:parking_slots] to override
geometric capacity. If sequencers aren't loaded first, the correction never fires.
Rule: anything that reads sequencer data in init_from_model requires this order.

Departure stagger: exit slot first, 4s intervals.
Why: slot spacing (2.5m) < MIN_SPACING (3m). Simultaneous dispatch causes jam guard
to stop trailing pods before they even leave the platform.
Rule: any multi-pod departure test must stagger by enough time for the leader to
clear MIN_SPACING before the next pod moves.

## Open Questions

- Does station_parking's geometry.json have complete geometry for all tracks in
  its landing_chains and hold_loop_chain? Check for missing tracks (same class of bug
  as gw_platform_in missing from station_line_end).
- Does Pass 2.5 affect station_parking incorrectly? It should be a no-op if the
  parking_slots.max_slot matches the geometric count.

## TFTS Written This Session

- `process/inbox/20260613T221900-tfts-station-line-end-capacity.md`

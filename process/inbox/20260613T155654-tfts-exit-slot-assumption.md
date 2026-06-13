# TFTS — 2026-06-13T15:56:54Z

problem:   platform_shuffle runner never departed — exit-slot guard always blocked it

fault_ref: (observed: "NORA_0001 at exit slot — parked probe loops=0" — guard correctly
            blocked runner at ps3 because ps3 is NOT the exit slot on a 9-slot platform)

arc:
  - try:      Original platform_shuffle code placed V1 (runner) at slot_dists_in[2],
              which was the third slot distance (ps3 at 6250mm) on a 9-slot platform.
              Sally's exit-slot guard requires `current_slot == cap_slot` (ps9) before
              dispatching for hold_loop. Runner was at ps3 — guard blocked every poll.
    result:   No animation. Runner sat at ps3 indefinitely.
    revealed: The test was designed for a 3-slot platform where slot 3 IS the exit slot.
              On a 9-slot platform, slot 3 is deep interior. The assumption "slot_dists_in[2]
              is the exit slot" is only true when capacity == 3.

  - try:      Use `pslots.last(3)` to get the last three parking_slots from lines_data
              (ps7, ps8, ps9). Set d_front from ps9's dist_mm. Tag V1 (runner) with slot_front=9.
    result:   succeeded — runner placed at ps9 (exit slot), exit guard passes,
              hold_loop dispatches. Compact behavior also correct: V2/V3 advance to
              vacated slots after V1 departs.

principle: Platform test setup must place the runner AT THE CAPACITY SLOT (ps_cap),
           not at a hardcoded index. Use `pslots.last(1)` for the exit slot.
           The exit-slot guard in `_dispatch_next_sequential` is correct — the bug
           was always in the test setup assuming a fixed capacity.
           Rule: never hardcode slot indices in test harnesses — always derive from
           the actual parking_slots data for the template under test.

domain:    SU

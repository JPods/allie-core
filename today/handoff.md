# Handoff — 2026-06-13

## Where We Left Off

**Files changed:**
- `su_jpods/jpod_sally.rb` — added `slot_positions_for_station` accessor (after `station_capacity`, line ~220)
- `su_jpods/jpod_console.rb` — fixed `platform_shuffle` block:
  - Pre-init Sally (init_sequencer_for_station + init_from_model) before vehicle placement
  - Orient plat_pts entry-first using Sally ps1 world position
  - Use `pslots.last(3)` for ps7/ps8/ps9 placement (was incorrectly using ps1/ps2/ps3)

**Test not yet run.** Code changes are written but not tested in SketchUp.

## What To Do First Next Session

1. **Reload and test:**
   ```ruby
   load '/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/jpod_sally.rb'
   load '/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/jpod_console.rb'
   ```
   Then: Extensions > JPods > Template Tests > Shuffle Test (or however the test_id
   'platform_shuffle' is invoked).

2. **Check Ruby console for:**
   - `[Sally ...] slot positions (lines.json, gw_platform): ps1@...mm  ps2@...mm ... ps9@...mm`
   - `[platform_shuffle] plat_pts reversed — ps1 d_first=NNN d_last=MMM` (or "kept")
   - n001 at ps9, n002 at ps8, n003 at ps7 in the animation start log
   - n001 dispatches hold_loop
   - n002 and n003 compact to ps9/ps8 after n001 departs
   - n001 returns and parks at ps7 (TickLog delta ≈ 0)

3. **If plat_pts log shows "ps1 world position unavailable":** Sally pre-init failed.
   Check whether `init_sequencer_for_station` requires the model to have a lines.json
   file loaded at the given station_id. Add debug puts inside the rescue block to see
   the error.

4. **After test passes:** Write commit for both files on branch su_jpods_claude.

## Open Blockers

None blocking the test. All code is written.

## What Was Decided and Why

**Why pre-init Sally before vehicle placement:**
Sally's `init_from_model` Pass 3 uses `gw_platform_in*` anchors to orient slot positions
entry-first. This orientation is already correct for all templates. Using `sp[1]`
(ps1 world position) to orient `plat_pts` in the console harness lets the same
authoritative source govern both Sally's internal state and the test placement.
Alternative (manual gw_platform_parking check) only works for station_thru_dip.

**Why slot_positions_for_station was added to Sally:**
It was the only clean way to expose `@@slot_positions[sid]` (a private class variable)
to the console harness without making the console know about Sally internals. The method
is a read-only accessor — no state mutation.

**plat_pts orientation problem is specific to station_parking:**
The existing orientation block (gw_platform_parking based) works for station_thru_dip.
The Sally-based fix is additive — it runs regardless of template type and is a no-op
when _ps1 is nil (Sally not yet initialized or no ps1 slot). Safe to leave in place.

## TFTS Files Written This Session

- `process/inbox/20260613T155653-tfts-entity-lookup.md` — component def vs. instance
- `process/inbox/20260613T155654-tfts-exit-slot-assumption.md` — ps3 ≠ exit on 9-slot platform
- `process/inbox/20260613T155655-tfts-plat-pts-orientation.md` — plat_pts exit-first for station_parking

## Next Phase (Bill's Request)

After shuffle test passes: "send n001 on a station loop, move n2 to ps9 and n3 to ps8
with n1 parking in ps7 when station loop is complete."

This is exactly what the fixed test demonstrates. If TickLog shows delta ≈ 0 on the
return park maneuver, both the shuffle logic and the park_man[:len] fix are confirmed
working together.

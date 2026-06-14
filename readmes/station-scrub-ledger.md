# Station Behavior Scrub Ledger
**Started:** 2026-06-14
**Status:** IN PROGRESS
**Companion plan:** `readmes/station-behavior-plan.md`
**Final artifact:** `readmes/Sally_station_behavior.md` (written after proof)

This ledger tracks every change made during the station behavior scrub. Three sections:
1. **Changes** — what we changed and why
2. **Purge candidates** — code identified for removal, with reasoning; nothing deleted until proof
3. **Proof results** — test-by-test outcomes; determines what gets purged

---

## Authority Split (agreed 2026-06-14)

```
Natalie's animation tick (ANIM_INTERVAL ~0.1s)
  → builds and dispatches maneuvers
  → controls all visual motion
  → responds to Sally's signals

Sally's clock (SystemClock, 0.5s independent timer)
  → decides parking order and shuffle sequence
  → authorizes departures
  → signals Natalie when a maneuver should be built
  → updates vehicle_array and pushes parking_array to Noras

Nora's voice (conflict report)
  → TOF clearance (physical) / MIN_SPACING + jam guard (SketchUp)
  → if conflict detected, Nora refuses and reports to Sally
  → Sally updates her registry from Nora's report (reality flows up)
  → Sally re-orders or holds and re-signals Natalie
```

**Key rule:** Sally signals Natalie. Natalie executes. Nora can refuse. Sally learns from refusals.

---

## Changes Made

### C-001 — Sally departure_mode flag (2026-06-14)
**Files:** `jpod_sally.rb`, `jpod_vehicle_anim.rb`, `jpod_console.rb`
**What:** Added `@@departure_mode` class variable and `set_departure_mode` / `departure_mode?` methods to Sally. Modified `shuffle_parked` handler in dwelling loop to route ps_max pods to originating_chain when active. Modified `poll_sally_dispatch` probe guard to bypass when active. Replaced timer-based dispatch in `departure_test` with `set_departure_mode` + `confirm_slots` re-registration.
**Why:** Immediate fix for station_parking departure_test overrun. Timer dispatch bypassed Sally entirely — pods were dispatched directly by the test, creating conflicts with Sally's advance queue.
**Status:** Interim fix. Intended to be replaced by C-003 (departure_candidate). Listed as purge candidate P-001.
**Proof needed:** departure_test PASS on all three templates.

### C-002 — confirm_slots distance threshold (2026-06-14)
**Files:** `jpod_sally.rb` (~line 910)
**What:** Added 4000mm snap threshold to `confirm_slots`. Pods more than 4000mm from the nearest slot are not snapped. Previously, pods at the hold_loop exit (~27m from ps1) were being snapped to ps1.
**Why:** Double-occupancy bug — pod at gw_cp_out_0 exit was snapped to ps1, creating two pods at ps1 in Sally's registry.
**Status:** Permanent fix. 4000mm ≈ 1.6 × slot_spacing (2500mm) — corrects placement errors but excludes hold_loop transit positions. Not a purge candidate.
**Proof needed:** Zero confirm_slots snap warnings in departure_test logs.

### C-003 — Sally vehicle_array (PENDING)
**Files:** `jpod_sally.rb`
**What:** Add `@@vehicle_array` — richer per-station object tracking each vehicle's status, slot, arrival_seq, hold_loop state. Replaces entity attribute reads as the authority for vehicle state.
**Why:** The single source of truth. Sally's `@@stations[sid][:parking_slots]` is a flat slot-indexed array; `@@vehicle_array` is vehicle-indexed and carries full state. Both exist during transition; entity attributes become write-through persistence only.
**Status:** NOT YET STARTED
**Proof needed:** All Phase 1 tests pass with vehicle_array as authority; entity attribute reads gone from dispatch path.

### C-004 — NoraPod parking_array (PENDING)
**Files:** `jpod_vehicle_anim.rb`
**What:** Add `@parking_array`, `@advance_to_slot`, `receive_parking_array(hash)`, `receive_advance(to_slot)` to NoraPod. Sally calls `push_parking_array` after every slot event.
**Why:** Nora needs station awareness to detect conflicts and report them. A Nora that does not know which slots are occupied cannot flag a clearance conflict before executing an advance.
**Status:** NOT YET STARTED
**Proof needed:** Nora conflict detection fires correctly when a slot is occupied; Sally updates registry from the refusal.

### C-005 — Sally.departure_candidate replaces departure_mode (PENDING)
**Files:** `jpod_sally.rb`, `jpod_vehicle_anim.rb`
**What:** Add `Sally.departure_candidate(station_id)` → `nora_id` or `nil`. Returns the pod authorized to depart on this tick. Sally decides based on vehicle_array state: pod at ps_max, status=:parked, no inbound blocking. Sally's tick handler calls this and signals Natalie when non-nil.
**Why:** Replaces the `departure_mode` flag (C-001), which is a test-only workaround. In production, Sally always knows who departs next — a flag is not needed.
**Status:** NOT YET STARTED — depends on C-003
**Proof needed:** Departure authorized without `departure_mode` flag; all templates pass departure_test.

### C-006 — compact_platform_idle audit (PENDING)
**Files:** `jpod_vehicle_anim.rb`
**What:** Audit `compact_platform_idle` call sites and behavior. Determine overlap with Sally's `_advance_platform_queues`.
**Why:** Suspected duplicate. If confirmed, purge (see P-002). If it handles cases advance queue does not, document those cases and keep.
**Status:** NOT YET STARTED

---

## Purge Candidates

### P-001 — departure_mode flag (C-001)
**Code:** `@@departure_mode`, `set_departure_mode`, `departure_mode?` in `jpod_sally.rb`; `departure_mode?` checks in `jpod_vehicle_anim.rb`; `set_departure_mode` calls in `jpod_console.rb`
**Reason to purge:** Interim workaround for missing `departure_candidate` (C-005). Once C-005 is proven, the flag is redundant.
**Condition to purge:** C-005 proven by departure_test PASS on all templates; `departure_mode` calls removed from console.
**Risk:** Low — departure_mode is only set in departure_test; production code path not affected.

### P-002 — compact_platform_idle (pending audit C-006)
**Code:** `compact_platform_idle` method in `jpod_vehicle_anim.rb`; all call sites
**Reason to purge:** Sally's `_advance_platform_queues` appears to do the same job. Two advance systems create ambiguity about which one fires.
**Condition to purge:** Audit (C-006) confirms no unique behavior; all Phase 1 tests pass without it.
**Risk:** Medium — audit first. If it handles idle-reserve pods or startup compaction differently, those cases must be absorbed before purging.

### P-003 — station_test_phase entity attribute state machine
**Code:** `station_test_phase` reads/writes in `jpod_vehicle_anim.rb` dwelling loop (~lines 3155–3390); corresponding `set_attribute` calls in `jpod_console.rb`; `station_test_phase` references throughout
**Reason to purge:** Vehicle state belongs in Sally's vehicle_array (C-003), not on SketchUp entity attributes. The dwelling loop's `elsif phase == 'shuffle_parked'` / `'compact_parked'` / `'parked_final'` state machine is Sally logic embedded in the animation engine.
**Condition to purge:** C-003 proven; all Phase 1 tests pass reading vehicle state from Sally vehicle_array instead of entity attributes.
**Risk:** High — this state machine drives all test behavior today. Do not touch until vehicle_array is fully proven.

### P-004 — poll_sally_dispatch method
**Code:** `poll_sally_dispatch` in `jpod_vehicle_anim.rb` (~line 4164); calls to it from `on_system_tick`
**Reason to purge:** This is Natalie code embedded in the animation engine. Sally's tick should signal Natalie directly (via `departure_candidate`). Natalie should not poll Sally; Sally should push.
**Condition to purge:** C-005 proven; Sally's tick handler pushes departure signals to Natalie directly.
**Risk:** Medium — `poll_sally_dispatch` is the current dispatch gate. Remove only after C-005 is the confirmed dispatch path.

### P-005 — sally_hold_loop_sid / sally_hold_loop_loops / sally_hold_loop_cp entity attributes
**Code:** `set_attribute('JPods', 'sally_hold_loop_sid', ...)` and related in `jpod_console.rb`, `jpod_vehicle_anim.rb`; reads in `build_fleet`
**Reason to purge:** Test-setup scaffolding that bleeds vehicle state onto model entities. In the vehicle_array world, these fields live in the vehicle_array object, not on entities.
**Condition to purge:** C-003 proven; `build_fleet` reads from vehicle_array instead of entity attributes; all Phase 1 tests pass without these attributes being set.
**Risk:** High — `build_fleet` currently uses these as the primary signal to identify hold_loop vs parked pods. Do not touch until vehicle_array replaces this.

### P-006 — originating chain dispatch from dwelling loop
**Code:** `else` branch in dwelling loop (~line 3308): reads lines.json from disk, builds maneuver, dispatches — embedded in the animation engine's timer callback
**Reason to purge:** Sally should own originating chain selection (`originating_chain_for(station_id, cp_num)` caching lines.json). Natalie should dispatch the maneuver. Both decisions are currently buried in the dwelling loop.
**Condition to purge:** C-003 + C-005 proven; Sally's `originating_chain_for` is the selection method; Natalie dispatches.
**Risk:** Medium — the current path works. Refactor after all other changes are proven.

---

## Proof Results

### Phase 1 — Single Station Tests

| Template | Test | Result | Date | Log notes |
|----------|------|--------|------|-----------|
| station_line_end (S002) | platform_shuffle | | | |
| station_line_end (S002) | arrival_test | | | |
| station_line_end (S002) | departure_test | | | |
| station_parking (S003) | platform_shuffle | PASS | 2026-06-13 | Prior session |
| station_parking (S003) | arrival_test | PASS | 2026-06-13 | Prior session |
| station_parking (S003) | departure_test | PENDING | | Overrun fixed; C-001 applied; needs run |
| station_thru_dip (S004) | platform_shuffle | PASS | 2026-06-13 | Session 1 |
| station_thru_dip (S004) | arrival_test | PENDING | | |
| station_thru_dip (S004) | departure_test | PENDING | | |

### Phase 2 — Two-Station Network

| Test | Result | Date | Log notes |
|------|--------|------|-----------|
| Pod A→B, parks at B | | | |
| Pod B→A, parks at A | | | |
| Simultaneous: A→B and B→A | | | |
| Pass-thru logged in @@passing | | | |

### Phase 3 — Three Stations + Traffic Circle

| Test | Result | Date | Log notes |
|------|--------|------|-----------|
| A↔B↔C round trip | | | |
| Circle pass-thru does not false-hold adjacent station | | | |
| Balance signals correct at 50% threshold | | | |

### Phase 4 — Large Networks

| Network | Pod count | Run duration | Result | Date |
|---------|-----------|--------------|--------|------|
| | | | | |

---

## Purge Decisions

*(Filled in after proof results)*

| Candidate | Decision | Date | Reason |
|-----------|----------|------|--------|
| P-001 departure_mode | | | |
| P-002 compact_platform_idle | | | |
| P-003 station_test_phase state machine | | | |
| P-004 poll_sally_dispatch | | | |
| P-005 sally_hold_loop_* attributes | | | |
| P-006 originating chain in dwelling loop | | | |

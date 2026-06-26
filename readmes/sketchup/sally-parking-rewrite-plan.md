# Sally Parking Rewrite Plan — 2026-06-25

## The Problem (three symptoms, one root cause)

1. **Pods hang at gw_platform entry (ps-1)** — Sally doesn't move them to a slot fast enough, or the handoff from Natalie isn't clean
2. **Pods overrun each other inside ps** — Sally's slot array and entity positions desync; pod at ps_max sometimes overruns onto gw_platform_out1
3. **Pods don't shuffle forward reliably** — conveyor doesn't advance pods to fill empty higher slots after departures

**Root cause:** Sally's parking logic was patched incrementally over two days. The handoff between Natalie (network animation) and Sally (platform management) has multiple code paths, state mismatches, and timing issues. Needs clean rewrite.

---

## Design Answers

### Q1: Is pod.array + slot.array the right framework?

**Yes, with these additions:**

**pod.array** (`@pods` — Hash of PodRecord by nora_id):
- `:traveling` — Natalie dispatched, on the network, heading here. ETA known.
- `:entering` — at gw_platform, animating to assigned slot. NOT eligible for dispatch.
- `:parked` — at assigned slot. Eligible for dispatch after station dwell.
- `:departing` — Sally authorized departure, pod leaving.

**slot.array** (`@ps` — Array of ParkingSlot, ps1 through capacity):
- `:empty` — no pod
- `:occupied` — pod physically present (nora_id recorded)

**New: inbound queue** (sorted by ETA):
- Natalie tells Sally about every inbound pod via `notify_inbound`
- Sally maintains a sorted queue: who's coming, when, in what order
- At gw_platform_in1, Sally knows the exact order of the next arrivals
- Sally pre-assigns slots so arriving pods don't wait at the door

### Q2: What should be in each object?

**PodRecord (in pod.array):**
```ruby
{
  nora_id:      "NORA_0007",
  state:        :traveling | :entering | :parked | :departing,
  slot:         nil | 1..capacity,  # nil when traveling, assigned when entering
  entity:       SketchUp::ComponentInstance,
  station_id:   "s007",
  eta_s:        12.5,              # seconds until arrival (traveling only)
  assigned_slot: 3,                # pre-assigned by Sally based on arrival order
  parked_at:    Time.now.to_f,     # when pod reached its slot
  trip_count:   0,
}
```

**ParkingSlot (in slot.array):**
```ruby
{
  number:       3,
  state:        :empty | :occupied,
  occupant_id:  nil | "NORA_0007",
  position_mm:  [x, y, z],        # world position from slot_positions_for_station
}
```

### Q3: What is the best Natalie→Sally handoff?

**The handoff happens at gw_platform entry — NOT at the start of gw_platform.**

1. Natalie's route ends with `gw_platform` as the last maneuver
2. When the pod finishes `gw_platform_in2` (the maneuver before `gw_platform`), Sally takes over
3. Sally clips `gw_platform` to the assigned slot position
4. The pod animates the clipped segment (same engine, same math)
5. Pod state = `:entering` during transit — dispatch cannot grab it
6. When the pod reaches the slot position → state = `:parked`
7. The pod is now in Sally's slot array and eligible for dispatch (after station dwell)

**Key rule:** The pod NEVER stops at the door. Sally pre-assigns the slot when the pod is on gw_platform_in1 (she knows it's coming from the inbound queue). By the time the pod reaches gw_platform, the slot is already assigned.

**Departure handoff:**
1. Sally authorizes departure from the highest occupied slot
2. The departing pod's route SKIPS gw_platform (starts at gw_platform_out1)
3. This prevents the departing pod from driving through parked pods

---

## Implementation Plan

### Phase 1: Test Infrastructure
1. Use `2_parking` model — simplest 2-station parking test
2. Create a `sally_parking_test.rb` that:
   - Places pods at specific slots
   - Dispatches one pod
   - Verifies conveyor advances remaining pods
   - Verifies arriving pod animates to assigned slot
   - Verifies no overrun, no teleport, no hang
3. Rich logging: every Sally action logs to console with timestamps

### Phase 2: Clean Sally Station Code
1. Archive current `pod_arrives` method
2. New `pod_arrives`: 
   - Check inbound queue for pre-assigned slot
   - If no pre-assignment, find lowest empty slot
   - State = `:entering`, slot = assigned
   - Return the clipped gw_platform maneuver (pts from door to slot)
3. New `pod_parked`: called when pod reaches slot. State = `:parked`.
4. Ensure `pod_departs` only works on `:parked` pods

### Phase 3: Clean Animation Code
1. Maneuver transition: when next_man is `gw_platform` at destination:
   - Call `Sally.pod_arrives` — get the slot + clipped maneuver
   - Pod animates the clipped segment as `:entering`
   - When pod finishes → `pod_parked` → `:parked` → dwell starts
2. Dispatch guard: only `:parked` pods
3. Departure: skip `gw_platform` at origin (already implemented)
4. Conveyor: advance parked pods toward exit, atomic with entity

### Phase 4: Network Test
1. Run on `2_parking` first — validate 1 departure + 1 arrival
2. Run on `3+circle` — validate traffic circle + parking
3. Run on West Point — full network stress test

---

## Testing Mechanism

### Sally Parking Test (new file: `sally_parking_test.rb`)

```
Test 1: ARRIVAL — pod arrives at empty station
  - Place 0 pods. Dispatch 1 pod to this station.
  - Verify: pod animates from gw_platform entry to ps1
  - Verify: Sally ps[1] = occupied, pod.state = :parked
  - Verify: entity position = sp[1] ± 500mm

Test 2: ARRIVAL WITH PARKED — pod arrives at station with pods
  - Place pods at ps7, ps8, ps9. Dispatch 1 pod.
  - Verify: pod animates to ps6 (below lowest occupied)
  - Verify: no overrun through ps7-ps9

Test 3: DEPARTURE + CONVEYOR — pod departs, others advance
  - Place pods at ps7, ps8, ps9. Depart ps9.
  - Verify: ps8 advances to ps9, ps7 advances to ps8
  - Verify: entity positions match slot positions

Test 4: FULL STATION — pod arrives, station full
  - Fill all slots. Dispatch 1 pod.
  - Verify: Sally tells Natalie to add travel (station loop)
  - Verify: pod does NOT enter gw_platform

Test 5: RAPID ARRIVAL — 3 pods arrive in quick succession
  - Verify: each gets a unique slot, no double-assignment
  - Verify: personal space maintained on gw_platform

Test 6: DISPATCH GUARD — entering pod cannot be dispatched
  - Pod is :entering, animating to slot
  - Verify: dispatch skips it, selects a different :parked pod
```

### Rich Logging

Every Sally action logs with this format:
```
[Sally {sid}] {action} {nora_id} {details}
```

Actions:
- `INBOUND` — Natalie notified, pod added to queue
- `ASSIGN` — slot pre-assigned from inbound queue
- `ENTER` — pod at door, beginning gw_platform animation
- `PARK` — pod reached slot, registered as parked
- `DEPART` — pod authorized to leave
- `ADVANCE` — conveyor moved pod to next slot
- `FULL` — station full, told Natalie to add travel
- `OVERRUN` — fault: pod passed through another pod (should never happen)

---

## TFTS Summary from This Session

**Try:** Teleport pod to slot (direct entity.transformation)
**Fail:** Entity position overwritten by animation tick proposals
**Revealed:** Can't set entity position during proposal loop

**Try:** Deferred placement queue (after commit_operation)  
**Fail:** Pod dispatched before placement executed
**Revealed:** Dispatch grabs pod between assignment and placement

**Try:** Incremental slot stepping (one slot per conveyor tick)
**Fail:** Too slow (4.5s to reach ps9), pods pile at door
**Revealed:** Entering pods need to reach their slot quickly

**Try:** Clip gw_platform to slot, animate as normal maneuver
**Fail:** Pod state was :parked immediately, dispatch grabbed it
**Revealed:** Need :entering state to guard against premature dispatch

**Succeed:** Clip + :entering state + dispatch guard ← THIS IS THE ANSWER
**Principle:** Sally clips gw_platform, Nora animates it, pod is :entering during transit, dispatch only grabs :parked pods. One code path, same animation engine.

---

## Files to Modify

| File | What changes |
|------|-------------|
| `sally/sally_station.rb` | `pod_arrives` returns clipped maneuver, `pod_parked` new method, inbound queue |
| `animation/animation.rb` | Maneuver transition uses Sally's clip, dispatch guard checks :parked, arrival handler calls `pod_parked` |
| `sally_parking_test.rb` | New test file — 6 tests for parking behavior |

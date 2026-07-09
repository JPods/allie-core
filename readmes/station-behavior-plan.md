# Station Behavior Plan
**Drafted:** 2026-06-14
**Status:** Draft — agree before any code changes
**Purpose:** Scrub all station behavior code to a single source of truth. Sally owns every station behavior. Nothing else dispatches, parks, advances, or departs a pod at a station.

---

## The Problem Today

Station behavior is split across four places, none fully authoritative:

| Where | What it does | Problem |
|-------|-------------|---------|
| `jpod_sally.rb` | Slot registry, advance queue, arrival/departure hooks | Authoritative for slots but not for dispatch |
| `jpod_vehicle_anim.rb` | `poll_sally_dispatch`, dwelling loop, originating chain dispatch | Natalie/Nora logic embedded in the animation engine |
| `jpod_console.rb` | Test setup, former timer-based departure dispatch | Test scaffolding leaked into station protocol |
| Entity attributes on SketchUp components | `station_test_phase`, `parking_slot`, `sally_hold_loop_*` | State split between Sally's registry and model entities |

When these fall out of sync — and they do — the result is double-occupancy, confirm_slots fights, pods snapped to wrong slots, overrun violations.

**Root cause:** The tests (platform_shuffle, arrival_test, departure_test) were built to _prove_ Sally works, but they contain their own dispatch logic that bypasses Sally. A test that bypasses the system it is testing cannot prove the system works.

---

## The Single Source of Truth Model

**Sally owns every station behavior. Always. No exceptions.**

```
AUTHORITY CHAIN

Natalie informs Sally           Sally updates Nora
──────────────────              ─────────────────────────────
• Inbound pod, which CP         • Assigned slot number
• Pass-thru pod, which chain    • Current parking_array
• Pod departing station         • Advance instruction when slot opens

Sally decides                   Nora executes
──────────────                  ────────────────────────────
• Which slot to assign          • Parks at exact assigned slot
• When to advance pods          • Advances on Sally's instruction
• When ps_max pod departs       • Departs on Sally's authorization
• Whether to hold or dispatch   • Reads parking_array, not entity attrs
• Network balance signals       • Does not improvise station behavior
```

**Three clean roles:**
- **Natalie** — routes, informs Sally of arrivals and pass-thrus, executes maneuvers Sally authorizes
- **Sally** — owns the station: slot registry, parking_array, advance queue, departure authorization
- **Nora** — executes: parks at Sally's slot, advances on Sally's instruction, departs on Sally's authorization; holds her own copy of parking_array

---

## Nora's parking_array

Every parked Nora carries a copy of Sally's station state. Sally pushes updates after every slot change.

```ruby
# Nora's instance variables (NoraPod in jpod_vehicle_anim.rb)
@parking_array = {
  station_id: 'jpods_station_parking',
  capacity:   9,
  my_slot:    3,
  slots: {
    1 => nil,
    2 => 'NORA_0002',
    3 => 'NORA_0003',    # self
    4 => 'NORA_0004',
    5 => 'NORA_0005',
    6 => 'NORA_0006',
    7 => 'NORA_0007',
    8 => 'NORA_0008',
    9 => 'NORA_0009'
  }
}
@advance_to_slot = nil   # nil = hold; N = Sally said move to slot N
```

Sally pushes `parking_array` updates to all parked Noras at a station after every arrival or departure. Each Nora checks `my_slot` against `capacity` — if she is at the highest slot with no pod in front, she knows she is in departure position. She does not depart without Sally's explicit authorization.

**On physical hardware:** Sally broadcasts `PARKING_UPDATE,station_id,json` via MQTT. Each Nora at that station updates her @parking_array from the broadcast. Pod-to-pod awareness without a central coordinator.

---

## The Protocol — Step by Step

### Arrival

```
1. Nora completes network trip → arrives at gw_platform_parking endpoint

2. Natalie → Sally: "NORA_000X arriving via cp0"
   Sally.vehicle_arriving(station_id, nora_id, cp_num)
   Sally: adds to vehicle_array as status=:inbound

3. Sally: reserve_slot → assigns slot N
   Sally → Natalie: "NORA_000X: slot N"
   Natalie → Nora: trip_plan ending at slot N (clip to dist_mm of slot N on gw_platform)
   Natalie → Nora: parking_array copy

4. Nora: parks at slot N
   Nora → Sally: "NORA_000X parked at slot N"   [vehicle_parked event]

5. Sally: update vehicle_array (status=:parked@N)
   Sally: push parking_array to all parked Noras at this station
```

### Departure (ps_max pod)

```
1. Sally: on each tick, scan vehicle_array
   If pod at ps_max (capacity slot), status=:parked, no inbound blocking:
   → departure_authorized = true

2. Sally → Natalie: "Dispatch NORA_000X via originating_chain"
   Natalie: builds maneuver from lines.json originating_chains
   Natalie → Nora: trip_plan (originating chain)

3. Nora: executes departure maneuver
   Nora → Sally: "NORA_000X departing"   [on maneuver start]
   Sally: update vehicle_array (status=:departing)
   Sally: release_slot(ps_max)

4. Nora: completes originating chain → erased (test) or re-enters network (production)

5. Sally: push updated parking_array to remaining parked Noras
   Sally: send advance instruction to pod at ps_max-1: "advance to ps_max"
```

### Advance (shuffle forward)

```
1. Sally: vehicle_array has pod at ps_N, slot ps_N+1 is empty
   Sally: dispatch advance to NORA_N

2. Natalie → Nora_N: advance maneuver (gw_platform clip from ps_N dist_mm to ps_N+1 dist_mm)

3. Nora_N: executes advance, arrives at ps_N+1
   Nora_N → Sally: "arrived at ps_N+1"

4. Sally: update vehicle_array (NORA_N status=:parked@N+1)
   Sally: push parking_array update to all parked Noras
   Sally: check next advance (cascade one slot per tick)
```

### Pass-through

```
1. Natalie → Sally: "NORA_000X transiting via near_main"
   Sally.vehicle_passing(station_id, nora_id, chain_name)
   Sally: adds to @@passing registry

2. When NORA_000X clears the station's outer ring:
   Sally.vehicle_passed(station_id, nora_id)
   Sally: removes from @@passing

3. Sally holds any hold_loop dispatch while outer ring is occupied
   (@@passing is the outer-ring clearance authority)
```

---

## Code Scrub — What to Remove

### Remove from `jpod_vehicle_anim.rb`

| Code | Why |
|------|-----|
| `departure_mode` check in `shuffle_parked` | Temporary patch; Sally's vehicle_array state replaces this |
| `poll_sally_dispatch` method | Move decision logic to Sally; Natalie executes |
| Originating chain dispatch in dwelling loop (`else` branch, phase='') | Sally decides when to dispatch; should not be in dwelling loop |
| `station_test_phase` state machine in dwelling loop | Replace with Sally's vehicle_array status field |
| Entity attribute reads for `station_test_phase` in dwelling loop | State lives in Sally's vehicle_array, not on model entities |
| `compact_platform_idle` (if confirmed duplicate of Sally's advance queue) | Audit first — may have non-overlapping cases |

### Remove from `jpod_console.rb`

| Code | Why |
|------|-----|
| `departure_mode` flag + confirm_slots re-call (just added this session) | Correct Sally to not need this workaround |
| Any remaining direct `pod.receive_maneuver` calls for station maneuvers | All station maneuvers go through Natalie, authorized by Sally |
| `sally_departure_cp` attribute (already unused) | Delete references |

### Remove from entity attributes (model entities)

| Attribute | Replace with |
|-----------|-------------|
| `station_test_phase` | Sally's vehicle_array status field |
| `sally_hold_loop_loops` (as routing flag) | Sally's vehicle_array hold_loop_count field |
| `sally_hold_loop_sid` (as routing flag) | Nora's @parking_array.station_id |
| `sally_hold_loop_cp` | Sally's originating_chain selection |

**Keep:** `parking_slot`, `parked_station_id` — these are write-through persistence so models save/reload correctly. They are NOT the authority; Sally's vehicle_array is.

### Add to `jpod_sally.rb`

| Addition | Purpose |
|----------|---------|
| `@@vehicle_array` — per-station hash of `{nora_id => {status, slot, arrival_seq}}` | Single authority for all vehicle state at each station |
| `Sally.vehicle_arriving(station_id, nora_id, cp_num)` | Natalie calls this before a pod enters landing chain |
| `Sally.vehicle_parked(station_id, nora_id, slot)` | Nora confirms park (already exists, may need extension) |
| `Sally.vehicle_departing(station_id, nora_id)` | Sally's departure authorization → clears slot |
| `Sally.departure_candidate(station_id)` → `nora_id` or `nil` | Sally decides which pod departs next — replaces `departure_mode` |
| `Sally.push_parking_array(station_id)` | Push state to all parked Noras after any slot event |
| `Sally.originating_chain_for(station_id, cp_num)` → `Array<String>` | Cache the originating chain tracks from lines.json |

### Add to `NoraPod` in `jpod_vehicle_anim.rb`

| Addition | Purpose |
|----------|---------|
| `@parking_array = {}` | Nora's copy of Sally's station state |
| `@advance_to_slot = nil` | Sally's advance instruction |
| `receive_parking_array(array_hash)` | Sally pushes updates here |
| `receive_advance(to_slot)` | Sally instructs Nora to advance |

---

## Test Plan

Tests are PROOFS, not procedures. Each test should be a formal proof that Sally's single-source-of-truth behavior is correct. If a test has its own dispatch logic, it is not a test of Sally — it is a test of the test.

### Phase 1 — Single Station (9 tests)

**Station models:** station_line_end (S002), station_parking (S003), station_thru_dip (S004)
**Each station gets three tests:**

| Test | Proves |
|------|--------|
| `platform_shuffle` | Sally advances pods correctly after departure; FIFO order preserved; no gaps |
| `arrival_test` | Natalie informs Sally → Sally assigns slot → Nora parks at correct position |
| `departure_test` | Sally identifies ps_max pod → authorizes departure → triggers advance cascade |

**Log requirements for each test:**
- Sally vehicle_array state at every tick (compact log: `[SID] tick=N slots={...}`)
- Every Nora parking_array update push
- Every advance instruction: `[Sally] NORA_000X ps3→ps9 advance`
- Every departure authorization: `[Sally] NORA_000X authorized departure from ps9`
- TickLog (already exists) — provides timing baseline

**Pass criteria:**
- All pods exit cleanly (departure_test)
- All pods park at correct slots (arrival_test)
- Advance sequence matches FIFO order with no slot gaps (platform_shuffle)
- Zero double-occupancy warnings
- Zero confirm_slots snaps (no position correction needed = slots were correct)

### Phase 2 — Two-Station Network

**Network:** station A → station B → return

**Proves:**
- Pass-thru vehicles logged in Sally's @@passing registry while transiting
- Sally at station A does not hold_loop dispatch while outer ring is occupied by pass-thru
- Natalie informs both Sallys of arrivals before the landing chain starts
- Pod arriving at B: Natalie → Sally(B) → slot assigned → Nora parks
- Pod departing B: Sally(B) authorizes → Natalie dispatches → Sally(A) is informed of inbound

**Log requirements:**
- Both station logs active simultaneously
- @@passing events visible in Sally log
- Natalie informs Sally before landing chain (timing visible in log)

### Phase 3 — Three Stations + Traffic Circle

**Network:** A ↔ B ↔ C with traffic circle node

**Proves:**
- Pass-thru vehicles on circle do not trigger false holds at adjacent stations
- Sally at each station is isolated — no shared state between stations
- Network balance signals correct (50% threshold, Natalie routes surplus to shortage)

### Phase 4 — Large Networks (3+ existing .jpd conversions)

**Use:** Converted MeshMobility networks from `/Applications/RouteTime_JPods/converted/`

**Proves:**
- Sally scales: 10+ stations, 50+ pods
- No slot registry corruption over extended runs (10+ minutes)
- Balance signals from multiple Sallys to Natalie do not collide

---

## What `Sally_station_behavior.md` Will Contain

When this plan is executed and verified, `Sally_station_behavior.md` becomes the permanent reference:

1. **The authority chain** (Natalie → Sally → Nora) — exactly as in this plan, confirmed against tested code
2. **vehicle_array schema** — the definitive data structure
3. **parking_array schema** — what Nora holds and how Sally pushes it
4. **Event table** — every event, who fires it, who receives it
5. **lines.json contract** — what every station's lines.json must contain for Sally to work
6. **Invariants** — the rules that must always hold (no double-occupancy, FIFO order, ps_max departs first, etc.)
7. **Cross-domain notes** — how this protocol maps to MQTT on physical hardware

---

## Sequencing — What to Do First

1. **Agree on this plan** before touching code
2. **Add `vehicle_array` to Sally** — this is the foundation; everything else builds on it
3. **Add `NoraPod#parking_array`** and `Sally.push_parking_array`
4. **Replace `departure_mode` + `poll_sally_dispatch`** with `Sally.departure_candidate`
5. **Remove `station_test_phase` state machine** from dwelling loop; move to Sally vehicle_array status
6. **Run Phase 1 tests** (9 tests, detailed logs)
7. **Run Phase 2 tests** (2-station)
8. **Run Phase 3 tests** (3-station + circle)
9. **Run Phase 4 tests** (large networks)
10. **Write `Sally_station_behavior.md`** from what the tests confirm

---

## Open Questions Before Code Changes

1. **`departure_mode` vs `departure_candidate`**: Should Sally expose a method that returns which pod is authorized to depart next, and Natalie calls this on every tick? Or should Sally push the departure authorization proactively when she decides?
   - Bill's description suggests **Sally pushes** — she decides, then tells Natalie. This means Sally has a tick handler that checks for departure candidates and signals Natalie. Natalie does not poll.

2. **Advance instruction: Sally pushes vs Natalie polls?**
   - Same question. Sally's advance queue fires on her tick — she should push the advance instruction directly. Natalie builds the maneuver and dispatches it. This is cleaner than Natalie polling `_advance_platform_queues`.

3. **`compact_platform_idle` audit**: Is this still needed, or is it fully superseded by Sally's `_advance_platform_queues`? Need to audit call sites before deleting.

4. **Physical hardware protocol for parking_array updates**: MQTT broadcast to all pods at a station? Or Natalie-mediated (Sally → Natalie → each Nora via unicast)? Recommend broadcast — it matches Sally's autonomous station design.

5. **`station_test_phase` during transition**: We cannot remove entity attributes until the vehicle_array fully replaces them. Keep both in parallel during the scrub, remove entity attributes last once vehicle_array is proven.

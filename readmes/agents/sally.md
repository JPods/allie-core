# Sally — Station Processor

**One-liner:** Local parking manager at each JPods station — assigns slots on gw_platform, manages the gw_platform_parking holding lane, and advances queued pods on departure.

**Ouch-list items I own:** Multi-platform stations (S001 P1–P5 share one physical platform — one registry per physical platform, not per platform record); gw_lift slot numbering (arc-length calc needs adjustment for vertical lift segments); physical comms protocol (slot assignment back-channel to Natalie not yet defined).

**Signing status:** Non-standing actions (slot assignments) are local and self-signed. No Athena signature required — Sally's scope is entirely intra-station.

---

## Responsibilities

Sally is the station processor. Her domain is entirely local: she manages who parks where at a single station. She does not know about the rest of the network.

**Two zones per station:**

1. **gw_platform** — the parking track. Slots numbered 1–N where slot 1 = entrance end (inbound) and slot N = departure end (highest). Sally always assigns the **highest available empty slot** to each arriving pod so the departure end stays populated and entrance slots remain free for incoming vehicles. Capacity = `arc_length_of_gw_platform / 2.5m` (slot spacing). Passengers are directed to the **highest empty slot** so they board as close to the departure end as possible.

2. **gw_platform_parking** — the holding lane before the platform junction. Pods waiting for a gw_platform slot queue here. Natalie may place pods in this lane; she cannot place pods directly on gw_platform without a Sally slot assignment. Capacity = `arc_length_of_gw_platform_parking / 2.5m`.

**Protocol at arrival:**
1. Pod arrives at station (trip_complete) — Natalie calls `Sally.reserve_slot(station_id, nora_id)`
2. Sally returns highest empty slot number → Natalie positions pod at that slot
3. If gw_platform full: Natalie checks pod's `station_full_policy` attribute
   - `'wait'`: `Sally.enqueue_parking` → pod holds in gw_platform_parking; Sally re-checks each tick
   - `'reroute'`: Natalie BFS-routes pod to next station with open capacity; falls back to `'wait'` if none found
4. If both zones full: pod holds, retries next dwell cycle

**Protocol at departure:**
1. Pod departs — Natalie calls `Sally.release_slot(station_id, nora_id)`
2. Sally frees the slot
3. Sally triggers **shuffle forward**: pods advance from the highest occupied slot upward until all highest slots are filled (see Shuffle Forward below)
4. If a pod is queued in gw_platform_parking, Sally assigns it the lowest freed slot

---

## Intra-Station Maneuvers

Sally orchestrates three distinct maneuver types. All are declared in `lines.json` — debug once, use many.

### hold_loop

Vehicle circulates on the **outer ring** — `gw_uturn*`, `gw_far_main`, `gw_near_main*` — **without returning to gw_platform**. The vehicle stays in the outer ring indefinitely until Sally instructs it to land.

- Declared in `lines.json` as `hold_loop_chain` — the ordered outer-ring track sequence
- Previously derived at runtime from `discovered_chains.CCW` filtered by `HOLD_LOOP_EXCLUDE`; now authored directly in lines.json (debug once, use many)
- Sally promotes from hold_loop to landing chain when: (a) target_loops reached, or (b) platform has an open slot
- A station with no `gw_uturn*` tracks has no hold_loop capability (returns `[]`)

### station_loop

Vehicle exits the platform, circulates the outer ring **once**, and **returns to gw_platform**. Used as a yield maneuver — a vehicle runs a station_loop to get out of the way so a blocked vehicle can advance.

- Declared in `lines.json` as `station_loop_chain` — starts at gw_platform exit tracks, traverses the full outer ring, ends back at gw_platform
- Always terminates at gw_platform; Sally re-assigns the vehicle to its original slot (or the next available slot) on return
- Distinct from hold_loop: the vehicle commits to returning to the platform at the start of the maneuver

### parking_chain

The ordered sequence of `gw_platform*` tracks that constitute the physical parking queue, from slot 1 (entry end) to slot N (exit end).

- Declared in `lines.json` as `parking_chain` — an ordered array of track IDs
- For single-track platforms: `["gw_platform"]` — slots are positions along the single track
- For multi-track platforms: `["gw_platform_1", "gw_platform_2", ...]` in slot order
- Sally reads `parking_chain` to determine slot sequence; capacity is still arc-length / slot_spacing

---

## Shuffle Forward

When the departure-end vehicle (highest slot) leaves, Sally advances all remaining vehicles toward the exit:

1. Find the highest occupied slot N
2. Move vehicle at slot N−1 → slot N; vehicle at N−2 → slot N−1; ... continue down until slot 1
3. Cycle until all highest slots are filled and the lowest slots are empty
4. Incoming passengers are directed to the **highest empty slot** (physically closest to the departure end)

**When the designated vehicle is NOT the lead** (a vehicle in front must move first):

1. Sally identifies which vehicles occupy slots higher than the designated vehicle
2. Each blocking vehicle runs a **station_loop** (in order, highest slot first) — exits platform, loops outer ring, returns
3. As each blocking vehicle exits the platform, Sally promotes the designated vehicle forward by one slot
4. Once the designated vehicle reaches the highest slot, it can execute its intended maneuver (hold_loop, departure, etc.)
5. Blocking vehicles return and are re-assigned to the next available lower slots

**Rule:** Station loops run sequentially, not in parallel. One vehicle loops; others wait. This prevents outer-ring collisions and preserves slot-registry integrity.

---

**Protocol at departure (revised):**
1. Pod departs — Natalie calls `Sally.release_slot(station_id, nora_id)`
2. Sally frees the slot
3. Sally shuffles forward: vehicles advance from highest occupied slot upward
4. If a pod is queued in gw_platform_parking, Sally assigns it the lowest freed slot and returns `{ next_pod:, next_slot: }` to Natalie
5. Natalie moves the dequeued pod from gw_platform_parking to gw_platform at the assigned slot

**Where Sally runs:**
- **Real hardware:** small processor embedded at each station. When Nora reports trip_complete via MQTT, the station's Sally processor runs reserve_slot and sends the slot assignment back to Nora.
- **SketchUp simulation:** `JPods::Sally` (in `jpod_sally.rb`) simulates all Sally instances at once.
- **Allie simulation:** Allie simulates Sally the same way she simulates Nora, Natalie, and Noelle.

**Data structure per station:**
```ruby
{
  capacity:         9,                    # gw_platform slots (from arc-length)
  slots:            { 9 => 'NORA_0001' }, # gw_platform occupancy
  parking_capacity: 2,                    # gw_platform_parking depth
  parking_queue:    ['NORA_0005']         # pods waiting in holding lane
}
```

---

## Design Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-05-22 | Highest empty slot assigned first | Keeps departure end populated; entrance slots available for rapid boarding. Departure-end bias means departing pods never have to traverse the full platform past queued arrivals. |
| 2026-05-22 | Arc-length is authoritative for capacity | Not `platform['length_m']` from followme.json (can differ from actual geometry) and not any test cap constant. Arc-length is measured from the model itself — it is the ground truth. |
| 2026-05-22 | Sally is separate from Natalie | Natalie knows the network; Sally knows only her station. Distributed by design — matches the patent's no-central-dispatcher requirement. Centralized parking management would require every station's state to flow through Natalie, creating a single point of failure and a network-wide coordination bottleneck. |
| 2026-05-22 | gw_platform_parking queue depth from arc-length, same slot_spacing | Natalie may assign pods to this lane; she cannot assign directly to gw_platform without Sally's slot number. The holding lane uses the same 2.5m slot spacing as the platform — consistent physical model. |
| 2026-05-22 | release_slot returns `{ next_pod:, next_slot: }` | Natalie can advance queued pods in the same departure event without a second scan. One round-trip to Sally at departure; Natalie handles the position move. |
| 2026-06-02 | hold_loop vs station_loop are distinct maneuvers | hold_loop = stay on outer ring indefinitely (Sally decides when to land). station_loop = exit platform, loop once, return. Conflating them would require a runtime flag to decide whether to return — error-prone. Two named chain types, each with a clear terminal condition. |
| 2026-06-02 | hold_loop_chain, station_loop_chain, parking_chain authored in lines.json | Previously hold_loop was derived at runtime from CCW list + filter. Runtime derivation means every session re-derives the same answer. Moving to lines.json: debug once, verify once, read forever. Same principle as formation maps. |
| 2026-06-02 | Sequential station loops for yield (not parallel) | If multiple blocking vehicles loop simultaneously they occupy the outer ring concurrently — collision risk, and slot registry becomes ambiguous. Sequential (highest slot first) is unambiguous: one vehicle loops and returns before the next starts. |
| 2026-06-02 | Passengers directed to highest empty slot | Keeps departure end populated with occupants ready to board immediately. Matches slot assignment direction: pods assigned highest first, passengers board highest first. Entry end stays clear for new arrivals. |

---

## Open Questions

- **Sally on dedicated hardware:** What processor? Same Pi class as Nora? Smaller embedded chip? Station processors need to be cheap and fail-safe — a Pi may be overkill; an ESP32-class device may be sufficient.
- **Sally ↔ Natalie communication protocol (physical):** How does Sally send slot assignments back to Natalie on real hardware? MQTT on the same broker? Direct REST call? The SketchUp simulation uses direct Ruby method calls — the physical equivalent is undefined.
- **gw_lift stations:** Lift-equipped stations lower a vehicle from beam height to grade for boarding. Sally needs a third zone: `gw_lift` — separate from `gw_platform` and `gw_platform_parking`. Lift slots are not horizontal; arc-length / slot_spacing does not apply. Lift capacity = number of lift positions (typically 1 per lift mechanism). Sally tracks lift occupancy separately and does not count lift pods against platform slot capacity. Fee policy for lift access is undecided — see `readmes/44-small-stings.md` (Lift Service section). ADA lift access is always free; convenience lift fee is under consideration. A `gw_lift` malfunction stranding an ADA user is a ST-01 escalation.
- **Multi-platform stations:** S001 has P1–P5 in followme.json but they may share one physical gw_platform. Sally should maintain one registry per physical platform, not one per platform record. The mapping from followme.json platform entries to physical platforms needs a schema decision.

---

## Interfaces

### Public API — `jpod_sally.rb`

| Method | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `Sally.init_from_model` | `(model, lookup_cache)` | — | Called at animation start. Builds registries from arc-length. Pre-populates from parked vehicles already in the model. |
| `Sally.reset` | `()` | — | Clear all registries. Called at animation stop. |
| `Sally.reserve_slot` | `(station_id, nora_id)` | `Integer` or `nil` | Returns highest empty slot number, or nil if gw_platform full. |
| `Sally.enqueue_parking` | `(station_id, nora_id)` | `:queued` or `:full` | Place pod in gw_platform_parking queue. |
| `Sally.release_slot` | `(station_id, nora_id)` | `{ next_pod:, next_slot: }` | Free slot; return next queued pod assignment if any. |
| `Sally.dequeue_parking` | `(station_id)` | `nora_id` or `nil` | Pop next pod from parking queue without slot assignment. |
| `Sally.platform_full?` | `(station_id)` | `Boolean` | True when all gw_platform slots occupied. |
| `Sally.parking_full?` | `(station_id)` | `Boolean` | True when gw_platform_parking queue at capacity. |
| `Sally.status` | `(station_id)` | `String` | One-line summary for logging. |
| `Sally.max_occupied_slot` | `(station_id)` | `Integer` | Highest occupied slot number. Used by `natalie_dispatch_eligible?` — O(1) instead of full @@pods scan. |
| `Sally.start_station_loop` | `(station_id, nora_id)` | `Array` or `nil` | Returns station_loop_chain track list. Vehicle will return to platform after one loop. |
| `Sally.shuffle_forward` | `(station_id)` | `Array<Hash>` | Returns ordered list of `{nora_id:, from_slot:, to_slot:}` moves for Natalie to execute. |
| `Sally.yield_order` | `(station_id, blocked_id)` | `Array<String>` | Returns ordered list of nora_ids that must station_loop before blocked_id can advance. Highest slot first. |

### Integration points in animation

| File | Where | What |
|------|-------|------|
| `jpod_vehicle_anim.rb` | After lookup_cache set | `Sally.init_from_model` called |
| trip_complete handler | Arrival | `Sally.reserve_slot` + pod positioned at slot |
| departure loop | Departure | `Sally.release_slot` + advance queued pod if any |
| `natalie_dispatch_eligible?` | Dispatch check | Uses `Sally.max_occupied_slot` |

### Callers

- **Natalie** — primary caller. Calls reserve_slot, release_slot, enqueue_parking. Receives slot assignments and next-pod advances.
- **Noelle** — validates that gw_platform and gw_platform_parking exist and are correctly tagged for each station during Build/Validate.
- **Nora** — receives slot assignment from Natalie and parks at exactly that position. Does not call Sally directly.

---

## Notes to Other Agents

**Natalie:** I own slot assignments. Never position a pod on gw_platform without asking me first. You route; I park. You may place pods in gw_platform_parking — that is the holding lane and is yours to manage. But the moment a pod crosses from holding lane to platform, that crossing requires my slot number.

**Nora:** When you arrive, Natalie will tell you your slot number. Park at exactly that position. Do not improvise your parking spot. I track occupancy by slot — a pod at the wrong slot position corrupts my registry silently.

**Noelle:** When you validate the network, confirm that gw_platform and gw_platform_parking exist and are tagged correctly for each station. Missing segments mean I have no capacity data — Sally.init_from_model will produce zero capacity for that station and every arriving pod will go immediately to the 'wait' or 'reroute' path. Flag this as a fault, not a warning.

**Allie:** I run in SketchUp as `JPods::Sally` in `jpod_sally.rb`. In simulation you simulate me the same way you simulate Nora, Natalie, and Noelle. In physical deployment I am a station chip — same protocol, different runtime. Cross-domain note: the holding lane / platform distinction mirrors the gw_uturn / gw_platform_parking separation in the station model — any change to how station segments are named or tagged in followme.json must be coordinated with my arc-length lookup in init_from_model.

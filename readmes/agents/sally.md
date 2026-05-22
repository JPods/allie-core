# Sally — Station Processor

**One-liner:** Local parking manager at each JPods station — assigns slots on gw_platform, manages the gw_platform_parking holding lane, and advances queued pods on departure.

**Ouch-list items I own:** Multi-platform stations (S001 P1–P5 share one physical platform — one registry per physical platform, not per platform record); gw_lift slot numbering (arc-length calc needs adjustment for vertical lift segments); physical comms protocol (slot assignment back-channel to Natalie not yet defined).

**Signing status:** Non-standing actions (slot assignments) are local and self-signed. No Athena signature required — Sally's scope is entirely intra-station.

---

## Responsibilities

Sally is the station processor. Her domain is entirely local: she manages who parks where at a single station. She does not know about the rest of the network.

**Two zones per station:**

1. **gw_platform** — the parking track. Slots numbered 1–N where slot 1 = entrance end (inbound) and slot N = departure end (highest). Sally always assigns the **highest available empty slot** to each arriving pod so the departure end stays populated and entrance slots remain free for incoming vehicles. Capacity = `arc_length_of_gw_platform / 2.5m` (slot spacing).

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
3. If a pod is queued in gw_platform_parking, Sally immediately assigns it the freed slot and returns `{ next_pod:, next_slot: }` to Natalie
4. Natalie moves the dequeued pod from gw_platform_parking to gw_platform at the assigned slot

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

---

## Open Questions

- **Sally on dedicated hardware:** What processor? Same Pi class as Nora? Smaller embedded chip? Station processors need to be cheap and fail-safe — a Pi may be overkill; an ESP32-class device may be sufficient.
- **Sally ↔ Natalie communication protocol (physical):** How does Sally send slot assignments back to Natalie on real hardware? MQTT on the same broker? Direct REST call? The SketchUp simulation uses direct Ruby method calls — the physical equivalent is undefined.
- **gw_lift stations:** Slot numbering may be vertical rather than horizontal on lift segments. Arc-length calculation needs adjustment for lift segment type — a lift is not a horizontal track and slot spacing in the arc may not correspond to usable vertical positions.
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

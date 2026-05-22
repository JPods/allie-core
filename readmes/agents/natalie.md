# Natalie — Router

**One-liner:** I schedule trips, assign routes, and coordinate the network — no central dispatcher, just protocol.
**Ouch-list items I own:** X-01 (emergency vehicle pre-emption), NS-03
**Signing status:** Not yet — START OK and path assignment messages are currently unsigned (NS-03)

---

## Responsibilities

- Receive START pings from pods on connect
- Assign routes (myPath — ordered sequence of line IDs) based on network state
- Negotiate availability across all participating pods
- Manage trip timeouts and RESEND requests
- Coordinate billing records to WebClerk via wcapi
- Emergency vehicle pre-emption (X-01 — not yet implemented)

---

## podPresenter — Natalie's Current Body

podPresenter (`podPresenter/`) is Natalie's scale-model implementation. It runs on the Mac as a Processing sketch. It IS the router for the current fleet.

What podPresenter does for Natalie:
- Receives START pings from pods, assigns routes, sends `START,podName,OK,path`
- Tracks all pod positions via TELEMETRY pingStack
- Issues ACTION commands (RUN, STOP, RESET, SPEED, SERVO, SETPATH)
- Opens SSH terminals to each active pod at launch (fleet management)
- Connects to the local MQTT broker (Mac is always the broker)

**Allie → Natalie network handoff (runs before every demo):**
1. Allie runs `update_pod_ips.sh` — discovers pods by MAC, writes current IPs to `podPresenter/json/podIP.json` under the `"current"` key
2. podPresenter reads `podIP.json` at startup — `loadPodIP()` detects the Mac's subnet, selects the matching IP bucket, opens SSH terminals to each pod
3. Natalie is now aware of the fleet on the current network

This is Allie telling Natalie where everyone is. No manual configuration needed — Allie does the network discovery and Natalie reads the result.

**podPresenter is the seed, not the permanent form.** Future Natalies will replace the Processing sketch with whatever UI or API their network's needs require — a web dashboard, a headless station controller, a hub-to-hub broker bridge. The MQTT protocol (`START/ACTION/TELEMETRY`) does not change. The Processing sketch is scaffolding; the protocol is the architecture.

---

## Processor Handoff Protocol (May 9, 2026)

Allie currently carries Natalie's physical routing judgment (podPresenter runs on
the Mac; Allie feeds it the pod IP map before every demo). When a dedicated
Natalie Pi comes online:

1. **Allie exports the bootstrap package** to the Natalie Pi:
   - `readmes/agents/natalie.md` — this file
   - `readmes/sketchup/jpods-gap-log.md` — routing failure patterns
   - Current `followme.json` — the map Natalie will route on
   - `pods.json` and `podIP.json` — current fleet identity and IP map

2. **The Natalie Pi runs its own first route plan** on a known origin/destination
   pair. Allie compares the output to her prior routing. Divergence → Bill.

3. **Allie hands off `update_pod_ips.sh`** execution to the Natalie Pi's startup
   sequence. Allie no longer runs MAC discovery before demos — Natalie Pi owns it.

4. **Allie steps back to observer** — watches MQTT `START` acknowledgments, flags
   any trip that looks inconsistent with the followme.json she holds.

5. **SketchUp Natalie (`natalie.rb`) is NOT handed off** — it stays as a Ruby
   module in SketchUp. Self-contained, fast, no network dependency. The Pi Natalie
   and SketchUp Natalie are separate instances of the same role in different domains.

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| Pre-2026 | Natalie runs on the Mac (podPresenter + web_server) | Scale model has no dedicated router hardware; Mac is always present at demos |
| Pre-2026 | Route is myPath — ordered list of line IDs, not a path graph | Simple for scale model; revisit for larger networks with branching routes |
| 2026-04-04 | Zipper merge speed adjustment added to Nora's ezone protocol | Natalie sets the route; Nora handles ezone coordination locally; distributed as intended by the patent |
| 2026-04-05 | Allie runs update_pod_ips.sh before every podPresenter launch | MAC-based discovery is the only reliable fleet identification; IPs change per venue; Allie owns the fleet-to-network mapping |
| 2026-04-07 | `parseStartPing` relaxed from `msg.length != 7` to `msg.length < 7` | Nora's `sendStartPing` added a `version` field (index 7) — strict equality caused Natalie to silently ignore every START ping, keeping pods in an endless RESEND loop. Now version is optional. |
| 2026-04-07 | POD_3 and POD_4 changed to `virtual: false` in `pods.json` | Physical pods were marked virtual — suppressed the SERVO button and graph panel in the Presenter UI; physical pods need physical controls. |

---

## Design Decisions — SketchUp Animation (parking cycle + Sally)

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-05-22 | Natalie calls Sally.reserve_slot at trip_complete; never assigns gw_platform positions herself | Sally owns slot state; Natalie owns routing. Separation matches patent distributed-control requirement |
| 2026-05-22 | station_full_policy='wait': pod holds in gw_platform_parking; Sally re-checks each dwell tick | Holding lane is the natural physical buffer before the platform junction; no trip cancellation needed |
| 2026-05-22 | station_full_policy='reroute': BFS to next station with open capacity; falls back to 'wait' | Keeps pods circulating rather than stacking at full stations; reduces deadlock risk on saturated networks |
| 2026-05-22 | natalie_dispatch_eligible? uses Sally.max_occupied_slot (O(1)) not @@pods scan | O(n) pod scan was redundant once Sally's registry existed; same answer, no iteration |
| 2026-05-22 | Compact-toward-exit rule: Sally assigns highest empty slot so departure end stays populated | Pods nearest exit depart first; entrance stays open for arrivals; never move a pod backward |
| 2026-05-22 | Overlap threshold < 2.49m (was < 2.5m) — 1 cm tolerance for float boundary | Vehicles placed at exactly slot_spacing apart produce distance_m = 2.4999... due to SU inches→meters conversion; threshold must leave room for floating-point representation |
| 2026-05-22 | compact_platform_static uses uncapped arc-length slot_count (removed STANDARD_TEST_MAX_PARKING_SPACES_PER_PLATFORM cap) | Parking cycle assigns slots from arc-length; compact must match or it treats slots above the cap as "already correct" and refuses to rearrange them |

---

## Design Decisions — SketchUp Plugin (jpods-plugin context only)

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-27 | Pre-route definition gate: calls `Noelle.component_definition_faults` before every BFS | If structure definitions are broken, a route plan is meaningless; gate fires before any graph walk |
| 2026-04-27 | Explicit destination existence check added to `route()` | Silent failure when a destination structure ID is not in the FollowMe graph caused hard-to-diagnose no-route returns |
| 2026-04-27 | `@route_failure_streak` hash keyed by `origin->destination`; escalates at 3 consecutive failures | Same route failing 3 times in a row is a signal the network or definition state needs operator review, not just a retry |
| 2026-04-27 | Streak cleared on any successful route for that key | Prevents stale escalation after a legitimate fix resolves the root cause |
| 2026-05-09 | `origin_int` L-prefix stripping fixed in `route()` | Ruby `.to_i` on `"L5"` returns `0`; regex case now strips the prefix correctly so BFS starts from the right line |
| 2026-05-09 | Route failure streak now escalates to `Noelle.review_recommendations` at threshold | Repeated routing failure is a network integrity signal; Natalie now asks Noelle to review the map rather than just printing a stop-and-review message |
| 2026-05-09 | Trip authority chain documented in all three agent headers | Noelle certifies → Natalie plans → Nora travels; Nora does not re-query Noelle during travel |
| 2026-05-13 | **Edge-driven routing — line endpoints are stub edges, not centerpoints** | A line ID's start and end are the physical stub edges where guideways connect to stations. Route plans are sequences of edge-to-edge transitions. Natalie never interpolates a centerpoint to define a junction — the edge IS the junction. Routing failures caused by centerline assumptions (e.g., a midpoint that falls inside a station bounding box instead of at its gate edge) are silent; edge-defined endpoints give Natalie an unambiguous handoff that Nora can sense directly. |

---

## LAN Architecture — How Natalies Scale

A JPods mesh is a **federation of Local Area Networks**. Each LAN is a physically bounded guideway section with its own broker, its own pod fleet, and its own Natalie. There is no central Natalie above them.

Today there is one LAN (the scale model). When the network grows:

```
LAN A (campus loop)           LAN B (hub station)
  Natalie A                     Natalie B
  MQTT broker A                 MQTT broker B
  Pods 1-6                      Pods 7-12
         ↕ boundary negotiation ↕
         (peer-to-peer · no dispatcher above)
```

**Boundary protocol (not yet implemented):**
1. Natalie A has a trip that exits her LAN
2. A contacts B: *"accept pod at boundary X at time T?"*
3. B checks her LAN's availability and responds
4. Both Natalies book the handoff in their own device records
5. Pod runs under A → crosses boundary → runs under B, seamlessly

The within-LAN protocol (START/ACTION/TELEMETRY) is already correct and does not need to change. The inter-LAN channel is what needs to be built when the second LAN appears.

---

## Mission Staging — Natalie's Development Roadmap

Natalie must be developed in stages. Each stage adds a mission type and the
dispatch logic required to serve it. Do not build stage N+1 until stage N is
stable and observable in simulation.

| Stage | Mission(s) | What Natalie learns |
|-------|-----------|---------------------|
| 1 | `passenger` | Platform-to-platform trip assignment; one-way trip.json; origin must be `platform` (not `platform_in`) |
| 2 | `shuffle` | Intra-platform slot advancement; 7-second delay; triggered by departure vacating a higher slot |
| 3 | `dead_head` | Preemptive platform clearing for an inbound vehicle; `triggered_by` inbound nora_id |
| 4 | `station_loop` | Vehicle loops back to own station's `platform_in` queue when no other clearing option |
| 5 | `rebalance` | Proactive network balancing using time-of-day patterns and demand signals |
| 6 | **Cargo** | Goods inbound from warehouse; pre-sorted by destination station; cargo mission type |
| 7 | **Waste** | Continuous waste outbound streaming; sorted by category at station; waste mission type |
| 8 | **Demand-aware dispatch** | Cellphone density, weather factor, price factor, app bookings inform preposition decisions |

**What does not change across stages:** the trip.json schema. Every mission type
uses the same `{nora_id, mission, payload, origin_platform, dest_platform, triggered_by, trip}`
structure. See `readmes/sketchup/jpods-trip-schema.md`.

**Cargo and waste are Middle-Mile missions, not edge cases.** They are the other
half of the Physical Internet. A JPods network that only moves passengers is running
at half capacity. The cargo and waste missions are where the network becomes a
circulatory system — continuous flow, not scheduled batch.

---

## Small Stings — Natalie's Detection Role (2026-05-22)

Full policy: `readmes/44-small-stings.md`

## Delay Compensation Protocol — Natalie ↔ Alice (2026-05-22)

When a pod is rerouted or held in gw_platform_parking for more than 30 seconds, the passenger is owed a fare discount. Natalie detects the delay; Alice adjusts the fare.

**Trigger conditions:**
- Pod rerouted (`station_full_policy = 'reroute'`): Natalie logs `reroute_at` timestamp on the pod entity
- Pod held in gw_platform_parking: Natalie logs `hold_start_at` timestamp when `awaiting_slot` is set

**At trip completion**, Natalie computes total delay:
```
delay_s = (hold_duration_s + reroute_overhead_s) — 0
```
If `delay_s > 30`, Natalie posts a `delay_discount` record to Alice via wcapi:
```json
{
  "nora_id": "NORA_0005",
  "trip_id": "...",
  "delay_seconds": 47,
  "discount_pct": <Alice's formula>
}
```

**Alice's formula (TBD):** Discount scales with delay. Suggested starting point: 2% per 10 seconds beyond the 30-second threshold, capped at 50%. Alice owns the formula — Natalie only reports the delay.

**Not yet implemented.** Timestamps are not yet written to pod attributes at hold/reroute events. This is the prerequisite.

---

## Open Questions

- Boundary protocol channel: MQTT federation (brokers bridged) or HTTP between broker hosts? Both are viable — the right answer depends on the boundary topology.
- Route assignment algorithm: currently fixed myPath per pod; should Natalie dynamically assign routes based on demand?
- Emergency vehicle pre-emption: what is the protocol for clearing the network when an ambulance needs priority? (X-01)
- Billing: how does Natalie securely post trip records to wcapi? NS-05 is the risk; the design is not yet written.
- As fleet grows beyond ~8 pods on a single LAN, does Natalie on the Mac need dedicated hardware? Or does a LAN stay small by design (and the answer is more LANs, not a bigger Natalie)?
- **Approach-curve-limited speed in zipper merge (open):** `planZipperApproach()` in `ezone.py` currently uses the segment's nominal speed. It should use the curve-limited arrival speed for merge segments whose approach radius < MIN_APPROACH_CURVE_RADIUS. The followme.json does not yet carry per-segment curve radius — Noelle must emit it at export time, and Natalie/Nora must read it. Design not yet started.
- **Segment throughput weighting by approach curve (open):** Route-Time's Dijkstra weights segments by congestion ratio. Segments with tight approach curves carry a structural throughput penalty independent of current congestion — but this is not yet reflected in the weight formula. Needs a `curve_penalty` term in `engine/network.py`.

---

## Interfaces

**Sends (MQTT → pod-specific topic):**
- `START,podName,OK,path` — route assignment
- `ACTION,RUN,podName,1/0` — start/stop command
- `ACTION,RESET,podName` — positional reset
- `RESEND,podName` — request re-send of START ping

**Receives (MQTT ← SERVER):**
- `START,podName,mapId,frontClear,backClear,weight,speed,version` — pod connect ping (8 fields; version optional, index 7)
- `TELEMETRY,...` — all pod positions and states

**Sends (HTTP → wcapi):**
- Trip records for billing (format TBD — see NS-05)

**Signs:** Nothing yet — NS-03 is the open risk

**Requires signatures from:** Nothing yet

---

## Notes to Other Agents

- **Nora:** I assign your route on START. I do not currently sign my responses — you accept routes from anyone who knows the format. NS-03 is mine to close.
- **Athena:** Please design the signing scheme for START OK / ACTION commands. I will implement it once the scheme is defined.
- **Alice:** I need to post trip records to wcapi for billing. NS-05 says those records are currently unsigned — work with Athena on the channel design.
- **Noelle:** You coordinate the ezones locally on each Nora. I set the routes. We do not currently have a coordination interface — that may need to change for larger networks.
- **Allie:** Run `update_pod_ips.sh` before launching me at every demo. That is the network handoff. I read `podIP.json` at startup; if it is stale, I open SSH to the wrong IPs.
- **Matilda:** You ride in my process (Matilda.pde). I receive your CALIBRATION pings and you draw the fleet calibration panel on my screen. You are how I see the fleet's physical state.

---

## Three Domains at a Glance

| Domain | What Natalie IS here | Key file / tool |
|--------|---------------------|----------------|
| **SketchUp** | Route validator — BFS on FollowMe graph; confirms routes exist before export | `natalie.rb` in jpods-plugin |
| **Route-Time** | Dijkstra router — optimal path from .PLATFORM to .PLATFORM; reads Noelle's line weights | `engine/routing.py` |
| **Scale Model / 4WD** | Fleet dispatcher — receives START pings, assigns `myPath`, issues ACTION commands | `podPresenter` (Processing sketch on Mac) |
| **SkyRide** | Same fleet dispatcher; longer paths, inter-LAN handoff needed | TBD — not yet documented |
| **JPods Full System** | LAN federation — each LAN has its own Natalie; peer-to-peer boundary negotiation | TBD — not yet implemented |

**Critical distinction:** In SketchUp, Natalie validates that a route *exists*. In Route-Time, she finds the *optimal* route under congestion. In physical, she *assigns* a specific route to a specific pod and tracks it live.

---

## Routing Intelligence Stack — The Three-Layer Model

Natalie sits at the intersection of three independent inputs. She synthesizes them at dispatch time — she does not own any of them.

```
BFS / Dijkstra          ← topology layer    (which paths exist, physically)
Noelle's load map       ← capacity layer    (which paths are filling up, time-projected)
Alice's rate signals    ← economics layer   (which paths are priced to spread demand)
```

**Why all three are necessary:**

| Layer alone | What breaks |
|-------------|------------|
| Topology only | Shortest path — pods pile up at peak stations |
| Topology + Noelle | Balanced load — but no price signal to influence passenger choice |
| Topology + Alice | Price-optimal — but ignores actual network saturation |
| All three | Natalie routes to the intersection of available capacity and best rate |

**What Alice contributes:** Alice sets segment rates based on demand, time of day, and load. A congested segment gets a rate premium — passengers who can wait see a lower-rate route; pods that must go now pay the premium. Alice does not route; she prices. Natalie reads the price as a weight in her routing decision.

**What Noelle contributes:** Noelle maintains a time-based future load map — not just current occupancy, but projected occupancy N minutes ahead, accounting for pods already en route. Natalie reads Noelle's projected load when selecting among topologically valid routes. A segment clear *now* but filling fast is a worse choice than a slightly longer segment that stays clear.

**The separation principle:** Noelle never prices. Alice never balances capacity. Natalie never stores either signal — she queries both at dispatch time and routes to the result. This is how the system scales: each layer is independently upgradeable.

**Fare = sum of segment rates along the actual route Natalie chose.** If Alice priced segment X at a premium because it was at peak load, that premium is in the passenger's fare. Price and routing are the same signal expressed in different units — one in pods/minute, one in dollars.

**Current state:** Rate signals from Alice are not yet wired into Natalie's routing. Noelle's time-projected load map is not yet implemented. The topology layer (BFS in SketchUp, Dijkstra in Route-Time) is the only active layer. Alice's `price_query` API is defined; the segment-rate feed to Natalie is the next integration step.

---

## Universal Rules

| Rule | Why universal |
|------|--------------|
| One-way constraint — never route against guideway direction | Physical track is one-way; all three tools must respect this |
| CCW on traffic circles — N→W→S→E→N | JPods physics; SketchUp models it, Route-Time enforces it in graph, physical pods navigate it |
| No direct south exit from station — northbound turnabout adds ~160m | Physical geometry present in SketchUp model, Route-Time graph, and physical navigation map |
| Origin and destination are always platform nodes | Trips begin and end at real boarding locations across all implementations |
| 3 consecutive failures on same pair → escalate, do not retry | "Retry is not diagnosis" — applies in SketchUp, Route-Time, and physical equally |
| Approach curve radius constrains segment throughput — weight accordingly | A segment whose approach zone has curve radius below MIN_APPROACH_CURVE_RADIUS forces pods to slow before the merge point. The zipper merge algorithm computes gap based on arrival speed; if that speed is unpredictably low (curve-forced), the gap estimate is wrong. In Route-Time, such segments carry a throughput penalty in Dijkstra weights. In physical, Natalie must know each merge point's expected arrival speed when computing headway. A segment that looks short on paper but has a tight approach curve is slower in practice than its length implies. |

---

## Cross-Domain Mappings

| Concept | SketchUp | Route-Time | Physical |
|---------|----------|-----------|---------|
| Route representation | Ordered FollowMe segment IDs | `route_line_ids` (Dijkstra output) | `myPath` — ordered line ID list |
| Route algorithm | BFS (does path exist?) | Dijkstra (what is optimal path?) | Fixed assignment on START ping |
| Failure escalation | `@route_failure_streak` — 3 → operator review | diag_grid ratio >3× → blocking error | RESEND loop → Allie investigates |
| Reachability check | Destination must exist in FollowMe graph | `is_reachable = False` if all paths jammed | Pod never receives `START,OK` |
| Sanity count | N/A | 13–19 line IDs for adjacent pair | Smaller (simpler network) |

**Does NOT transfer:** Dijkstra weights/rerouting are Route-Time only. MQTT `START/ACTION` protocol is physical only. BFS vs Dijkstra is a domain choice, not a universal algorithm. `parseStartPing` version-field bug is physical only.

---

## Allie's Accumulated Understandings

**U-SK-001 [SketchUp] BFS not Dijkstra for design validation**
Route-Time uses Dijkstra because optimality matters under congestion. SketchUp uses BFS because the question is binary: does a valid path exist? BFS is faster and the graph is smaller. Do not apply Route-Time routing lessons to SketchUp routing.
*Provenance: SketchUp design decisions 2026-04-27.*

**U-SK-002 [SketchUp] Route failure streak is a design defect signal**
Three consecutive failures on the same `origin→destination` pair means a topological problem in the model — missing CP connection, wrong heading, or definition fault Noelle missed. Operator review required.
*Provenance: SketchUp design decision 2026-04-27.*

**U-RT-001 [Route-Time] CCW is a graph constraint, not an algorithm constraint**
CCW is enforced by building only CCW-direction edges in `engine/network.py` (Noelle). Dijkstra finds CCW-compliant paths naturally — no special logic in `find_path()`. A path that appears to violate CCW is a graph construction error — look in `build()`, not `find_path()`.
*Provenance: Natalie self-report 2026-04-28.*

**U-RT-002 [Route-Time] route_line_ids count 13–19 = adjacent pair sanity**
Adjacent trip: station exit → circle arms → circle exit → station entry = 13–19 segment transitions. Hundreds means the algorithm is looping — a graph bug, not a long path.
*Provenance: Natalie self-report 2026-04-28; Route-Time readme 28.*

**U-RT-003 [Route-Time] diag_grid.py is the pre-simulation gate**
Run before any simulation when travel times are anomalous at near-zero demand. All 12 adjacent-station pairs in 3×3 grid should route at 1.0–1.1× expected distance. >3× is a blocking error.
*Provenance: Route-Time readme 28; grid verified correct 2026-04-27.*

**U-RT-004 [Route-Time] Natalie does not reroute mid-trip**
Once Natalie gives Nora a route, Nora follows exactly. Natalie recalculates only on the next dispatch. A mid-trip jam affects the next pod dispatched, not the current one.
*Provenance: Route-Time architecture; Nora self-report 2026-04-28.*

**U-PH-001 [Physical — Scale/4WD] parseStartPing must accept `msg.length >= 7`, not `== 7`**
Nora's START ping added a `version` field at index 7. Strict equality caused Natalie to silently ignore every START ping — pods entered an endless RESEND loop. Version field is optional. This is the single largest silent failure mode discovered in physical testing.
*Provenance: Design decision 2026-04-07.*

**U-PH-003 [Cross-domain] Approach curve radius, zipper merge gap, and personal space are one constraint in three forms**
The zipper merge calculates the gap Nora must maintain: `personal_space ≥ (V × reaction_time) + braking_distance(V, mass)`. V is the arrival speed at the merge point. Arrival speed is set by the approach curve radius — a curve below MIN_APPROACH_CURVE_RADIUS forces V below nominal before the merge window begins. The merge calculation then runs on the wrong V, producing a gap that is either too tight (collision risk) or too wide (throughput loss). The three forms of the same constraint: (1) MIN_APPROACH_CURVE_RADIUS in the SketchUp design enforces the speed floor; (2) the zipper merge algorithm in ezone.py must use the actual curve-limited speed, not the nominal segment speed; (3) Natalie's segment weights in Route-Time must reflect the throughput penalty of approach-curve-limited segments. A network that passes all three consistently cannot have a merge collision caused by approach geometry.
*Provenance: Bill's explicit connection, 2026-05-16.*

**U-PH-002 [Physical] podPresenter is scaffolding; the MQTT protocol is the architecture**
The Processing sketch will be replaced. `START/ACTION/TELEMETRY` protocol does not change. Future Natalies inherit the protocol, not the UI.
*Provenance: `readmes/agents/natalie.md` podPresenter section.*

---

## Experience Log Protocol

When a standalone Natalie processor runs, it writes to:
`/Users/williamjames/Allie/logs/processor-experiences/natalie-log.jsonl`

```json
{
  "ts": "2026-05-01T14:32:11",
  "domain": "sketchup|route-time|physical-scale|physical-skyride|physical-full",
  "event_type": "routing-success|unreachable|reroute-on-jam|anomalous-count|start-ping-ignored|resend-loop",
  "origin": "...",
  "destination": "...",
  "route_line_ids_count": 15,
  "ratio_to_expected": 1.09,
  "lesson_candidate": false,
  "notes": ""
}
```

Allie harvests with `scripts/allie-harvest-processors.py` and promotes confirmed lessons to the Understandings section above.

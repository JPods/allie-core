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

## Design Decisions — SketchUp Plugin (jpods-plugin context only)

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-27 | Pre-route definition gate: calls `Noelle.component_definition_faults` before every BFS | If structure definitions are broken, a route plan is meaningless; gate fires before any graph walk |
| 2026-04-27 | Explicit destination existence check added to `route()` | Silent failure when a destination structure ID is not in the FollowMe graph caused hard-to-diagnose no-route returns |
| 2026-04-27 | `@route_failure_streak` hash keyed by `origin->destination`; escalates at 3 consecutive failures | Same route failing 3 times in a row is a signal the network or definition state needs operator review, not just a retry |
| 2026-04-27 | Streak cleared on any successful route for that key | Prevents stale escalation after a legitimate fix resolves the root cause |

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

## Open Questions

- Boundary protocol channel: MQTT federation (brokers bridged) or HTTP between broker hosts? Both are viable — the right answer depends on the boundary topology.
- Route assignment algorithm: currently fixed myPath per pod; should Natalie dynamically assign routes based on demand?
- Emergency vehicle pre-emption: what is the protocol for clearing the network when an ambulance needs priority? (X-01)
- Billing: how does Natalie securely post trip records to wcapi? NS-05 is the risk; the design is not yet written.
- As fleet grows beyond ~8 pods on a single LAN, does Natalie on the Mac need dedicated hardware? Or does a LAN stay small by design (and the answer is more LANs, not a bigger Natalie)?

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

## Universal Rules

| Rule | Why universal |
|------|--------------|
| One-way constraint — never route against guideway direction | Physical track is one-way; all three tools must respect this |
| CCW on traffic circles — N→W→S→E→N | JPods physics; SketchUp models it, Route-Time enforces it in graph, physical pods navigate it |
| No direct south exit from station — northbound turnabout adds ~160m | Physical geometry present in SketchUp model, Route-Time graph, and physical navigation map |
| Origin and destination are always platform nodes | Trips begin and end at real boarding locations across all implementations |
| 3 consecutive failures on same pair → escalate, do not retry | "Retry is not diagnosis" — applies in SketchUp, Route-Time, and physical equally |

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

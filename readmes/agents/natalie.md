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
- `START,podName,...` — pod connect ping
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

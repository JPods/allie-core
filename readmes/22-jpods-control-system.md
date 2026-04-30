# JPods Control System — Nora, Natalie, Noelle
**Action:** Reference when building or extending JPods vehicle, routing, or load balancing code
**Function:** System architecture for the three control behaviors defined in US Patent 6,810,817
**Frequency:** Read at start of any JPods control system session
**Process:** Build against patent claims; keep behaviors separated by agent spec

---

## Overview

US Patent 6,810,817 (granted 2004, inventor: William James) defines a distributed intelligent transport system with **no centralized control**. Devices coordinate via protocol — no master controller, no dispatcher.

The patent maps to three behavioral roles:

| Agent | Role | Patent Claims |
|-------|------|--------------|
| **Nora** | Vehicle — autonomous transit pod | 1, 6, 7, 12a, 17 |
| **Natalie** | Router — trip scheduling and routing | 8, 9, 11, 12, 13 |
| **Noelle** | Load Balancer — switches, stations, storage, prepositioning | 3, 4, 5, 11e, 14g, 14l, 18, 20 |

These are behavioral roles, not processes. Any device on the network can manifest one or more roles.

---

## Nora — Vehicle Behavior

**What Nora does:** Autonomous transit from start to end point. Executes the event loop. Monitors clearance front and back. Reads position tags (HuskyLens/AprilTags). Controls motor and servo via I2C. Reports telemetry. Responds to ACTION commands from Natalie. Coordinates with other vehicles on the same line via MQTT telemetry.

**Design constraint — PEC (Parasitic Energy Consumption):**
```
PEC = (vehicle_mass + payload_mass)²
      ────────────────────────────
              (payload_mass)²
```
- Car: PEC ≈ 676
- JPod target: PEC < 10
- Scale model: PEC ≈ 121 (vehicle ~1kg, payload ~0.1kg)
- Minimize vehicle mass; suspend from rails; dynamic inertial dampening

**Current code:** `jpod_OS/main.py`, `motor.py`, `collision.py`, `tof.py`, `servo.py`, `husky.py`

**Agent spec:** `allie/agent/nora-agent.md`

---

## Natalie — Router Behavior

**What Natalie does:** Receives START pings from pods. Assigns routes (`myPath` — ordered sequence of line IDs). Negotiates availability across the network. Schedules trips against accumulated device availability. Records routes in each participating device's database. Manages trip timeouts. Billing.

**Trip lifecycle (Claims 8, 9):**
1. Requester sends trip request
2. Negotiator accumulates time-based availability
3. Scheduler negotiates with negotiators; identifies available devices
4. Scheduler books capacity; records route in each device's database
5. Trip executes; devices report completion
6. Emergency management via negotiators if timeout

**What Natalie knows:** The map (lines, segments, lengths, ezones). All pods' current positions via telemetry. Available routes. Historical demand patterns (for prepositioning).

**Current code:** `podPresenter/` (visualization + control), `web_server/` (Node.js), MQTT START/RESEND/ACTION handlers

**Agent spec:** `allie/agent/natalie-agent.md`

---

## Noelle — Load Balancer Behavior

**What Noelle does:** Manages exclusive zones (switch coordination points where only one pod may be at a time). Accumulates device availability. Prepositioning — dispatches vehicles to anticipated demand locations before requests arrive. Storage management — moves idle vehicles to storage rails, recalls when needed.

**Key insight:** Noelle is already implemented as a **distributed behavior**. Each Nora instance runs the ezone logic and broadcasts state via MQTT. The emergent coordination IS Noelle. There is no central Noelle process. This is the patent's core innovation: distributed network without centralized control.

**Behaviors:**
- `ezone.py` — exclusive zone stack (distributed switch coordination)
- Speed adaptation in `collision.py` — stop/slower/default/faster based on proximity
- Storage dispatch (not yet implemented in scale model)
- Historical demand prepositioning (not yet implemented)

**Agent spec:** `allie/agent/noelle-agent.md`

---

## JPods LAN Architecture — The Mesh of Bounded Networks

A JPods deployment is a **federation of Local Area Networks**. Each LAN is a physically bounded section of guideway — a station loop, a campus segment, a city block. Each LAN governs itself.

### LAN Boundaries

A boundary is any point where one LAN's guideway meets another's — a hub station, a merge junction, a transfer loop. Boundaries are managed, not dissolved. A pod crossing a boundary is a guest on the next LAN; it follows that LAN's rules while it is there.

### What Each LAN Contains

| Resource | Owned by |
|----------|---------|
| Guideway and pods | LAN's local operator |
| MQTT broker | Mac or station controller — one per LAN |
| Natalie instance | Routes within the LAN; negotiates at boundaries |
| Noelle behavior | Distributed across all Noras on the LAN |
| Fleet JSON | Allie maintains on her drive; matches MAC to LAN |

### How Natalies Coordinate at Boundaries

Natalies do not have a central dispatcher above them. They negotiate peer-to-peer:

1. Natalie A receives a trip request that exits her LAN
2. She contacts Natalie B at the boundary: *"can you accept a pod at boundary point X at time T?"*
3. Natalie B checks her network's availability and responds
4. Both Natalies book the boundary handoff in their own devices' records
5. The pod travels A's LAN, crosses the boundary, and runs under B's routing without interruption

No central Natalie. No dispatcher. Boundaries are agreed, not commanded.

### Today — Single LAN, Scale Model

The scale model is **one LAN**. One Natalie (podPresenter on Mac). One MQTT broker (Mac). All pods on the same WiFi network. No boundaries to manage yet.

This is the correct starting state. The protocol does not need to change as more LANs are added. What needs to be built when the second LAN appears:
- Inter-Natalie messaging channel (MQTT federation, or HTTP between broker hosts)
- Boundary point definitions (which line IDs are the handoff points)
- Cross-LAN trip scheduling (Natalie A negotiates with Natalie B before confirming the trip)

The scale model proves the within-LAN protocol. Every additional LAN replicates the same structure at the next physical boundary.

### Connection to Patent Claims

- **Claim 11e — regional accumulators:** The multi-LAN architecture IS this claim. Each Natalie is a regional accumulator for her LAN. Boundary negotiation is accumulator-to-accumulator coordination.
- **Claim 12 — network scheduler:** The trip scheduler that spans LANs — the peer negotiation protocol between Natalies — is not yet implemented.
- **Claims 8, 9 — availability negotiation:** Already implemented within a single LAN; the boundary version is the same algorithm run across a network connection.

### Sovereignty Note

Each LAN is locally governed. No external authority can command a Natalie. A pod from another LAN is a guest, operating under the receiving LAN's rules, same as a car crossing from one state highway onto another. The boundary negotiation protocol is bottom-up: peer agreement, not top-down dispatch.

---

## podPresenter — The Current Implementation

podPresenter (`/Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/podPresenter/`) is the scale-model instantiation of Natalie + Noelle + Matilda running on the Mac.

**Files:**
| File | Agent | What it does |
|------|-------|-------------|
| `podPresenter.pde` | Natalie | Map render, SSH terminal launch, MQTT broker connection, IP detection |
| `MQTT.pde` | Natalie | START/TELEMETRY/ACTION/FAULT/CALIBRATION message handlers |
| `Pod.pde` | Natalie | Per-pod state: position, speed, ezone, path |
| `GUI.pde` | Natalie | Fleet control panel — run/stop/speed/reset per pod |
| `Controller.pde` | Natalie | Aggregate fleet controls |
| `Matilda.pde` | Matilda/Noelle | Fleet calibration panel — mmStep drift, line bias, fleet_log.json |
| `Map.pde` | — | Map geometry rendering |
| `GraphLog.pde` | — | Per-pod telemetry graph |

**Network handoff — Allie tells Natalie/Noelle who is on the network:**
1. Allie runs `update_pod_ips.sh` → scans ARP for `b8:27:eb:*` MACs → writes `podPresenter/json/podIP.json` `"current"` key with live pod IPs
2. podPresenter reads `podIP.json` at launch → detects subnet → opens SSH terminals to each pod
3. Natalie now knows the fleet; Noelle has the calibration data from fleet_log.json

This is the design intent: Allie does MAC-based discovery (the only stable identity), then hands off to Natalie. IPs change at every venue. MACs do not.

**podPresenter is the seed.** The START/ACTION/TELEMETRY protocol does not change as the network grows. A JPods station controller at a real hub will be another Natalie instance reading the same message types. A hub-to-hub network will be multiple Natalies coordinating across an IP fabric. The scale model is the first correct instance of that architecture.

---

## What Is Not Yet Implemented

| Gap | Patent Claim | Notes |
|-----|-------------|-------|
| Passenger trip requester | Claim 8 | Natalie receives pod pings, not passenger requests |
| Billing computers | Claim 13 | Not in scale model |
| Solar/wind integration | Claims 10, 19 | Scale model uses wired power |
| Storage rails and dispatch | Claims 5, 20 | No storage rails in scale model |
| Inter-LAN boundary negotiation | Claim 11e, 12 | LAN architecture defined; boundary protocol not yet implemented; needs inter-Natalie channel design |
| Historical demand prepositioning | Claim 18 | Requires accumulated data over time |
| MyCarryOn integration | — | Passenger identity and trip preferences |

---

## Protocol Architecture

Devices communicate via MQTT. No central coordinator. All state is distributed.

**Message types:**
- `START` — pod requests a trip (origin → destination)
- `RESEND` — request to re-broadcast route
- `ACTION` — Natalie directs pod behavior (speed, route, wait)
- Telemetry — continuous position/state broadcast from each pod

**Ezone protocol (Noelle's core):**
- Each switch or merge point is an exclusive zone
- Only one pod may occupy an ezone at a time
- Pods broadcast ezone entry/exit via MQTT
- Collision-avoidance via distributed consensus, not central lock

---

## Connection to 5X5 Standard

Claim 7 (PEC optimization) is the mathematical foundation for the 5X5 Standard's "5x efficiency" requirement:
- Roads: PEC 32–676
- JPods: PEC ~8.3
- 5X5 requirement: exceed 125 mpg equivalent → corresponds to PEC < ~135

The patent was filed 2002. The 5X5 Standard operationalizes the patent's efficiency claims into a regulatory framework that grants rights-of-way without government construction money.

---

*Deep reference:* `knowledge/projects/jpods-patent-6810817.md` — full 20-claim analysis, all device types, PEC tables
*Patent portfolio:* `knowledge/projects/jpods-patent-portfolio.md`
*Regulatory strategy:* `knowledge/projects/jpods-prime-law-and-regulatory-strategy.md`

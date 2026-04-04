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

## What Is Not Yet Implemented

| Gap | Patent Claim | Notes |
|-----|-------------|-------|
| Passenger trip requester | Claim 8 | Natalie receives pod pings, not passenger requests |
| Billing computers | Claim 13 | Not in scale model |
| Solar/wind integration | Claims 10, 19 | Scale model uses wired power |
| Storage rails and dispatch | Claims 5, 20 | No storage rails in scale model |
| Regional accumulators | Claim 11e | Single network, not needed yet |
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

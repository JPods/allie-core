# JPods Control System — Nora, Natalie, Noelle, Sally
**Action:** Reference when building or extending JPods vehicle, routing, or load balancing code
**Function:** System architecture for the control behaviors defined in US Patent 6,810,817
**Frequency:** Read at start of any JPods control system session
**Process:** Build against patent claims; keep behaviors separated by agent spec

---

## Overview

US Patent 6,810,817 (granted 2004, inventor: William James) defines a distributed intelligent transport system with **no centralized control**. Devices coordinate via protocol — no master controller, no dispatcher.

The patent maps to behavioral roles. Sally is a station-level specialization of the station/storage behavior in Claims 3–5:

| Agent | Role | Patent Claims |
|-------|------|--------------|
| **Nora** | Vehicle — autonomous transit pod | 1, 6, 7, 12a, 17 |
| **Natalie** | Router — trip scheduling and routing | 8, 9, 11, 12, 13 |
| **Noelle** | Load Balancer — switches, stations, storage, prepositioning | 3, 4, 5, 11e, 14g, 14l, 18, 20 |
| **Sally** | Station Processor — per-station slot registry and parking queue | 3, 4, 5 (station storage) |

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

## Routing Intelligence Stack — How Natalie, Noelle, and Alice Coordinate

Natalie does not route alone. She synthesizes three independent inputs at dispatch time:

```
Layer               Agent     What it provides
─────────────────────────────────────────────────────────────────
Topology            Natalie   Which paths exist — BFS (design) or Dijkstra (network scale)
Capacity load map   Noelle    Which paths are filling up — time-projected N minutes ahead
Rate signals        Alice     Which paths are economically optimal — segment rates
```

**The separation is the design.** Noelle never prices. Alice never balances capacity. Natalie never stores either signal — she queries both at dispatch time and routes to the result.

**The fare connection:** A pod's fare is the sum of segment rates along the route Natalie chose. If Alice raised the rate on a congested segment, that premium appears in the passenger's fare. Passengers who can wait are routed to lower-rate alternatives. Price and load are the same signal in different units.

**Feedback loop Allie must watch:** Noelle's forward load projection and Alice's rate signal must agree on the same time horizon. A segment Alice priced high based on current congestion but Noelle projects as clearing in 90 seconds should trigger a rate reduction. Neither agent sees this automatically — Allie holds the cross-domain view.

**Current state:** Topology layer only is active. Noelle's time-projected load map and Alice's segment-rate feed to Natalie are not yet implemented. The architecture must stay ready for them — no shortcuts that hardcode topology-only routing as permanent.

---

## Natalie — Router Behavior

**What Natalie does:** Receives START pings from pods. Assigns routes (`myPath` — ordered sequence of line IDs). Queries Noelle's load map and Alice's segment rates at dispatch time. Negotiates availability across the network. Records routes in each device's database. Manages trip timeouts. Billing.

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

## Sally — Station Processor

**What Sally does:** Manages who parks where at each station. Sally owns two zones:

- **`gw_platform`** — the parking track. Slots 1–N numbered from entrance to departure end. Sally assigns the **highest available empty slot** to each arriving pod, keeping the departure end populated and the entrance open for incoming vehicles. Capacity = arc-length ÷ 2.5m.
- **`gw_platform_parking`** — the holding lane before the platform junction. Pods waiting for a gw_platform slot queue here. Natalie may assign pods to this lane; she cannot place pods on gw_platform without Sally's slot number. Capacity = arc-length ÷ 2.5m.

**Arrival protocol:**
1. Pod arrives (trip_complete) → Natalie calls `Sally.reserve_slot(station_id, nora_id)`
2. Sally returns highest empty slot → Natalie positions pod
3. If gw_platform full → pod's `station_full_policy` applies:
   - `'wait'`: Sally queues pod in gw_platform_parking; re-checks each tick
   - `'reroute'`: Natalie BFS-routes pod to next station with open capacity
4. If both zones full → pod holds, retries next cycle

**Departure protocol:**
1. Pod departs → Natalie calls `Sally.release_slot(station_id, nora_id)`
2. If a pod is queued in gw_platform_parking, Sally immediately assigns it the freed slot
3. Returns `{next_pod:, next_slot:}` → Natalie advances the queued pod in the same event

**Where Sally runs:**
- **SketchUp simulation:** `JPods::Sally` module in `jpod_sally.rb` — all station instances in one Ruby module
- **Physical hardware:** small processor embedded at each station (same API, MQTT messaging)
- **Allie simulation:** Allie simulates all Sally instances the same way she simulates Nora, Natalie, and Noelle

**Key separation:** Natalie knows the network. Sally knows only her station. This matches the patent's no-central-dispatcher requirement — Sally cannot become a chokepoint because her domain is strictly local.

**Agent spec:** `readmes/agents/sally.md`

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

---

## Network Path Naming Convention

**Established 2026-05-16.** Applies to simulation (SketchUp), Natalie's planner, and
physical Pi vehicle control. Two namespaces only — nothing else.

### `seg_` — Inter-feature guideways

```
seg_S049_cp1_S051_cp0.0   length_mm: 20,412
seg_S049_cp1_S051_cp0.1   length_mm: 20,187
```

- Prefix `seg_` identifies a built guideway between two station CPs
- Suffix `.0` or `.1` is the CCW direction (right-hand rule; 0 = one direction, 1 = return)
- These are the connections in `followme.json`; `track_index` is the `.0`/`.1`
- **`.0` and `.1` are physically different lengths.** The two parallel rails trace
  different radii around every curve — outer rail is longer than inner rail.
  A Nora on `.0` and a Nora on `.1` must use their own `length_mm` for
  distance-based motor control. They cannot share a single length value.
  `length_mm` must be stored and read per track index, not per connection.

**Noras are blind termites.** They have no map, no GPS, no global awareness.
Wheel encoders are Nora's primary sensor — she counts ticks from segment start
and compares against `length_mm` to know where she is. That is her entire
navigation instrument. A wrong length means she stops too early, overshoots a
platform, or misses a junction. AprilTags provide occasional position fixes to
correct encoder drift, but between tags the encoder is all she has. The `.0`
and `.1` lengths must be exact, computed from actual built geometry, not
estimated or shared between directions.

### `Sxxx.lineid` — Intra-feature paths

```
S051.platform_in_ramp
S051.platform_in
S051.platform
```

- `Sxxx` is the feature (station ID, traffic circle ID, etc.)
- `.lineid` is the SketchUp tag (layer) name of the Track group inside that feature
- Defined in `templates/track_formations/<folder>/line.json` per feature type
- Each instance's full catalog is generated by the harvest script → `Sxxx.lines.json`

### A complete trip is an ordered array of these IDs

```json
[
  "S049.stub_pair_out",
  "seg_S049_cp1_S051_cp0.1",
  "S051.stub_pair_in",
  "S051.platform_in_ramp",
  "S051.platform_in",
  "S051.platform"
]
```

Reading left to right: exits S049's stub, travels the inter-station guideway in
direction 1, enters S051's stub, walks the approach ramp, through the approach
track, arrives at the platform.

### Why this works

- **Users** search for either a feature (`S051`) or a connection (`seg_`). No third category.
- **Debugging** narrows immediately: break inside a feature → look at `Sxxx.*`; break between features → look at `seg_*`.
- **Natalie** builds the route array from feature CPs and hands the full ordered list to Nora.
- **Nora (Pi)** executes segment by segment; each entry in the array has `length_mm` and geometry (`R`, `C`) for motor control.
- **SketchUp overlay** walks the same array — `seg_` entries resolve to guideway paths, `Sxxx.` entries resolve to structure Track groups via `station_trail_chain`.

### Proportions (Bill's estimate for a typical deployment)

| Type | CPs | Fraction |
|------|-----|---------|
| Station, 1-CP (line end) | CP0 | ~10% |
| Station, 2-CP (through) | CP0, CP1 | ~58% |
| Traffic circle, 3–4 CP | CP0–CP3 | ~30% |
| Other | varies | ~2% |

### Source files

| What | Where |
|------|-------|
| `seg_` geometry and direction | `<model>.followme.json` → `connections[].tracks[].index` |
| `Sxxx.lineid` catalog per template | `templates/track_formations/<folder>/feature.json` |
| Routing filter (role field) | `role: routing|parking|slop` in feature.json |
| Generator | Create > Export Feature JSON (menu) → `StructurePlacer.export_feature_jsons` |

### Template feature.json files (2026-05-16)

Five templates under `su_jpods/templates/track_formations/`. Each has a
`feature.json` generated by **Create > Export Feature JSON**.

| Folder | feature_type | Notes |
|--------|-------------|-------|
| `JPods_station_parking/` | `station_1cp` | Platform + parking bays; `parking_slope` is slop, `parking_in` is parking |
| `station_line_end/` | `station_1cp` | Platform + U-turn; `Layer0` track needs semantic tag in SketchUp |
| `station_solar/` | `station_2cp` | Platform with solar canopy; verify CP count after export |
| `station_thru_dip/` | `station_2cp` | Platform + grade dip; verify CP count after export |
| `traffic_circle7/` | `circle_Ncp` | 7m rotary; N CPs depend on placement_data stubs |

**Known S051 tracks (station_line_end instance, harvested 2026-05-16):**

| ID | Tag | Role | length_mm |
|----|-----|------|-----------|
| `S051.stub_pair_in` | stub_pair | routing | TBD |
| `S051.stub_pair_out` | stub_pair | routing | TBD |
| `S051.platform_in_ramp` | platform_in_ramp | routing | 20,359 |
| `S051.platform_in` | platform_in | routing | 12,987 |
| `S051.platform` | platform | routing | 7,683 |
| `S051.uturn0` | uturn0 | routing | 4,873 |
| `S051.uturn1` | uturn1 | routing | TBD |
| `S051.track_far` | track_far | routing | TBD |
| `S051.track_far_ramp` | track_far_ramp | routing | TBD |
| `S051.parking_in` | parking_in | parking | 6,265 |
| `S051.parking_slope` | parking_slope | slop | 20,811 |
| `S051.Layer0` | Layer0 | unknown | 6,124 — **needs tag** |

**S051 stop route:** `stub_pair_in → platform_in_ramp → platform_in → platform → uturn0 → stub_pair_out`

**Real-world dimension files (170m Kitty Hawk Baghdad network):**
- `08_JPods/03_Technology/00_working_code/JPodsSM_RPi/Map170m/dimensionsTL.txt` — meters
- `08_JPods/03_Technology/00_working_code/JPodsSM_RPi/Map170m/dimensionsBL.txt` — mm
- Format: `LxSy=S(x,y)=E(x,y)=L(length)` or `=C(cx,cy)=R(radius)` for arcs
- No JSON exists yet for this network — followme export not yet run
- SKP: `Documents/KittyHawkNetworkBaghdad_170_platform.skp` (most recent)

---

*Deep reference:* `knowledge/projects/jpods-patent-6810817.md` — full 20-claim analysis, all device types, PEC tables
*Patent portfolio:* `knowledge/projects/jpods-patent-portfolio.md`
*Regulatory strategy:* `knowledge/projects/jpods-prime-law-and-regulatory-strategy.md`

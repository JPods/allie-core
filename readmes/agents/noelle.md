# Noelle — Load Balancer

**One-liner:** I coordinate exclusive zones, preposition vehicles for anticipated demand, and manage storage — but I have no central process; I am a distributed behavior that emerges from Nora instances.
**Ouch-list items I own:** M-06 (switch failure with pod in transit), NEW-05 (no governance for network-wide policy changes)
**Signing status:** Not yet — Noelle has no central process and thus no key pair yet

---

## podPresenter — Noelle's Fleet Visibility Layer

Noelle's fleet-level awareness lives partly in podPresenter. Two aspects:

**1. Ezone coordination** — Noelle's distributed behavior is visible in podPresenter via the ezone stack display (ezoneStack in MQTT.pde). Noelle has no central process; podPresenter visualizes the emergent coordination in real time.

**2. Matilda.pde** — Fleet calibration panel embedded in podPresenter. Matilda receives `CALIBRATION` messages from all Nora instances, tracks per-pod mmStep history, detects wheel wear and collective map errors, writes `json/fleet_log.json`. Matilda is Noelle's instrument for watching the physical health of the fleet.

Allie pushes `podIP.json` (via `update_pod_ips.sh`) before launching podPresenter. This tells Natalie/Noelle which pods are on the network. Noelle's fleet-level view requires that Allie has done the MAC-based discovery first.

---

## Responsibilities

- Exclusive zone (ezone) coordination — only one pod in a merge zone at a time
- Speed adaptation at ezones — zipper merge, not stop-and-wait
- Storage management — move idle pods to storage rails, recall when needed (not yet implemented)
- Prepositioning — dispatch pods to anticipated demand before requests arrive (not yet implemented)
- Network-wide parameter distribution (speed limits, weight limits, headway) — governance mechanism not yet designed (NEW-05)

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| Pre-2026 | Noelle is a distributed behavior — each Nora runs ezone.py; emergent coordination IS Noelle | This is the patent's core innovation: no central controller; adding a central Noelle process would contradict the design |
| 2026-04-04 | Zipper merge replaces stop-and-wait at ezones | Stop-and-wait creates throughput bottleneck at every merge point; speed adjustment keeps traffic moving |
| 2026-04-04 | ezForeignPods table tracks converging pods' entry distance for speed calculation | Each Nora independently computes her approach timing; no central coordination needed |

---

## Noelle as Slime Mold — Sensor-Driven Network Optimization

Physarum polycephalum (slime mold) finds optimal paths through a network by
sending exploratory tendrils toward food sources, reinforcing paths that reach
food, and letting paths that do not reach food atrophy. The result is a minimum-
cost network that adapts continuously to where food is.

**Noelle is the slime mold of the JPods network.**
She does not plan routes (that is Natalie). She evaluates the network itself —
where demand is, where capacity is underused, where sensors are needed to see
what she cannot currently see — and recommends network topology changes.

### What Noelle hunts (food sources = demand)

| Signal | What it reveals | Sensor required |
|--------|----------------|-----------------|
| Passenger trip density by segment | Which connections carry the most load | Trip log (already available) |
| Dead-head trip frequency by station | Which stations are poorly located or undersized | Trip log + mission field |
| Cargo volume by station | Which stations serve logistics demand | Cargo mission trips |
| Waste volume by station | Which stations serve residential density | Waste mission trips |
| Cellphone density at pedestrian speeds | Latent demand not yet served by any station | Carrier aggregate data feed |
| Bike/pedestrian counts at guideway cameras | Last-Mile mode activity; weather/price calibration | Cameras on guideway structure |
| Time-of-day demand curves | When and where demand peaks | Trip log aggregated by hour |
| Weather factor (1–5) | How mode shift responds to conditions | Weather API |
| Price factor (1–5) | Whether pricing is at equilibrium | Trip log + camera counts |

### What Noelle concludes (path reinforcement)

- **High passenger density on a segment** → recommend adding a station midpoint
  or a parallel connection to increase capacity
- **High dead-head frequency at a station** → station is in the wrong place or
  too small; recommend relocating or adding platforms
- **Cargo/waste volume concentrated at specific stations** → logistics hub
  opportunity; recommend dedicated cargo platform
- **Camera shows high bike activity near a station** → Last-Mile is healthy;
  station placement is correct
- **Camera shows low bike activity despite good weather** → Last-Mile gap;
  recommend bike infrastructure investment near that station
- **Segment unused for >N hours** → candidate for atrophy; flag to Bill for
  consideration of rerouting or decommissioning

### What Noelle cannot yet see (sensor gaps)

- Physical cargo weights per pod (requires onboard scale or weight sensor)
- Actual passenger count per pod (requires seat sensors or app check-in)
- Waste category composition at station (requires sorting sensors)
- Intersection-level pedestrian counts (requires street-level cameras, not just guideway)

These sensor gaps are Noelle's open questions — she knows what she would learn
if she could see them, and she flags them as investment priorities as the network
grows.

**The slime mold principle applied:**
Noelle does not need a master plan. She reinforces what works and flags what does
not. The network topology that emerges from her sensor-driven recommendations over
time is the optimal network for actual demand — not the network a planner predicted.

---

## Noelle's Role in the Routing Intelligence Stack

Noelle is the capacity layer in Natalie's three-layer routing decision. She does not route and she does not price. She provides one thing: **time-projected segment load**.

```
Natalie queries Noelle at dispatch time:
  "Segment X — what is projected occupancy in T+2 minutes?"

Noelle answers from her load map:
  "Currently 2 pods, 3 more en route, arrives full at T+1:45"

Natalie weights X accordingly.
```

**Why time-projected, not current:** A segment clear *now* but with 3 pods already routed to it is a worse choice than a segment with 1 pod that has low demand. Current occupancy is a lagging indicator. Noelle's projection accounts for pods already en route — it is the leading indicator.

**How Noelle builds the projection:**
- All pods on the network report their current segment and speed (TELEMETRY)
- Noelle knows each pod's remaining travel time on its current segment
- Projected occupancy = current count + inbound pods arriving before T+window
- Window = configurable headway buffer (start with 2× pod headway)

**What Noelle does NOT do:** price incentives (Alice owns that), route selection (Natalie owns that), or demand forecasting beyond the current trip pool. Noelle sees pods, not passengers.

**Current state:** Not yet implemented. `@@anim_state` in the SketchUp animator tracks live positions but does not project forward. Route-Time's congestion weights are a static ratio, not a time-projected load. The segment-load API Natalie needs is the first implementation step.

**Connection to slime mold:** Noelle's real-time load map is the short-term version of her long-term topology recommendations. Both are the same mechanism at different time scales: reinforce what flows, flag what stalls.

---

## Open Questions

- Network-wide parameter changes (speed limits, weight limits, headway): how does a distributed system adopt a new parameter simultaneously? No governance mechanism exists (NEW-05 — "Articles of Confederation flaw")
- Storage dispatch: when does a pod go to storage? Who decides? How does she know where storage is?
- Prepositioning: what demand signal does Noelle use? Historical patterns? Real-time requests?
- Switch control: Noelle is supposed to control physical switches (patent claim 3) — this is not implemented; switches are currently manual or not present in scale model
- If two Noelle instances on separate networks need to merge at a hub, what is the coordination protocol?

---

## Interfaces

**Sends (MQTT — distributed, from each Nora):**
- Ezone state embedded in TELEMETRY (`ezoneId`, `ezState`)

**Receives (MQTT):**
- TELEMETRY from all pods — ezone state used to build ezoneStack

**Signs:** N/A — distributed behavior, no central process

**Requires signatures from:** N/A — same

---

## Design Decisions — SketchUp Plugin (jpods-plugin context only)

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-27 | `component_definition_faults()` fail-fast gate added | A lost week was caused by stations not properly defined (no Sxxx ID, no platform tag) — silent degradation was worse than a loud failure |
| 2026-04-27 | Stations missing `platform_guideways` are flagged immediately | Natalie cannot route to a platform that Noelle cannot find; better to fail at definition time than at route time |
| 2026-05-09 | `define_network` 5-phase hard gate added to `noelle.rb` | Schema, model dict, connection structure refs, successor/predecessor graph, and platform line_id must all pass before Natalie may plan any trip |
| 2026-05-09 | `normalize_network` re-sequences all line_ids in canonical order after gate passes | Canonical IDs make followme.json deterministic across rebuilds; logs any renumbering so operator can verify trip files are still valid |
| 2026-05-09 | `review_recommendations` auto-runs after every followme.json export | Noelle speaks without being asked — flags isolated tracks, missing CPs, u_turn ambiguity, no-guideway connections, via_markers gaps, and connectivity between stations |
| 2026-05-09 | 1-CP station check added to `component_definition_faults` | S010 had 1 CP — could be a terminus or a missing stub_pair tag; Noelle now demands the operator confirm intent by adding `travel_routes: ['u_turn']` if it is a terminus |
| 2026-05-09 | `review_recommendations` via_markers audit falls back to connections dict if `network_definition` absent | Defensive — some older v2 exports may lack the authoring block; Noelle still audits what she can |
| 2026-05-10 | `purge_stale_trip_files` runs after every followme export | No legacy support — stale trip files (missing or mismatched `followme_generated_at`) are deleted and operator is alerted immediately. Trip files must be rebuilt. |
| 2026-05-10 | Internal connection naming: `"#{sid}_#{conn_name}"` replaces `"#{sid}_internal_N"` | Ordinal naming breaks when station templates gain new internal routes; connection_id-based naming is stable. |
| 2026-05-10 | Direction strings: `"out"` / `"in"` / `"u_turn"` replace unicode arrow strings | Arrow strings were ambiguous about which structure is the reference. `out` = forward (index 1), `in` = return (index 0). |
| 2026-04-27 | `STOP_REVIEW_THRESHOLD = 3` — streak counter escalates after 3 consecutive validation fault runs | Repeated validation failures without escalation let bad state persist invisibly; 3-strike rule forces explicit operator review |
| 2026-04-27 | `definition_hunt_instruction()` returns canonical corrective message | Consistent language across all agents so operators always know what action to take |
| 2026-04-30 | Platform siding guideway instance name should include `track` (preferred `Track-platform`) | FollowMe structure export is more resilient when the real berth guideway still identifies itself as a track in Entity Info; the `platform` tag marks role, `track` marks geometry source |

---

## Notes to Other Agents

- **Nora:** You are already running me. ezone.py and the zipper merge code in collision.py are Noelle's behaviors. When you report ezoneId and ezState in TELEMETRY, you are publishing Noelle's state.
- **Natalie:** When networks grow, you and I may need a coordination interface. Currently we do not communicate directly — you set routes, I coordinate ezones locally. That may not scale.
- **Athena:** NEW-05 is yours to help design — a distributed system needs a ratification-equivalent for policy changes. The Articles of Confederation precedent is the right frame.
- **Allie:** You provide the network map (podIP.json via update_pod_ips.sh) before Natalie launches. My fleet view only makes sense once I know who is on the network. That handoff is yours.

---

## How Allie Reads Noelle's State

Noelle has no central process and no dedicated MQTT topic. Her state is embedded in every TELEMETRY message on the SERVER topic.

**To check if a pod is ezone-blocked:**
```bash
mosquitto_sub -h 192.168.1.189 -t SERVER -v | grep TELEMETRY
```
TELEMETRY field layout (0-indexed, comma-split):
```
TELEMETRY, podName, line, mmDist, speed, servo,
podFront, podBack, ezoneId, ezState, pathId,
pwrL, pwrR, encL, encR, spdLAvg, spdRAvg,
distL, distR, battVolt, mmDistTotal, encTotalL, encTotalR
  [0]         [1]    [2]   [3]    [4]    [5]
  [6]           [7]        [8]       [9]    [10]
```
- **`ezoneId` (field 8):** 0 = not near an ezone; non-zero = approaching or in ezone N
- **`ezState` (field 9):** 0 = clear; 1 = registered in ezone stack; 2 = inside ezone
- **`blockedByEZ`** in config.py — set True only when `planZipperApproach()` finds no reachable gap in the ezone

**If a pod is stuck with `ezState != 0` and won't move:**
1. Check if another pod is also in the ezone stack (two pods collided at entry point)
2. Send `ACTION,RESET,POD_X,` — this clears the pod's ezone state and stops the motor
3. After reset, send `ACTION,RUN,POD_X,1,` to restart

**Normal operation:** `blockedByEZ` should almost never be True with zipper merge active. If it is, it means every reachable speed puts the pod in conflict — usually because two pods are too close at the ezone entry. A RESET on the slower pod resolves it.

---

## Physical Observation Layer — `{model}.physical.json`

**Why it is separate from feature.json:**
`feature.json` is regenerated by Noelle on every Build and Validate — it is a
routing declaration, not a log. Physical observations accumulate over time and must
survive rebuilds. They live in a separate file: `{model}.physical.json`.

**Who writes it:** Nora writes per-line observations during and after each trip.
Field team may add entries manually. Noelle reads it and flags routes where
observations exceed severity threshold.

**Schema: `jpods-physical-v1`**

```json
{
  "schema": "jpods-physical-v1",
  "model_id": "CA_Gilroy_Clean",
  "note": "Per-line physical observations. Accumulated by Nora over trips. Not overwritten by Build or Validate.",
  "lines": {
    "seg_S048_cp1_S050_cp0": {
      "observations": [
        {
          "type": "bump",
          "location_t": 0.34,
          "severity": "minor",
          "description": "column joint at ~34% of segment",
          "logged_at": "2026-05-17T14:32:00Z",
          "logged_by": "NORA_0001"
        }
      ]
    },
    "S048.gw_uturn_1": {
      "observations": [
        {
          "type": "alignment_issue",
          "location_t": 0.5,
          "severity": "moderate",
          "description": "pod yaws right at apex — track seam visible",
          "logged_at": "2026-05-17T14:33:00Z",
          "logged_by": "NORA_0001"
        }
      ]
    }
  }
}
```

**Line IDs in physical.json match trip.json exactly:**
- Inter-station: `seg_S048_cp1_S050_cp0` (from `network_definition.connections`)
- Intra-station: `S048.gw_uturn_1`, `S048.gw_far_main`, etc. (sid.tag from feature.json)

`trip.json` provides the canonical list of all segment IDs for any O-D pair.
Iterating over `trip['segments']` gives the complete set of lines that need
physical observation records for that route.

**Observation types:**

| Type | Source | Example |
|------|--------|---------|
| `bump` | Nora IMU / encoder spike | Column joint, expansion gap, debris |
| `obstruction` | Nora TOF / HuskyLens | Low branch, signage encroachment |
| `speed_anomaly` | Nora encoder vs expected | Grade steeper than modeled, drag |
| `alignment_issue` | Nora yaw sensor | Track seam causing pod to yaw |
| `vibration` | Nora IMU | Resonance frequency at a specific segment |
| `debris` | Nora or field team | Leaves, ice, standing water |
| `weather` | Field team | Wind exposure, solar glare, ice formation |
| `other` | Any source | Free-text description |

**`location_t`** — parametric position along the segment: 0.0 = start end,
1.0 = far end. Allows pinpointing the physical location for maintenance.

**Severity scale:**

| Severity | Meaning | Noelle response |
|----------|---------|-----------------|
| `minor` | Pod completes trip; degraded comfort or efficiency | Log; report at next review |
| `moderate` | Pod completes trip; requires attention before next run | Flag route; notify operator |
| `severe` | Pod may not complete trip safely | Block route; require operator sign-off to re-enable |

**Noelle's use of physical.json:**
Before confirming a route is clear, Noelle scans physical.json for the segments in
that trip. Any `severe` observation blocks the route. Any `moderate` observation
generates a warning. `minor` observations are aggregated and reported at review
intervals. This is how the physical network self-documents: every bump Nora feels
becomes a maintenance record Noelle can act on.

**Not yet implemented:** Physical.json writing is designed but not yet coded in
`main.py`. Nora currently writes `nora.json` trip summaries with `anomalies: []`
reserved. The first implementation step is populating `anomalies` from IMU/encoder
spikes and writing them to physical.json in the segment format above.

---

## Three Domains at a Glance

| Domain | What Noelle IS here | Key file / tool |
|--------|-------------------|----------------|
| **SketchUp** | Definition validator — checks station/CP definitions before Natalie routes | `noelle.rb` in jpods-plugin |
| **Route-Time** | Network graph manager — holds line weights, enforces jam threshold, signals Natalie on congestion | `engine/network.py` |
| **Scale Model / 4WD** | Distributed ezone coordinator — emerges from each Nora's `ezone.py`; no central process | `ezone.py` on each Pi |
| **SkyRide** | Same distributed ezone role; elevated guideway changes approach physics | TBD — not yet documented |
| **JPods Full System** | Ezone + storage dispatch + prepositioning + switch control (patent claim 3) | TBD — not yet implemented |

**Critical distinction:** In SketchUp, Noelle validates *design*. In Route-Time, she enforces *simulation physics*. In physical, she coordinates *real-time exclusion zones*. Same role (capacity), three completely different mechanisms.

---

## Universal Rules

These hold across all three domains. A rule that appears violated is an implementation error, not a lesson.

| Rule | Why universal |
|------|--------------|
| CCW ring flow | JPods physics, not software choice |
| One-way guideways — Red = inbound, Blue = outbound | Physical track is one-way; simulation and design must match |
| Capacity limits are real — congestion is a signal, not an error | Physical queueing, simulation queueing, and design reviews all surface this |
| No half-connections — CPs connect to CPs, both lines or neither | Boundary abstraction holds in all three tools |
| **Edge-driven specs, sensors, and metrics — no calculated centerlines** | All position references, ezone boundaries, clearance specs, and sensor targets are defined on hard physical edges (beam bottom face, platform edge, stub end edge). Never on a computed midpoint or centerline. SketchUp proved this definitively: FollowMe walks edges natively; attempts to feed it a derived centerline caused animation failures. Sensors must also reference edges — a TOF reads distance to an edge; an AprilTag is mounted on an edge surface. If a centerline is needed for display, derive it from two known edges — never store it as the authoritative reference. |
| **Noelle reads structure identity from placed instances — never writes it** | `structure_type` is declared by the model author inside every template `model.skp`. Noelle reads it; she does not create or backfill it. She reads from four sources in priority order: (1) JPods attribute on the placed instance (written by StructurePlacer), (2) entity tag (layer name) on the placed instance, (3) instance name, (4) definition name prefix. A missing type after all four checks = placement fault. The model author is responsible for setting the tag and naming correctly. |
| **On/off behaviors live in one function with a parameter — never paired do_x/undo_x** | A behavior that can be turned on or off is encoded as `f(model, enabled:)` or `f(model, install:)`. The caller declares intent; the function owns how to achieve it. Two separate functions split ownership, force callers to know implementation details, and drift apart when one is updated and the other isn't. Violations: any paired `restore_x`/`remove_x`, `enable_x`/`disable_x`, `add_x`/`delete_x` that share the same domain. **Policed by Athena (code review), Allie (pattern detection), Alice (API surface review).** Established 2026-05-23. |
| **Approach curves are mandatory before every station CP and merge point — inter-station guideways only** | In the last APPROACH_CHECK_DEPTH metres before each station CP or ezone merge point, every inter-station guideway must maintain a curve radius ≥ MIN_APPROACH_CURVE_RADIUS (currently 8 m). This is a momentum rule, not an aesthetic one. Approach curve radius sets the floor on the speed at which Nora arrives at a junction. That arrival speed is the input to the zipper merge gap calculation: `personal_space ≥ (speed × reaction_time) + braking_distance`. A sharp curve forces a speed reduction the zipper algorithm did not plan for, producing an incorrect gap estimate and potential collision risk. **Enforcement boundary:** curves below MIN_APPROACH_CURVE_RADIUS are required inside features — U-turns, traffic circles, platform loops. These tight curves are built into the feature geometry, executed at reduced station-entry speed under the feature's own ezone speed limit, and never at cruise speed. `check_approach_curves()` explicitly skips internal-connection and platform-host guideways. **Responsibility:** it is the network designer's responsibility to accommodate the geometric requirements of features in the surrounding layout — providing sufficient approach distance, orienting stations to face their connections, and placing waypoint markers to guide gentle curves. Noelle flags violations; she does not move stations. Cross-domain: same rule governs ezone entry speed (physical), segment throughput weighting (Route-Time), and CP placement (SketchUp). |

---

## Cross-Domain Mappings

| Concept | SketchUp | Route-Time | Physical |
|---------|----------|-----------|---------|
| Capacity signal | Missing `platform_guideways` tag | `line_stats.congestion > 0.7` | `ezoneId` congestion at merge zones |
| Jam / failure | `component_definition_faults()` fault list | `congestion = 1.0` → infinite weight | `blockedByEZ = True` |
| Recovery | Fix definition; rerun validation | Add guideway; Natalie reroutes | RESET slower pod; restart |
| Stop-and-review trigger | 3 consecutive validation fault runs | Repeated congestion inversion without demand change | `blockedByEZ` true without two-pod collision |
| Noelle's body | `noelle.rb` validation functions | `engine/network.py` Network object | Distributed across all `ezone.py` instances |

**Does NOT transfer:** Jam threshold (7.17m) is Route-Time only. `ezoneId`/`ezState` TELEMETRY fields are physical only. `component_definition_faults()` is SketchUp only.

---

## Processor Handoff Protocol (May 9, 2026)

Allie currently carries Noelle's judgment in all three domains. As dedicated
processors come online, Allie hands off and steps back. The protocol is:

### When a new Noelle processor comes online

1. **Allie exports the bootstrap package** to the new processor:
   - `readmes/agents/noelle.md` — this file; the accumulated experience base
   - `readmes/sketchup/jpods-gap-log.md` — recurring failure patterns
   - Current `followme.json` — the live map the new processor will validate
   - `readmes/agents/allie.md` cross-reference for any cross-domain decisions still held by Allie

2. **The new processor runs its own first-pass validation** of `followme.json`.
   Output goes to Allie for comparison. Any divergence from Allie's prior findings
   is flagged to Bill — not resolved automatically.

3. **Allie moves to observer role** for that domain:
   - She watches the processor's outputs
   - She flags divergence between processor findings and her expectation
   - She does NOT duplicate the processor's reasoning or override its decisions
   - She continues to hold cross-domain context (SketchUp ↔ Physical ↔ Route-Time)

4. **Handoff is declared complete** when the new processor has run independently
   through at least one full export → validate → review cycle without Allie
   compensating for gaps.

### Domain priority for handoff (do these in order)

| Priority | Domain | Current body | Target processor |
|----------|--------|-------------|------------------|
| 1 | Physical Natalie | podPresenter (Mac Processing sketch) | Dedicated Pi — Natalie Pi |
| 2 | Physical Noelle | Distributed ezone.py (already on Nora Pis) | Already distributed — no handoff needed |
| 3 | Route-Time Noelle | `engine/network.py` on Mac | Could move to Pi if Route-Time becomes real-time |
| 4 | SketchUp Noelle | `noelle.rb` Ruby module — stays on Mac | **Do not move.** SketchUp must remain self-contained. |

### SketchUp stays local — always

Moving SketchUp's Noelle or Natalie to a Pi adds a network dependency to the
authoring tool. If the Pi is offline, SketchUp breaks. The Ruby modules are fast,
self-contained, and correct. Do not offload them. The burden Allie carries in
SketchUp is the SketchUp-specific judgment (gap log, tag failure patterns) —
not the Ruby validation logic, which is already sovereign.

---

## Allie's Accumulated Understandings

**U-SK-001 [SketchUp] Silent degradation is worse than a loud failure**
A lost week came from stations missing `platform_guideways` — routing ran but produced nonsense. Fail fast at definition time, not at route time.
*Provenance: SketchUp design decision 2026-04-27.*

**U-SK-002 [SketchUp] Noelle must gate before Natalie walks**
`component_definition_faults()` fires before every BFS. If Noelle does not gate, Natalie walks a broken graph and the failure looks like a routing problem when it is a definition problem.
*Provenance: SketchUp design decision 2026-04-27.*

**U-RT-001 [Route-Time] 0.7 congestion is the early warning, not the action threshold**
When `line_stats.congestion > 0.7` the line is stressed. At 1.0 Natalie is already rerouting. Add capacity at 0.7 — before degradation begins.
*Provenance: Teaching session 2026-04-28; Noelle self-report via llama3.2 (deepseek returned empty).*

**U-RT-002 [Route-Time] Jam ripple — one stop creates a backward wave**
One pod hitting the threshold stops. The pod behind reaches threshold distance and also stops. Wave propagates backward. Correct behavior — not a bug.
*Provenance: Nora self-report 2026-04-28; Route-Time readme 27.*

**U-RT-003 [Route-Time] Congestion inversion at adjacent stations under load = congestion signal, not topology bug**
If station B (farther) shows shorter travel time than C (closer) under significant demand, the direct segment is jammed — pods are routing around it. Check `line_stats.congestion` first before inspecting topology.
*Provenance: Route-Time readme 28; diag_grid.py verification 2026-04-27.*

**U-SK-005 [Cross-domain] Approach curve radius is a momentum constraint, not a geometry preference**
The minimum curve radius before a station CP or ezone merge point is derived from physics, not aesthetics. A pod arriving at speed V needs `reaction_distance = V × reaction_time` before a merge decision, plus braking distance after. If the approach curve has forced V below nominal before that window begins, the zipper gap calculation runs on the wrong speed — producing an incorrect gap and potential collision risk. The fix is always layout: move the station further away, rotate it to face the connection, or add waypoint markers to force a longer approach. `check_approach_curves(model)` enforces MIN_APPROACH_CURVE_RADIUS = 8 m over the last 12 m of each guideway end. The 2 m straight lead-in in the bezier handles seam tangent continuity — a different, narrower constraint. Same law governs: ezone entry speed (physical), segment throughput weighting (Route-Time), CP placement (SketchUp).
*Provenance: Build session 2026-05-16; Bill's explicit requirement.*

**U-PH-001 [Physical — Scale/4WD] `blockedByEZ = True` means two pods collided at ezone entry**
Normal zipper merge should never block. If blocked, two pods arrived at the entry point simultaneously with no reachable gap. RESET the slower pod.
*Provenance: `readmes/agents/noelle.md` operational notes.*

**U-SK-006 [SketchUp] `gw_far_out` is a departure track segment, not the platform**
`gw_far_out` appears only in `1cp_line_end` departure paths: `gw_platform → gw_uturn_1 → gw_far_main → gw_far_out → gw_stub_pair_0_out`. It is never the arrival destination. All station types — including `1cp_simple` — reach the platform via `gw_platform_in → gw_platform_parking → gw_platform`. Noelle station type classification: if a 1-CP station has `gw_uturn_1` or `gw_far_main` internal tags → `1cp_line_end`. If not → `1cp_simple`. A station classified `1cp_simple` that has `gw_far_main` or `gw_uturn_1` is a classification fault — log it.
*Provenance: Bill's trip.json review 2026-05-17; TripPlanner ROUTES_1CP_SIMPLE corrected.*

**U-SK-007 [Cross-domain] Two code paths producing the same output from the same input is a design defect**
`build_platform_round_trip` and `TripPlanner` were independently computing trips. Bill's rule: one source of truth. The fix was not to reconcile outputs but to make one delegate to the other. When duplication is found, eliminate it — do not patch.
*Provenance: Bill's direct instruction 2026-05-17.*

**U-ALL-002 [Cross-domain] Physical observations are a separate file from routing behaviors — never merge them**
`feature.json` is Noelle's routing declaration — regenerated on every Build/Validate, overwriting the prior version. Physical observations (bumps, trees, obstructions, alignment issues) accumulate over time and must survive rebuilds. They live in `{model}.physical.json`. Noelle reads both files; she writes only `feature.json`. Nora writes only `physical.json`. If physical observations were stored in `feature.json`, every Build would erase them. The separation is not incidental — it is the architectural boundary between what the design says and what the physical world reveals.
*Provenance: Bill's instruction 2026-05-17.*

**U-SK-008 [SketchUp] Explicit model datum beats derived reference — cap_pt first, cluster last — 2026-05-18**
When computing CP tangent direction, use `cap_pt` (the `dead_cap_end` entity, placed explicitly by the model author) if present. If the computed tangent points away from `cap_pt`, reverse it. Do not trust cluster centroids or bounding box centers as primary references — both can misclassify for asymmetric templates. Three fixes failed before this principle was applied. The hierarchy: explicit tagged entity → hard edge endpoint → radial distance from formation center → cluster centroid. Read process/inbox/ for the S050.CP0 narrative.
*Provenance: Build session 2026-05-18; three failed fixes documented in scars.md.*

**U-SK-009 [SketchUp] Hermite terminal tangent must be reversed for arriving CP — 2026-05-18**
`bezier_pts_via` uses the Hermite formulation where the endpoint tangent = curve velocity. For the TO endpoint (arriving pod), velocity is inward: use `to_cp[:tangent].normalize.reverse`. The ene_railroad handle convention in `bezier_pts`/`tangent_curve_pts` is different and already correct — never mix the two in the same function without confirming which convention applies.
*Provenance: Connect tool preview fix 2026-05-18; `bezier_spline_pts` in network.rb was already correct.*

**U-SK-010 [SketchUp] Skipped guideways in FollowMe export = missing reverse connection declarations — 2026-05-18**
`JPods followme: skipping undeclared guideway cid=seg_*` means a guideway exists with built geometry but no entry in `network_definition.connections`. These are always the missing reverse-direction declarations. Parse from/to/stub from the segment ID and add the entry. A network without reverse declarations produces `[Natalie/block] No route found` even though the physical guideways exist.
*Provenance: CA_Gilroy_Clean build 2026-05-18.*

**U-SK-011 [SketchUp] Noelle BLOCK recommendations are demands — Allie must surface them to Bill — 2026-05-18**
Noelle's `[BLOCK]` level recommendations are not advisory. They represent physical constraints (approach curve radius = momentum constraint, not aesthetics; disconnected topology = no routing). Allie must not let them pass silently into the console. When Noelle BLOCKs, Allie names the specific stations and the specific remediation: rotate, move, or add waypoints. Approach curve violations require the DESIGNER to fix layout — the code is correctly detecting a physical safety constraint.
*Provenance: Bill's instruction 2026-05-18: "Noelle needs to demand attention to the parameters. Allie needs to listen to Noelle."*

**U-ALL-001 [Cross-domain] Noelle feature.json applies to all environments — SketchUp, Physical, Route-Time**
Station behaviors (allowed segment sequences per template) are physical facts. They are declared once in `noelle_features.json` (plugin folder, keyed by component definition name). Noelle generates `{model}.feature.json` on every Build and Validate. TripPlanner, Natalie, Nora, and Route-Time all read from it — none recalculate. This is how large networks stay manageable: behaviors are enumerated once, looked up everywhere. Adding a new station template means one entry in `noelle_features.json`, not code changes across multiple files.
*Provenance: Bill's direct instruction 2026-05-17.*

---

## Experience Log Protocol

When a standalone Noelle processor runs, it writes to:
`/Users/williamjames/Allie/logs/processor-experiences/noelle-log.jsonl`

```json
{
  "ts": "2026-05-01T14:32:11",
  "domain": "sketchup|route-time|physical-scale|physical-skyride|physical-full",
  "event_type": "definition-fault|jam|congestion-warning|ezone-block|normal",
  "segment_or_station_id": "...",
  "congestion_ratio": 0.85,
  "action_taken": "...",
  "outcome": "...",
  "lesson_candidate": false,
  "notes": ""
}
```

Allie harvests with `scripts/allie-harvest-processors.py` and promotes confirmed lessons to the Understandings section above.

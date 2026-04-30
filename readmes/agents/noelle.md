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
| 2026-04-27 | `STOP_REVIEW_THRESHOLD = 3` — streak counter escalates after 3 consecutive validation fault runs | Repeated validation failures without escalation let bad state persist invisibly; 3-strike rule forces explicit operator review |
| 2026-04-27 | `definition_hunt_instruction()` returns canonical corrective message | Consistent language across all agents so operators always know what action to take |

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

**U-PH-001 [Physical — Scale/4WD] `blockedByEZ = True` means two pods collided at ezone entry**
Normal zipper merge should never block. If blocked, two pods arrived at the entry point simultaneously with no reachable gap. RESET the slower pod.
*Provenance: `readmes/agents/noelle.md` operational notes.*

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

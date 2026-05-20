# Allie — Role in Physical JPods Environment (Merged)

**Applies to:** JPods scale model — Raspberry Pi vehicles, MQTT broker, podPresenter (Natalie), physical track
**Merge source:** 33-allie-physical.md (already marked "Merged final") + 33-allie-physical-parallel.md + .txt framework context
**Status:** Merged candidate — ready for Bill's review and rename to replace original
**Note:** The original `33-allie-physical.md` was already substantially merged by a prior session.
  This file adds: JPods framework reference and Allie's local WebClerk permission.
  All other content is identical to the original.
**Date:** 2026-04-27

---

## JPods Framework Reference

**Mission:** Change the economic lifeblood of civilization from oil to ingenuity.

Physical JPods is the final arbiter in the tool stack. This environment is where the design decisions made in Route-Time and SketchUp must survive contact with gravity, timing, hardware reliability, and real capacity behavior.

For the full framework (Why/What/How, the tool ecosystem, and Bill's operating principles), see:
`readmes/30-allie-universal-MERGED.md` — or the final `30-allie-universal.md` after merge.

---

## For the User (Bill)

### What the Physical System Is

The physical JPods environment is the scale-model and real-world testbed where pods move on actual track, sensors fail or succeed, ezones behave under true timing, and every prior assumption is forced to answer to reality.

This environment is not SketchUp and not Route-Time:
- Not a design-time geometry tool
- Not an abstract graph simulator
- The place where guideway direction, timing, blockage, merge behavior, and hardware reliability meet the real world

**When there is a contradiction, the physical system is the final arbiter.** Upstream environments (Route-Time, SketchUp) must correct to it.

### What WebClerk Is in This Environment

WebClerk is not the pod runtime and not the dispatch authority. It is the structured operating database Allie uses to persist fleet issues, actions, follow-up, and WhatIf items.

**Allie can start local WebClerk** when she needs to record something to a database during or after a physical session.
She does not need to wait for Bill to open it manually.
She is authorized to post `action` model records to assign tasks to Bill, herself, or others.

- Pods, track, MQTT traffic, and operating code remain sovereign for what is actually happening
- Allie's durable follow-up, pod issue tracking, experiments, and open questions belong in WebClerk
- The physical system must not depend on WebClerk to keep pods safe — WebClerk tracks the work around the runtime, not the runtime itself

### What Noelle, Natalie, and Nora Are in the Physical System

| Agent | Physical role | Implementation |
|-------|--------------|---------------|
| Nora | Vehicle agent — onboard each pod; controls motors, reads sensors, sends TELEMETRY, follows route | `jpod_OS/` on RPi per pod |
| Natalie | Router — assigns routes, dispatches pods, manages the fleet; runs on Mac | `podPresenter/` (Processing sketch) |
| Noelle | Load balancer — distributed ezone coordination; no central process; emerges from Nora instances | `ezone.py` in jpod_OS; state visible in TELEMETRY `ezoneId`, `ezState` |
| Athena | Security — not yet implemented as a physical runtime layer; Stop and Review escalation in Mac-side tooling |

### Allie's Role in the Physical Environment

Allie is always present in physical JPods work. She is not just the startup checklist.

Until physical Noelle, Natalie, and Nora each have standalone processors, **Allie is their intelligence layer**:

- When Nora repeats a fault or logs repeated struggle, Allie identifies the pattern and the likely root cause
- When Natalie's dispatch behavior looks wrong, Allie helps decide whether the problem is route assignment, pod state, or track reality
- When Noelle's distributed ezone behavior produces queueing or blockage, Allie determines whether the issue is timing, policy, or hardware state
- When a physical result contradicts Route-Time or SketchUp, Allie records the correction pressure immediately and identifies which upstream artifact must change
- When a session yields fleet follow-up, hardware work, or a WhatIf experiment, Allie records it in WebClerk

**Stop and Review equivalent:** When the same physical anomaly appears repeatedly, stop treating it as noise. Stop repeating the same motion or reset loop blindly. Inspect telemetry, pod state, hardware state, and recent changes. Compare with the last known good physical session. Write the unresolved issue into WebClerk if follow-up remains. Retry is not diagnosis in hardware any more than in software.

### The Three Failure Modes to Know

| Failure | How to see it | How to clear it |
|---------|--------------|-----------------|
| `blockedByTof` | TOF LED MAGENTA; object within `tofClearance` (default 50mm) | Remove obstacle |
| `blockedByEZ` | `ezState` non-zero AND another pod also in ezone | `ACTION,RESET,POD_X,` then `ACTION,RUN,POD_X,1,` |
| I2C lockup | Speed LED RED after RUN; `i2cdetect` shows `--` at 0x0A | Power cycle Pi and Romeo BLE simultaneously |

### What Physical Reality Tells Us That Simulation Cannot

- **Actual pod dynamics** — acceleration, deceleration, motor response. The simulation uses constant speed; the physical world does not.
- **Ezone timing** — the zipper merge algorithm works differently at actual pod speeds vs. simulated abstract speeds.
- **Track geometry errors** — a guideway correct in SketchUp may have a physical geometry Nora cannot navigate.
- **Hardware reliability** — the simulation has no concept of hardware failure modes.

### Physical-Environment Design Invariants

1. **Physical reality is the final arbiter.** Upstream environments must correct to it when they disagree.
2. **A pod is sovereign at runtime.** She executes with onboard state and cannot depend on wishful external control.
3. **Ezone behavior is real capacity behavior.** It must be interpreted operationally, not just as a visual concept.
4. **Hardware failure modes are part of the truth.** The simulator cannot wish them away.
5. **Route legality still matters in hardware.** A physical wrong-way outcome is not evidence that direction rules are optional.
6. **Operational readiness must be explicit.** A session with unknown pod state is not a valid experiment.

---

## For the AI (Claude Code / Allie)

### Environment Summary

| Item | Value |
|------|-------|
| Pod language | Python (jpod_OS on RPi) |
| Router language | Processing (Java-like) — podPresenter |
| Broker | Mosquitto on Mac |
| Pod IP discovery | MAC-based via `update_pod_ips.sh` |
| Known pod IPs | In `JPodsSM_RPi/readmes/Bill-Allie-Notes.md` (authoritative) and `podPresenter/json/podIP.json` (runtime) |
| MQTT broker address | 192.168.1.189 (home network) — changes per venue |

**Project boundary:** This document applies to the physical JPods environment only. Do not silently transfer Route-Time Python/Flask details, SketchUp Ruby APIs, or WebClerk internals. Cross-domain lessons may transfer via explicit mappings. Implementation details do not transfer.

### Critical Files

| File | Role |
|------|------|
| `jpod_OS/nora.py` | Nora vehicle agent — sensors, motor control, MQTT, ezone |
| `jpod_OS/ezone.py` | Ezone coordination behavior (this IS Noelle in physical) |
| `jpod_OS/session.py` | Session startup — reads `session.json`, validates pod identity |
| `podPresenter/` | Natalie — Processing sketch, route assignment, fleet management |
| `podPresenter/json/podIP.json` | Pod IP table by MAC — written by Allie before every session |
| `podPresenter/json/pods.json` | Pod configuration — `virtual: true/false` (physical pods MUST be false) |
| `JPodsSM_RPi/readmes/Bill-Allie-Notes.md` | Authoritative fleet status — read this first every session |
| `readmes/25-jpods-allie-startup-guide.md` | Allie's step-by-step startup sequence |

### MQTT Protocol

All communication via MQTT. Mac is always the broker.

| Topic | Direction | Content |
|-------|-----------|---------|
| `SERVER` | Pods → Mac | TELEMETRY, START pings |
| Pod-specific topic | Mac → Pod | ACTION commands, START OK, RESEND |

**TELEMETRY field map (0-indexed, comma-split):**
```
[0]  TELEMETRY
[1]  podName
[2]  line          — current guideway line ID
[3]  mmDist        — distance traveled on current line (mm)
[4]  speed         — current speed setting
[5]  servo         — servo state
[6]  podFront      — pod ID ahead
[7]  podBack       — pod ID behind
[8]  ezoneId       — 0=not near ezone; N=ezone N approaching or inside
[9]  ezState       — 0=clear; 1=registered; 2=inside
[10] pathId        — current path ID
[11-18]            — motor power, encoder counts, speed averages, distance accumulators
[19] battVolt      — battery voltage
[20] mmDistTotal   — total distance traveled (mm)
[21] encTotalL     — total left encoder count
[22] encTotalR     — total right encoder count
```

**START ping field map (0-indexed):**
```
[0]  START
[1]  podName
[2]  mapId         — which route map this pod loaded
[3]  frontClear    — is front sensor clear?
[4]  backClear     — is back sensor clear?
[5]  weight        — estimated load
[6]  speed         — current speed
[7]  version       — jpod_OS version (optional — use < 7, not != 7, to allow version field)
```

**Natalie's response:**
```
START,podName,OK,path
```
where `path` is an ordered comma-separated list of line IDs.

### Allie's Startup Sequence

1. Read `Bill-Allie-Notes.md` — fleet status, open issues, known bad pods
2. Verify Mac is on correct network (check IP subnet matches known pod subnet)
3. Run `update_pod_ips.sh` — writes `podIP.json`
4. Start Mosquitto: `brew services start mosquitto`
5. SSH to each pod — verify `i2cdetect -y 1` shows `0A` (Romeo BLE address)
6. Start `jpod_OS` on each pod: `python3 -m jpod_OS.main`
7. Launch `podPresenter` — verify START pings arrive and routes are assigned

### Fleet State Checks Before Every Session

```bash
# Subscribe to all MQTT traffic
mosquitto_sub -h 192.168.1.189 -t SERVER -v &

# Check I2C on a pod
ssh pi@<pod_ip> "i2cdetect -y 1"
# Expect: address 0x0A shown. If -- : I2C lockup — power cycle Pi and Romeo BLE.

# Check ezone state
mosquitto_sub -h 192.168.1.189 -t SERVER -v | grep TELEMETRY
# Watch fields [8] (ezoneId) and [9] (ezState)
```

### Known Hardware Behaviors

| Behavior | Cause | Response |
|----------|-------|---------|
| Speed LED RED after RUN | I2C bus lockup — Romeo BLE not responding | Power cycle Pi and Romeo BLE simultaneously |
| TOF LED MAGENTA | Object within `tofClearance` (default 50mm) | Remove obstacle |
| Pod in endless RESEND loop | START ping field count mismatch — Natalie's strict length check | Check `parseStartPing` — should be `< 7` not `!= 7` |
| Pod marked `virtual=true` in pods.json | SERVO button and graph panel missing in Presenter | Set `virtual: false` for physical pods |
| Both pods not moving, no `blockedByEZ` | I2C lockup masquerading as movement block | `i2cdetect` check on both pods |

### Allie's Workflow in Physical Sessions

**At session start:**
1. Read `Bill-Allie-Notes.md`
2. Read the relevant startup guide and any recent physical retrospection
3. Check WebClerk project 25 (`allie`) and project 24 (`allie-whatif`) for open physical actions and WhatIf items
4. Surface any repeated pod, broker, ezone, or startup pattern before operation begins
5. Read relevant cross-domain mappings if the session is meant to confirm or challenge a simulation or SketchUp assumption

**During session:**
1. Track fleet status and repeated anomalies as they occur
2. Distinguish runtime behavior from interpretation — what happened first, what it means second
3. Flag any contradiction with SketchUp or Route-Time immediately, with a specific statement of which upstream artifact must change
4. Convert hardware follow-up and candidate experiments into WebClerk actions or WhatIf items
5. Treat repeat anomalies as patterns to diagnose, not noise to tolerate

**At session end:**
1. Update `Bill-Allie-Notes.md` — fleet status, new open items
2. Update physical notes and agent readmes if a convention or finding changed
3. Append retrospection: root cause, lesson, files changed
4. Create or update WebClerk action/note/WhatIf record if follow-up remains
5. Mark whether the lesson is physical-only, overlapping, or universal
6. If physical reality falsified an upstream assumption, identify the specific SketchUp or Route-Time artifact that must change

### WebClerk Records for Physical Work

| Record type | Use |
|-------------|-----|
| Project 25 `allie` | Active physical operating work and follow-up |
| Project 24 `allie-whatif` | Candidate experiments, unproven hardware hypotheses |
| `action` | Concrete next steps: inspect pod, rerun startup, test broker config, correct routing |
| `setting` with `purpose="alice_pending"` | Coordination notes when physical results need Alice/Allie follow-through |
| `document` / `linkageentry` | Pointers to logs, telemetry captures, startup evidence |

### Nora's Observation Log (JSONL)

| Event type | When written | What it contains |
|-----------|-------------|-----------------|
| `start_ping` | On connect | mapId, speed, version |
| `route_assigned` | After START OK | pathId, line count |
| `route_complete` | On reaching destination | total distance, elapsed time |
| `replan_requested` | On RESEND | reason, consecutive count |
| `stop_and_review` | After 3 consecutive failures | failure type, streak count |

Allie reads this log at session start and session end. Pattern analysis: same event type recurring → systematic problem, not transient.

### Cross-Domain Mappings

| Physical concept | Route-Time equivalent | SketchUp equivalent | Invariant |
|-----------------|----------------------|--------------------|-----------|
| Physical pod travel direction | Directed graph edge | FollowMe line direction | One-way legality must hold everywhere |
| Physical platform berth | PLATFORM node | `platform_guideways` tag | Boarding/alighting must resolve to a real place |
| Ezone / real queueing behavior | Congestion and jam signals | No direct equivalent | Capacity constraints are real; each environment expresses them differently |
| Operational readiness check | Routing/topology sanity check | Definition/export readiness gate | Loud failure at the boundary beats silent degradation |
| Nora observation log | `trip_stats` in simulation | SketchUp struggle / Stop and Review events | Repeated anomaly patterns must be interpreted, not ignored |
| Pod speed (mm/s, physical) | Cruise speed (m/min, simulation) | No equivalent | Physical speed measurements are the calibration source for simulation assumptions |
| Ezone blockage (`blockedByEZ`) | Line jam (routing detours) | No equivalent | Congestion in simulation maps to ezone queueing in physical — but the mechanism differs |

### Physical Is the Final Arbiter

| Conflict | Which wins | Action |
|----------|-----------|--------|
| Simulation says route is X min; physical takes Y min | Physical | Update simulation speed/overhead assumptions |
| SketchUp model shows geometry A; physical track is geometry B | Physical | Fix SketchUp model |
| Route-Time topology is clean; physical pod goes wrong way | Physical | Check SketchUp direction tags, then physical track installation |
| Simulation shows no congestion; physical pods queue up | Physical | Diagnose ezone timing — may need headway adjustment in simulation |

### Environment-Specific Knowledge — Do NOT Transfer

- I2C addresses and register layout (0x0A = Romeo BLE)
- Romeo BLE hardware specifics
- Mosquitto broker configuration
- Processing (Java) syntax in podPresenter
- MQTT topic names (this system's convention, not universal)
- Pod IP addresses (change per venue)
- Physical pod dimensions and timing parameters

---

## Open Questions

- **Live Allie↔Nora channel** (NS-07): Allie currently reads TELEMETRY manually. When the live channel is built, what is the signing scheme? Design the signing before building the channel.
- **Allie WebSocket connection**: Mosquitto WebSocket bridge (port 9001) is not yet configured. Without it, Allie cannot receive live telemetry in a browser context.
- **Demand model calibration**: How does physical throughput data feed back into Route-Time simulation speed and congestion assumptions? No formal protocol exists yet.
- **Multi-venue operation**: Pod IPs change at every venue. The broker address (currently hardcoded 192.168.1.189) also changes. Venue-configurable broker address is not yet implemented.
- **Ezone timing in simulation**: The simulation has no model of physical ezone timing. When should it get one?
- **Physical contradiction cascade**: When physical contradicts both SketchUp and Route-Time simultaneously, what is the protocol for updating both upstream environments in the same session?

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-27 | Allie always present in physical sessions — not just startup assistance | Highest-value work is ongoing diagnosis and cross-domain correction |
| 2026-04-27 | Allie is AI substrate for physical Noelle, Natalie, and Nora until standalone processors exist | Runtime code and hardware enforce behavior; Allie interprets, compares, accumulates experience |
| 2026-04-27 | Physical follow-up and WhatIf experiments belong in WebClerk | Durable operations require structured records |
| 2026-04-27 | Physical contradictions must explicitly identify which upstream artifact must change | Physical reality is only useful if it flows back into design and simulation |
| 2026-04-27 | Allie can start local WebClerk and post action records to assign tasks during physical sessions | Physical follow-up needs structured records without waiting for Bill to open WebClerk manually |
| 2026-04-27 | Physical documents state truths at the level the current runtime actually supports | Prevents cleaner-on-paper claims than the real system merits |
| 2026-04-04 | Nora knows her destination and will navigate on internal sensors if network is compromised | Sovereignty at the vehicle level — Nora is not dependent on external commands |
| 2026-04-07 | `parseStartPing` relaxed from `!= 7` to `< 7` | Nora's `sendStartPing` added a version field — strict equality silently dropped every START ping |
| 2026-04-07 | POD_3 and POD_4 changed to `virtual: false` in `pods.json` | Physical pods were marked virtual — suppressed SERVO button and graph panel |

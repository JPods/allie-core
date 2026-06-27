# Lessons from SU Animation for Physical JPods Networks — 2026-06-26

These lessons were earned during a SketchUp animation session where Sally's pod management broke down. Every failure has a direct physical equivalent. The physical network will face these same problems at higher stakes — a stuck pod on an elevated guideway is not a visual glitch, it is a stranded passenger.

---

## Lesson 1: Ghost Pods — Stale Records Survive Restarts

**What happened in SU:** Sally's `pods[]` array accumulated 15 records across stop/start cycles. Only 2-3 slots were actually occupied. The ghost records blocked the conveyor and prevented dispatch. The station jammed.

**Physical equivalent:** A pod loses MQTT connectivity (Pi reboot, WiFi dropout, battery brown-out). Sally's station chip keeps the record. When the pod reconnects — or doesn't — Sally still thinks the slot is occupied. The station blocks.

**Physical fix needed:**
- Every pod record needs a `last_heartbeat` timestamp
- Sally purges any record where `now - last_heartbeat > HEARTBEAT_TIMEOUT_S` (suggest 30s)
- Nora publishes heartbeat on TELEMETRY topic every 5s — if Sally doesn't hear it, the pod is gone
- Purge logs to `defect.json` equivalent on the station chip

**Files to modify:**
- `JPodsSM_RPi/jpod_OS/main.py` — add periodic heartbeat publish
- Station chip Sally (future) — add heartbeat timeout purge
- `podPresenter` — Natalie fleet registry with heartbeat tracking

---

## Lesson 2: Natalie Dispatches Blind — No Fleet Awareness

**What happened in SU:** Natalie planned routes and dispatched pods without knowing where any pod actually was. Pods piled up at stations because Natalie didn't count en-route pods.

**Physical equivalent:** podPresenter dispatches a pod to a station without checking how many pods are already headed there. Three pods arrive simultaneously. Station has 2 empty slots. One pod has no slot.

**Physical fix needed:**
- Natalie (podPresenter) maintains a fleet registry: `nora_id → { position, station, state, destination, last_telemetry }`
- Updated from TELEMETRY MQTT messages (already published by every Nora)
- Before dispatch: `effective_occupancy = occupied_slots + inbound_count`. If >= capacity, don't dispatch there
- Fleet registry is the cross-check for Sally's slot array

**Files to modify:**
- `JPodsSM_RPi/podPresenter/` or `podPresenter_v3/` — add fleet registry from TELEMETRY
- Dispatch logic — check `effective_occupancy` before sending START OK

---

## Lesson 3: One Stuck Pod Blocks the Entire Station

**What happened in SU:** A ghost pod at ps9 (ps_max) could not be dispatched because it wasn't in the `dwelling` set. The conveyor couldn't advance any pod past it. All arrivals stacked at ps5. The station effectively died.

**Physical equivalent:** A pod at the exit slot loses encoder feedback. Sally thinks it's there but can't confirm movement. No pod can advance. No pod can depart. The station is dead until a human intervenes.

**Physical fix needed:**
- Sally must be able to declare a slot `BLOCKED` after N failed advance attempts
- A blocked slot triggers Natalie notification: "station X degraded, capacity reduced by 1"
- Natalie stops routing pods to full/degraded stations
- Physical recovery: maintenance team manually moves the pod, Sally clears the block
- Nora's sovereign baseline (`native.json`) already supports emergency stop — extend to "request assistance" state

**Files to modify:**
- Station chip Sally (future) — blocked slot state machine
- `JPodsSM_RPi/jpod_OS/mqtt.py` — publish BLOCKED status
- `podPresenter` — listen for BLOCKED, reduce station capacity in routing

---

## Lesson 4: Two Arrays Must Stay in Sync — Bidirectional Validation

**What happened in SU:** Sally's `pods[]` (who she knows about) and `ps[]` (which slots are occupied) diverged. A pod record claimed slot 9 but slot 9's occupant was a different pod. Both pod and slot looked valid individually. Together they were contradictory.

**Physical equivalent:** Sally's memory says NORA_0011 is at slot 9. The ToF sensor at slot 9 sees NORA_0037. Both are "correct" in their own domain. The control system makes wrong decisions.

**Physical fix needed:**
- Bidirectional validate on every dispatch decision:
  - For every `pods[nid].slot == N`: verify `ps[N].occupant == nid`
  - For every `ps[N].occupant == nid`: verify `pods[nid]` exists and claims slot N
  - Mismatch → purge the stale record, log defect, reduce capacity until resolved
- ToF sensor at each slot is the physical source of truth — not Sally's memory
- Validate runs on demand (maintenance) and on every departure decision, not on a timer

**Files to modify:**
- Station chip Sally (future) — validate! method with ToF cross-check
- `JPodsSM_RPi/jpod_OS/tof.py` — slot occupancy confirmation

---

## Lesson 5: The Control Loop Is Sacred — Rule 24

**What happened in SU:** A diagnostic dashboard polling Ruby from JavaScript every 2 seconds degraded animation. Pods stuttered. State reads returned stale data. A validate function running on every 0.5s tick with disk I/O caused additional hitching.

**Physical equivalent:** Verbose MQTT logging, sensor polling at full rate, or telemetry publishing on the motor control loop steals CPU from encoder reading and PID correction. The pod overshoots a stop point because the control loop missed a tick.

**Physical fix needed:**
- Motor control loop (PID + encoder) runs at highest priority, never interrupted
- Telemetry publishes on a separate timer, not on the control loop
- MQTT publishes are fire-and-forget (`qos=0`) on the control path
- Logging goes to RAM buffer, flushed to SD card every 4 minutes or on trip completion
- Diagnostic tools (unitTest, calibration) run INSTEAD of control, never alongside

**Files to modify:**
- `JPodsSM_RPi/jpod_OS/main.py` — ensure motor loop is not sharing thread with telemetry
- `JPodsSM_RPi/jpod_OS/mqtt.py` — verify qos=0 for telemetry, separate thread for subscribe
- `JPodsSM_RPi/jpod_OS/motor.py` — PID loop must not call any blocking I/O

---

## Lesson 6: Defect Logging Beats Real-Time Dashboards

**What happened in SU:** The Sally Dashboard gave a snapshot that was already stale. The defect.json log captured every anomaly with full context (both arrays, fleet positions, timestamps). Patterns emerged from the log that no dashboard could show.

**Physical equivalent:** A status dashboard on podPresenter shows current state. But the failure that happened 3 minutes ago — the one that caused the cascade — is gone. The log has it.

**Physical fix needed:**
- Each agent writes defect records to local storage (SD card on Pi, disk on podPresenter)
- Format: JSON lines, append-only, one record per defect
- Fields: `dt` (UTC), `local`, `agent`, `type`, `detail`, `data` (state snapshot)
- Allie reads these nightly for cross-domain pattern detection
- Physical faults already use `_write_fault()` — extend to include full state snapshots

**Files to modify:**
- `JPodsSM_RPi/jpod_OS/main.py` — extend `_write_fault` with state snapshot data
- `podPresenter` — fleet-level defect log aggregating from all station/pod faults
- `~/Allie/scripts/allie-capture.py` — ingest physical defect.json files

---

## Physical Todo List

### Nora (jpod_OS on Pi)

| # | Feature | File(s) | Priority | Notes |
|---|---------|---------|----------|-------|
| PH-01 | Heartbeat publish every 5s on TELEMETRY | `main.py`, `mqtt.py` | High | Sally and Natalie need this to detect dead pods |
| PH-02 | Defect logging with state snapshot | `main.py` | High | Extend `_write_fault` with encoder pos, slot, trip state |
| PH-03 | RAM-buffered logging, flush every 4 min | `main.py` | Medium | Rule 24 — don't write SD on control loop |
| PH-04 | "Request assistance" state (extend sovereign baseline) | `main.py`, `session.py` | Medium | Pod declares it cannot self-recover |
| PH-05 | I2C bus lock (threading.Lock) | `i2c_lock.py`, `main.py` | High | Ouch-list I2C-01 — three libraries share bus 1 |

### Natalie (podPresenter)

| # | Feature | File(s) | Priority | Notes |
|---|---------|---------|----------|-------|
| PH-06 | Fleet registry from TELEMETRY | `podPresenter_v3/` | High | nora_id → position, station, state, heartbeat |
| PH-07 | Effective occupancy check before dispatch | `podPresenter_v3/` | High | occupied + inbound >= capacity → don't dispatch |
| PH-08 | Defect log aggregator | `podPresenter_v3/` | Medium | Collect fault files from all Pis, write fleet defect.json |
| PH-09 | Station degraded notification | `podPresenter_v3/` | Medium | Reduce routing capacity when Sally reports blocked slot |

### Sally (station chip — future)

| # | Feature | File(s) | Priority | Notes |
|---|---------|---------|----------|-------|
| PH-10 | Heartbeat timeout purge (30s) | station chip | High | Purge pod records with no heartbeat |
| PH-11 | Bidirectional validate (pods[] ↔ ps[] ↔ ToF) | station chip | High | Three-way cross-check on every dispatch |
| PH-12 | Blocked slot state machine | station chip | Medium | After N failed advances, declare slot blocked |
| PH-13 | Slot occupancy from ToF sensor | station chip, `tof.py` | High | Physical source of truth for slot state |

### 4WD Floor Robots (JRobots_4WD)

| # | Feature | File(s) | Priority | Notes |
|---|---------|---------|----------|-------|
| PH-14 | Heartbeat on BLE/WiFi | `jpod_OS/main.py` | Medium | Same ghost-pod risk over BLE as MQTT |
| PH-15 | Waypoint-graph fleet registry | `web_client/` | Medium | Romeo BLE robots need fleet awareness too |
| PH-16 | Defect logging to local storage | `jpod_OS/main.py` | Medium | SD card or flash — same format as Pi pods |

---

## The Governing Principle

From PRINCIPLES.md: *"If local responsibility exceeds current capacity, Nora must be able to ask for more assets."*

Every lesson above is an instance of this. A ghost pod is a pod that can't report its own state. A stuck station is a station that can't ask for help. A blind dispatcher is a coordinator that can't see the fleet. The fix in every case is the same: give the agent enough information and authority to act on its own reality, and enough voice to report when it can't.

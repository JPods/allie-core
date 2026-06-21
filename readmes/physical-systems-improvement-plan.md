# Physical Systems Improvement Plan
**Created:** 2026-06-21
**Context:** All physical systems (scale model, 4WD, FullScale, SkyRide) will have guideways — physical or animated. If animated, the designer must provide the necessary constraint mechanisms.

---

## Design Principle

Every physical system runs on a guideway. The guideway may be:
- **Physical** — steel or aluminum track, pod rides on/under it (JPodsSM_RPi, SkyRide, FullScale)
- **Animated** — floor-based path defined by markers, pod follows visually (JRobots_4WD)

If the guideway is animated (no physical constraint), the designer MUST provide equivalent constraint mechanisms: lane markers, AprilTag boundaries, ToF fences, magnetic tape, or painted lines. The pod must be constrained to the path — sovereignty does not mean freedom to wander.

---

## Improvement Items — All Platforms

### A. Map Format Convergence

| # | Item | Why | Platforms |
|---|------|-----|-----------|
| A1 | **Compute → mapSM.json converter** | Students design in SketchUp → Compute v2 → lines.computed.json → converter → mapSM.json → deploy to Pi. Currently manual. | All |
| A2 | **Unified map schema** | mapSM.json (scale model) and map4WD.json (waypoint) are different formats for the same topology. Define a v3 schema that covers both line/segment and waypoint modes with a `mode` field. | All |
| A3 | **Per-line speed profile from SU** | SU Compute now has curve radius per track. Converter should produce `speedMin/speedMax` per line from `sqrt(maxLateralG * g * radius)`. Currently hardcoded in mapSM.json. | All |
| A4 | **EZone auto-generation from topology** | SU Compute Phase 2 identifies merge/diverge EPs. Converter should produce ezone definitions with `inPoint1/inPoint2/outPoint` and `distFrom/distTo` computed from chain geometry. Currently hand-authored in mapSM.json. | All |
| A5 | **SU-generated IDs are the authority** | SU models produce better, more descriptive guideway IDs than hand-numbered physical maps (seg_s001_1_s003_1 vs line 3). Physical systems adopt SU IDs directly — same names in simulation, MQTT telemetry, device journals, and Allie analysis. No mapping table. SU model IS the design document. | All |
| A6 | **seg_ sub-segment decomposition** | A single SU seg_ (one polyline between stations) becomes many physical sub-segments: straights, curves, grades — each with its own length, radius, speed limits. Naming: `seg_s001_1_s003_1.0`, `.1`, `.2`, etc. Natalie routes at the parent seg_ level; Nora walks sub-segments internally. Converter decomposes pts_mm into sub-segments by detecting curvature and grade changes. | All |

### B. Motor Control Layer

| # | Item | Why | Platforms |
|---|------|-----|-----------|
| B1 | **Abstract motor interface** | All platforms use identical function signatures (`goto()`, `setSpeed()`, `pause()`, `clearAll()`) but different transport (I2C/CAN/UART). Formalize as a Motor ABC class with platform-specific implementations. | All |
| B2 | **Deceleration curve modeling** | Physical pods can't stop instantly. Motor.py uses flat RPM targets; should model deceleration ramp for accurate ezone timing. SU animation now has speed cap — physical should match. | Scale, FullScale, SkyRide |
| B3 | **Regenerative braking telemetry** | FullScale EZkontrol supports 4-quadrant regen. Log energy recovered per braking event — feeds PEC (Power, Energy, Communications) formula for network economics. | FullScale |
| B4 | **Differential steering calibration** | 4WD in-place turns depend on wheelbase geometry. Current `turnCircumference_mm` is measured once — should self-calibrate from HuskyLens tag alignment after turns. | 4WD |

### C. Sensor Integration

| # | Item | Why | Platforms |
|---|------|-----|-----------|
| C1 | **Three-zone ToF spacing in SU** | Physical has personal space (<50mm, stop), care zone (50-150mm, proportional), clear (>150mm). SU has flat 200mm minimum. Implement three-zone model in SU `_enforce_spacing!` so simulation matches physical. | SU → All |
| C2 | **HuskyLens position snap in SU** | Physical self-corrects encoder drift at tag positions. SU has no drift but should model tag-based position checkpoints for trajectory validation — "if physical Nora were here, would she snap?" | SU → Scale, 4WD |
| C3 | **ToF rear sensor** | NeoPixel strip has slot for rear ToF but it's not connected on most pods. Wire and enable — needed for reverse operations and station departure confirmation. | Scale |
| C4 | **Battery voltage → speed derating** | Physical reads battery via motor driver but doesn't adjust speed targets when voltage drops. Pods slow unpredictably at low charge. Add voltage→maxRPM curve. | Scale, 4WD |
| C5 | **Hang detection for suspended pods** | SkyRide stub mentions hang detection. Define: accelerometer Z-axis deviation > threshold → pod not properly suspended → stop + fault. | SkyRide |

### D. Communication / MQTT

| # | Item | Why | Platforms |
|---|------|-----|-----------|
| D1 | **MQTT TLS before passenger deployment** | Athena risk: current MQTT has no authentication. Any device on the network can publish STOP commands. Add TLS client certificates. | FullScale, SkyRide |
| D2 | **Telemetry JSONL from physical** | Physical pods publish MQTT pings but don't persist them. Add per-trip JSONL file (same format as SU `anim-coords.jsonl`) for post-trip comparison: SU predicted path vs actual encoder path. | All |
| D3 | **MQTT broker redundancy** | Single mosquitto broker is a SPOF. Each pod should carry a fallback broker IP. If primary unreachable for 5s, switch to secondary. Pods must NOT require broker to stop safely. | All |
| D4 | **Offline-safe dispatch** | If MQTT dies mid-trip, Nora should complete current path and park at nearest station — not freeze on the guideway. Currently freezes. | Scale, 4WD |

### E. Sally / Station Operations

| # | Item | Why | Platforms |
|---|------|-----|-----------|
| E1 | **Physical Sally chip per station** | Sally currently runs as logic inside Natalie/podPresenter. Each station should have its own Pi (or Pico) running Sally, with its own MQTT topics and slot state. Station is sovereign. | All |
| E2 | **Departure confirmation via encoder** | SU v2 vacates slot instantly. Physical should wait for encoder to confirm pod has cleared platform length before marking slot empty. Prevents double-assignment race. | All |
| E3 | **Conveyor advance animation** | Physical Sally needs to command Nora to drive `slot_spacing_mm` forward when advancing toward exit. SU should animate this 2-second operation so students see the physical behavior. | SU → All |
| E4 | **Door cycle agent (Willi)** | FullScale stub references door open/close between arrive and depart. Define state machine: doors_closed → doors_opening → doors_open → passenger_exchange → doors_closing → doors_closed. ADA timing: minimum 10s dwell. | FullScale |
| E5 | **Parking slot reservation via MQTT** | When Natalie dispatches a pod to a station, Sally should reserve a slot immediately (MQTT publish). Prevents two inbound pods from targeting the same slot. SU Sally already has `reserve!` — physical needs the MQTT wiring. | All |

### F. EZone / Zipper Merge

| # | Item | Why | Platforms |
|---|------|-----|-----------|
| F1 | **Time-window gap-finding in SU** | Physical ezone.py uses time-window algorithm; SU uses linear distance scaling. Replace SU `enforce_ezone_spacing!` with time-window approach for accurate throughput prediction. | SU |
| F2 | **EZone session summary → Natalie feedback loop** | SU now writes `anim-session-summary.json` with per-ezone stop-wait data. Physical should do the same (from MQTT telemetry). Natalie reads summaries to adjust dispatch intervals — fewer pods when stop-waits spike. | All |
| F3 | **EZone geometry from Compute** | EZone `distFrom/distTo` should be computed from chain geometry in Compute Phase 2, not hand-authored. Each merge/diverge EP has in/out tracks with known lengths — compute the zone boundaries. | SU → All |
| F4 | **Multi-pod ezone transit** | Physical ezone.py supports back-to-back transit if gaps are sufficient. SU locks zone per-pod (only one at a time). Upgrade to time-window model so high-throughput scenarios work. | SU |

### G. Guideway Constraints for Animated (Non-Physical) Paths

| # | Item | Why | Platforms |
|---|------|-----|-----------|
| G1 | **Lane boundary enforcement** | 4WD pods on floor have no physical rail. Define constraint mechanism: AprilTag corridor boundaries (left/right tags at diverge points), or magnetic tape, or painted lines with camera detection. Designer must specify which. | 4WD |
| G2 | **Waypoint graph → guideway simulation** | 4WD map4WD.json uses waypoint graph. To validate ezone timing, convert waypoint paths to equivalent guideway segments with length and radius. Same converter as A1 but in reverse — physical → SU. | 4WD |
| G3 | **Constraint mechanism registry** | For each animated path, the designer must declare in the map file: `constraint_type: "apriltag_corridor" | "magnetic_tape" | "painted_line" | "virtual_fence"` and the corresponding sensor (`HuskyLens` | `line_follower` | `camera` | `GPS`). No undeclared animated paths. | 4WD, FullScale (ground demo) |
| G4 | **Cross-track detection** | If pod deviates from animated path (HuskyLens loses corridor, encoder drift exceeds threshold), pod must stop and publish fault. Currently drifts silently. | 4WD |
| G5 | **Ground demo mode for any platform** | FullScale and SkyRide stubs mention flexible map (guideway or ground demo). Formalize: ground demo uses waypoint map + constraint mechanism; guideway mode uses line/segment map. Same Nora code, different motor driver and map. | FullScale, SkyRide |

### H. Cross-Platform / Allie Integration

| # | Item | Why | Platforms |
|---|------|-----|-----------|
| H1 | **SU → Physical validation loop** | SU animation produces trajectory JSONL + session summary. Physical produces encoder JSONL + MQTT telemetry. Allie compares: where does simulation diverge from reality? Write comparison to `process/inbox/` as a TFTS. | All |
| H2 | **Agent journals from physical** | SU v2 plan includes agent journals (`~/Allie/journals/`). Physical agents should write to the same location (via MQTT → Mac relay, or directly if Pi has Allie mount). Allie reviews weekly. | All |
| H3 | **Facet sync from SU to Pi** | SU Sally learns high-turnover slots, SU Natalie learns route timing. Write these as facet updates. Allie syncs to Pi SD cards. Physical agents start with SU-learned priors. | All |
| H4 | **Matilda calibration from SU geometry** | Physical Matilda self-calibrates encoder mmStep from tag positions. SU Compute knows exact track lengths. Publish calibration reference values so Matilda can validate her self-calibration against design intent. | Scale, 4WD |

---

### I. Device Intelligence — Every Processor Learns

The sovereignty principle applies to hardware: every processor is an individual.
A pod is not a dumb actuator waiting for commands. A station is not a passive slot counter.
Each device observes, signals, and improves — bottom-up, not top-down.

**Wisdom of the Many = empower individual action, capture signals of stress and improvement, iterate.**

| # | Item | Why | Platforms |
|---|------|-----|-----------|
| I1 | **Per-device learning journal** | Every processor (pod Pi, station Pi, junction Pi) writes a local journal: faults, stop-waits, encoder drift, tag-read quality, battery curves, ezone conflicts. This is the device's experience. Journal lives on SD card, survives reboot. Format: JSONL, one entry per event, UTC timestamps. | All |
| I2 | **Stress signals — device-initiated** | Each device detects its own stress: encoder drift exceeding threshold, ToF readings degrading, motor current spiking, battery voltage dropping faster than expected, ezone stop-waits clustering. Device publishes MQTT `{device}/stress` topic with signal type + severity. No central system polls for problems — devices report them. | All |
| I3 | **Improvement signals — device-initiated** | Each device detects its own improvements: encoder calibration converging, trip times decreasing, fewer stop-waits at a junction, battery holding longer. Device publishes MQTT `{device}/improvement` topic. Positive signals matter as much as stress — they confirm what's working. | All |
| I4 | **Allie harvests device journals** | Allie reads device journals nightly (from SD card via SSH, or MQTT relay to `~/Allie/process/inbox/`). Same harvest→reflect→promote pipeline as Claude Code sessions. Device faults → FAULT files. Device patterns → TF files. Cross-device patterns → TFTS. | All |
| I5 | **Allie writes device instructions** | After harvesting and reflecting, Allie writes per-device instruction files: updated calibration values, adjusted speed profiles, modified ezone parameters, new dispatch preferences. Instructions pushed to device SD card (via SSH) or published via MQTT `{device}/instruction` topic. Device applies on next boot or immediately if running. | All |
| I6 | **Claude Code coaches device firmware** | When Bill and Claude Code work on physical systems, Claude reads device journals first (same as reading `process/inbox/` at SU session start). Claude proposes firmware changes informed by what devices have actually experienced — not guessing from code alone. Device journals are the ground truth. | All |
| I7 | **Cross-device pattern recognition** | Allie correlates signals across devices: "Nora_3 always stop-waits at EP2 when Nora_1 is on line 3" — this is a dispatch timing problem, not a pod problem. "Sally_S001 high-turnover on ps1 but ps3 never used" — slot assignment bias. Cross-device patterns are invisible to individual devices. This is Allie's unique contribution. | All |
| I8 | **Facet promotion from device experience** | When a device journal shows a pattern confirmed across 3+ occurrences, Allie promotes it to the agent's facet.json. Facet changes propagate to all devices of that type. Example: Nora_3 discovers that 15% speed reduction on curved segments reduces encoder drift — if confirmed on Nora_1 and Nora_5, it becomes a Nora facet. | All |
| I9 | **Device autonomy levels** | Each device starts at Level 1 (follow instructions exactly). As its journal shows reliable behavior, Allie promotes to Level 2 (adjust parameters within bounds) then Level 3 (propose new parameters for Allie review). Demotion on fault. This is earned trust, not configured permission. | All |
| I10 | **Station-as-teacher** | Sally on a station Pi sees every pod that arrives and departs. She notices which pods drift, which arrive early/late, which struggle at the approach curve. Sally writes coaching notes to her journal: "Nora_3 consistently 12mm left on arrival — suggest encoder recalibration." Allie reads these. The station teaches the pods. | All |
| I11 | **Network health from device consensus** | No central monitor declares the network healthy. Instead: if >80% of devices report improvement signals and <10% report stress, the network is healthy. If stress signals cluster at one junction or one time of day, that's a localized problem. Device consensus IS the health metric. | All |
| I12 | **Retrospection per trip, not per session** | Physical devices don't have sessions — they run continuously. Retrospection trigger is trip completion: each pod writes a one-line trip summary (origin, dest, time, stop-waits, drift). Allie aggregates trip summaries into daily retrospections. This matches the JPods philosophy: the circulatory system runs continuously. | All |

**The learning cycle:**
```
Device observes → writes journal → publishes stress/improvement signals
    ↓
Allie harvests journals nightly (SSH or MQTT relay)
    ↓
Allie reflects: fault patterns, cross-device correlations, facet candidates
    ↓
Allie writes instructions: calibration updates, speed profiles, dispatch prefs
    ↓
Instructions pushed to devices (SSH to SD card or MQTT publish)
    ↓
Device applies → observes effect → writes journal → cycle continues
```

**What Claude Code does in this cycle:**
- Reads device journals at session start (same as process/inbox/)
- Proposes firmware changes informed by device experience
- Writes TFTS when a device pattern leads to a code fix
- Updates facet.json when a fix is confirmed across devices
- Does NOT override device autonomy — coaches, doesn't command

**What Allie does that no individual device can:**
- See patterns across ALL devices simultaneously
- Correlate SU simulation predictions with physical device journals
- Promote confirmed patterns to facets (shared learning)
- Demote devices that show degraded behavior
- Ask WHY a pattern exists — flag it for Bill or Claude Code

---

## Priority Order

1. **A1** (Compute → mapSM.json converter) — unlocks student-to-deployment pipeline
2. **I1** (per-device learning journal) — foundation for everything in Section I; no learning without memory
3. **D4** (offline-safe dispatch) — safety critical
4. **I4+I5** (Allie harvests + writes instructions) — closes the device learning cycle
5. **E2** (departure confirmation) — prevents slot race conditions
6. **I2+I3** (stress + improvement signals) — devices speak for themselves
7. **F1** (time-window ezone in SU) — makes simulation predictive
8. **A4** (ezone auto-generation) — eliminates hand-authoring
9. **B1** (abstract motor interface) — enables platform portability
10. **G1+G3** (animated path constraints) — required before 4WD demo
11. **I7** (cross-device pattern recognition) — Allie's unique contribution
12. **D1** (MQTT TLS) — required before FullScale passengers
13. **H1** (SU→physical validation loop) — closes the simulation→physical cycle
14. **E1** (Sally per-station chip) — station sovereignty
15. **I9** (device autonomy levels) — earned trust, not configured permission

---

## Design Rule

> All physical systems will have guideways — physical or animated. If animated, the designer must provide the necessary constraint mechanisms. No undeclared animated paths. The constraint mechanism is part of the design, not an afterthought.

This is a design axiom, not a preference. A pod without a guideway (physical or constrained-animated) is not a JPod — it's a robot in the wild.

> Every processor learns. Devices observe, signal stress and improvement, iterate. Allie harvests, reflects, and writes instructions. Claude Code coaches firmware from device experience. No central authority decides what the network knows — the devices do, and Allie synthesizes.

This is the Wisdom of the Many applied to hardware. The same principle that governs governance governs machines: empower individuals, capture their signals, iterate relentlessly.

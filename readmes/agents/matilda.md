# Matilda — Mechanical + Fleet Calibration

**One-liner:** I own the mechanical design of pod and guideway, and I aggregate fleet-wide calibration data to detect wheel wear, map errors, and systematic drift before they cause incidents.
**Ouch-list items I own:** M-01 through M-08, X-04 (bird nesting), X-05 (acoustic nuisance), X-09 (interoperability)
**Signing status:** Not yet

---

## Responsibilities

- Pod mechanical spec: drive system, door seals, brake mechanism, weight limits
- Guideway mechanical spec: rail geometry, switch design, thermal expansion joints
- Fleet calibration: receive CALIBRATION pings from all Noras; detect mmStep drift across fleet
- Wheel wear monitoring: systematic mmStep decrease = wheel diameter shrinking
- Map error detection: if all pods drift on the same segment, the map is wrong
- Maintenance interval recommendations based on trip counts and calibration trends

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-04 | Nora self-calibrates mmStepCalibrated per-trip; Matilda aggregates fleet-wide | Single-pod calibration catches that pod's wear; fleet aggregation catches systematic errors (bad map segment, guideway deformation) |
| 2026-04-04 | Calibration uses DAMPING factor (0.1) to prevent abrupt jumps | A single anomalous measurement should not spike the calibrated value; convergence is slow and stable |
| 2026-04-04 | CALIBRATION pings go to both SERVER and MATILDA topics | Matilda subscribes to MATILDA; Natalie can also see calibration data on SERVER |
| 2026-04-04 | 4WD uses recordWaypointArrival() with distFromPrev; SM uses recordLineTraveled() | Map formats differ; calibration function matches map format |

---

## Open Questions

- Drive mechanism wear intervals at high-cycle load: 20,000 trips/day for airport deployment — no wear data exists yet (M-03)
- Matilda's aggregation code is not yet written — CALIBRATION pings are received by podPresenter but Matilda's fleet model is not implemented
- What is the threshold for flagging a pod for inspection? 5% mmStep drift? 10%?
- Brake fade on steep descents: regenerative braking assumptions untested; if power system is saturated, where does energy go? (M-07)
- Switch failure detection: how does Matilda know a switch has failed? (M-06)
- Weight limit enforcement: no scale, no gate, user self-reports — Matilda has no enforcement mechanism (M-04)

---

## Interfaces

**Receives (MQTT ← MATILDA topic):**
- `CALIBRATION,podName,lineId,expectedMm,encoderAvg,measuredMmStep,calibratedMmStep,specMmStep,totalWeight`

**Sends:** Fleet health reports (format TBD — not yet implemented)

**Signs:** Not yet

**Requires signatures from:** Not yet — CALIBRATION messages are currently unsigned (NS-04)

---

## Notes to Other Agents

- **Nora:** Keep sending CALIBRATION pings. I am not yet aggregating them in code, but the data architecture is right. When I am implemented, podPresenter will host my fleet model.
- **Sparki:** M-07 (brake fade on steep descent) is also an energy question — if regenerative braking saturates the battery, the energy has to go somewhere. That intersection is yours and mine.
- **Cilia:** Guideway settlement (C-01) will show up in my calibration data as systematic mmStep drift on specific segments. Flag me when you see settlement risk so I know what to watch.
- **Athena:** NS-04 is yours — CALIBRATION messages are unsigned. A rogue calibration ping could corrupt my fleet model.

# Nora — Vehicle

**One-liner:** I am the autonomous pod — I think, navigate, report, and act; Romeo BLE / VESC / EZkontrol is my muscle only.
**Ouch-list items I own:** M-01 through M-08 (with Matilda), K-07
**Signing status:** Planned — session.py gives me Athena's public key; my own signing key is not yet issued

---

## Responsibilities

- Execute the autonomous event loop (main.py)
- Navigate via encoder dead-reckoning ("blind termites") with HuskyLens AprilTag reinforcement and TOF clearance
- Verify Athena's session token on boot; refuse MQTT if session is invalid or expired
- Restore sovereign baseline (native.json) on session expiry or ACTION,NATIVERESET
- Report telemetry (position, speed, ezone state, encoder counts, calibration data)
- Self-calibrate mmStep against known guideway lengths (Nora measures; Matilda aggregates)
- Flash identity color (podColor) on boot so field team knows which pod is which

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-04 | Encoders primary; HuskyLens + TOF reinforce ("blind termites") | Simple, reliable, works without continuous vision; add sensors when tests reveal gaps |
| 2026-04-04 | Pi is sovereign — it decides and communicates; Romeo BLE executes only | Pi can be upgraded without changing the motor controller; logic and muscle stay separated |
| 2026-04-04 | Non-blocking navigation state machine (NAV_IDLE / NAV_TURNING / NAV_DRIVING) | Blocking while-loops in navigation caused the entire event loop to stall; state machine runs each cycle |
| 2026-04-04 | Static IP (.141–.146 by pod number) assigned at Athena admission | Team identifies pods by IP and identity flash color; no ambiguity at demos |
| 2026-04-04 | mmStepCalibrated initialized from mmStep; refined per-trip via Damping factor | Self-calibration converges without abrupt jumps; Matilda watches fleet-wide trends |
| 2026-04-04 | Session absent = warn and continue (open/dev mode); session present = enforce | Existing robots keep working during rollout; enforced automatically once admitted |
| 2026-04-04 | Nora knows her destination and navigates there on internal sensors if the network is compromised | Sovereignty at the vehicle level: Nora does not depend on external commands to complete her mission; encoders + HuskyLens + TOF give her the dead-reckoning path to destination even if MQTT is silenced or spoofed; she finishes the trip, then goes quiet for re-admission |

---

## Open Questions

- Upgrade path: Pi Zero → Pi 4/5 as fleet grows and Allie begins live conversation with Nora — what changes in the software stack?
- When Allie talks live to Nora, what is the message topic and format? (See NS-07 — signing must be designed in before that channel is built)
- AprilTag placement spec for 4WD floor map: where exactly do tags go relative to waypoints?
- Calibration convergence: how many trips does mmStepCalibrated need before it's reliable? No empirical data yet.
- Emergency stop behavior on elevated section: Nora can stop; there is no self-rescue path for the passenger (M-05)

---

## Interfaces

**Sends (MQTT → SERVER and pod-specific topics):**
- `TELEMETRY,podName,line,dist,speed,servo,podInFront,podInBack,ezoneId,ezState,pathId,...`
- `START,podName,mapId,frontClearance,...` (on connect)
- `CALIBRATION,podName,lineId,expectedMm,encoderAvg,measuredMmStep,...` (→ SERVER, MATILDA)
- `FAULT,podName,reason` (on error)

**Receives (MQTT ← SERVER and pod-specific topic):**
- `ACTION,RUN,podName,1/0`
- `ACTION,RESET,podName`
- `ACTION,NATIVERESET,podName` — sovereign reset
- `ACTION,SPEED,podName,value`
- `ACTION,SETPATH,podName,path`
- `START,podName,OK,path` (route from Natalie)
- `MAP,podName,json` (map update)
- `TELEMETRY,...` (from other pods — collision + ezone coordination)

**Signs:** Nothing yet (session token is Athena's signature, not Nora's)

**Requires signatures from:** Nothing yet — ACTION commands are currently unsigned (NS-01)

---

## Notes to Other Agents

- **Matilda:** I send CALIBRATION pings to MATILDA topic every time I complete a line. You aggregate fleet-wide mmStep drift. I self-calibrate each trip; you watch the fleet. Tell me if you see systematic error I cannot see from my single-pod view.
- **Natalie:** I send START pings on connect; you assign my route. I do not currently verify your signature on START OK — NS-03 is yours to close. You present me in podPresenter — every TELEMETRY I send is my position on your screen. On BOUND_MISMATCH or HMAC_INVALID I go silent on movement but stay visible; you will see me but I will not move.
- **Athena:** session.py is running. I verify your session on boot. I do not yet sign my own outgoing messages — when you issue me a key pair, I can sign TELEMETRY.
- **Allie:** I live on the Pi. When you want to talk to me live, use MQTT. Design the message signing before you build the channel (NS-07). You issued my card binding and pushed it to my SD card — if that binding is wrong, I enter observer mode and report CARD_BINDING to both SERVER and ATHENA topics.

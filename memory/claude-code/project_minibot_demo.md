---
name: Mini-bot table-top JPods demo
description: Baron-4WD + Romeo BLE/ESP32-S3 + Pi table-top demo system — parked until ~2026-05-15
type: project
---

Color-code junction routing on printed MeshMobility network. Revisit in ~2 weeks.

**Why:** Physical demonstration of full JPods routing stack at table scale.

**Hardware Bill has:**
- DFRobot Baron-4WD chassis with wheel encoders
- Romeo BLE + Raspberry Pi (existing Nora platform)
- Romeo ESP32-S3 + Pi
- ToF sensors (existing on physical pods)
- Husky cameras (visual positioning / lane detection)

**Design settled:**
- Black track lines on printed paper (A0 from MeshMobility export)
- 4-block color sequences (R/G/B/Y) at junction approaches = junction ID
- TCS34725 RGB sensor reads junction codes
- Encoder-timed slowdown before expected junction (dead reckoning between junctions)
- Pi queries Natalie: `GET /natalie/turn?pod=X&junction=c3&trip=T042`
- Natalie returns turn + next_junction + expected_distance_m
- ToF for obstacle/stopping; Husky cam for optional visual lane assist

**To build when returning:**
1. `GET /natalie/turn` endpoint
2. `junction_reader.py` on Pi (color read + Natalie query)
3. Junction code assignment script (MeshMobility node IDs → color sequences)
4. Network print workflow from MeshMobility export
5. README: `readmes/40-minibot-table-demo.md`

**How to apply:** When Bill says "mini-bot" or "table demo" or "2-week project," this is it.

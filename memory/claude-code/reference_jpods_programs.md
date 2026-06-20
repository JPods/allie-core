---
name: JPods Program Registry
description: Four programs in the JPods ecosystem — their purpose, location, and boundaries. Never mix concerns between them.
type: reference
---

Four separate programs in the JPods ecosystem. Keep their concerns distinct.

| Program | Stack | Purpose |
|---------|-------|---------|
| **Route-Time** | Python, Flask, Leaflet | `/Users/williamjames/Documents/08_JPods/03_Technology/route_time` — Estimates travel times. Browser-based network planner and simulator. Design tool — does not run vehicles. |
| **JPodsSM_RPi** | Python, MQTT, Raspberry Pi | `/Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi` — Runs physical vehicles. Nora (vehicle), Natalie (router), Noelle (network) on hardware. |
| **SketchUp Plugin** | Ruby | `/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods` — 3D modeling of networks. Places structures, assigns CPs, generates geometry. |
| **WebClerk** | Django, Python, PostgreSQL, React | `/Users/williamjames/Documents/CommerceExpert/webClerk3` — Enterprise software with Alice agent built in. Stores anything helpful — network data, trip logs, operational records, shared context across programs. Alice is WebClerk's agent. |

**How they relate:**
- SketchUp → designs 3D physical structure, exports CP geometry
- Route-Time → uses that geometry to plan networks and simulate transit times
- JPodsSM_RPi → runs the real network the other two model
- WebClerk → persistent store and coordination layer; Alice bridges it to the other programs

**Shared standards (apply to all):**
- Red = inbound (hot), Blue = outbound (cool)
- CPs connect to CPs — never individual lines
- `network_map.json` is the canonical physical network format (Noelle owns at runtime)

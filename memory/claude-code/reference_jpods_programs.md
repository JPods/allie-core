---
name: JPods Program Registry
description: Five programs in the JPods ecosystem — their purpose, location, and boundaries. Never mix concerns between them.
type: reference
---

Five separate programs in the JPods ecosystem. Keep their concerns distinct.

| Program | Stack | Purpose |
|---------|-------|---------|
| **MeshMobility** | Python, Flask, Leaflet | `00_working_code/mesh_mobility` — Network planner and simulator. Design tool — does not run vehicles. Reads data from CrashHarvester library only. |
| **JPodsSM_RPi** | Python, MQTT, Raspberry Pi | `JPodsSM_RPi` — Runs physical vehicles. Nora (vehicle), Natalie (router), Noelle (network) on hardware. |
| **SketchUp Plugin** | Ruby | SketchUp Plugins/JPods — 3D modeling of networks. Places structures, assigns CPs, generates geometry. |
| **CrashHarvester** | Python | `00_working_code/CrashHarvester` — Data supply chain. Harvests government data, normalizes to uniform schemas, produces clean library. Alice manages sources. MeshMobility and public API are consumers. DynamicCatalogs pattern. |
| **WebClerk** | Django, Python, PostgreSQL, React | `CommerceExpert/webClerk3` — Enterprise software with Alice agent. Persistent store and coordination layer. |

**How they relate:**
- SketchUp → designs 3D physical structure, exports CP geometry
- MeshMobility → uses that geometry to plan networks and simulate transit times (reads crash/traffic/census data from CrashHarvester library)
- CrashHarvester → normalizes government data into clean library; MeshMobility, public API, student kits are consumers
- JPodsSM_RPi → runs the real network the other two model
- WebClerk → persistent store and coordination layer; Alice bridges it to the other programs and manages CrashHarvester sources

**Shared standards (apply to all):**
- Red = inbound (hot), Blue = outbound (cool)
- CPs connect to CPs — never individual lines
- `network_map.json` is the canonical physical network format (Noelle owns at runtime)

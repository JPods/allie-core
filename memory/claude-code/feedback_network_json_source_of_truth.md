---
name: network.json is source of truth for all network-specific data
description: Template folders hold only static framework and generalized model data; ALL use data to build and operate the network lives in .network.json
type: feedback
---

Only static frameworks and data specific to the generalized model lives in the su_jpods template folder. ALL use data to build and operate the network lives in the .network.json file.

**Why:** Station names, connections, waypoints, operational parameters — anything specific to THIS network — must be in network.json. Entity attributes inside the .skp are invisible to external tools (Travel app, Route-Time, Alice, WebClerk). Template folders are shared across all networks — network-specific data doesn't belong there.

**How to apply:**
- Station friendly names → network.json `station_names{}`
- Connections and waypoints → network.json `connections{}`
- Per-network Build Profile overrides → network.json (not model attributes)
- BOM → {model}.bom.json in project folder
- Crew observations → {model}.crew.json in project folder
- Template folders (track_formations/) are READ-ONLY during network operations
- Entity attributes on ComponentInstances are a CACHE for SU display, not source of truth
- If a tool can't read it from network.json without opening SketchUp, it's stored in the wrong place

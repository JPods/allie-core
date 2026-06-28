---
name: Model vs Network boundary — never cross
description: Model (template) = lines.json + lines.computed.json + model.skp, isolated station. Network = network.json + seg_ connections. Compute is model-only. Build is network-only. Track names gw_cp_in/out are internal CCW flow, NOT network connections.
type: feedback
---

Model and Network are two distinct scopes. Confusing them is the most repeated error in the SketchUp codebase — it causes 180° rotated tracks, 4.3m offsets, and jammed stations.

**Model scope:** Single station template in isolation. lines.json (topology), lines.computed.json (geometry), model.skp (3D). Compute operates here only. Model tests (shuffle/depart/arrive) validate here only. Track names gw_cp_in_0/gw_cp_out_0 define one-way flow within the station's CCW loop — they are NOT references to network connections. There is no "in/out to other devices" at this level.

**Network scope:** Placed instances connected by seg_ segments. network.json holds connections, routing graph. Build reads network.json + template computed files, transforms to world coordinates. seg_ connections are the only place "in/out to other stations" exists.

**Why:** Axiom 10, Axiom 19. Attempting to determine model-level in/out from network-level concepts (model.bounds.center, world position, station orientation in the network) collapses the boundary and produces geometry that rotates or offsets when the surrounding model changes. All guideways are one-way. All station circulation is CCW (Rule 12).

**How to apply:** Compute must never read network.json. Build must never modify template files. Model tests must never require network context. When writing Compute code, the only inputs are model.skp geometry and lines.json topology.

---
name: Noelle algorithm library
description: Noelle should have a library of network design algorithms, not just one; current grid preserved; new crash-corridor algorithm to build; 15-min walk + more doors as constraints
type: project
---

Noelle should maintain a library of network design algorithms. Each is a tool she selects based on context. Never lose an algorithm — add new ones.

**Why:** The 1x2 grid mesh is one valid approach but ignores crash corridor data. A crash-driven algorithm produces radial spoke networks that match the actual danger pattern. Different cities need different approaches. Noelle picks.

**How to apply:**

Current algorithms to preserve:
- **Grid mesh** (1x2) — uniform spacing, good for blank-slate coverage analysis
- **City Mesh** — grid with urban filter, snapped to intersections

New algorithm to build:
- **Crash corridor** — extract corridor spines from top 10% crash density cells, place stations along spines, connect with cross-links, fill gaps with single-slot poles

Design constraints for the new algorithm:
- 15-minute walk radius (0.75 mi) maximum from any point to nearest station
- "More doors" — prefer many small stations over few large ones
- Noelle sets slot count from data (crash density, population, traffic)
- Crash corridors = guideways, walk circles = station placement
- Single-slot poles (1-2 slots) fill coverage gaps along corridors
- Hubs (50-100 slots) at batch-to-packet conversion points (train stations, airports)

Algorithm selection: Noelle recommends based on data available. User can override.

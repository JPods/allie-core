---
name: Noelle network design rules
description: Noelle Draft pattern — stations only, highways as boundaries, crash rate primary signal, 1:14 road ratio, 1x2 mile grid
type: reference
---

**Noelle's Established Draft Pattern (Tulsa, 2026-07-05):**

Three rules:
1. **Stations only** — Noelle places stations; designer adds circles (circles need local knowledge)
2. **Highways are boundaries, not corridors** — nobody walks to I-44; stations on arterial grid between highways
3. **Crash rate per 10K AADT is primary signal** — Tulsa: local arterials 87.7/10K (9× interstates at 9.3/10K)

Road ratio:
- FHWA HM-72: Tulsa has 14 road mi/sq mi
- Target: 1 mi JPods per 12-18 mi road → 1×2 mile grid optimal (1:14)
- 1×1 over-capitalized (1:7), 2×2 too sparse (1:28)

Design principles:
- Circles at corridor intersections (4 CPs = junctions), stations mid-block (2 CPs = stops)
- Primary network: arterial grid crash + AADT signal. Secondary: accident clusters
- Stations at commercial nodes on neighborhood BOUNDARIES
- JPods is Middle-Mile; Last-Mile = walking/biking/scooters/LUVs
- Mesh over capacity: parallel paths, never a single point of failure
- Capacity bottleneck: station dwell (30s/pod), not guideway (9,191 people/hr/direction)

GUI: Draft button (places stations + shows panel) + Report button (printable HTML)
API: POST /api/noelle/draft?place=true, GET /api/noelle/report
Full doc: readmes/48-noelle-data-driven-design.md

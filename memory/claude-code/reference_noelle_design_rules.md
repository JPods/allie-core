---
name: Noelle network design rules
description: Noelle Draft pattern — stations only, highways as boundaries, crash rate signal, 1:14 road ratio, 1x2 grid, both-side access, Local Knowledge QA
type: reference
---

**Noelle's Established Draft Pattern (Tulsa→7 cities, 2026-07-05/06):**

Three rules:
1. **Stations only** — Noelle places stations; designer adds circles (circles need local knowledge)
2. **Highways are boundaries, not corridors** — nobody walks to I-44; stations on arterial grid between highways
3. **Crash rate per 10K AADT is primary signal** — Tulsa: local arterials 87.7/10K (9× interstates at 9.3/10K)

Road ratio:
- FHWA HM-72: Tulsa has 14 road mi/sq mi
- Target: 1 mi JPods per 12-18 mi road → 1×2 mile grid optimal (1:14)
- 1×1 over-capitalized (1:7), 2×2 too sparse (1:28)

Both-side access rule:
- Avoid building along linear barriers (rivers, freeways, rail)
- Per $ of guideway, both-side access = better ROI
- Exception: frontage roads with commercial between freeway and neighborhood
- Test: can pedestrians reach station from two different neighborhoods?

Design principles:
- All-severity crash density is better signal than fatal-only (too sparse for small cities)
- Circles at corridor intersections (4 CPs = junctions), stations mid-block (2 CPs = stops)
- Mesh over capacity: parallel paths, never a single point of failure
- JPods carries bikes/scooters — Last-Mile radius is biking distance (5km), not walking (1.2km)

Three ways to start:
1. **Draft** — Noelle proposes as toggle layer (purple dots), Apply when ready
2. **Grid** — uniform grid, then Refine prunes/fills from data
3. **Manual** — place by hand with keyboard shortcuts 1-6

Tools: Draft (toggle layer) → Apply Draft → Refine → Report → Local Knowledge QA
Census overlays: Population Density, Property Values, Jobs (isochronal)
7 cities: Tulsa OK, Bloomington MN, Weymouth MA, Secaucus NJ, Greenville SC, Arlington TX, Spokane WA
Full doc: readmes/48-noelle-data-driven-design.md

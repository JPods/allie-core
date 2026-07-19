---
name: Structure UUIDs + network merge
description: Stations/circles are serialized items with permanent UUIDs; local IDs (s1, c1) renumber on save; /api/network/merge combines .jpd files by UUID matching
type: project
---

Built 2026-07-18. Structures (stations, traffic circles) are now serialized items — each has a permanent UUID that survives merge, copy, fork. Local IDs (s1, c1) are convenience labels renumbered per file.

**UUID fields added to:**
- `Structure.structure_uuid` (12-char hex, auto-generated on creation)
- `ConnectionPoint.cp_uuid` (12-char hex, auto-generated on creation)
- Both persisted in .jpd via `to_dict()`, restored on load

**Merge endpoint:** `POST /api/network/merge`
- Accepts `{path: "/path/to.jpd"}` or `{content: "json string"}`
- Matches structures by UUID — same UUID = same physical asset, kept once
- New structures get renumbered local IDs; nodes/CPs/lines remapped
- Inter-structure guideways from the merged file are preserved
- Cross-network connections (between the two halves) made manually after merge

**Why:** Adjacent city networks built separately need to combine. Also: UUID ties station identity across all four programs (MeshMobility, SketchUp, JPodsSM_RPi, WebClerk/Alice). Bill: "same uuid vs id used in wc3 for station identification."

**How to apply:** UUID is the station's permanent serial number. Local ID bends to the file context. On merge, UUID detects duplicates. Noelle and Alice should think about database structure for stations as serialized assets.

**Database thinking (not built yet):** Bill flagged that Noelle and Alice should start designing a database structure for serialized station assets. Not required now, but will be important once building starts.

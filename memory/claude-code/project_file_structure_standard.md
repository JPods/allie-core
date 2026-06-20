---
name: JPods model file structure standard
description: Correct file structure for JPods network models — lines.json + lines.computed.json + network.json
type: project
---

Model-level files should be exactly two:

- `lines.json` — raw geometry (replaces path.json)
- `lines.computed.json` — Compute output: direction, successors, CP positions

All structural non-trip data goes into `network.json` in the `network.skp/` folder.

**Why:** Current proliferation (path.json, followme.json, map.json, segment_registry.json, vehicles.json, visits.json) is too many files. Missing `lines.computed.json` is why Natalie has 130 proximity fallbacks — no computed successor/direction data to read.

**How to apply:** When touching Compute, Build, or Natalie dispatch — verify files exist with correct names. `path.json` = misnamed `lines.json`. `lines.computed.json` missing = Compute output not written or written elsewhere. Established 2026-06-18.

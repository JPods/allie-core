---
name: No salvage before release
description: Pre-release policy — never try to salvage stale data files; always start fresh
type: feedback
---

Never attempt to salvage stale network models, map.json, path.json, or other generated data files when geometry or schema has changed. Start fresh every time until a release version is declared.

**Why:** Salvaging pre-release data carries forward unknown inconsistencies. The cost of starting fresh is low; the cost of debugging a network built on stale data is high.

**How to apply:** When a template geometry change, schema change, or CP position shift occurs, recommend a new network model — not a rebuild or reconnect of the old one. Do not offer "salvage" as an option pre-release.

---
name: Process capture architecture
description: Allie has outcomes (session logs, retrospections, Understanding entries) but not indexed process. The fix is ~/Allie/process/ with narrative.md — reasoning chains with "what this told us" at each failed step.
type: reference
---

Allie currently has **outcomes**, not **process**. Session logs describe what changed; retrospections have lessons; Understanding entries are distilled rules. None of these capture the reasoning chain through failed → partial → successful approaches.

Principle: *"Knowing the outcome is much less valuable than knowing the process."* — Bill James, 2026-05-18

**Fix:** `~/Allie/process/` directory — one folder per problem, organized by domain (`sk/`, `rt/`, `ph/`).

Most valuable file in each folder: `narrative.md` — the reasoning chain with **"what this told us"** at each failed step.

**Signal vs. noise rule:** Record the key shift at each attempt — the moment a failure revealed something. Not every error. Three attempts each revealing one thing = signal. Twenty incremental cycles on the same misunderstanding = noise.

**When to write:** During the session, at the moment of failure — not at session end.

**Integration:** Understanding entries get a `process_ref:` field pointing to the narrative. `allie-reflect.py` should scan `process/` for new narratives and index them into `thoughts/`.

**Format guide:** `~/Allie/process/README.md`
**Agent doc:** `readmes/agents/allie.md` § "Process Knowledge — What Allie Knows vs. What She Needs"

Four backfill entries owed: bezier-height, vector3d-multiply, layer-manager-missing, cp-anchor-z.

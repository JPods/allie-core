---
name: Break and fix now — no legacy
description: Bill's principle for handling accumulated technical debt and inefficiency
type: feedback
---

Now is the only time we have to correct past inefficiencies. Better to suffer now and learn.

**Why:** Legacy accumulation is compounding debt. Every session that tolerates duplication, stale interfaces, or workarounds makes the next session harder. The cost of breaking and fixing today is bounded; the cost of carrying legacy forward is unbounded.

**How to apply:** When a session reveals duplication, stale interfaces, or accumulated workarounds, propose cleaning them up in the same session rather than deferring. Do not add to a legacy pattern to make something work — break the pattern and fix it. Temporary pain now beats permanent noise.

Examples where this applied:
- Console cleanup: 43 tasks → 16 (2026-05-18, archived, not deleted)
- Menu cleanup: 30+ menu items across 3 submenus → 3 items (2026-05-18, migrated to Console)
- GL overlay display: replaced with direct material assignment on guideway groups

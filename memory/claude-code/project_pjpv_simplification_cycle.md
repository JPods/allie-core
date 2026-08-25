---
name: PJPV simplification cycle method
description: The audit→fix→verify→audit cycle for eliminating duplicate paths and translation layers; applied 2026-08-24 with major results
type: project
---

PJPV simplification follows a relentless cycle: scrub → fix → verify → look deeper → repeat.

**Why:** Each pass exposes the next layer. The PJPV compliance scrub (removing scalar shadows) revealed 10 simplification opportunities (duplicate registries, duplicate computations, N+1 queries). Fixing those revealed 11 more (duplicate views, duplicate utilities, backward-compat shims). The cycle continues until the codebase converges on one path per concept.

**How to apply:**

1. **Audit** — launch parallel read-only agents across backend, frontend, docs. Look for: duplicate computations, translation layers, multiple paths to same result, backward-compat shims.

2. **Fix** — group by file overlap to avoid conflicts. Launch parallel fix agents. Each fix follows the same pattern: keep the canonical version, delete the rest, update callers.

3. **Verify** — run another scrub agent to confirm clean. Run tests.

4. **Look deeper** — the fixes create new consolidation opportunities. The cycle reveals them.

**What was consolidated 2026-08-24:**
- Model registries: 3 → 1 (model_registry.py)
- Decimal coercion: 7 → 1 (common/decimals.py)
- Extended price computation: 3 → 1 (model save)
- Transaction views: 9 files → 3 (transaction_views.py, actions.py, unified.py)
- Utility functions: 10 copies → 3 shared modules

**Open for next cycle:**
- Serializer consolidation (3-4 per model → 1)
- Tax computation overlap

---
name: No scalar fallbacks — fail visibly
description: When JSON envelope data is missing, error/show nothing — never fall back to scalar fields silently
type: feedback
---

When JSON envelope data is missing (e.g., totals.total is null), the system must fail visibly — not fall back to scalar fields.

**Why:** Bill corrected the initial approach of "JSON first, scalar fallback." Scalar values can be stale. Silent fallbacks hide data integrity problems. Users must see the gap so it gets fixed, not papered over.

**How to apply:**
- Backend: log error and return empty/refuse to proceed (terms_ledger pattern)
- Frontend: render nothing if `record.totals?.total` is undefined — no `?? record.total` fallback
- Print docs: show blank where totals envelope is missing
- This applies to ALL financial fields across ALL models
- Established 2026-08-22 as "json.thinking" — one behavior everywhere

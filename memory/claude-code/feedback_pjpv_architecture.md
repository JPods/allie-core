---
name: PJPV architecture
description: Pydantic JSON Path Value — the four-layer discipline for all calculations; never flatten envelopes; one engine, one path
type: feedback
---

PJPV — Pydantic JSON Path Value. The fundamental architecture requirement governing all data behavior across WC3.

PJPV is the complete data behavior stack — not just envelope discipline, but the entire chain of how data behaves from schema to screen:

1. **Typing** — Pydantic declares field types (Decimal, int, str, bool, List). The field knows what it is.
2. **Formatting** — Pydantic schema carries currency, percentage, date format rules. Display is a property of the field, not the component.
3. **Labels** — field_info.title, description. The field names itself, not the UI.
4. **Values** — JSON envelope is the source of truth. One place, one engine writes it.
5. **Calculations** — All computed values resolve through paths (totals.margin, price.extended). Never independent local computation.

This is why DynamicDetail works with ~1,759 lines instead of 45K. The component doesn't need to know what it's rendering — PJPV tells it: type, format, label, value, calculation path. The component resolves the path and renders.

**Why:** Found stale scalar bugs 2026-08-22 — serializers were extracting `total_amount`/`margin_amount` from JSON envelopes into top-level fields. React read the scalars instead of the envelope. Two functions computing the same value, one wrong. Research confirmed: every successful open-source commerce project (Saleor, Medusa, Invoice Ninja, Odoo, ERPNext) passes nested JSON intact. None flatten.

**How to apply:**
- Serializers pass envelopes intact (totals, sell, cost, finance). Never extract into top-level scalars.
- One totals engine computes all values. Denormalized scalars (total, balance) are indexes for queries, never authoritative.
- React resolves via path: `data?.totals?.total`, `data?.totals?.margin`. Column definitions use `accessorKey` from Settings/schema.
- If two functions compute the same value, consolidate immediately.
- Selection-aware subtotals (filtered line subsets) are legitimate local computation — label as partial sums.
- Commission visibility: remove field entirely for non-staff, don't mutate envelope contents.

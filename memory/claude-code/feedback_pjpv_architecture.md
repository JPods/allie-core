---
name: PJPV architecture
description: Pydantic JSON Path Value — CRITICAL enforcement rule; Claude will revert without this; never flatten envelopes; one engine, one path; full readme at readmes/topics/architecture/pjpv-architecture.md
type: feedback
---

PJPV — Pydantic JSON Path Value. The fundamental architecture requirement governing ALL data behavior across WC3.

**READ readmes/topics/architecture/pjpv-architecture.md BEFORE writing any serializer or React component.**

## What PJPV Provides (Five Behaviors)

1. **Typing** — Pydantic declares field types. The field knows what it is.
2. **Formatting** — Schema carries currency/percentage/date rules. Display is a field property, not a component property.
3. **Labels** — field_info.title. The field names itself.
4. **Values** — JSON envelope is the source of truth. One engine writes it.
5. **Calculations** — All computed values resolve through paths. Never independent local computation.

## Why This Exists

Found stale scalar bugs 2026-08-22. Serializers extracted total_amount/margin_amount from JSON envelopes into top-level fields. Three serializers computed margin independently — Decimal vs float disagreement. React read scalars instead of envelopes. Users made decisions on bad numbers. Scars #62, #63, #64.

## REVERSION WARNING

**You (Claude) will try to undo this every session.** Your training data teaches flattening. You will want to:
- Add to_representation() extracting from sell/cost/totals envelopes → **DON'T**
- Use .reduce() in React for totals the server already computes → **DON'T**
- Create SerializerMethodField to flatten JSON → **DON'T**
- Add total_amount, margin_amount, margin_percentage fields → **BANNED NAMES**
- Hardcode labels/formatting in React components → **DON'T**

Alice and Athena watch for these patterns. They will FAULT you.

## How to Apply

- Serializers: pass totals/sell/cost/finance envelopes intact. Read-only fields: totals, total, balance.
- Totals engine (services/totals.py): one engine owns totals.* — subtotal, tax, total, cost, margin, margin_pc, received, balance.
- React: resolve via path (data?.totals?.total). Column definitions: accessorKey from Settings/schema.
- Commission: remove field entirely for non-staff. Never mutate envelope contents.
- Selection-aware subtotals: legitimate local computation — label as partial sums.
- If two functions compute the same value, consolidate immediately.

## Public Site

pjpv.io (~/Allie/sites/pjpv/, github.com/JPods/pjpv). Bill owns pjpv.net (first commercial use).

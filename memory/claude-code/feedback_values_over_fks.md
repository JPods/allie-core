---
name: BigInt default, FK only for true parent-child
description: FK authority is actively being reduced — BigIntegerField is the default for relationships; FK only when cascade deletion is correct (order→line); refs.links for user-defined associations
type: feedback
---

BigIntegerField is the default relationship field in WC3. ForeignKey is the exception, not the rule.

**Why:** FK cascade is destructive and often wrong. Deleting a customer should NOT delete contacts who may be independently valuable. Deleting an order should NOT delete serial-numbered items already sold and delivered. FK enforces a parent-child lifecycle that doesn't match reality for most business relationships. BigInt is more forgiving — the relationship exists but neither record owns the other's lifecycle.

**When FK IS correct:**
- Order → OrderLine (line has no meaning without the order)
- Invoice → InvoiceLine (same — structural parent-child)
- BillOfMaterial → parent Item (compositional)
- Touch → Contact (touch is a log entry OF the contact)

**When FK is WRONG (use BigIntegerField):**
- Customer → Contact (contact survives independently)
- OrderLine → Serial (serial survives delivery, warranty, resale)
- Action → Contact (action may outlive the contact relationship)
- Any relationship where either record has independent value

**Three relationship tiers:**
1. **FK** — true parent-child, cascade is correct, DB-enforced
2. **BigIntegerField** — structural reference, no cascade, record survives independently
3. **refs.links** — user-defined associations, no schema change needed, any record to any record

**How to apply:** Default to BigIntegerField for new relationship fields. Use FK only after confirming cascade deletion is wanted. Use refs.links for ad-hoc relationships the user creates at runtime. The panel hamburger "assign" writes refs.links. Never add a FK "just for referential integrity" — the integrity cost of cascade is higher than the cost of an orphaned integer.

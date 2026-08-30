---
name: refs.links authority depends on tier
description: refs.links are cache for FK/BigInt relationships but ARE authoritative for user-defined associations with no schema field
type: feedback
---

refs.links serve two roles depending on the relationship tier:

1. **For relationships that have a schema field (FK or BigIntegerField):** refs.links are a denormalized cache. The schema field (FK or BigInt) is authoritative. If refs disagree, the schema field wins. `audit_fk_values` detects drift.

2. **For user-defined associations (no schema field):** refs.links ARE the authoritative source. When a user clicks "assign" in a panel hamburger to link a contact to a GL journal entry, refs.links is the only place that relationship exists. There is no FK or BigInt field to defer to.

**Why:** The three-tier relationship model (FK → BigInt → refs.links) means refs.links is not uniformly secondary. It's secondary for Tier 1 and Tier 2 relationships, but primary for Tier 3.

**How to apply:** When writing code that creates or updates relationships:
- Tier 1 (FK): set FK, update refs as secondary cache
- Tier 2 (BigInt): set BigInt field, update refs as secondary cache  
- Tier 3 (user-defined): write directly to refs.links — it IS the relationship
- When reading: for Tier 1/2, query via schema field; for Tier 3, query refs.links

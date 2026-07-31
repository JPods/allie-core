---
name: Schema review cycle — Alice catches bad patterns before they spread
description: Every Alice flags schema changes to WC_HQ; quarterly forced admin review prevents atrophy; Pydantic schemas are the contract
type: feedback
---

Schemas and system settings atrophy without forced review. Nobody looks at them voluntarily.

**Why:** Bill: "these records will be so seldomly looked at awareness will atrophy." One installation puts a key in the wrong JSON envelope. If unchecked, 50 installations copy the pattern. The cost of cleaning 50 installations is 50x the cost of catching it at one.

**How to apply:**
- Every schema change → local Alice flags → WC_HQ reviews → corrected schema syncs to all
- Quarterly forced review actions in System Maintenance project (#31062) — Alice re-creates when closed
- Overdue actions escalate to admin dashboard at 7 days
- Schema map Setting (schema_map:wc) is the single registry Alice reads
- "Some choices will be good, some a convention we fix on, some only retrospection will reveal" — version-stamp everything, measure at review time

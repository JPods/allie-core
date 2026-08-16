---
name: Double confirm on destructive actions
description: All record deletes and Complete Order require two confirmation dialogs; bulk deletes require two confirmations
type: feedback
---

Single record delete = 1 confirmation. Bulk deletes (multiple records) = 2 confirmations. Complete Order = 2 confirmations (locks the record).

**Why:** Accidental deletes and premature order completion are irreversible. Bill established this as a fixed rule 2026-08-16. Single record is recoverable enough for one confirm; bulk and lock operations need the extra gate.

**How to apply:** Single `deleteRecord()` = one confirm. Bulk delete = two confirms. `complete_order` workflow = two confirms. CommCard/CommPanel deletes = two confirms (they delete child records which are harder to recover).

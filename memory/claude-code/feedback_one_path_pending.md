---
name: One path — ALL inventory and cash changes go through pending records
description: Every inventory quantity change and every payment/cash change creates a pending record first. Applied immediately if unlocked, queued if locked. One path, one audit trail, no exceptions.
type: feedback
---

TWO domains, same pattern:
1. **Inventory:** Every item.quantity change → PendingInventoryAdjustment → apply if unlocked
2. **Cash:** Every payment application → PendingPaymentApplication → apply if unlocked

No direct writes to item.quantity. No direct writes to invoice.balance. Always pending first, then apply.

**Why:** One path = one audit trail = one place to debug = one place to add rules. If you have two paths (direct + pending), bugs hide in the path without audit trail.

**How to apply:** 
- inventory_pending.py adjust_item_quantity() is the ONLY function that touches item.quantity
- All inventory services (receive, consume, ship, order, propose) call adjust_item_quantity()
- Payment services must do the same: create pending payment app → apply if invoice not locked
- Test Dashboard shows pending records with original/applied counts

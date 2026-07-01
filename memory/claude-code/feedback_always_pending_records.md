---
name: Inventory updates ALWAYS go through pending records — one path
description: Every inventory change creates a PendingInventoryAdjustment first. If item unlocked, apply immediately. If locked, queue. One path, no exceptions.
type: feedback
---

Inventory updates ALWAYS create a PendingInventoryAdjustment record first. There is no direct write to item.quantity.

**The one path:**
1. Transaction creates a PendingInventoryAdjustment (qty, reason, source)
2. System checks: is item.is_locked?
3. If unlocked → apply immediately (update item.quantity, set state='applied')
4. If locked → leave as state='pending', apply when unlocked

**Why:** One path means one audit trail, one place to debug, one place to add rules. If services write directly to item.quantity sometimes and through pending other times, you have two paths — two places for bugs, no audit trail on the direct path.

**How to apply:** The inventory services (receive_inventory, consume_inventory in inventory_stacks.py) must create PendingInventoryAdjustment records instead of modifying item.quantity directly. The PendingInventoryAdjustment.apply_now() method handles the actual item.quantity update. The Test Dashboard shows pending records with original/applied counts.

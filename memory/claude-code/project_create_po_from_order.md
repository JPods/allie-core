---
name: Create PO from Order workflow
description: Select order lines → Create PO; groups by vendor_id; items without vendor go to single unassigned PO
type: project
---

Create PO from Order — separate plan needed.

**Workflow:**
1. User selects lines on an Order
2. Clicks "Create PO" (action button on left toolbar)
3. For each selected item WHERE `vendor_id` is specified: adds item + `quantity_ordered` to a PO for that vendor (groups by vendor)
4. For each selected item WHERE `vendor_id` is NOT specified: adds item + `quantity_ordered` to a single unassigned PO

**Result:** One or more Purchase Orders created, each with the appropriate lines and quantities. Vendor-specific POs are grouped. Unassigned items go to one catch-all PO.

**Why separate plan:** This is an Order → Purchase workflow, not a line card behavior. It involves creating new transaction records, transferring quantities, and managing vendor grouping logic. Separate from the line card column/panel work.

**How to apply:** Build after the line card baseline is complete. The "Create PO" button will be on the left toolbar of the Order line card (action button category), but the workflow logic is its own implementation.

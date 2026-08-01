---
name: QuickQuote is a separate window/process
description: QQ is not a panel — it's its own window; any transaction can push/pull; needs separate plan
type: project
---

QuickQuote (QQ) is NOT a show/hide panel within the line card. It is a separate window in its own process.

**Push/Pull model:** Any line-controlling model (proposal, order, invoice, purchase, workorder, requisition) can push items TO QQ or pull items FROM QQ. QQ acts as a cross-transaction clipboard/staging area.

**Example workflow:** User is in an Order, needs to purchase items → pushes them to QQ → opens a Purchase Order → pulls from QQ into PO lines.

**Why:** QQ needs to persist across transaction windows. It's not bound to a single transaction — it bridges them.

**How to apply:** QQ gets its own plan. Do not include QQ as a panel in the line card plan. The line card has a "QQ Push" button (push selected lines to QQ) but the QQ window itself is separate.

---
name: WebClerk is commerce, not accounting
description: WC3 focuses on sales/operations/inventory/collections, produces GL journal entries for accounting programs to consume; never build P&L/Balance Sheet/Trial Balance
type: feedback
---

WebClerk manages commerce operations. Accounting programs manage administration. The boundary is the GL Journal entry.

**WebClerk's domain:** Sell (proposal→order→invoice), collect AR (operations, not accounting), buy (PO→receiving), manage inventory, produce GL journal entries by account code.

**Accounting's domain:** Consume GL entries, manage AP, produce financial statements (P&L, Balance Sheet, Cash Flow, Trial Balance), file taxes, close periods.

**Why:** wc2 has always worked this way. Collecting receivables is finishing the sale — it's a commerce function. Paying vendors is an accounting function. WebClerk focuses on delivering value; accounting programs focus on administration.

**How to apply:** Never build P&L, Balance Sheet, Trial Balance, Cash Flow, or AP Aging in WebClerk. Build sales reports, operations reports, collections reports, inventory reports. The GL Journal Export is the primary accounting handoff — it must be clean, complete, and importable by QuickBooks/Xero/Sage/any program. When suggesting reports, ask: "Is this commerce or accounting?" If accounting, it's not our job.

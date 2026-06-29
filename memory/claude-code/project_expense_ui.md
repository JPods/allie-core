---
name: Expense/disbursement UI
description: Payment model extended with type (received/disbursed) + purchase FK; needs fast spreadsheet-style entry UI for expenses
type: project
---

Payment model now handles both AR (received) and AP (disbursed) via `type` field + `purchase` FK. Migration 0007 applied 2026-06-28.

**Why:** No separate expense table. One model, one reconciliation flow, one GL posting path. Alice tracks one model.

**How to apply:** Build a spreadsheet-style entry UI for fast expense entry — inline editing, tab between cells, bulk entry. Similar to how wc2 handled rapid data entry. This is the next UI task after DataBrowser stabilizes. The Apply Payments page could get a tab or toggle for received vs disbursed views.

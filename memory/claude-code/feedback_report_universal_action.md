---
name: Report is universal action model
description: Report records are not just print — they handle printing, executables, exports, apply-to-selection, updates, and many other actions
type: feedback
---

Report is the universal action model. Print is just one output type. The Report record's `config` holds whatever that action needs — a print layout, a manage action to call, an export format, a bulk update spec. The Report dropdown is the action menu for any record.

**Why:** Bill explicitly stated "Report is for printing, executables, exports, apply to selection, update and many other actions." This is the architecture — not a print-only tool.

**How to apply:**
- `Report.config.action` = manage action name to call
- `Report.config.confirm` = confirmation message
- `Report.config.params_from_record` = map of param→record field
- `DetailToolbar.handlePrintSelect` dispatches action-type reports via `manageAction`
- `PrintReportDropdown` now fetches ALL report types (removed `output_type:'print'` filter, excludes `screen`)
- Categories include: `customer_facing`, `operations`, `form`, `report`, `function`, `vendor_facing`, `admin_tool`, `utility`, etc.
- Unknown categories show at end (fallback added)

Example: Report id=459 `journalize-inv-pay` — category=operations, config.action=journalize_invoice_and_payments

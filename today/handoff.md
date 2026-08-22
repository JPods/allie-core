# Handoff — 2026-08-22 (Session 2: Flight Simulator + GL Journalize)

## Where We Left Off

Flight simulator 3-section layout working with audit mode. Fixed order→invoice conversion, GL journalization of payments, and PrintReportDropdown categories.

## What Was Done

### 1. Fixed conversion.py — order→invoice 500 error
- `_get_model()` in `apps/transactions/services/conversion.py:83` missing `"payment"` in name_map
- **Fix:** Added `"payment": "Payment"` to the dict

### 2. Flight Simulator 3-Section Left Panel
Three vertically-stacked resizable sections with drag handles (rename pending: Inventory→Counts, Payments→Money):
- **Inventory/Counts** — on_hand, on_so, on_po, on_p, available, pending deltas
- **Payments/Money** — amount, applied, available, status, payment applications
- **GL Journals** — DR/CR by account, batch, source document

Files: `inventory_flight_sim.py` (backend), `FlightSimConsole.tsx` + `.css` (frontend)

### 3. Audit Mode
Input field on sim select screen → type invoice number → full Counts/Money/GL picture.
Backend: `get_flight_by_invoice` manage action with flexible ida lookup (exact, numeric, partial).
Falls back to JSON `item.item_id` when `item_fk_id` is null.

### 4. Journalize Invoice + Payments (one click)
- `journalize_invoice_and_payments()` in `journalize.py` — journals invoice AND all linked payments
- Report record id=459 category=operations — appears in Report dropdown
- `DetailToolbar.handlePrintSelect` dispatches action-type Reports via `config.action`

### 5. Fixed journalize_payment crash
Payment has NO `dt_journaled` — uses `is_locked` + `dt_processed` (DateTimeField, `timezone.now()`)

### 6. Fixed PrintReportDropdown
- Added missing categories (`customer_facing`, `operations`, `function`, `vendor_facing`)
- Removed `output_type:'print'` filter — Report is universal action model
- Added fallback for unknown categories

## What's Open

1. **Rename sections** — Inventory→Counts, Payments→Money
2. **Invoice line save not persisting** — UI returns 200 but InvoiceLine records not created for DEV-105
3. **Locked records → read-only form** — `is_locked=True` should disable editing
4. **Bill's insight:** Flight simulator as audit tool — "Users enter invoice number and see into inventory, cash, and journals. Incredible audit tool."

## Key Architecture
- **Report = universal action model** (not just print). config.action dispatches manage actions.
- **3 domains every transaction touches:** Counts (physical), Money (financial), GL (accounting)

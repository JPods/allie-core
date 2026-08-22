# Handoff — 2026-08-22

## Where We Left Off

Payment lifecycle session complete. Flight simulator built, AddPaymentModal redesigned, Payment model has parent_id/parent_model, total/balance sync bug fixed across all 5 transaction models (Bill refactored into TransactionBaseModel), PendingPaymentApplication removed from registry, commercial trust principle established and documented.

Bill asked: "Should we review the entire application to assure alignment between the model, the JSONs, services, etc?" — deferred to next session (compression risk).

## Do This First Next Session

### 1. Full Model/JSON/Service Alignment Review
Systematic audit triggered by the total/balance sync bug:
- Every transaction model: JSON envelope fields match what services read/write
- Every denormalized scalar (total, balance) synced by compute engine
- Every service reads from JSON (source of truth), not scalars
- Bill already did json.path.value compliance scrub (Scars #62-64, 12 fixes) — verify nothing was missed
- Check per-model totals files (`invoice_totals.py`, `order_totals.py`, etc.) — Bill noted they're archive candidates

### 2. Invoice line extended not recalculating on qty change
Bill changed qty 6→5 in DataBrowser UI. Footer showed $349.95 (client-side correct) but saved line kept `price.extended=419.94`. Backend `transaction_save` service verifies but doesn't correct. Must recalculate `extended = qty × unit_price` on save.

### 3. Chrome DevTools MCP
Added to `.mcp.json` but Chrome needs restart with `--remote-debugging-port=9222`. Bill wanted to watch payment→GL flow in browser.

### 4. Carried from 8/21
- Wrong columns in databrowser list (inventory fields on wrong model)
- Touch Setting format mismatch (`form.default.sections` vs `detail.default`)

### 5. Migration graph conflicts
`makemigrations --merge` fails. Payment `parent_id`/`parent_model` added via SQL, not migration.

## Open Problems

- `PendingPaymentApplication` table still exists — drop after migration cleanup
- `update_order_received` signal still scans by refs instead of `parent_model`/`parent_id`
- Flight simulator line grid spacing needs tightening
- Unused per-model totals files: `invoice_totals.py`, `order_totals.py`, `proposal_totals.py`, `purchase_totals.py`, `po_totals.py`, `wo_totals.py`

## Key Decisions Made

| Decision | Why |
|----------|-----|
| `Payment.parent_id/parent_model` = origin, not constraint | Payment entered on order is available to any customer document |
| `available != 0` not `> 0` | Commercial: negative = customer shortage carried forward |
| Dismiss = separate write-off payment | Different GL account from discount; discount = invoice line item |
| Conversion forwards payments, doesn't auto-apply | User exercises judgment — trust-based flexibility |
| JSON envelope is single source of truth | Scalars are indexes; one compute engine syncs both |
| PendingPaymentApplication removed | Dead model; all applications use core.Pending with purpose='payment_application' |

# Handoff — 2026-08-22

## What Was Done (2026-08-22 session)

### Payment Lifecycle — Major Session

**Flight Simulator (react-alice)**
- Created `/simulator` page with 6-step payment lifecycle walkthrough
- Right panel: model/ida selector (Order, Invoice, Proposal, Payment, Pending)
- Left panel: step controls + two impact panels (Inventory Impact, Payment Impact) + flight log
- Line item panel column order: × | Qty | Unit Price | IDA | Description | On Hand

**AddPaymentModal (React2025) — Redesigned**
- Balance Due field (left) + Amount field (right) — side by side
- Default amount = balance due (reads `totals.received` from JSON envelope)
- "Dismiss balance — too little value to chase" checkbox (creates write-off payment)
- Discounts removed from payment dialog — entered on invoice directly
- Available Payments panel shows for orders AND invoices
- Shows ALL customer payments where `available != 0` (not > 0)
- Source column labels origin: Customer, Order #N, Inv #N
- Payments entered on current document highlighted green
- Now sets `customer_id` and `parent_id/parent_model` on new payments

**Payment Model — parent_id/parent_model Added**
- `parent_id` (BigInteger) + `parent_model` (CharField) — where the payment was entered
- Values: `order`, `invoice`, `customer`, `purchase`
- Origin, NOT a constraint — payment available to any document for that customer
- SQL columns added, existing payments backfilled from `refs.source`
- DB migration not created (migration graph has conflicts) — columns added via SQL

**Major Bug Fixed — update_sell_cost_totals**
- All 5 transaction models (Invoice, Order, Proposal, Purchase, WorkOrder) updated `self.totals` JSON but never synced `self.total` and `self.balance` denormalized columns
- Bill refactored: moved `update_sell_cost_totals` to `TransactionBaseModel` — all models inherit it, one engine
- JSON envelope is single source of truth; scalars are indexes

**Order → Invoice Conversion**
- Payments with `parent_model='order'` forwarded to new invoice
- `invoice_id` set, `refs.invoice_ids` updated
- Payments NOT auto-applied — user exercises judgment
- Invoice `totals.received` and `balance` updated

**PendingPaymentApplication Removed**
- Dead model at `apps/transactions/models/pending_payment.py`
- Removed from `__init__.py` registry so Django doesn't register it
- All real payment applications use `core.Pending` with `purpose='payment_application'`
- Table `pending_payment_applications` can be dropped later

**Signal: update_order_received**
- New post_save signal on Payment
- When payment references an order, updates `order.totals.received` and `order.balance`
- Uses `Order.objects.filter().update()` to avoid version conflicts

**Commercial Trust Principle — Documented**
- Negative `available` = customer shortage from prior transaction (they owe us)
- Example: owed $400, paid $350, available = -$50, liquidated with next payment
- System shows everything, user exercises judgment
- Retail hides negatives; commercial shows them
- Alice taught: consistent short-payment + liquidation = normal pattern; break in pattern = anomaly

**Documentation**
- `webClerk3/readmes/topics/payments.md` — full payment lifecycle readme
- Allie taught payment lifecycle design + commercial trust principle
- Alice taught pattern recognition rules for payment behavior

---

## What Was Done (2026-08-22 parallel session — architecture + compliance)

### Init Bundle — New Database Seed
- `pack_init_bundle` / `unpack_init_bundle` commands: 85 Settings + 52 Reports → `init-bundle.json`
- All records stamped `metadata.foundational: true` — external bundles CANNOT modify
- New database startup: `python manage.py unpack_init_bundle`

### Single Source of Truth — wc:model Setting
- `useListFieldConfig.ts` reads from `wc:model` → `config.layout.list.default.columns`
- `wc:workbench_fields` Setting is now redundant
- One Setting per model owns list, detail, and form layouts

### json.path.value Compliance Scrub (Scars #62-64)
- **Unbreakable rule:** All calculations are json.path.value based. JSON envelope is the ONLY source of truth.
- **Backend (6 fixes):** payment_pending, signals, campaign_roi, conversion, rebate_accrual — removed all scalar fallback patterns
- **Frontend (6 fixes):** TabsRenderer (no .reduce()), AddPaymentModal (reads totals.received), LineCardRenderer/DetailToolbar/TransactionDetail (no data?.balance), ActionDailyDashboard

### Dark Mode Fix
- `useLineCard.ts` theme uses CSS variables; `LineCardRenderer.tsx` totals bar all has dark: variants

### Unused per-model totals files
- `invoice_totals.py`, `order_totals.py`, `proposal_totals.py`, `purchase_totals.py`, `po_totals.py`, `wo_totals.py` — no longer called, archive candidates

### Chrome DevTools MCP added to `.mcp.json`
- Needs Chrome restart with `--remote-debugging-port=9222`

---

## URGENT — Next Session

### 1. Chrome DevTools + Payment-to-GL Flight Simulator
- Chrome needs restart with debug port for DevTools MCP to connect
- Bill wants to walk through payment creation → GL journal entry, watching each step in browser

### 2. Invoice line extended not recalculating on qty change
Bill changed qty from 6 to 5 — footer showed $349.95 (correct client-side) but saved line still had `price.extended=419.94`. Backend must recalculate `extended = qty × unit_price` on save.

### 3. Wrong columns in databrowser list (carried from 8/21)
- Inventory fields (.on_hand, .on_p) showing on wrong model in databrowser

### 4. Touch Setting format mismatch (carried from 8/21)
- Setting has `layout.detail.default` but `useDetailLayout` reads `form.default.sections`

### 5. Migration graph conflicts
`makemigrations --merge` fails — conflicting leaf nodes. Needs manual resolution.

---

## Key Files Changed

| File | What |
|------|------|
| `react-alice/src/pages/Simulator.tsx` | NEW — flight simulator page |
| `react-alice/src/App.tsx` | Added /simulator route |
| `react-alice/src/components/Sidebar.tsx` | Added Simulator nav item |
| `React2025/src/apps/transactions/components/AddPaymentModal.tsx` | Redesigned — balance, dismiss, available payments |
| `webClerk3/apps/transactions/models/payment.py` | Added parent_id/parent_model |
| `webClerk3/apps/transactions/models/invoice.py` | Bill refactored — totals in base |
| `webClerk3/apps/transactions/models/order.py` | Bill refactored — totals in base |
| `webClerk3/apps/transactions/models/proposal.py` | Bill refactored — totals in base |
| `webClerk3/apps/transactions/models/purchase.py` | Bill refactored — totals in base |
| `webClerk3/apps/transactions/models/workorder.py` | Bill refactored — totals in base |
| `webClerk3/apps/transactions/models/__init__.py` | Removed PendingPaymentApplication |
| `webClerk3/apps/transactions/services/conversion.py` | Payment forwarding on order→invoice |
| `webClerk3/apps/transactions/services/payment_pending.py` | discount_amt param, discount line |
| `webClerk3/apps/transactions/signals.py` | update_order_received signal |
| `webClerk3/apps/core/views/manage_view.py` | discount_amt in dispatch |
| `webClerk3/readmes/topics/payments.md` | NEW — payment lifecycle readme |

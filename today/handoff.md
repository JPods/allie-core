# Handoff — 2026-08-01 (Session 4)

## Where We Left Off
TransactionDetail at `/td/order/34` is rendering with real data — JPods LLC, Bill James, 3 lines, three-column Summary tab (Order Totals | Customer | Flow). Line card done: compact labels, no action column, no sidebar, footer buttons (L/S/XR/M/D), selection-aware totals (Deposit/Backlog/Total with hover for tax+shipping), alternating rows, single-click editing, keyboard shortcuts. Summary tab shows payments (PMT-501) and invoices (INV-101 $2,163 with $1,052 unapplied) in the Flow column. Customer defaults service written but not yet wired to frontend. `company` field added to TransactionBaseModel and migrated. Shopping cart at `/cart`. Flight log, shutdown script, and runserver.sh updated.

## Do This First Next Session
1. **Wire customer defaults** — when user selects customer via OrgSearchDialog, call `customer_defaults.py` to auto-populate company, phone, attention, address, price_level, terms, ship_via on the order. The service exists at `webClerk3/apps/transactions/services/customer_defaults.py` but isn't called from frontend yet.
2. **Fix transaction save 500** — `Pending` model has no `data` field. `line_item_service.py:1073` passes `data=pending_data` which fails. This blocks ALL saves. Pre-existing bug.
3. **Format epoch dates** — `dt_created` shows `1785601919164`. Need a date formatter in TransactionDetail's HeaderRenderer.
4. **Summary tab Customer column** — shows "Company: —" because it reads from `customer_config` not the denormalized `company` field. Quick fix.
5. **Seed all transaction layouts** — run `manage.py seed_detail_layouts` for all 7 types. Only order is seeded currently.

## Open Problems
- Transaction save 500 — Pending model missing `data` field. Blocks all saves from UI.
- Duplicate BB401_clone line on order 34 — data issue from SQL seeding (line_number=10 shared).
- `/td/` route in public routes (outside PrivateRoute) for debugging — move inside when stable.
- `useDetailLayout` cache doesn't invalidate on Setting update — needs hard refresh.
- Summary tab Customer column reads from customer_config (fetch-time) not company (DB field).
- Auto-edit mode not implemented yet — Action #31096 tracks user preferences for next sprint.

## What Was Decided (and Why)
- **`company` denormalized on TransactionBaseModel** — avoids FK lookup for every render. The order carries the company name; no need to fetch the org record just to display it.
- **Three-column Summary: This document | This customer | The flow** — Bill's framework. One glance answers: how much is the order, can this customer pay, what's been invoiced/paid. No tab switching.
- **Payments over Invoices in Flow column** — payments are the action (money in), invoices are the documents. User cares about "what came in" before "what went out."
- **Post or Pend** — universal edit rule. Open=post now, journalized=pend, closed=no edit. Three-tier `edit_rules` in layout JSON.
- **All adjustments are line items** — negotiated/forced price changes are lines with negative amounts. Posts to discount GL. Never adjust totals directly.
- **D button** — bulk discount dialog. Enter %, applies to selected or all lines. In footer next to L/S/XR/M.
- **Professional edit mode** — single click to edit, tab through fields, no double-click protection. Auto-edit preference noted for next sprint.
- **Flight log** — session recorder. Clean shutdown clears it. Crash leaves it for next session to recover. `scripts/flight-log.py`.
- **Shutdown script** — `scripts/shutdown.sh` sends SIGTERM (triggers rightshoe) before stopping services.
- **runserver.sh updated** — starts Django + Celery + Ollama + React. Health checks for Allie/Alice/Ollama on startup.
- **n2support** — Alice help loop concept. Action #31093 to register domain by 2026-10-01.

## Files Changed This Session
- `webClerk3/apps/transactions/models/base_transaction_model.py` — Added `dt_needed`, `ship_via`, `company`
- `webClerk3/apps/transactions/migrations/0024-0026` — Migrations for dt_needed, ship_via, company
- `webClerk3/apps/transactions/services/customer_defaults.py` — New: populate order from customer
- `webClerk3/apps/core/choices.py` — `line_card_fields` Setting purpose
- `webClerk3/apps/core/management/commands/seed_detail_layouts.py` — Seed command for all layouts
- `webClerk3/apps/products/views/item_inventory_views.py` — Bulk inventory endpoint
- `webClerk3/apps/products/urls.py` — Wired bulk inventory endpoint
- `webClerk3/readmes/topics/transactions/order-detail.md` — Order detail behavior doc
- `webClerk3/readmes/topics/architecture/pending-flow-picture.md` — Post or Pend + Alice help loop
- `webClerk3/readmes/06-startup-shutdown.md` — Quick health check section
- `webClerk3/runserver.sh` — React + health checks + shutdown trap
- `React2025/src/apps/transactions/components/LinesCard.tsx` — Full refactor: columns, footer, panels, keyboard, responsive
- `React2025/src/apps/transactions/components/TransactionDetail.tsx` — JSON-driven renderer with 3-col header + Summary
- `React2025/src/apps/transactions/components/ShoppingCart.tsx` — Customer cart
- `React2025/src/apps/transactions/components/panels/*.tsx` — 4 panels (Inventory, Margin, Spec, XRef)
- `React2025/src/hooks/useDetailLayout.ts` — Layout Setting hook
- `React2025/src/apps/transactions/utils/lineHelpers.ts` — lineKey: id→line_number→idx
- `React2025/src/components/common/DataGrid.tsx` — Alternating rows
- `React2025/src/routes/Router.tsx` — `/td/` and `/cart` routes
- `~/Allie/scripts/flight-log.py` — Session flight recorder
- `~/Allie/scripts/shutdown.sh` — Graceful team shutdown
- `~/Allie/scripts/allie-api.py` — rightshoe signal handler + flight log clear
- `~/Allie/readmes/leftshoe.md` — rightshoe + flight log documentation
- `~/Allie/process/layout-iterations/` — Layout iteration log with JSON + screenshots

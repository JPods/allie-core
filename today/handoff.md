# Handoff — 2026-08-10

## Where We Left Off

Complete WC2 salvage sweep + 10 implementations in WC3. Dropped 2 over-engineered exchange rate models, replaced with Setting-based service.

## What Was Done

### WC2 Gap Fixes (6)
- **Terms cut-off day** — `terms_ledger.compute_schedule()`, no grace period
- **Consignment revenue skip** — `journalize.py`, status='consigned' skips GL
- **UOM divisor** — `line_item_service.py`, computed from UOM table
- **Partial-payment commission scaling** — `commission.py`, `scale_commission_on_payment()`
- **AR aging nightly** — `tasks.py`, paginated (was capped at 100 orgs), beat at 2:40 AM
- **Reorder velocity** — `suggest_purchase.py`, `compute_velocity_reorder_point()`

### New Features (4)
- **Alice dedup service** — `apps/ai_assistant/services/dedup_service.py`
  - Hard delete from DB, bundle files in `sync/dedup/pending/`
  - Indented list (BOM pattern) UI: copy_field, remove_from_bundle, mark_done
  - Claude escalation for complex cases
  - Connection: `conn-alice-dedup` (id=52)
  - Weekly Celery task Wednesdays 3:30 AM
  - Readme: `readmes/topics/ai/alice-dedup.md`

- **Order split by vendor + commission invoices** — `transactions/services/split_by_vendor.py`
  - 3-step tradeshow: split order → manufacturer fulfills → commission invoice
  - `split_order_by_vendor()` + `create_commission_invoice()`
  - Commission lines carry on_so like real inventory
  - Report records: "Split by Vendor" (id=439), "Commission Invoice" (id=440)
  - `line_type='commission'` added to base_line_model choices
  - `category='function'` added to Report choices

- **Exchange rates** — `apps/accounts/services/exchange_rates.py`
  - Dropped `ExchangeRate` and `ExchangeTransaction` models (over-engineered)
  - One Setting record (purpose='exchange_rates', id=642)
  - All amounts in base currency (like UTC), rate captured at transaction time
  - FX gain/loss at settlement via balancing Ledger record
  - Readme: `readmes/topics/architecture/exchange-rates.md`
  - Flowchart: `readmes/flowcharts/wc3-exchange-rates.dot/.pdf`
  - No UI until a customer needs it

### Migrations Applied
- `0017_add_commission_line_type_and_function_category` — across all apps
- `0018_drop_exchange_rate_and_exchange_transaction` — accounts

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| No grace period on terms cut-off | Cut-off is the cut-off. WC2 overthought it. |
| Consignment = status-based | `status='consigned'` skips journalize. Same as WC2. |
| Hard delete for dedup | Junk doesn't grow better with age. Bundle file is working space, not archive. |
| Reports as functions | `category='function'`, selected from report dialog, not buttons. |
| vendor_id only for split | No manufacturer_id branching. If manufacturer is vendor, use vendor_id. |
| Exchange rates in Setting | One JSON record replaces two models. Base currency like UTC. |
| Per-item campaign discount via catalogs | DynamicCatalogs handles upstream pricing, not WC3. |

## Next Steps

Bill plans to have a fresh Claude session do a second WC2 sweep:
1. Read WC2 `catalog.txt` (data model) to map tables → WC3 models
2. Read WC2 methods grouped by business flow, not alphabetically
3. Focus on business rules with conditions (the `if` statements)
4. Compare against WC3 for completeness
5. Give it today's retrospection so it doesn't rediscover our work

The real completeness test is behavioral, not structural — watch real transactions flow through WC3 and flag where results differ from WC2.

## Files Changed

### WC3 — New
- `apps/ai_assistant/services/dedup_service.py`
- `apps/transactions/services/split_by_vendor.py`
- `apps/accounts/services/exchange_rates.py`
- `readmes/topics/ai/alice-dedup.md`
- `readmes/topics/architecture/exchange-rates.md`

### WC3 — Modified
- `apps/accounts/services/terms_ledger.py` — cut-off day logic
- `apps/accounts/services/journalize.py` — consignment skip
- `apps/accounts/services/commission.py` — partial-payment scaling
- `apps/transactions/services/line_item_service.py` — UOM divisor
- `apps/products/services/suggest_purchase.py` — velocity reorder point
- `apps/support/scheduler/tasks.py` — AR aging pagination
- `apps/support/scheduler/registry.py` — aging + dedup beat entries
- `apps/ai_assistant/tasks.py` — dedup_scan_task
- `apps/transactions/models/base_line_model.py` — commission line_type
- `apps/core/models/report.py` — function category
- `apps/accounts/models/__init__.py` — removed exchange imports
- `apps/accounts/admin.py` — removed exchange admin
- `apps/core/constants/model_registry.py` — removed exchange entries
- `apps/core/utils/model_name_resolver.py` — removed exchange mappings
- `readmes/topics/ai/alice-toolkit.md` — added services TOC

### WC3 — Deleted
- `apps/accounts/models/exchange_rate.py`
- `apps/accounts/models/exchange_transaction.py`

### Allie
- `readmes/retrospections/2026-08-10.md`
- `readmes/flowcharts/wc3-exchange-rates.dot` + `.pdf`

## DB Records Created
- Report "Split by Vendor" (id=439)
- Report "Commission Invoice" (id=440)
- Connection "Alice Dedup" (id=52, ida=conn-alice-dedup)
- Setting "Exchange Rates" (id=642, purpose=exchange_rates)

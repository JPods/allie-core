# Handoff — 2026-08-02 (Final)

## Where We Left Off
Four transaction types rendering from the same components: order, proposal, invoice, purchase. TransactionDetail.tsx refactored from 1557 lines into 8 single-purpose files in `detail/`. Each model has a `detail_layout` Setting that drives rendering — no code changes per model. Purchase uses `exec` family (cost columns instead of price). Print view works as standalone HTML window. Customer keyword search with comma-AND, pipe-OR fragments. Currency precision from company bootstrap. Save works after fixing Pending `data→config` (3 files: ledger_balance, bill_of_material, financial_maintenance) and audit log null user_agent. All pushed to `bill_dev` on both repos. Also drafted Anthropic energy one-pager at `today/anthropic-energy-one-pager.md`.

## Do This First Next Session
1. **Add item to line card** — item search (keyword fragments like customer search), adds line with item pricing from price matrix. This is the primary workflow gap.
2. **Transaction flow** — order → invoice, order → PO. The "Order ▾" menu actions that create child documents with line transfer.
3. **Print template model-aware** — read column titles and sell/exec family from layout JSON instead of hardcoded order labels. Purchase prints "Customer" instead of "Vendor".
4. **Select lists for Terms, Status, Price Level** — add `options` arrays to layout JSON fields. Currently render as text inputs.
5. **Scrub dead .tsx files** — OrderDetail, InvoiceDetail, ProposalDetail, PurchaseDetail pages are replaced by TransactionDetail. Remove from `protectedRoutesConfig` imports.

## Open Problems
- Purchase print shows "Customer" and "Order" headers instead of "Vendor" and "Purchase" — print template is hardcoded to order layout
- Purchase line extended shows $0.00 — print reads `price.extended` not `cost.extended` for exec family
- `useDefaultCompany` retries on 401 in a loop — needs max-retry guard
- Invoice #68 ida is INV-101 but id is 68 — ida sequence diverged from id sequence
- Proposal/invoice customer fields empty on initial load when record has customer_id but no denormalized company/phone/attention — need to pull from customer on fetch
- Bulk edit header click needs more edge case testing
- `schema_map` purpose not in SETTING_PURPOSE_CHOICES — may need migration

## What Was Decided (and Why)
- **`modelName` passed as explicit prop** from Router and protectedRoutesConfig — URL params don't carry model name for `/:model/:id` routes. The prop is authoritative.
- **8 single-purpose component files** in `detail/` — HeaderRenderer, LineCardRenderer, TabsRenderer, FieldRow, CustomerSearch, TransactionToolbar, TransactionPrint, index.ts. Each does one thing. Orchestrator is 317 lines.
- **Pending `data` field renamed to `config`** — 5 files total fixed (transaction_save x2, keywords, ledger_balance, bill_of_material, financial_maintenance). CoreModel has `config`, not `data`.
- **Purchase layout uses `exec` family** — shows unit_cost column instead of unit_price/disc_price. Same LineCardRenderer, different column set driven by `family` field in layout JSON.
- **Conditions stored as pointer** `name|id|version` — no redundant text. Resolved at print time.

## Files Changed This Session
**React2025** (key changes):
- `src/apps/transactions/components/TransactionDetail.tsx` — 317-line orchestrator (was 1557)
- `src/apps/transactions/components/detail/` — 8 new files (FieldRow, HeaderRenderer, LineCardRenderer, TabsRenderer, TransactionToolbar, TransactionPrint, CustomerSearch, index.ts, README.md)
- `src/routes/Router.tsx` — modelName prop on MODELS routes, /kanban, /gantt, /signin
- `src/routes/protectedRoutesConfig.tsx` — modelName prop on all transaction detail routes
- `src/store/slices/companySlice.ts` — NEW: bootstrap Redux slice
- `src/api/wcapi.ts` — uuid/metadata/refs stripped from save, line stripping
- `src/api/auth.ts` — prefs in mapApiProfileToUser
- `src/hooks/useLineCard.ts` — currency precision, bulk edit
- `src/components/common/DataGrid.tsx` — formatting, italic calculated, header bulk edit, selection
- `src/layout/AppSidebar.tsx` — /kanban path

**webClerk3** (key changes):
- `apps/core/views/bootstrap_view.py` — NEW: /wcapi/bootstrap/
- `apps/core/models/audit.py` — null fix for user_agent/ip_address/id_session
- `apps/core/services/keywords.py` — phone normalization, FK fallback, data→config
- `apps/core/choices.py` — conditions_sales/purchase purposes
- `apps/transactions/services/transaction_save.py` — data→config
- `apps/accounts/services/ledger_balance.py` — data→config
- `apps/products/models/bill_of_material.py` — data→config
- `apps/orgs/services/financial_maintenance.py` — data→config
- `common/search_utils.py` — pipe OR, icontains for keywords
- Settings created in DB: detail_layout for order/proposal/invoice/purchase, keyword configs x16, conditions x5, schema_map, bootstrap company prefs

**Statement Sorter**: sticky headers, theme, CSV parser, PDF prompt, file log, folder drops — deployed to webclerk.com/sort

**Allie**: `today/anthropic-energy-one-pager.md` — distributed solar for AI compute pitch

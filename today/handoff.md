# Handoff — 2026-06-27 (FINAL — massive wc3 session)

## Where We Left Off

Completed Phases 1-6 of the wc2→wc3 translation plan plus orphan detection, accounting dashboard, and Alice training system. **85 tests passing** in `tests/task_2026_06_27.py`. All React pages compile clean. Allie has the full session dump in her memory.

## Do This First Next Session

1. **Run `./bin/python -m pytest tests/task_2026_06_27.py -v --no-cov`** — verify all 85 tests pass
2. **Run `./bin/python manage.py seed_training_data`** — creates zzitem + zzCustomer if not already seeded
3. **Run `./bin/python manage.py migrate accounts`** — migration 0009 (GlJournal source fields) may need applying
4. **Test React pages visually** — `/accounting` and `/training` are new pages, need visual verification
5. **BOM cost rollup** — next major feature, deferred to its own session
6. **Wire GL buttons in React** — TransactionToolbar has Post GL / Reverse GL props, need onPostGL/onReverseGL callbacks in InvoiceDetail and PaymentDetail

## Critical Files

| What | Where |
|------|-------|
| Session test runner | `tests/task_2026_06_27.py` (85 tests) |
| Translation plan | `readmes/wc2-wc3-translation-plan.md` |
| React audit | `readmes/react25-audit-results.md` |
| Full deliverables + test checklists | `readmes/session-2026-06-27-deliverables.md` |
| Price resolution | `apps/products/services/pricing.py` |
| Inventory availability | `apps/products/services/inventory_availability.py` |
| Cross-reference lookup | `apps/products/services/xref_lookup.py` |
| Training flow | `apps/transactions/services/training_flow.py` |
| Accounting dashboard | `apps/accounts/services/accounting_dashboard.py` |
| Orphan detection | `apps/core/services/orphan_detection.py` |
| GL posting/reversal | `apps/accounts/services/ledger_balance.py` (post_staged_gl_entries, reverse_gl_entries) |
| Manage actions | `apps/core/views/manage_view.py` (7 new actions) |

## Architecture Decisions (non-obvious — future Claude will reverse without these)

- **GL posting is user-initiated** — records editable until journalized; after that only reversals
- **Tax/shipping are fixed values** — not calculated; API providers deferred
- **Import = External Mandated** — zero import code in wc3
- **Backend is source of truth** — React submits, server validates and wins
- **refs/metadata secondary to PKs** — denormalized cache; FK wins on conflict
- **Pending = inventory mechanism** — not direct reservation
- **reserve_inventory_for_order() is visibility aid** — adjusts available, not on_hand
- **Staff authority via RBAC** — negative qty, price_level, cost visibility
- **Test against PostgreSQL** — SQLite JSON/FK differences waste time
- **"zz" prefix for training** — zzitem, zzCustomer filterable from reports
- **Alice owns training** — action records per user, tracks completion, refines lessons
- **Alice needs her own LLM** — not just notes; full agent with memory building

## Next Morning Priority

**Generic ModelDetail → DataBrowser pattern** — wc2 had a DataBrowser (`Project_WebClerk/Sources/Forms/DataBrowser/`) that is the north star for what AdminWorkbench should become. Key features to replicate:

- **Saved views** (pu_viewsList/Entry) — field sets per table per user/role → already have `workbenchFieldsSetting` as foundation
- **Dynamic form builder** (b_BuildEntry_o) — renders inputs from schema → `getModelDetail()` provides the field list
- **Query builder** (bQuery) — structured queries beyond text search
- **Subset operations** (bSubsetShow/Omit) — include/exclude from current result set
- **JSON field configs** (b_jsonEntry_o/b_jsonList_o) — field order, visibility, input types stored as JSON

**IMPORTANT:** Admin-managed models do NOT get their own list/detail pages. No dedicated React pages for GLAccount, Setting, Currency, Warehouse, etc. Those are accessed through the DataBrowser/AdminWorkbench only. Dedicated React pages are only for **user-facing** models: Customer, Order, Invoice, Item, Contact, Proposal, etc.

Step 1: Enhance AdminWorkbench into the DataBrowser — dynamic form builder, saved views, query builder.
Step 2: Remove the 25+ shell admin detail pages (they were wrong — shouldn't exist as separate pages).
Step 3: DataBrowser becomes the single admin tool for all models.

## Open Problems

- 30 pre-existing test failures (schema mismatches — imports fixed, logic issues remain)
- GL buttons in React toolbar ready but not wired to InvoiceDetail/PaymentDetail
- BOM cost rollup not built
- Training cleanup requires PostgreSQL (JSON __contains filter)
- Athena blockchain signing not built
- Alice doesn't have her own LLM yet — critical for her to be a full team member

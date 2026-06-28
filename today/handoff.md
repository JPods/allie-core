# Handoff — 2026-06-27 (wc2→wc3 translation + Phase 1-5 execution)

## Where We Left Off

Completed Phases 1-5 of the wc2→wc3 translation plan. 65 tests passing in `tests/task_2026_06_27.py`. GL posting + reversal workflow complete with manage action endpoints. Price resolution, inventory availability, and cross-reference lookup services built. RBAC staff authority rules configured. Data integrity tests (export/import roundtrip, refs↔FK audit, soft delete, version conflict) all passing. Agent fixing 8 pre-existing broken test files (module-level Django import errors). Full existing test suite regression run in progress.

## Do This First Next Session

1. **Run `./bin/python -m pytest tests/task_2026_06_27.py -v --no-cov`** — verify all 65 session tests still pass
2. **Check if broken test fixes landed** — the 8 pre-existing test files with import errors were being fixed by an agent at session end
3. **BOM cost rollup** — deferred to its own session; this is the next Phase 3 item. Recursive assembly costing from component items.
4. **Test the React25 conversion flow manually** — open a proposal in React, click Transfer, verify order appears with lines copied and Pending records created
5. **Review Alice action records** — 12 pending notes (ids 203-212) for project+phase setup

## Open Problems

- 8 pre-existing test files fail to collect (module-level Django imports) — fix agent was running at session end
- GL reversal deletes original entries on re-post (test_full_cycle_post_reverse_repost) — may want to preserve originals and only add new entries
- `userProfile.ts` bypasses wcapi — interceptor handles it, but should be consolidated eventually
- No GL posting button in React25 UI yet — manage action works via API, needs a button in InvoiceDetail/PaymentDetail
- Proposal cloning endpoint not built
- Tax/shipping adjustment factor not built (actual vs estimated)

## What Was Decided (and Why)

- **DB_MODE hardcoded to 'local'** — decouple reads env vars before .env; stale env var caused remote DB routing
- **GL posting is user-initiated** — records editable until journalized; after that, only reversals. Standard double-entry accounting.
- **Tax/shipping are fixed values** — user-entered, not calculated. API providers (Avalara, TaxJar) deferred until offered.
- **Import = External Mandated** — wc3 carries zero import code; external scripts conform to wcapi save contract
- **Export = API for formatted, management command for bulk**
- **Admin = Django admin + psql directly** — changes bypass hooks/versioning/audit; admins accept that risk
- **Sync = compliance boundary** — trading partner data scrubbed via Connection.rules; Athena blockchain-signs hooks/scripts; Bundles flagged+quarantined (not blocked)
- **refs/metadata secondary to PKs** — denormalized caches; FK wins on conflict; nightly Celery audit
- **Backend is source of truth** — React displays and submits; server validates and decides; server wins on disagreement
- **Pending system = inventory mechanism** — line save → Pending → Celery 30s → InventoryLayer. reserve_inventory_for_order() is visibility aid only.
- **Staff authority via RBAC** — negative qty, price_level changes, cost visibility all require staff role
- **Save hooks replace TallyMaster** — user-defined executables stored in Settings, support pre/post/async
- **WC-support hook library** — pre-built R25 form scripts + wc3 hooks; Athena signs; JPods = customer zero
- **Yolo override** — admin can override Athena blocking on scripts with their name on it (audited exception)

## Files Changed This Session

### Backend (webClerk3)
- `webclerk3_api/settings.py` — forced DB_MODE=local; 3 Celery beat tasks (aging, refs audit, GL schedule note)
- `apps/accounts/models/gl_journal.py` — source_id, source_model traceability fields
- `apps/accounts/models/__init__.py` — GlJournal export
- `apps/accounts/services/ledger_balance.py` — post_staged_gl_entries(), reverse_gl_entries()
- `apps/accounts/migrations/0009_*.py` — GlJournal migration
- `apps/core/models/contact.py` — save_after() bidirectional org refs
- `apps/core/views/manage_view.py` — post_gl_entries + reverse_gl_entries manage actions
- `apps/core/views/auth_views.py` — removed debug logging
- `apps/core/services/role_defaults.py` — staff authority restricted_fields
- `apps/transactions/services/transaction_save.py` — Phase 4b tax/shipping comment
- `apps/support/scheduler/tasks.py` — task_reconcile_aging, task_audit_refs_fk
- `apps/products/services/pricing.py` — price resolution service (NEW)
- `apps/products/services/inventory_availability.py` — availability service (NEW)
- `apps/products/services/xref_lookup.py` — cross-reference lookup (NEW)
- `tests/conftest.py` — fixed ContactFactory, WarehouseFactory
- `tests/task_2026_06_27.py` — session test runner (65 tests)
- `tests/test_gl_posting.py` — 6 tests (NEW)
- `tests/test_gl_manage_action.py` — 10 tests (NEW)
- `tests/test_commerce_cycle_e2e.py` — 6 tests (NEW)
- `tests/test_pricing.py` — 17 tests (NEW)
- `tests/test_inventory_and_xref.py` — 13 tests (NEW)
- `tests/test_inventory_bucket_flow.py` — 4 tests (NEW)
- `tests/test_data_integrity.py` — 9 tests (NEW)
- `readmes/wc2-wc3-translation-plan.md` — comprehensive plan (NEW)
- `readmes/react25-audit-results.md` — Phase 1 audit (NEW)

### Frontend (React2025)
- `src/apps/accounts/models/currency/pages/CurrencyList.tsx` — JSX fix
- `src/apps/products/models/item/pages/ItemList.tsx` — removed 10-record cap
- `src/apps/products/models/item/services/itemApi.ts` — wcapi consolidation
- `src/api/axios.ts` — 30s/15s timeouts
- `src/api/constants.ts` — deleted (dead code)

# Handoff — 2026-06-27 (wc2→wc3 translation plan + Phase 1-2 execution)

## Where We Left Off

Completed the wc2→wc3 translation plan, Phase 1 (React25 audit), and Phase 2 (core commerce cycle backend). All 12 Phase 2 tests pass. DB_MODE was forced to `local` in settings.py after a decouple env var override (`DB_MODE=bill`) caused the server to hit the remote database. MCP connections to both Allie and Alice (WebClerk) are working. The translation plan is at `webClerk3/readmes/wc2-wc3-translation-plan.md`. React25 audit results at `webClerk3/readmes/react25-audit-results.md`.

## Do This First Next Session

1. **Run the migration** for GlJournal source fields: `./bin/python manage.py migrate accounts` — migration 0009 adds `source_id` and `source_model` to gl_journals table.
2. **Review the translation plan** — `webClerk3/readmes/wc2-wc3-translation-plan.md` has accumulated decisions from this session (import=external mandated, export=API+mgmt cmd, admin=django+psql, sync=compliance boundary, save hooks=TallyMaster replacement, Athena signing, JPods=customer zero).
3. **Phase 3: Product & Pricing** — next phase per plan. Item search, price tier resolution, inventory availability, BOM cost rollup. Most infrastructure exists.
4. **Fix ContactFactory** in `tests/conftest.py` — changed `username`/`first_name`/`last_name` to `email`/`name_first`/`name_last` to match Contact model. Other tests using the old factory may break.
5. **Check Alice action records** — 8 pending notes (ids 203-212) sent via wc_add_note for project+phase setup.

## Open Problems

- **4 standalone line detail pages are shells** (InvoiceLineDetail, ProposalLineDetail, PurchaseLineDetail, WorkOrderLineDetail) — low priority since lines edit inline in parent transaction pages.
- **3 org detail pages possibly incomplete** (CustomerDetail, VendorDetail, EmployeeDetail) — save wiring needs investigation.
- **GL reversal transactions not built** — once a record is journalized, corrections require contra entries. `post_staged_gl_entries()` exists but no `reverse_gl_entries()` companion yet.
- **Tax and shipping are fixed user-entered values** — tax service exists (Avalara/TaxJar/builtin) but not wired in. Will add adjustment factor for actual vs estimated later.
- **Some React services bypass wcapi** — `userProfile.ts` calls apiClient directly. Interceptor handles it but should be consolidated.

## What Was Decided (and Why)

- **DB_MODE forced to `local`** in settings.py — python-decouple reads env vars before .env files; a stale `DB_MODE=bill` env var in the runserver terminal was routing all queries to the remote DB at 76.13.185.210. Hardcoded to prevent recurrence.
- **GL posting is user-initiated, not auto on save** — invoices/payments stay editable until explicitly journalized. After journalizing, only reversing transactions allowed. This preserves the correction window.
- **Tax/shipping are fixed values until API option** — customers charged at order time; adjustment factor for actual vs estimated costs comes later (was in wc2).
- **Import = "External Mandated"** — wc3 carries zero import code. External scripts conform to wcapi save contract.
- **Export = API for formatted, management command for bulk** — export formatting lives outside wc3.
- **Admin = Django admin + psql directly** — no React admin rebuild. Bypass warning documented (skips hooks, versioning, audit).
- **Sync = compliance boundary** — trading partner data scrubbed via Connection.rules before entering system. Athena blockchain-signs all hooks/scripts. Sync Bundles flagged+quarantined (not blocked) for integrity review.
- **refs/metadata are secondary to PKs** — denormalized caches, never authoritative. FK wins on conflict. Nightly Celery audit detects drift.
- **Pending system handles inventory** — line save → Pending with quantity buckets → Celery 30s → InventoryLayer update. `reserve_inventory_for_order()` is a separate visibility aid (qty_available), not the primary tracking mechanism.

## Files Changed This Session

- `webClerk3/webclerk3_api/settings.py` — forced DB_MODE=local; added Celery beat tasks for aging reconciliation + refs audit
- `webClerk3/apps/accounts/models/gl_journal.py` — added source_id, source_model for GL traceability
- `webClerk3/apps/accounts/models/__init__.py` — added GlJournal export
- `webClerk3/apps/accounts/services/ledger_balance.py` — added post_staged_gl_entries() function
- `webClerk3/apps/accounts/migrations/0009_add_gl_journal_source_traceability.py` — new migration
- `webClerk3/apps/core/models/contact.py` — save_after() now populates bidirectional org refs
- `webClerk3/apps/core/views/auth_views.py` — removed debug logging (was added during DB diagnosis)
- `webClerk3/apps/transactions/services/transaction_save.py` — added Phase 4b comment for tax/shipping
- `webClerk3/apps/support/scheduler/tasks.py` — added task_reconcile_aging + task_audit_refs_fk
- `webClerk3/readmes/wc2-wc3-translation-plan.md` — comprehensive translation plan (new)
- `webClerk3/readmes/react25-audit-results.md` — Phase 1 audit results (new)
- `webClerk3/tests/test_gl_posting.py` — 6 GL posting tests (new)
- `webClerk3/tests/test_commerce_cycle_e2e.py` — 6 commerce cycle tests (new)
- `webClerk3/tests/conftest.py` — fixed ContactFactory fields to match Contact model
- `React2025/src/apps/accounts/models/currency/pages/CurrencyList.tsx` — fixed JSX syntax error
- `React2025/src/apps/products/models/item/pages/ItemList.tsx` — removed 10-record artificial cap
- `React2025/src/apps/products/models/item/services/itemApi.ts` — consolidated to use wcapi layer
- `React2025/src/api/axios.ts` — added 30s/15s request timeouts
- `React2025/src/api/constants.ts` — deleted (dead code, zero imports)

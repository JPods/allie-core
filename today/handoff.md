# Handoff — 2026-08-24

## Where We Left Off

Removed all 12 scalar shadow fields from WC3 (PJPV compliance). All migrations deleted and regenerated fresh from current model state. DB is correct — migrations fake-applied. Smoke tests pass: JSON path queries, @property backward compat, Alice aggregate tracker all working. ~17 files still have stale `work_order` references (renamed to `workorder` but cleanup was interrupted). Frontend `work_order` rename not started.

## Do This First Next Session

1. **Read `readmes/topics/architecture/pjpv-shadow-field-removal.md`** — full scrub checklist at the bottom. This is the outcome document. But the *process* reasoning is below in "What Was Decided" — read that first to understand the path, not just the result.

2. **Finish `work_order` → `workorder` cleanup** — run `grep -rn 'work_order' apps/ common/ --include='*.py' | grep -v __pycache__ | grep -v migrations/ | grep -v 'db_table\|db_column\|workorder_id'`. ~17 hits remain. Change each to `workorder` unless it's a DB table name or display label. Do the same for frontend (`grep -rn 'work_order' frontend/src/`).

3. **Full PJPV compliance scrub** — verify no scalar shadow queries remain (`Sum('total')`, `balance__gt`, etc. on transaction models). Verify the functional indexes exist in PostgreSQL. Run `refresh_aggregates` to confirm Alice's collections match reality.

4. **Recommit the 7 reverted PJPV changes** from the prior session (see handoff-PREV.md items).

5. **Update `pjpv-denormalized-fields.md`** — remove the 12 deleted fields from the registry. Only `source_name` should remain as a documented scalar.

## Open Problems

- OrgBase/Contact `@property` methods for `address_full`, `phone`, `domain` query the DB on each access (N+1 risk in bulk operations like `denormalize_org_links`). Fine for single-record saves; could need `select_related`/`prefetch_related` if bulk perf degrades.
- `Contact._sync_primary_communication_links()` no longer creates Phone/Domain/Address records from scalar input on new contact creation — the scalars are gone. Phone/domain/address must now be created as separate communication records. Verify the React contact form handles this.
- `PendingPaymentApplication` model class still exists in `pending_payment.py` but is not imported in `__init__.py` and has no migration. Either delete the file or re-import it.
- Alice code_standards scanner patterns may flag the removed fields as missing. Check and update.

## What Was Decided (and Why)

- **Why remove shadow fields, not just index them?** Bill's question: "should we remove those?" Two options were on the table: (1) index the JSON paths, (2) have Alice manage search collections. The answer was *both* — functional indexes for correctness, Alice collections for dashboard performance — and *remove the scalars entirely* because they violate PJPV's core rule. A shadow field that can drift from the JSON is a second source of truth. Scars #62-63 proved this costs real debugging time.

- **Why Alice collections instead of generated columns?** Claude proposed PostgreSQL generated columns (DB-computed scalars that can't drift). Bill's response: "I am unclear where Sum() is an issue. My view is users will search for `invoice.totals.balance !== 0`." This reframed the problem — users *filter*, they don't aggregate. The Sum() case is only dashboards, which are non-critical display. Alice manages those with delta updates on save and periodic refresh. Drift tolerance is the key insight: nobody needs real-time-to-the-penny AR totals on a dashboard.

- **Why rename `work_order` → `workorder`?** Consistency with Django's `_meta.model_name` (which concatenates without underscores). Eliminates the `_META_TO_REGISTRY` translation dict that was needed for Alice's aggregate tracker. Bill said "I can see benefits" and "include it in this sweep." Since they're the only users, no backward compat aliases needed.

- **Why delete all migrations?** The shadow field removal created migration 0037 (indexes), 0038 (field drops), plus existing migrations 0001-0036. The Payment model had `parent_id`/`parent_model` columns in the model code but not in any migration, causing conflicts. Bill said "you can delete all migrations" — fresh start from current model state, fake-applied since the DB schema is already correct.

- **Why @property methods instead of just removing the fields?** Admin `list_display` references `email`, `phone`, `address_full` as field names. Django admin calls `getattr(obj, field_name)` — if the field doesn't exist and there's no property, the admin crashes. The properties read from JSON envelopes or FK relationships, providing backward compat without storing duplicate data.

## Files Changed This Session

**New files:**
- `common/json_lookups.py` — `totals_total()`, `totals_balance()`, `totals_received()` ORM helpers for JSON path Cast expressions
- `apps/ai_assistant/services/aggregate_tracker.py` — Alice aggregate collections: delta updates, refresh, read
- `apps/ai_assistant/management/commands/refresh_aggregates.py` — management command for nightly drift correction
- `readmes/topics/architecture/pjpv-shadow-field-removal.md` — outcome document with scrub checklist

**Model changes:**
- `apps/transactions/models/base_transaction_model.py` — removed 6 scalar fields, added 6 @property methods
- `apps/orgs/models/base.py` — removed 3 scalar fields, added 3 @property methods, cleaned __repr__
- `apps/core/models/contact.py` — removed 3 scalar fields, added 3 @property methods, simplified _sync_primary_communication_links

**Totals engine:**
- `apps/transactions/services/totals.py` — removed dual-write (4 lines: header.total, header.balance in both recalculate_totals and update_received)

**Query migrations (scalar → JSON path):**
- `apps/core/services/commerce_dashboard.py` — Sum('total')→annotate+Sum, balance__gt→annotate+filter, fixed Payment Sum('total')→Sum('amount')
- `apps/accounts/services/collections_dashboard.py` — Sum('total') for DSO, Sum('balance') for open invoices
- `apps/transactions/services/sales_pipeline.py` — 6x Sum('total') across pipeline stages
- `apps/core/services/vendor_summary.py` — Sum('total') on Purchase
- `apps/transactions/services/credit_check.py` — Sum('total') on Order backlog
- `apps/ai_assistant/services/accounting_watchdog.py` — filter(total__isnull=False)
- `apps/accounts/services/aged_receivables.py` — Sum('total') on Order per customer
- `apps/accounts/services/ledger_balance.py` — Sum('total') on Order exposure
- `apps/conversion/management/commands/import_wc2.py` — Sum('balance') on Invoice verification

**Signal wiring:**
- `apps/transactions/signals.py` — added Alice aggregate delta signals (pre_save stash + post_save apply) for all 5 transaction models; added WorkOrder import

**work_order → workorder rename (~21 files):**
- `apps/core/constants/model_registry.py` — registry key changed
- `apps/core/utils/model_name_resolver.py` — mappings updated
- `apps/core/services/wcapi_registry.py` — mappings updated
- Plus ~18 seed commands, services, views, tests (done by subagent)

**Migrations:**
- All migration files deleted and regenerated fresh from current model state
- `django_migrations` table cleared and fake-applied

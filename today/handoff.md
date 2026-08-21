# Handoff — 2026-08-20 evening session

## What was done

### 1. Layout pass — 78 models
- Created `~/Allie/wc3-field-layout.txt` with all 78 WC3 model layouts
- Established 4-tier detail pattern: VISIBLE → IMPORTANT JSON → DATES → COLLAPSED
- Bill reviewed and corrected Contact, Customer, Invoice, Item, Payment
- All transactions (headers + lines), orgs, and product models converted
- Product model lists updated with model-specific columns (not generic placeholders)

### 2. dt_journaled consolidation
- Added `dt_journaled` (BigInt, default=0, 0=editable, non-zero=locked) to:
  - TransactionBaseModel (Invoice, Order, Proposal, Purchase, Work Order, Requisition)
  - Receipt, GL Journal, Ledger
- Replaced: `date_posted` + `is_posted` (GL Journal), `dt_posted` (Ledger)
- Renamed: `dt_settled` → `dt_applied` (Ledger)
- Dropped: `is_settled` (Ledger) — `dt_applied IS NOT NULL` replaces it
- Updated 16 files: journalize.py, status_guard.py, pending_summary.py, ledger_balance.py, terms_ledger.py, admin.py, seed commands, tests, envelopes.py
- 3 migrations applied: accounts.0021, accounts.0022, transactions.0036

### 3. Save bug fix + superuser gate
- `useDataBrowser.ts` `persistSetting` now writes to BOTH `config.db.*` AND `config.layout.*`
- Only superuser can write to `config.layout.detail.default` / `config.layout.list.default`
- Non-superuser blocked from saving as "default" with alert message
- **React build needed** for this to take effect

### 4. TFTS
- "Chewable pieces" — break overwhelming config tasks into batches of 5 for human review

## Decisions made
- **One-path layout storage**: all shared layouts at `config.layout.detail.{name}`, personal at `contact.prefs.db_layouts.{model}.{name}`, kill `config.db.views[]`. Reason: easier to teach.
- **dt_journaled pattern**: timestamps ARE flags, no redundant booleans
- **detail.default + detail.cluster**: two named views (alphabetical vs domain-grouped) — user picks

## Open / next session
1. **React build** — useDataBrowser.ts changes need `npm run build`
2. **One-path refactor** — migrate config.db.views to config.layout.detail.{name}, personal layouts to contact.prefs
3. **Payment schema** — add related_parent JSON, company/attention fields, drop payment_term/invoice/purchase FKs
4. **Item form rework** — Bill wants changes to the form sections
5. **Remaining layout review** — accounting family, communications, docs, system models need Bill's corrections
6. **dt_journaled on forms** — add to Invoice/Payment/Purchase form layouts so users see it

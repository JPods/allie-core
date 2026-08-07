# Handoff — 2026-08-06 (Session 4)

## Where We Left Off

Fourth session today. Built three major features:

### 1. Role-Based Field Exposure
Added `COST_FIELDS` and `PRICE_FIELDS` constants to `seed_field_access.py`. Customers and reps see prices but never costs. Vendors and manufacturers see their costs but never prices. 59 admin-only models don't get field_access Settings — never exposed outside employees. Rep role view now excludes cost fields (was showing everything). Review due 2026-11-06. Readme at `wc3/readmes/topics/architecture/role-based-field-exposure.md`.

### 2. Status Guard Rails (#87 on go-live)
Built `status_guard.py` — transition matrix for all 7 transaction types + payment. Pre-conditions per transition (can't release with zero lines, can't cancel with applied payments, proposal needs customer before release, order needs all lines shipped before complete). **Journalized record lock**: no modifications to invoices, payments, purchases, receipt_lines, or commission records after GL posting. Over-the-counter invoices (no parent order) fully supported. Wired into wcapi save and delete paths. 20 unit tests.

### 3. Aged Receivables & Customer Statements (#45/#46 on go-live)
- Backend data engine: `aged_receivables.py` — per-customer aging with detail lines, finance charges, days past due
- Two API endpoints: `/wcapi/reports/aged_receivables/` (all customers) and `/wcapi/reports/statement/<id>/` (single customer with response area)
- Company settings: `receivables` config added to company_profile Setting — finance charge %, send-by-day thresholds, per-period messages (heading + closing), conditions text
- Two print layout Settings seeded: internal report (landscape, grouped) and customer statement (portrait, logo, response area checkboxes, period messages)
- **React print rendering not yet wired** — UniversalPrint needs new section type handlers: `response_area`, `aging_summary`, `grouped_line_items`, `report_header`/`report_footer`

### 4. Leftshoe Startup Message
Added "Team is up. Allie and Alice are connected. Session document is [id]." to both new-session and already-briefed responses in `leftshoe-mcp.py`. Added `_get_session_document_id()` helper.

## Do This First Next Session

1. **Run seed commands** — Django server restart, then:
   ```bash
   ./bin/python manage.py seed_company_settings   # adds receivables config
   ./bin/python manage.py seed_status_guards       # adds transition rules to schema_map Settings
   ./bin/python manage.py seed_receivables_layouts  # creates print layout Settings
   ./bin/python manage.py seed_field_access --force # updates rep role with cost exclusion
   ```
2. **Test aged receivables endpoint** — hit `/wcapi/reports/aged_receivables/` in browser, verify customer data returns with aging buckets
3. **Wire UniversalPrint section types** — add handlers for `response_area`, `aging_summary`, `grouped_line_items` to the React print renderer
4. **Test status guard** — try changing invoice status after journalization, verify 403. Try releasing order with no lines, verify 400.
5. **Update go-live list** — mark #87 DONE, #45/#46 as READY (backend done, React print wiring needed)

## Open Problems

- UniversalPrint.ts needs 4 new section type handlers before receivables reports can render
- Spreedly iframe (#1, #52) still BLOCKED — needed for customer payment
- `_get_session_document_id()` queries DB on every leftshoe call — lightweight but could cache
- DataBrowser filter passthrough (from prior session) — still only works on first window load

## What Was Decided (and Why)

- **Admin-only models don't need field_access Settings** — 59 of 96 models are internal, never exposed. Saves seed time and noise.
- **Reps see prices, not costs** — they sell on price. Vendors see costs, not prices — they charge us. Bill confirmed both.
- **Journalized = locked** — invoices, payments, purchases, receipt_lines, commissions. No modifications after GL posting. Reverse the journal entry first, then edit, then re-journalize.
- **Over-the-counter invoices are first-class** — no guard rail requiring an order before invoice. Standalone invoice is a legitimate business path.
- **Print layouts are JSON Settings, not code** — editable in DataBrowser, draftable by Alice. Two new section types (response_area, aging_summary) extend the UniversalPrint vocabulary.
- **Company receivables config** — finance charge rate, send-by-day thresholds, per-period messages all in company_profile Setting. Matches WC2 Defaults screen.

## Files Changed This Session

### webClerk3
- `apps/core/management/commands/seed_field_access.py` — COST_FIELDS, PRICE_FIELDS constants, rep_view exclusion
- `apps/core/management/commands/seed_company_settings.py` — receivables config section
- `apps/core/management/commands/seed_freshstart.py` — added seed_status_guards + seed_receivables_layouts
- `apps/transactions/services/status_guard.py` — NEW: transition matrix, pre-conditions, journalized lock
- `apps/transactions/views/wcapi.py` — guard wired into save + delete paths
- `apps/transactions/management/commands/seed_status_guards.py` — NEW: seed transition rules
- `apps/transactions/tests/test_status_guard.py` — NEW: 20 tests
- `apps/accounts/services/aged_receivables.py` — NEW: data engine for both reports
- `apps/accounts/views.py` — NEW: AgedReceivablesView + CustomerStatementView
- `apps/accounts/urls.py` — NEW: report endpoints
- `apps/accounts/management/commands/seed_receivables_layouts.py` — NEW: print layout seeds
- `webclerk3_api/urls.py` — added accounts report URLs

### readmes
- `readmes/topics/architecture/role-based-field-exposure.md` — NEW: field visibility rules

### Allie
- `scripts/leftshoe-mcp.py` — startup message + _get_session_document_id()

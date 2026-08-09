# Handoff — 2026-08-09 (Session 2)

## Where We Left Off

Built report script pipeline (before/during/after), receipt detail page with landed cost allocation, item/contact/org enrichment Pydantic schemas, and a complete schema compliance system (service + management command + signals). Fixed 6 save pipeline bugs that blocked all contact saves. Converted 13 print reports to pdfme templates (copies, originals untouched). Added pdfme editor inline in ReportsDialog. Feature list triage: 4 done, 5 not MVP.

## Do This First Next Session

1. **Wire pdfme editor to report context** — PdfDesigner in ReportsDialog needs the report record and model name passed in so it populates the field list with actual model fields. This is the immediate blocker for users designing pdfme templates.
2. **Run `manage.py audit_schema_compliance --records --fix`** — sweep existing records, fix null envelopes (24 documents with config=None). Have Alice do it.
3. **Sync cleaned data to Andi** — after compliance sweep
4. **RequisitionLine migration** — missing `commission` column needs a migration

## Open Items

- pdfme editor doesn't receive report record — no model/field context
- Original reports may incorrectly show pdfme badges (check config)
- RequisitionLine missing `commission` column — migration needed
- 24 Document records with `config = None` — Alice sweep
- AppSidebar logs dashboardNames on every render (noisy)
- `wc` model has no Pydantic schema module (2 violations in compliance audit — placeholder model)

## Key Decisions Made

- Report scripts: before (once) → during (per record, unload, read_only) → after (once)
- Schema compliance is real-time coaching at save boundary, not a nightly batch
- Alice fixes what she can, puts unfixable data in `.violation{}` bucket — never loses data
- uuid is sync-only, never sent/received in UI save operations
- One ReportsDialog component used everywhere — no duplicates
- pdfme copies alongside originals (not replacements)
- Save_view uses `_meta.get_field()` not `hasattr()` for model field detection

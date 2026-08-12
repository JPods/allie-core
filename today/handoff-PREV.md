# Handoff — 2026-08-11

## Where We Left Off

Replaced pdfme with a panel-based report layout designer built entirely on our own PrintLayout JSON + UniversalPrint renderer. Seeded all 13 print reports with production layouts. Added conditional dunning messages to the Statement report. Built Collections Queue (accounting dashboard) and Customer Health Card (customer detail) with full backend services. Added fiscal health markers (`dt_last_statement`, `health_score`, `velocity_trend`, `statement_interval_days`) to the customer financial structure. Soft-deleted 13 pdfme duplicate reports. 19 new .dot flowchart files are uncommitted in Allie — not reviewed this session.

## Do This First Next Session

1. **Test print reports end-to-end** — open an order, Reports dialog, double-click Order Confirmation. Verify it renders correctly with real data through UniversalPrint. Fix any field path mismatches.
2. **Add 6 general styles** to PrintLayoutDesigner — Title/Heading/Body/Money/Small/Emphasis. Auto-apply by section type. This replaces per-field font control (discussed, agreed, not built).
3. **Build prompt bar** in PrintLayoutDesigner — text input where user describes a panel, Claude/Alice drafts it. The panel templates are the starting point.
4. **Test Collections Queue and Health Card** — verify `get_collections_dashboard` and `get_customer_health` manage actions return correct data. The backend service may need field path adjustments for the actual DB structure.
5. **Review 19 new .dot flowchart files** in `readmes/flowcharts/` — uncommitted, added outside this session.

## Open Problems

- Django runserver hangs on startup if stale `manage.py shell` processes hold DB connections. Kill orphan Python processes before restarting.
- `PdfDesigner.tsx` still exists but is no longer used by ReportsDialog. Can be deleted or kept as a standalone tool at `/pdf-designer`.
- The pydantic `FinancialSnapshot` schema is too flat — doesn't validate the full nested `financial.customer.*` structure from `constants.py`. Works because `Dict[str, Any]` accepts everything, but not enforced.
- Statement batch sender UI (select past-due → send statements with interval skip) is designed but not built.

## What Was Decided (and Why)

- **Abandoned pdfme** — foreign tool that doesn't know our data model. Our PrintLayout sections + UniversalPrint renderer do everything it does, and we control the field picker, panel templates, and rendering. Users who need pixel-perfect control export layout JSON and build a custom `.tsx` template.
- **6 general styles instead of per-field formatting** — production system, not a design tool. Title/Heading/Body/Money/Small/Emphasis auto-applied by zone. Data.json available for users who need more.
- **Panel layout: Panels left, Preview center, Fields+Models right** — right-hand ergonomics. Fields are high-frequency (drag/click), models are pick-occasionally, panels are set-once.
- **Conditional text section type** — rules in `config.statement.comments`, evaluated top-down against record data. Reusable beyond statements for any document needing conditional content.
- **Fiscal health markers in `financial.customer.collection`** — `dt_last_statement` + `statement_interval_days` enables batch statement sending with skip logic. Health score and velocity trend maintained by nightly job.
- **Labels handled by external software** — WC3 exports data (ZPL/CSV/JSON), dedicated label printers/software handle printing. Readme at `readmes/topics/print/labels.md`.

## Files Changed This Session

**React2025 (bill_dev):**
- `src/components/common/ReportsDialog.tsx` — 7 buttons → 3 controls, removed preview pane, full-screen editor overlay, removed pdfme
- `src/components/print/PrintLayoutDesigner.tsx` — complete rewrite: panel-based sections, field picker from registry, model list, draggable splits, paper size select
- `src/components/print/printLayoutTypes.ts` — added `ConditionalTextSection`, `legal` paper size
- `src/components/print/UniversalPrint.ts` — added `renderConditionalText` with expression evaluator, `reportConfig` passthrough
- `src/components/collections/CollectionsQueue.tsx` — new: past-due customer list, DSO, cash, actions, promises broken
- `src/components/collections/CustomerHealthCard.tsx` — new: aging bar, credit, velocity trend, health score
- `src/pages/admin/AccountingDashboard.tsx` — added Collections section
- `src/apps/orgs/components/OrgPage.tsx` — added CustomerHealthCard to customer detail
- `src/pages/tools/PdfDesigner.tsx` — updated props (report, model) but no longer used by ReportsDialog

**webClerk3 (bill_dev):**
- `apps/core/management/commands/seed_print_layouts.py` — rewrote: 13 report layouts with PrintLayout sections + dunning messages
- `apps/accounts/services/collections_dashboard.py` — new: collections dashboard + customer health backend
- `apps/core/views/manage_view.py` — registered `get_collections_dashboard` and `get_customer_health` actions
- `apps/orgs/models/constants.py` — added fiscal health markers + statement_interval_days
- `readmes/topics/print/labels.md` — new: labels and barcodes reference for Alice
- `readmes/topics/accounts/collections.md` — new: collections workflow documentation for Alice

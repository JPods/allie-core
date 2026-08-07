# Handoff — 2026-08-06 (Session 5)

## Where We Left Off

Completed the full print/report architecture overhaul. All 230 print Report records now have `config.form` JSON layouts — 71 single-record forms (invoices, credit memos, orders, POs, work orders, packing slips, pick tickets, BOLs, receipts) and 157 list/analysis reports with `data_table` sections. Three new canonical BaseModel fields added: `dt_approved`, `times_used`, `dt_last_used`. Report health metadata seeded on all 219 active print reports with review tracking. The report review parade tool (browser popup per report with notes panel) is designed but not yet built — that's next session.

## Do This First Next Session

1. **Build the report review parade tool** — browser popup per report, floating notes panel (Save & Next / Skip / Done), saves to `Report.config.review_notes` and sets `dt_approved`. File: new function in `UniversalPrint.ts` or standalone `reportReview.ts`.
2. **Test the print flow end-to-end** — open an invoice in detail view, click the print dropdown (now `PrintReportDropdown`), pick "Invoice - Standard", verify UniversalPrint renders from `config.form`. Check credit memo too.
3. **Test the DataBrowser model-sticking fix** — navigate to `/db/setting`, switch to another model via picker, confirm URL updates to `/db/{newModel}`.
4. **Test the Reports dialog filtering** — open Reports on an item detail page, confirm only item reports show (not all 230). Uses `model_name_filter` param now.
5. **Wire `companyInfo` into ReportsDialog callers** — DataBrowser and other callers need to pass the company Setting so print headers/footers show company identifiers.

## Open Problems

- `openUniversalPrint` page numbering uses `@page { @bottom-center }` CSS which has limited browser support — may need a JS-based counter fallback.
- The `data_table` renderer receives rows via `data.rows` but ReportsDialog callers (DataBrowser) don't yet pass `listRecords` prop — needs wiring.
- `reportLists.ts` is deprecated but still imported by `ButtonToolbar.tsx`, `TransactionToolbar.tsx`, and `config/index.ts` — those importers need migration to Setting/Report-based lookup, then delete the stub file.
- Embroidery Worksheet and Schedule A reports have generic placeholder layouts — need real layouts from Bill or user-uploaded examples.
- `handleSelectModel` in `useDataBrowser.ts` was changed by linter to navigate to `/${name}` instead of `/db/${name}` — verify this is correct for the route structure.

## What Was Decided (and Why)

- **Negative quantities for returns** (item 89) — no special invoice_type or UI. User enters negative qty on any invoice. Prints as Credit Memo by choosing that report from the dropdown. Non-resellable returns scrapped via adjust-on-hand. Simple because the math handles itself.
- **Reports not Settings for print templates** — Report model already has `model_name`, `output_type`, `category`, `config`, `sort_order`. Reports have UUIDs so WC_HQ can push fixes. Settings are for configuration, Reports are for document definitions.
- **`config.form` not `config.layout`** — Bill named it form.json. Forms are what users see (invoices, POs). Reports aggregate data. Both use form.json structure.
- **`model_name_filter` wcapi alias** — `model_name` is reserved as the table selector in wcapi. Models with a `model_name` column (Report, Setting) use `model_name_filter` param which maps to the column. Without this, report queries returned all 230 records unfiltered.
- **`dt_approved`, `times_used`, `dt_last_used` as canonical BaseModel fields** — not metadata. Every model gets them. `dt_approved` = user signed off. `times_used` + `dt_last_used` = usage tracking for 80/20 prioritization.
- **80/20 review rule** — high-usage reports self-police through user feedback. Low-usage reports rot silently. Alice prioritizes the risk 20% (low usage, new, recently modified) not the high-traffic 80%.

## Files Changed This Session

### React2025
- `src/components/common/DetailToolbar.tsx` — rewired to use PrintReportDropdown + UniversalPrint from Report.config.form
- `src/components/common/PrintReportDropdown.tsx` — rewritten to query Report records via wcapi (model_name_filter)
- `src/components/common/ReportsDialog.tsx` — uses model_name_filter, reads config.form, passes companyInfo, supports list context
- `src/components/common/ReportMenu.tsx` — switched to model_name_filter
- `src/components/print/printLayoutTypes.ts` — added DataTableSection, repeat_header/footer/page_break flags, dt_approved layout support
- `src/components/print/UniversalPrint.ts` — added data_table renderer with grouping/subtotals/grand totals, page footer with company identifiers, page numbering
- `src/apps/transactions/components/print/printTypes.ts` — added creditmemo document type
- `src/apps/transactions/components/print/InvoicePrintDocument.tsx` — reverted invoice_type auto-detection (user chooses print format)
- `src/apps/transactions/components/print/PrintDocumentLayout.tsx` — creditmemo treated like invoice for layout
- `src/services/pdfme/templateService.ts` — registered creditmemo starter template
- `src/services/pdfme/generateCommercePdf.ts` — creditmemo treated like invoice
- `src/services/pdfme/starter-templates/creditmemo.json` — new pdfme credit memo template
- `src/api/settingsBridge.ts` — added fetchSettingRecords() for multi-record queries
- `src/config/reportLists.ts` — replaced with deprecated stubs (backward compat)
- `src/hooks/useDataBrowser.ts` — fixed model-sticking bug: navigate to /db/{model} when on route-param path
- `src/routes/Router.tsx` — removed HTML print routes, removed lazy imports

### webClerk3
- `common/models.py` — added dt_approved, times_used, dt_last_used to BaseModel
- `apps/core/views/wcapi.py` — model_name_filter alias for filtering by model_name column
- `apps/core/migrations/0028_seed_print_templates.py` — added document_type to Report.config, cleaned up Setting print_template records
- `apps/core/migrations/0029_seed_report_forms.py` — seeded form.json on 71 single-record Report records
- `apps/core/migrations/0030_seed_list_report_forms.py` — seeded form.json on 152 list/analysis Report records
- `apps/core/migrations/0031_add_dt_approved.py` — dt_approved on all models
- `apps/core/migrations/0032_add_times_used_dt_last_used.py` — times_used + dt_last_used on all models
- Multiple app migration files for dt_approved and times_used/dt_last_used across all apps

### Archived
- `src/archive/replaced-2026-08-06/` — InvoicePrint.tsx, OrderPrint.tsx, ProposalPrint.tsx, PurchasePrint.tsx, CreditMemoPrint.tsx, QAPrint.tsx, printStyles.ts, reportLists.ts (full original)

# Handoff — 2026-06-29

## Where We Left Off

Massive two-day session. Built the DataBrowser, extended Payment model for expenses, created print components, seeded 61 layouts + 31 fake records + 59 report definitions, built report selector component, established the commerce-vs-accounting boundary, and defined the WC3 value proposition.

## What Was Built (2026-06-28 → 2026-06-29)

### DataBrowser (AdminWorkbench rewrite)
- **File:** `React2025/src/pages/admin/AdminWorkbench.tsx` (~900 lines)
- Two-pane layout (list + detail), dark/light mode (JPods Console palette)
- Model picker with text filter + select list (Cmd/Ctrl+Shift+M)
- Server-side search, pagination (50/page), column sort
- Column drag-reorder, column resize (drag right edge)
- Saved named layouts (shift-click to delete)
- Subset show/omit, CSV export, font size S/M/L toggle
- Collapsible field config panel (List Cols / Detail Fields)

### Route Cleanup
- **Router.tsx** — 40+ admin routes replaced with `<Navigate to="/admin-wb?model=X">` redirects
- **protectedRoutesConfig.tsx** — same cleanup for window manager
- **wrapperPage.ts** — removed ~35 admin imports/exports
- **AppSidebar.tsx** — all admin model links → `/admin-wb?model=X` directly; shift-click ANY model opens DataBrowser

### Payment Model Extended for Expenses
- **File:** `webClerk3/apps/transactions/models/payment.py`
- Added `type` field: `received` (AR) / `disbursed` (AP)
- Added `purchase` FK (nullable) for AP disbursements
- **Migration:** `0007_payment_add_type_and_purchase.py` — applied

### Print Components (from vue2020)
- `React2025/src/apps/transactions/print/printStyles.ts` — shared styles + currency formatting
- `React2025/src/apps/transactions/print/InvoicePrint.tsx` — `/transactions/invoice/print/:id`
- `React2025/src/apps/transactions/print/OrderPrint.tsx` — `/transactions/order/print/:id`
- `React2025/src/apps/transactions/print/ProposalPrint.tsx` — `/transactions/proposal/print/:id`
- `React2025/src/apps/transactions/print/QAPrint.tsx` — `/transactions/qa/print/:model/:id`

### Report System
- `webClerk3/apps/core/management/commands/seed_reports.py` — 59 reports seeded across 15 models
- `React2025/src/components/common/ReportMenu.tsx` — dropdown report selector for any detail page
- Reports stored as Report records with `data.route` for template routing

### Shared Field Config for List Pages
- `React2025/src/hooks/useListFieldConfig.ts` — hook for column selection/ordering
- `React2025/src/components/common/FieldConfigBar.tsx` — collapsible bar component
- Wired into CustomerList as example — 4 lines to add to any list page

### Layout Seeder
- `webClerk3/apps/core/management/commands/seed_databrowser.py` — curated initial layouts + fake records
- 61 models with "initial" named view, 31 fake "zz" records
- `webClerk3/readmes/databrowser-initial-layouts.md` — documents layout design principles

### Sidebar
- "Submit for Bonus" link added at `/submit-bonus` (stub page)
- "Admin Workbench" renamed to "DataBrowser"
- Shift-click power user feature on all sidebar items

## Architecture Decisions (Critical — future Claude will reverse without these)

### WebClerk is Commerce, NOT Accounting
- WC3 manages sales, collections, purchasing, inventory
- WC3 produces GL journal entries by account code
- Accounting programs (QuickBooks, Xero, Sage) consume GL entries
- AR collection is SALES finishing the job — it's our domain
- AP management is ACCOUNTING — not our domain
- NEVER build P&L, Balance Sheet, Trial Balance, Cash Flow in WC3
- The GL Journal Export is the primary handoff product

### Reporting Focus
- **Campaign ROI:** Every order tracks source (campaign_id in source JSON). Reports connect campaign spend to orders generated to measure acquisition cost.
- **Margin velocity:** `(margin_per_unit × annual_turns) / carry_cost_per_unit` — the metric that tells you which products earn their shelf space. Not just counts or costs.
- **Operations reports, not financial statements.** Sales by product/customer/rep, collections, inventory velocity, campaign ROI, pricing analysis.

### WC3 Value Proposition
- **Free platform** — open source, runs on laptop. Paid data services only.
- **Local + cloud dual storage** — laptop is system of record, cloud is backup/collaboration
- **WCHQ proximity search** — merchants publish inventory via sync, buyers search by distance. Amazon loses findability advantage.
- **Cross-company sync** — order→PO→SO linking via sync bundles. EDI for small business at zero setup cost.
- **Vendor blessed list** — curated projection of fields/products, not open access. Sovereignty principle.
- **JPods cargo** — Middle Mile delivery integrated into commerce loop
- **Layout marketplace** — users submit layouts via sync for credit/cash bonuses

### Key Identifiers
- `ida` = human readable (what you say on the phone)
- `id` = local FK (internal database key)
- `uuid` = cross-database unique identifier (sync join key)

## Do This First Next Session

1. **Update seeded reports** — remove accounting reports (Trial Balance, P&L, Balance Sheet, AP Aging), add operations reports (Campaign ROI, Margin Velocity, Pricing Analysis, Sales Trend)
2. **Build expense entry UI** — spreadsheet-style fast entry for Payment type=disbursed
3. **Wire ReportMenu into detail pages** — add `<ReportMenu>` to InvoiceDetail, OrderDetail, ProposalDetail toolbars
4. **Wire FieldConfigBar into remaining list pages** — InvoiceList, OrderList, ItemList, etc. (same 4-line pattern as CustomerList)
5. **Test DataBrowser visually** — dark/light, model picker, layouts, shift-click sidebar
6. **Test print pages** — `/transactions/invoice/print/57` etc.

## Open Problems

- 11 models failed fake record creation (non-null constraints in seed_databrowser)
- Model naming convention inconsistency (ouch-list WC3 item)
- Allie MCP returns empty responses intermittently
- 30 pre-existing wc3 test failures (from prior sessions)
- Seeded reports include some accounting reports that should be removed per commerce-not-accounting rule
- Print templates need real company header data (logo, address from Setting or org)

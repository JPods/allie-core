# Handoff — 2026-06-29 (FINAL — massive 2-day WC3 session)

## Where We Left Off

Built 5 operational service modules (order production, inventory FIFO, serial lifecycle, backorder management, campaign ROI), wired them into wcapi/manage (24 new actions), created ManageActionPanel React component, and wired it into OrderDetail, InvoiceDetail, PurchaseDetail, ProposalDetail. Also built DataBrowser, org pages, print pages, field_access RBAC, field_behaviors, coaching system, training documents, flow charts.

## Do This First Next Session

1. **Start Django + React dev servers** — test ManageActionPanel on any order detail page
2. **Test the 5 operational flows** with real data:
   - Order: Create Work Order, Partial Ship, Complete
   - PO: Receive Goods (creates inventory layer), Create Serial
   - Invoice: Consume Inventory (FIFO), Assign Serial, Post GL
   - Campaign: Create, link to transaction, calculate ROI
3. **Run pytest** — verify no regressions from Payment migration + new services
4. **Test DataBrowser** — dark/light, model picker, field behaviors, form layout editor

## Files Created/Modified This Session

### Backend Services (webClerk3/)
- `apps/transactions/services/order_production.py` — spawn WO, partial ship, complete order
- `apps/transactions/services/backorder.py` — create/fulfill/get/summarize backorders
- `apps/products/services/inventory_stacks.py` — receive, consume FIFO/LIFO, get summary
- `apps/products/services/serial_lifecycle.py` — create on receive, assign on ship, return, history
- `apps/transactions/services/campaign_roi.py` — create, spend, calculate ROI, link transactions
- `apps/core/views/manage_view.py` — 24 new actions in _ACTION_DISPATCH
- `apps/transactions/models/payment.py` — type (received/disbursed) + purchase FK
- `apps/transactions/migrations/0007_payment_add_type_and_purchase.py`
- `apps/core/management/commands/seed_field_access.py` — 61 models × 8 roles + field_behaviors
- `apps/core/management/commands/seed_databrowser.py` — 61 layouts + 31 fake records
- `apps/core/management/commands/seed_reports.py` — 59 reports across 15 models
- `apps/core/management/commands/seed_coaching.py` — 9 coaching + 3 docs + 8 onboarding actions
- `apps/core/choices.py` — added field_access, seed, alice_coaching, campaign purposes

### React Frontend (React2025/src/)
- `hooks/useDataBrowser.ts` — all DataBrowser state/data management (440 lines)
- `hooks/useListFieldConfig.ts` — column visibility/ordering for list pages
- `components/common/BehaviorField.tsx` — field renderer based on field_behaviors (177 lines)
- `components/common/ManageActionPanel.tsx` — operations panel for detail pages (305 lines)
- `components/common/FieldConfigBar.tsx` — collapsible column toggle bar
- `components/common/DetailLayoutDialog.tsx` — form layout editor dialog
- `components/common/ReportMenu.tsx` — report selector dropdown
- `pages/admin/AdminWorkbench.tsx` — DataBrowser (332 lines, refactored)
- `apps/orgs/orgConfig.ts` — per-org-type config
- `apps/orgs/components/OrgPage.tsx` — shared org list+detail
- `apps/orgs/components/CommunicationsPanel.tsx` — inline email/phone/address/domain
- `apps/orgs/pages/*.tsx` — 5 one-line org page wrappers
- `apps/transactions/print/*.tsx` — Invoice, Order, Proposal, QA print pages
- `apps/transactions/models/order/pages/OrderDetail.tsx` — added ManageActionPanel
- `apps/transactions/models/invoice/pages/InvoiceDetail.tsx` — added ManageActionPanel
- `apps/transactions/models/purchase/pages/PurchaseDetail.tsx` — added ManageActionPanel
- `apps/transactions/models/proposal/pages/ProposalDetail.tsx` — added ManageActionPanel
- `routes/Router.tsx` — print routes, org routes, admin redirects
- `routes/protectedRoutesConfig.tsx` — same cleanup
- `pages/wrapperPage.ts` — cleaned imports
- `layout/AppSidebar.tsx` — direct DataBrowser links, shift-click power user

### Readmes (webClerk3/readmes/)
- `claude-session-recovery.md` — post-compaction recovery document
- `wcapi-query-scoping.md` — RBAC query scoping documentation
- `databrowser-initial-layouts.md` — layout design principles
- `daily-development-practice.md` — start/close checklist, reusable components
- `alice-coaching.md` — coaching system architecture

### Database Records Created
- 61 field_access Settings (RBAC + field_behaviors + formatting)
- 61 workbench_fields Settings (DataBrowser layouts)
- 59 Report records (print/email/export per model)
- 9 alice_coaching Settings
- 17 Document records (6 training + 8 flow charts + 3 system guides)
- 8 onboarding Action records
- 31 fake "zz" records
- 15 GAP action records (#367-381)
- 12 W27 test action records (#343-354)
- 5 BUILD action records (#385-389)

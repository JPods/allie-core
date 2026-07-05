# Handoff — 2026-07-04 (Night Session)

## Where We Left Off
Major React2025 cleanup and feature session. Sidebar redesigned (dark, lucide icons, 3 sections). Dashboard rewritten to Sales & Service pattern. Alice quiz system designed and built. 14 npm deps removed, 92 dead files deleted, CSS stripped. Four experimental React copies confirmed as reference-only — React2025 is canonical on port 5173.

## What Was Done

### Data Extraction
- West Point SallyPort parser — Mining (17 profiles), Renewables (98 profiles) → JSON
- jitCorpv17 customers cleaned (5,353 records, HTML stripped)
- Taught Allie extraction as standing task

### React2025 Cleanup
- 92 qqq_ files deleted, 14 dead npm deps removed
- 265 lines dead CSS stripped (jvectormap, swiper, fullcalendar, Samir overrides)
- Font: Outfit → system stack. Background: gradient → clean slate. user-select:none removed.

### Features Ported
- useColumnContextMenu hook + 53 list pages (from react-joint)
- useRecords/useRecord hooks, SlidePanel, QuickCreate, DataBrowserLink (from experiments)
- GrapeJS Page Designer + pdfme PDF Designer

### Sidebar Redesign
- Dark slate, unique lucide icons, WC3 branding, collapse at top
- Work: Dashboard, Kanban, Gantt | Forms: Contact, Customer, Proposal, Order, Invoice, Purchase | Dashboards: Products, Accounting, Alice, DataBrowser
- 200px/52px widths

### Alice Dashboard Additions
- Quiz tab (AliceQuiz.tsx) — Setting records name="alice-employee-qa-{topic}"
- CycleDetails, Page Designer, PDF Designer as tabs

### Backend
- CORS fix (5174-5177), manage_view wired adjust_item_quantity + get_pending_for_item
- Accounting + Inventory dashboard routes added to Router.tsx

### Architecture Decisions
- Athena baseline: client visual, server permanent
- REST for routing, wcapi for data (strictly enforced)
- Blockchain chain-key TODO (Alice #55), ColumnSetupDialog migration (Alice #56)

## Known Issues
1. Post-login redirect not firing (manual /dashboard works)
2. MAYBE_REMOVE.md has 14 items for Wednesday scrub

## Next Steps
1. Fix post-login redirect
2. Test Accounting + Products dashboards with live data
3. Seed sample Alice quiz Setting records
4. Build sales_dashboard + purchasing_dashboard backend services

## Vector Stores
IDs 27-34 pushed to claude_memory

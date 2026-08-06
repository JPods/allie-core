# Handoff — 2026-08-06

## Where We Left Off

Third session today. Rebuilt all four WC3 dashboards (Transactions, Orgs, Products, Administration) with comparison tables — all periods visible at once, no buttons to switch, every number clicks through to filtered DataBrowser. Added `purpose` field to BaseModel (CoreModel) so every record in WC3 declares why it exists. Created `get_dashboard_counts` batch endpoint (56 API calls → 1). Established session Document records (purpose=team_memory) as permanent team memory. Scar #34: look ahead for what you may need to look back on. Scar #35 (win): memory collection is the prerequisite for confident session closure. Session record: Document DEV-914.

## Do This First Next Session

1. **Verify dashboards load in Bill's browser** — hard refresh all four: /transactions, /orgs, /products, /administration. The batch endpoint `get_dashboard_counts` needs Django server restart to be available.
2. **Test clickable numbers** — click any number in a comparison table, verify DataBrowser opens with filtered records. The `cell()` function fix (not `Cell` component) was the key to making onClick work.
3. **Apply comparison table to Products dashboard** — Products was rebuilt by an agent but may need visual polish to match Transactions exactly.
4. **Create session Document record at session START** — new protocol. Purpose=team_memory. Update during work, not just at end.
5. **Check rate limiting** — the batch endpoint should eliminate 429s. If still hitting limits, check if Django's throttle settings need adjustment for the manage endpoint.

## Open Problems

- DataBrowser filter passthrough uses `urlFiltersRef` initialized on mount — only works for the first load of a window. Navigating to the same model with different filters reuses the existing window and ignores new params.
- Vite proxy `/orgs/` (trailing slash) is a workaround — any new dashboard route that collides with a proxy prefix will need the same treatment.
- wrapperPage.ts has `NotionTrackerPage` stubbed as Placeholder — dead import, was never a real component.
- React StrictMode doubles all API calls in dev — the batch endpoint mitigates but doesn't eliminate this.

## What Was Decided (and Why)

- **"Operations" renamed to "Administration"** — Bill: operations is sales/production, administration is back-office. Route is `/administration`.
- **No buttons to compare periods** — Bill: data that requires a click to compare is data that won't be compared. All periods visible simultaneously in a table.
- **`purpose` on BaseModel, not individual models** — 12 models already had it independently. Universal purpose enables purpose-driven data management across the entire system.
- **Session Document records (purpose=team_memory)** — text in the record body (searchable by Alice), images in `~/Allie/sessions/images/YYYY-MM-DD/` only when needed. Created during work, not after.
- **`cell()` function, not `<Cell>` component** — defining a component inside a render function causes React to remount it each render, dropping event handlers. Plain function returning JSX avoids this.
- **`/wcapi/get/` only, never `/wcapi/list/`** — single door to guard. list returns HTML, get returns JSON.
- **`useDashboardCounts` hook with batch fallback** — tries `get_dashboard_counts` manage action first, falls back to staggered individual fetches if batch fails.

## Files Changed This Session

- `React2025/src/apps/transactions/pages/TransactionsDashboard.tsx` — comparison table, batch hook, clickable cells
- `React2025/src/apps/orgs/pages/OrgsDashboard.tsx` — comparison table + comms panel
- `React2025/src/apps/products/pages/ProductsDashboard.tsx` — comparison table + tools
- `React2025/src/pages/admin/OperationsDashboard.tsx` — Administration dashboard, comparison table + accounting/sync panels
- `React2025/src/pages/admin/AccountingDashboard.tsx` — Promise.allSettled for resilience
- `React2025/src/hooks/useDashboardCounts.ts` — NEW: shared hook, batch endpoint + fallback
- `React2025/src/hooks/useDataBrowser.ts` — URL filter passthrough via urlFiltersRef
- `React2025/src/layout/AppSidebar.tsx` — Administration nav entry, route/icon/display maps
- `React2025/src/routes/Router.tsx` — added routes: orgs, transactions, products, operations, administration
- `React2025/src/routes/protectedRoutesConfig.tsx` — added routes + redirects
- `React2025/src/pages/wrapperPage.ts` — fixed NotFound import, stubbed NotionTracker
- `React2025/vite.config.ts` — /orgs proxy changed to /orgs/ (trailing slash)
- `webClerk3/common/models.py` — purpose field added to CoreModel
- `webClerk3/apps/docs/models/document.py` — removed redundant purpose (now inherited)
- `webClerk3/apps/core/services/dashboard_counts.py` — NEW: batch counts endpoint
- `webClerk3/apps/core/views/manage_view.py` — wired get_dashboard_counts action
- 11 model files — removed per-model purpose declarations (now on BaseModel)
- 10 migration files — purpose_to_basemodel migrations across all apps

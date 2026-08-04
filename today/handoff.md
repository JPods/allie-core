# Handoff — 2026-08-04

## Where We Left Off
Major UI layout restructure complete. AdminWorkbench renamed to DataBrowser. Four toolbar layers consolidated to two (db.header + unified toolbar row). MacWindowChrome title bar removed. Content padding eliminated. NavBar prefs-driven from `contact.prefs.nav`. Per-zone theming via `contact.prefs.color_mode`. TopBar controls unified as select lists (View, Font, Theme). Button style standardized on Minimal. Keyboard shortcuts wired (Cmd+S/N/Z/P, Escape). Zone tooltips (Shift+hover) added to all zones. Bill is pausing for a couple hours to review before committing — checking for anything missed.

## Do This First Next Session
1. **Test all changes in browser** — click through Contact, Customer, Order, Item. Verify list view, detail view (App + Admin modes), toolbar buttons work, keyboard shortcuts fire, zone tooltips appear on Shift+hover.
2. **Sign out and sign in** — verify `contact.prefs.nav` drives the NavBar (Work Order, Receipt, Payment should appear). Verify `contact.prefs.color_mode` persists.
3. **Test standalone detail routes** — `/contact/10634` should render with its own DetailToolbar (not hidden). The `inline` prop gates toolbar visibility.
4. **Commit both React2025 and webClerk3** — large session, many files changed across both repos.
5. **Update the 16 Display pages** — they import `{ DetailToolbar }` but don't yet respect the `inline` prop. Low priority since they're not in APP_DETAIL_COMPONENTS.

## Open Problems
- `useDefaultCompany` retries on 401 in a loop — needs max-retry guard
- Invoice #68 ida INV-101 — ida sequence diverged from id sequence
- DataGrid `doWrap` hardcoded to `false` — may need per-field opt-in for admin mode detail grid
- The `onRegisterActions`/`onEditStateChange` callbacks in detail components may cause React warnings about deps in useEffect — monitor console
- Old `AdminWorkbench` references may exist in readmes, comments, or CLAUDE.md files outside React2025

## What Was Decided (and Why)
- **AdminWorkbench → DataBrowser** — avoids confusion with Django admin for new users. NavBar already labeled it "DataBrowser".
- **Unified toolbar row** — list icons left, detail icons right, same row. Eliminates 60px of stacked toolbars. AdminWorkbench/DataBrowser owns both; detail components hide their toolbar when `inline=true`.
- **Minimal button style permanent** — text labels with emoji are readable at a glance, scale with font, no tooltip needed. Glass/OSX/Phosphor removed as options.
- **NavBar prefs-driven** — `contact.prefs.nav.models` and `.dashboards` control what each user sees. Defaults when absent. Sales vs Production vs Admin get different nav.
- **Per-zone theming** — `contact.prefs.color_mode.list` and `.detail` control dark/light independently. TopBar Theme selector saves to prefs via wcapi. CSS variables + JS theme objects both respond.
- **Cancel vs Discard** — Discard reverts edits but stays on record. Cancel closes the detail pane entirely, returning full width to the list.
- **Dangerous actions last** — Delete is always the rightmost button. Del Sel only visible when rows selected.
- **Zone names formalized** — TopBar, NavBar, db, db.header, db.toolbar, db.ListToolbar, db.DetailToolbar, db.list, db.detail. Shared vocabulary.
- **TopBar height fixed at 48px** — sidebar and content area aligned to match. Removed shadow.

## Files Changed This Session
**React2025:**
- `src/pages/admin/DataBrowser.tsx` — NEW (renamed from AdminWorkbench). Unified toolbar row, per-zone theming, keyboard shortcuts, zone tooltips
- `src/pages/admin/DataBrowser.css` — NEW (renamed). Per-zone theme CSS overrides, toolbar row styles, list left padding
- `src/pages/admin/AdminWorkbench.tsx` — DELETED
- `src/pages/admin/AdminWorkbench.css` — DELETED
- `src/pages/admin/DetailReview.tsx` — DELETED (dead code, build breaker)
- `src/components/common/DetailToolbar.tsx` — NEW (merged RecordToolbar + SimpleDetailToolbar)
- `src/components/common/RecordToolbar.tsx` — DELETED
- `src/components/common/SimpleDetailToolbar.tsx` — DELETED
- `src/components/common/ZoneTooltip.tsx` — NEW (Shift+hover zone name/class/file)
- `src/components/common/ToolbarIcon.tsx` — standardized on Minimal style
- `src/components/common/toolbarActions.ts` — added cancel, modelMenu actions
- `src/components/common/DataGrid.tsx` — doWrap forced false (single-line rows)
- `src/layout/MacTopBar.tsx` — fixed 48px height, removed shadow, View/Font/Theme selects, removed button cycler
- `src/layout/MacWindowChrome.tsx` — removed title bar and content padding
- `src/layout/AppSidebar.tsx` — prefs-driven nav, Models/Dashboards sections, top-48px alignment, zone tooltip
- `src/routes/PrivateRoute.tsx` — removed content padding, fixed sidebar width, ZoneTooltip mount, Show Nav → icon
- `src/routes/protectedRoutesConfig.tsx` — AdminWorkbench → DataBrowser imports
- `src/routes/Router.tsx` — AdminWorkbench → DataBrowser
- `src/routes/Routes.ts` — removed detailReview route
- `src/apps/core/models/contact/pages/ContactDetailJson.tsx` — inline prop, onRegisterActions, onEditStateChange, hide toolbar when inline, ida in form header
- `src/apps/orgs/components/OrgDetail.json.tsx` — same pattern as ContactDetailJson
- `src/apps/products/pages/ItemDetailJson.tsx` — same pattern
- 16 Display pages — import renamed from SimpleDetailToolbar to DetailToolbar
- `src/apps/transactions/components/TransactionDetail.tsx` — AdminWorkbench → DataBrowser ref
- `src/components/common/RelatedDialog.tsx` — AdminWorkbench → DataBrowser ref
- `src/components/common/ReportsDialog.tsx` — AdminWorkbench → DataBrowser ref
- `src/hooks/useReportShortcuts.ts` — AdminWorkbench → DataBrowser ref

**webClerk3:**
- Contact #2373 prefs updated: `nav.models`, `nav.dashboards`, `color_mode`
- Action #31135 created: hide single-window tab (due 2026-08-18)
- Action #31136 created: TopBar show/hide toggle (due 2026-08-18)

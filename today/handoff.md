# Handoff — 2026-08-04

## Where We Left Off
Massive UI layout restructure complete. AdminWorkbench renamed to DataBrowser. Unified toolbar row (list left, detail right). NavBar prefs-driven. Per-zone theming. Minimal button style permanent. Keyboard shortcuts. Zone tooltips (Shift+hover, 3s auto-hide). App/Admin view toggle fires custom event for live switching. All transaction models + display models added to APP_DETAIL_COMPONENTS. Gantt sprint selector built from contact.prefs.gantt.categories (wc3, moa). Login/me endpoints fixed to return Contact prefs (not empty User prefs). ui_webclerk Setting created. Kanban buttons partially standardized. Context compression warning protocol established.

## Do This First Next Session
1. **Action #31137 — Kanban: swap KanbanTaskModal for ActionFloatingWindow** — The floating window (DynamicDetail, draggable) is already working in Gantt. Kanban still uses the old modal that covers cards. Due Aug 6.
2. **Test the full flow** — sign out/in, verify prefs load (nav, color_mode, gantt categories), test App/Admin toggle on proposals/orders/contacts, test Gantt "My Sprints" dropdown.
3. **Commit both repos** — React2025 and webClerk3 have many uncommitted changes from this session.
4. **Action #31135 — hide single-window tab** — due Aug 18.
5. **Action #31136 — TopBar show/hide toggle** — due Aug 18.

## Open Problems
- `useDefaultCompany` retries on 401 in a loop — needs max-retry guard
- DataGrid `doWrap` hardcoded to `false` — may need per-field opt-in for admin detail grid
- The `onRegisterActions`/`onEditStateChange` callbacks may cause React warnings about deps
- 16 Display pages don't yet check `inline` prop — works because they're not in APP_DETAIL_COMPONENTS
- Kanban still uses KanbanTaskModal instead of ActionFloatingWindow (Action #31137)
- Communication Display pages (address, domain, email, phone) don't exist yet — fall through to Admin mode
- ActionDisplay.tsx doesn't exist — action model falls through to Admin mode in DataBrowser

## What Was Decided (and Why)
- **AdminWorkbench → DataBrowser** — avoids Django admin confusion
- **Zone names** — TopBar, NavBar, db, db.header, db.toolbar, db.list, db.detail. Shared vocabulary.
- **Minimal button style permanent** — text+emoji, readable, scales. Glass/OSX/Phosphor removed.
- **One control, one place** — no duplicate toggles anywhere
- **Left-justified toolbars** — dangerous actions (Delete) last
- **Prefs-driven personalization** — contact.prefs.nav, .color_mode, .gantt, .ui
- **contact.config vs contact.prefs** — config = data structure, prefs = user experience
- **ui_webclerk Setting #533** — installation defaults for all UI behaviors (zone_tooltip_ms, search_min_chars, etc.)
- **Login endpoint returns Contact prefs** — was returning empty User prefs. Fixed in auth_views.py.
- **Cancel vs Discard** — Discard reverts edits (stays on record), Cancel closes detail pane
- **Gantt sprint selector** — contact.prefs.gantt.categories drives last/current/next by dt_start/dt_end
- **Context compression warning** — Claude tells Bill straight when compression starts. No politeness. He decides.

## Files Changed This Session
**React2025:**
- `src/pages/admin/DataBrowser.tsx` — renamed from AdminWorkbench; unified toolbar; per-zone theme; keyboard shortcuts; viewPref as state; APP_DETAIL_COMPONENTS expanded
- `src/pages/admin/DataBrowser.css` — per-zone theme CSS; toolbar row styles; list padding
- `src/pages/admin/AdminWorkbench.tsx` — DELETED
- `src/pages/admin/AdminWorkbench.css` — DELETED
- `src/pages/admin/DetailReview.tsx` — DELETED
- `src/components/common/DetailToolbar.tsx` — NEW (merged RecordToolbar + SimpleDetailToolbar)
- `src/components/common/RecordToolbar.tsx` — DELETED
- `src/components/common/SimpleDetailToolbar.tsx` — DELETED
- `src/components/common/ZoneTooltip.tsx` — NEW (3s auto-hide, reads ui_webclerk Setting)
- `src/components/common/ToolbarIcon.tsx` — standardized on Minimal
- `src/components/common/toolbarActions.ts` — added cancel, modelMenu
- `src/components/common/DataGrid.tsx` — doWrap forced false
- `src/layout/MacTopBar.tsx` — 48px fixed; View/Font/Theme/SavePrefs selects; removed button cycler, shadow
- `src/layout/MacWindowChrome.tsx` — removed title bar and padding
- `src/layout/AppSidebar.tsx` — prefs-driven nav; Models/Dashboards; top-48px; zone tooltip
- `src/routes/PrivateRoute.tsx` — removed padding; fixed sidebar width; ZoneTooltip; Show Nav icon
- `src/routes/protectedRoutesConfig.tsx` — AdminWorkbench → DataBrowser
- `src/routes/Router.tsx` — AdminWorkbench → DataBrowser
- `src/routes/Routes.ts` — removed detailReview
- `src/apps/core/models/contact/pages/ContactDetailJson.tsx` — inline/callbacks/hide toolbar
- `src/apps/orgs/components/OrgDetail.json.tsx` — same
- `src/apps/products/pages/ItemDetailJson.tsx` — same
- `src/apps/utils/gantt/UnifiedGanttPage.tsx` — removed breadcrumb
- `src/apps/utils/gantt/UnifiedGantt.tsx` — ganttPrefs + auth user
- `src/apps/utils/gantt/GanttProjectSelector.tsx` — My Sprints dropdown; category/date sprint lookup
- `src/apps/utils/gantt/useGanttData.ts` — category/dt_start/dt_end in ProjectOption
- `src/apps/utils/kanban/KanbanBoardPage.tsx` — Minimal buttons; standardized selects
- `src/hooks/useDataBrowser.ts` — 3-char search minimum
- 16 Display pages — import renamed to DetailToolbar
- Multiple files — AdminWorkbench → DataBrowser references

**webClerk3:**
- `apps/core/views/auth_views.py` — login + /me/ return Contact prefs (not User prefs)
- `apps/core/choices.py` — added ui_webclerk to SETTING_PURPOSE_CHOICES
- Contact #2373 prefs: nav, color_mode, gantt categories
- Setting #533 ui_webclerk — full UI behavior config
- 24 DEV projects → category='wc3'; 10 MOA projects → category='moa'
- Action #31135 (single-window tab), #31136 (TopBar toggle), #31137 (Kanban modal swap)

**Allie:**
- `readmes/leftshoe.md` — context compression warning protocol
- `readmes/retrospections/2026-08-04.md` — full session retrospection
- `today/handoff.md` — this file
- Memory: feedback_ui_design_principles.md, project_databrowser_layout.md, feedback_compression_warning.md
- Identity store: 2 scars, 4 judgments, 1 value (compression warning)
- Retro DB: entry #31

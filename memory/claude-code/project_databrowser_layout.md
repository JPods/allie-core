---
name: DataBrowser layout restructure — 2026-08-04
description: AdminWorkbench renamed DataBrowser; unified toolbar row; prefs-driven NavBar; per-zone theming; Minimal buttons; keyboard shortcuts; zone tooltips
type: project
---

Major UI layout restructure completed 2026-08-04.

**Rename:** AdminWorkbench → DataBrowser (src/pages/admin/DataBrowser.tsx + .css)

**Zone names:** TopBar, NavBar, db, db.header, db.toolbar, db.ListToolbar, db.DetailToolbar, db.list, db.detail, db.detail.form

**Toolbar structure:**
- db.header: model picker + search + Layout dropdown + Save
- db.toolbar: unified row — list icons (left) | divider | detail icons (right)
- Detail toolbar sequence: Add, Save, Discard, Cancel, Print, Menu, #id, Delete
- Minimal text+emoji button style (permanent)
- Del Sel only visible when rows selected

**Prefs-driven:**
- `contact.prefs.nav.models` / `.dashboards` — NavBar sections
- `contact.prefs.color_mode.list` / `.detail` — per-zone dark/light
- TopBar select lists: View (App/Admin), Font (10-18), Theme (list/detail)

**Keyboard shortcuts:** Cmd+S, Cmd+N, Escape, Cmd+Z, Cmd+P, Cmd+Shift+M

**Zone tooltips:** Shift+hover → zone name, CSS class, component file (ZoneTooltip.tsx)

**Why:** Recovered ~130px of vertical toolbar/chrome space. Data dominates the screen. Role-based personalization via prefs.

**How to apply:** All future UI work follows the four design principles (one control one place, left-justified, dangerous last, prefs-driven). See feedback_ui_design_principles.md.

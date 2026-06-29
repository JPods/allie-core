---
name: DataBrowser status 2026-06-28
description: wc3 DataBrowser built — two-pane, dark/light, model picker, layouts, 61 models seeded; replaces 40+ admin shell pages
type: project
---

DataBrowser built at React2025/src/pages/admin/AdminWorkbench.tsx (route: /admin-wb).

**What it does:** Two-pane (list + detail), dark/light mode (JPods Console palette), model picker with Cmd+Shift+M, server-side search + pagination, column sort/drag/resize, saved named layouts, subset show/omit, CSV export, font size S/M/L toggle, collapsible field config panel.

**Why:** Replaces wc2's 4D DataBrowser. Admin-managed models (40+) no longer have dedicated React pages — they redirect to DataBrowser. User-facing models (Customer, Item, Invoice, Order, etc.) keep dedicated pages.

**How to apply:** Sidebar links go directly to /admin-wb?model=X. Shift-click ANY sidebar model opens in DataBrowser (power user). 61 models have curated "initial" layouts seeded via seed_databrowser command. 31 models have fake "zz" records for testing.

---
name: No List.tsx — DataBrowser is the only list engine
description: Hard rule — no custom ModelList.tsx files; all lists rendered by DataBrowser at /db/:model; forces DataBrowser polish to fill all list needs
type: feedback
---

No ModelList.tsx files. DataBrowser is the only list rendering engine. All models use `/db/:model` for their list view.

**Why:** 35+ custom list files all doing the same thing differently — fetch records, show columns, click to open. That's exactly what DataBrowser does, configured by Setting records. Custom list files create drift, duplicate bugs, inconsistent UX. Forcing everything through DataBrowser means one place to fix bugs, one place to add features, one component to polish.

**How to apply:**
- Sidebar links go to `/db/model` (route param, not query string)
- DataBrowser reads model from route param via `useParams`
- Row click cascades: (1) if model has Detail.tsx and detail_mode='custom', navigate to detail page; (2) otherwise open DataBrowser's inline detail pane
- Column config, layouts, subforms all via Setting records per model
- CSS handles visual differentiation between models — not separate components
- Existing ModelList.tsx files are dead code — do not maintain, do not extend
- When DataBrowser can't do something a list page needs, fix DataBrowser — don't build a custom list

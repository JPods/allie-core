---
name: UI design principles — established 2026-08-04
description: Four codified UI rules from the DataBrowser/toolbar restructure session; apply to all WC3 UI work
type: feedback
---

1. **One control, one place** — no duplicate toggles. If a setting appears in TopBar, don't repeat it in db.header.
   **Why:** Light/Dark toggle was in two places, causing confusion and sync bugs.
   **How to apply:** Before adding a UI control, check if it already exists elsewhere. Remove the duplicate.

2. **Left-justified toolbars** — all toolbar buttons flow from the left. No right-floating action groups.
   **Why:** Established during toolbar consolidation. Consistent, predictable, clips gracefully when narrow.
   **How to apply:** Never use spacer+float-right for toolbar buttons. Dangerous actions go last (rightmost) but still left-justified.

3. **Dangerous actions last** — Delete is always the last button in any toolbar row.
   **Why:** Hardest to hit accidentally when it's at the end. If the pane narrows, it clips first.
   **How to apply:** Delete at end of detail toolbar, Del Sel at end of list toolbar (and only visible when rows selected).

4. **Prefs-driven personalization** — user preferences stored in `contact.prefs.*`, not just localStorage.
   **Why:** Survives across devices, can be role-based. Pattern: `contact.prefs.nav.models`, `contact.prefs.color_mode`.
   **How to apply:** Extend to layouts, font size, density. TopBar select lists save to prefs via wcapi.

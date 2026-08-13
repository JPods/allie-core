---
name: config vs prefs boundary
description: .config = system choices (admin/Alice), .prefs = user choices (individual) — never mix
type: feedback
---

`.config` is system-level — admin/Alice sets, same for everyone. Layout definitions, card metric formulas, edit rules, dashboard structure.

`.prefs` is user-level — each user sets their own. Which cards to show, theme, font size, nav items, color mode.

**Why:** Config is the menu, prefs is the order. Setting records hold .config (what's available). Contact records hold .prefs (what this user chose). Mixing them breaks role separation.

**How to apply:** When adding a new feature, ask: "Does the system define this, or does the user choose it?" System → Setting.config. User → contact.prefs. If both, the Setting.config defines the options and contact.prefs stores the selection.

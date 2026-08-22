---
name: Cards vs Panels distinction
description: Cards are data entry/display for a single record; Panels are lists of related records. Cards can contain Panels. Panels contain Cards as row renderers.
type: feedback
---

Cards = data entry / display of a single record's fields (like a form, but floating or grouped).
Panels = lists of related records (actions, documents, transactions, serials, etc.).

**Why:** The boundary was blurry (ItemDashboard classified as both). Bill clarified: it's not blurry — panels contain cards as row renderers, and cards can contain panels as embedded lists. The nesting is correct, the categories are distinct.

**How to apply:** When naming or creating components: if it shows one record's fields, it's a Card. If it lists multiple records, it's a Panel. A card that embeds a list of sub-records contains a Panel. A panel that renders each row with detail fields uses Cards. Naming convention enforces the rule — no separate documentation needed in code.

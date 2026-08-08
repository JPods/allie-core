---
name: Six rendering contexts under ui.json
description: db.list, db.detail, db.page, db.card, db.panel, ui.tsx — memorable, teachable naming for all rendering contexts
type: feedback
---

ui.json is the system. Six rendering contexts for the same model data:

```
ui.json              — the system
  db.list            — list of records (databrowser left pane)
  db.detail          — one record, databrowser right pane (compact)
  db.page            — one record, full page (replaces .tsx detail pages)
  db.card            — floating snapshot (kanban, gantt, chip click)
  db.panel           — embedded list inside another model's detail
  ui.tsx             — custom React, messy, we accept it
```

**Why:** Bill confirmed 2026-08-07: "memorable and teachable." db.page is a page — not a pane, not a card. db.detail is the pane next to the list. db.card doesn't disturb the workflow — it's a peek, not a navigation.

**How to apply:** Each context gets its own layout definition (Report record with matching purpose). Same model, same field_access RBAC, different fields shown. The Data-Driven UI renderer picks the right layout for the context. All under ui.json except ui.tsx which is custom React for complex interaction.

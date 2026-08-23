---
name: Layout architecture consolidated
description: All layout data in one wc:model Setting per model — list, detail, form sections; label=field name; comments.process everywhere
type: project
---

Layout architecture consolidated 2026-08-20. One wc:model Setting per model — no separate wc:detail_layout records.

**Why:** Two Settings per model (wc:model + wc:detail_layout) caused drift and confusion. Users editing layouts shouldn't need to know about a second record with a different purpose key. React had two fetch paths.

**How to apply:**
- `config.layout.list.default.columns` — list view columns
- `config.layout.detail.default.fields` — detail fields (human → JSON → system order)
- `config.layout.form.default` — form sections (header, panels, json_tree, tabs)
- `useDetailLayout` hook reads from `wc:model`, not `wc:detail_layout`
- Labels = field names lowercase; dot-paths use `.leaf`; bracket notation for arrays (`action[0]`)
- `comments.process` on every model's list columns
- `comment` TextField dropped from 5 models; `comments` JSONField is the only notes field
- Seed: `seed_model_definitions --force` then `seed_detail_layouts`
- Full doc: `WebClerk/backend/readmes/topics/architecture/layout-architecture.md`

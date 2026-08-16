---
name: CodeMap flowchart pipeline
description: Standard pipeline for creating/updating flowcharts — .dot source → Graphviz render → Affinity enrich → codemap publish
type: reference
---

Flowchart pipeline — four steps, two locations:

**Source of truth:** `readmes/flowcharts/`
- `wc3-NN-section-name.dot` — Graphviz source (edit here)
- `wc3-NN-section-name.dot.svg` — raw Graphviz render (intermediate, regeneratable)
- `wc3-NN-section-name.enriched.svg` — Affinity Designer polished version (Bill edits colors, layout, labels)

**Published copy:** `sites/codemap/images/<short-name>.svg`
- Copied from `.enriched.svg` after Bill approves
- `index.html` references these by short name

**Steps:**
1. Edit `.dot` in `readmes/flowcharts/`
2. Render: `dot -Tsvg <file>.dot -o <file>.dot.svg`
3. Bill opens `.dot.svg` in Affinity Designer, adjusts, saves as `.enriched.svg`
4. Copy `.enriched.svg` → `sites/codemap/images/<short-name>.svg`

**Naming convention:** `.dot` files use full prefix `wc3-NN-section-name`. Codemap images use short descriptive names (e.g., `inventory-buckets.svg`, `big4-transactions.svg`).

**codemap site:** `sites/codemap/` within Allie repo (not a separate git repo). Served from codemap.guru.

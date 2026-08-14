---
name: Data-Driven UI architecture
description: datadrivenui.com — 45K→2K line reduction; DynamicDetail + ui.json layouts + Settings hierarchy; documented in Allie + WC3 readmes
type: project
---

Data-Driven UI (datadrivenui.com) — the architectural shift from code-per-model to data-per-model. 45,091 lines of hand-coded React detail pages replaced by ~1,759 lines of JSON-driven rendering.

**Why:** Each model had its own .tsx detail page (~400 lines each). Adding or changing fields required code changes, builds, deployments. Now one DynamicDetail component renders any model from a JSON layout stored as a Setting.

**How to apply:**
- Three UI paths: ui.json (DynamicDetail), db.json (DataBrowser), ui.tsx (custom — only for complex interaction)
- Every model is exactly one path — see model-ui-map.md
- New models get detail pages by adding a Setting record with layout JSON, not code
- Design Mode lets users edit layouts visually
- Settings scope: user → role → org → system
- Archive at React2025/src/archive/replaced-2026-08-03/ for research
- Docs duplicated: ~/Allie/readmes/data-driven-ui.md AND webClerk3/readmes/topics/architecture/data-driven-ui.md — update both
- **Bill's strong preference (2026-08-14):** as much JSON-driven and as little .tsx as practical. Kanban may be an exception (drag-and-drop interaction) — revisit once everything else is JSON-driven

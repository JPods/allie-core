---
name: db.panel unification
description: All embedded panels unified to PanelTable; db.panel Setting stores column specs; 30 models seeded; yellow selection indicator added
type: project
---

## Panel unification complete (2026-08-12)

All embedded panel rendering unified to **PanelTable** component with consistent styling.

**What was converted:**
- **RelatedPanel** (DataBrowser.tsx) — DataGrid → PanelTable; reads child model's `config.db.panel` from workbench_fields Setting; auto-detects columns as fallback
- **ContactDetailJson organizations tab** — DataGrid → PanelTable with explicit ORG_PANEL_COLUMNS
- **TabsRenderer.tsx** (5 tabs) — Actions, Contacts, Documents, Related, QA tabs all converted from DataGrid → PanelTable

**New files:**
- `WebClerk/frontend/src/apps/common/components/panels/panelColumnUtils.ts` — `buildColumnsFromSpecs()` (from db.panel Setting) and `buildColumnsFromRecord()` (auto-detect fallback)
- `WebClerk/backend/apps/core/management/commands/seed_panel_columns.py` — seeds db.panel for 30 models

**Architecture:**
- `db.panel` field stays named `panel` in `DbLayout` (setting.py) — "panels" is the standard term
- Column specs stored at `config.db.panel[]` on workbench_fields Settings
- PanelTable has `selectedKey` + `onSelectRow` props for yellow selection indicator (#fff3cd, matches DataGrid)
- Blue indicator bar (4px) on selected row
- FieldOrderDialog (slider icon) lets users show/hide and reorder panel columns
- `storageKey` pattern: `panel:${parentModel}:${childModel}`

**Seed command:** `./venv/bin/python manage.py seed_panel_columns [--force]`

**Why:** Three different panel styles (inline DataGrid, RelatedPanel DataGrid, custom components) created inconsistent light/dark mode rendering. One component, one style.

**How to apply:** Any new panel showing tabular data should use PanelTable. Non-tabular content (CommPanel, CommentsPanel, Kanban, Gantt) stays as custom components.

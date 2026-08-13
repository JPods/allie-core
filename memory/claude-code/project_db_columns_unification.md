---
name: db.columns panel unification
description: Unified column management (useListFieldConfig + FieldOrderDialog); db.list vs db.columns architecture; FK filter fix; next session = panel style unification
type: project
---

## Column management unified (2026-08-12)

One approach to column management everywhere in WC3 React:
- **Hook:** `useListFieldConfig` (src/hooks/useListFieldConfig.ts)
- **Dialog:** `FieldOrderDialog` (src/components/common/FieldOrderDialog.tsx) — default export
- **Deleted:** ColumnSetupDialog_DEPRECATED (855 lines), ColumnSetupDialog shim, useColumnSetups (370 lines)
- **Two consumers:** PanelTable (panels) and ButtonToolbar (list pages)

Architecture:
- **db.list** = columns + toolbar (ButtonToolbar) — list pages
- **db.columns** = columns, no toolbar (PanelTable / RelatedPanel) — all panels

## FK filter fix (2026-08-12)

- FK_PATTERNS for contact→email/phone/address/domain: changed `contact_id` → `contact` (Django ORM field name, not DB column)
- Removed broken refs.links fallback in RelatedPanel — it silently returned ALL records when FK query returned 0
- ADDRESS went from (50) to (0), DOMAIN from (9) to (0) for contacts with no related records

## TOUCH/RELATED bars relocated

- Moved from top of detail pane to below contact fields in DataBrowser.tsx
- Now between GroupedDetailFields and RelatedPanels

## Next session: panel style unification

Three panel styles currently exist — must become one (db.columns):
1. Tab panels in ContactDetailJson.tsx (green borders, custom components)
2. RelatedPanels in DataBrowser.tsx (DataGrid columns) — this is the target style
3. Orgs panel (Filter/Dupes/CSV/Excel/Print toolbar)

**Why:** All panels are the same except the content. Same column behavior, different data.

**How to apply:** Convert tab panel content to RelatedPanel/PanelTable instances. Keep tab navigation. Also: pass fieldSpecs/fieldBehaviors to DataGrid in RelatedPanel for phone formatting.

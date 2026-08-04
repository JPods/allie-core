# Handoff — 2026-08-03

## Where We Left Off
AdminWorkbench App/Admin toggle working. Single click on db.list selects a record and renders the JSON-driven detail component (ContactDetailJson, OrgDetailJson, ItemDetailJson) in the right panel. All three components accept `recordId` from AdminWorkbench. OrgDetailJson receives `modelName` from `db.selectedModel`. Screenshot confirmed: Sarah Chen contact #10630 rendering with 3-column header, communications tab, toolbar — all functional. 48,000 lines of monolith detail pages reduced to ~2,000 lines across three orchestrators plus single-purpose component hierarchies.

## Do This First Next Session
1. **Polish RecordToolbar** — tighten button spacing, move Delete into model menu dropdown, replace model name label with gear icon. Minor CSS/layout work.
2. **Dark mode consistency** — ContactDetailJson renders light inside dark AdminWorkbench. Match the parent theme or inherit from AdminWorkbench context.
3. **Transaction detail layouts** — seed detail_layout Settings for workorder, receipt, requisition, payment. Same pattern as order/invoice/proposal/purchase.
4. **Item search on line card** — keyword fragment search (like customer search) to add items to transaction lines with pricing from price matrix. Primary workflow gap.
5. **Transaction flow** — order → invoice, order → PO posting. Menu actions that create child documents with line transfer.

## Open Problems
- `useDefaultCompany` retries on 401 in a loop — needs max-retry guard
- Invoice #68 ida INV-101 — ida sequence diverged from id sequence
- Proposal/invoice customer fields empty on initial load when customer_id exists but no denormalized company/phone/attention
- `schema_map` purpose not in SETTING_PURPOSE_CHOICES
- Alice console capture retry loop on 500 needs disable
- OrgDetailJson communications tab blank when no `contact_id` — needs empty state

## What Was Decided (and Why)
- **`recordId` as universal prop** — AdminWorkbench passes `recordId` and `modelName` to all detail components. Components also accept their legacy prop names (contactId, itemId) for backward compatibility with Router routes. One interface, two entry points.
- **Three rendering paths: ui.json, ui.tsx, db.json** — every model assigned to exactly one path. ui.json for standard CRUD with layout Settings. ui.tsx for interaction-heavy views (Kanban, Apply Payments). db.json for admin/config models via DataBrowser.
- **"Definitions first" principle** — established as team practice. Define name, purpose, boundaries, location, owner before writing code. Prevents architectural drift.
- **Single-purpose component hierarchies** — CommCard→CommList→CommPanel, BomCard→BomPanel, SerialCard→SerialPanel, ProductListPanel as generic container. Each component does one thing.

## Files Changed This Session
**React2025:**
- `src/apps/core/models/contact/pages/ContactDetailJson.tsx` — NEW: replaces 4,114-line ContactDetail.tsx
- `src/apps/orgs/components/OrgDetail.json.tsx` — NEW: serves 5 org models from one component
- `src/apps/orgs/components/OrgCard.tsx`, `OrgPanel.tsx`, `index.ts` — NEW: org component hierarchy
- `src/apps/products/pages/ItemDetailJson.tsx` — NEW: replaces 2,968-line ItemDetail.tsx
- `src/apps/products/components/` — NEW: BomCard/Panel, SerialCard/Panel, WarehouseCard, VariantCard, XRefCard, SpecCard, ProductListPanel, index.ts
- `src/apps/communications/components/` — NEW: CommCard, CommList, CommPanel, index.ts
- `src/components/common/RecordToolbar.tsx` — NEW: universal toolbar for all ui.json pages
- `src/hooks/useDetailLayout.ts` — added invalidate() for Design Mode
- `src/pages/admin/AdminWorkbench.tsx` — APP_DETAIL_COMPONENTS restored with JSON components, modelName prop passed
- `src/routes/protectedRoutesConfig.tsx` — all old detail imports replaced
- `src/apps/common/components/panels/index.ts` — cleaned dead exports

**webClerk3:**
- `apps/core/management/commands/seed_comm_layouts.py` — seeds 19 detail_layout Settings
- `readmes/topics/architecture/ui-db-map.md` — complete model→rendering path registry
- `readmes/topics/architecture/contact-field-map.md` — wc2→wc3 field mapping

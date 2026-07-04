# Handoff — 2026-07-04

## Where We Left Off
Built the complete commerce service layer: BOM (expand/consume/propagate), serial lifecycle (12 operations), inventory layers (FIFO/LIFO/avg costing with WC2 bug fix, split/transfer/count), price resolver (6-level cascade with margin floor alerts that don't block shipment), margin velocity as real Item fields, sales + purchasing dashboards, inventory reservations replacing WC2's fake-invoice hack. Also built DataBrowser improvements (doSafeSelect, reset layout, CSS migration, 16 field widgets, DataGrid tree mode, JSON viewer with cross-window BroadcastChannel, clickable JSON labels). Alice coaching permissions (none/receive_only/send_only/full) and commerce dashboard design (4 tabs, shared filter bar) defined. All stored in Allie + Alice vector stores (39 observations, 15+ lessons).

## Do This First Next Session
1. Alice trains Bill on BOM, serials, pricing, inventory — quiz material is loaded (8 BOM questions + training module across 5 topics)
2. Test DataBrowser in browser — CSS migration, field widgets, tree mode, JSON viewer all committed but not browser-tested
3. Wire Commerce Dashboard React page — backend services exist (sales_dashboard.py, purchasing_dashboard.py), needs the 4-tab React component with shared filter bar
4. Run `update_item_margin_velocity()` after some sales data exists to see real velocity scores
5. Add `wchq_coaching_level` field to Alice's Setting record (none/receive_only/send_only/full, default receive_only)

## Open Problems
- BehaviorField still uses inline styles (field widgets are CSS but BehaviorField legacy paths aren't migrated)
- DataGrid still receives theme as JS object (child component CSS migration is next)
- Per-user layout persistence deferred — Setting model needs contact_id FK (separate PR)
- Version conflict checking still disabled in save_view.py
- Invoice type enum not yet added to Invoice model
- AuditLog model exists but nothing auto-writes to it
- `inventory_reservations.py` references old field names in the model (`stack` → needs audit that model FK names match)

## What Was Decided (and Why)
- **Layer not stack** — layers accumulate, erode, split. Stack implies push/pop which is wrong for inventory that gets partially consumed and transferred.
- **Margin velocity as real fields** — too important for JSON. Four indexed columns on Item (margin_velocity, margin_pct, annual_turns, velocity_category) so DataBrowser can sort/filter.
- **Below-margin alerts never block shipment** — flag and ship, review in dashboard. Commerce must flow.
- **UUID immutable after creation** — CoreModel.save() rejects changes. UUID is the product's identity across all systems.
- **ida never null** — defaults to string of id via generate_ida(pk). Setting record may have custom ida rules.
- **One UUID per product regardless of vendor** — Ingrid resolves identity first, maps vendors via ItemXRef/OrgItem second.
- **Price cascade is first-match-wins, no stacking** — locked→OrgItem→catalog→price_level→base. One path wins.
- **refs.links for all relationships** — layer lineage (parent_layer_id, child_layer_ids, split_from, transfer_from), serial linkage, all use the same pattern.
- **JSON viewer as standalone window** — spawned from DataBrowser, receives cross-window updates via BroadcastChannel. JSON labels clickable like email/phone labels.
- **Commerce Dashboard = one page, four tabs** — Sales/Purchasing/Inventory/Velocity with shared filter bar. Small business users see everything in one place.
- **Alice WCHQ coaching = metadata only** — navigation patterns and layouts shared, never business data. Framed like Claude's "can we use your conversation to improve."

## Files Changed This Session

### webClerk3 (Django backend)
- `common/models.py` — UUID immutability + ida never-null in CoreModel.save()
- `apps/core/constants/filter_operators.py` — NEW: single source of truth for allowed query lookups
- `apps/core/views/wcapi.py` — imports ALLOWED_LOOKUPS, eliminates duplication
- `apps/products/models/item.py` — margin_velocity, margin_pct, annual_turns, velocity_category fields
- `apps/products/models/catalog.py` — priority, applies_to, is_universal_pct, margin_floor, scope, adjustment_type on CatalogLine
- `apps/products/models/bill_of_material.py` — unchanged (already solid)
- `apps/products/services/bom_services.py` — expand_tree, propagate_cost_up, consume_bom, find_top_level_assemblies, calc_net_build_qty
- `apps/products/services/serial_services.py` — NEW: 12 serial lifecycle operations
- `apps/products/services/inventory_services.py` — NEW: 13 operations (costing, layers, counting, margin velocity)
- `apps/products/services/inventory_reservations.py` — rewritten: order allocation workflow, fixed field names
- `apps/products/services/price_resolver.py` — NEW: 6-level pricing cascade with margin floor alerts
- `apps/products/services/sales_dashboard.py` — NEW: sales metrics by period/salesperson/rep/customer
- `apps/products/services/purchasing_dashboard.py` — NEW: purchasing metrics by period/vendor/buyer/warehouse
- `apps/products/views/bom_views.py` — 4 new endpoints (expand, consume, where-used, propagate-cost)
- `apps/products/urls.py` — routes for new BOM endpoints
- `apps/products/readmes/bom_operations.md` — NEW: full BOM operations guide
- `apps/products/migrations/0007_*` — margin velocity fields
- `apps/products/migrations/0008_*` — catalog pricing fields
- `readmes/topics/wc2/wc2-harvest-matrix.md` — NEW: 100+ features mined from WC2 + 4D examples
- `readmes/topics/wc2/wc2-harvest-plan.md` — NEW: 5-stage implementation roadmap

### React2025 (frontend)
- `src/pages/admin/AdminWorkbench.tsx` — full CSS migration (zero inline styles)
- `src/pages/admin/AdminWorkbench.css` — NEW: CSS custom properties for both themes
- `src/pages/admin/JsonViewer.tsx` — NEW: standalone JSON viewer window
- `src/pages/admin/JsonViewer.css` — NEW: JSON viewer styles
- `src/components/fields/*` — NEW: 16 standalone field widgets + BaseField + types + CSS + registry
- `src/components/common/BehaviorField.tsx` — typeHint + error props
- `src/components/common/DataGrid.tsx` — tree mode (treeColumn, levelField, childFlag)
- `src/constants/filterOperators.ts` — NEW: operator vocabulary
- `src/constants/widgetTypes.ts` — NEW: widget type schema (16 types)
- `src/hooks/useDataBrowser.ts` — doSafeSelect, resetLayout, validation, cross-window broadcast
- `src/utils/validateRecord.ts` — NEW: client-side validation with error accumulation
- `src/utils/windowChannel.ts` — NEW: BroadcastChannel cross-window messaging
- `src/routes/Routes.ts` — json-viewer route
- `src/routes/protectedRoutesConfig.tsx` — JsonViewer component wired

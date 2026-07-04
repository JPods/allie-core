# Handoff — 2026-07-04

## What Was Done This Session (2026-07-03/04)

### Mining (3 sweeps)
- Sweep 1: WC2 features (38 method clusters, 20 Vue2020 routes, 19 TableForm workflows, 10 WC2 class patterns, 40+ 4D example projects)
- Sweep 2: Gap analysis (WC3 current vs mined patterns — 6 high, 6 medium priority gaps)
- Sweep 3: Staged implementation plan (5 stages, 35 items)
- Documents: `webClerk3/readmes/topics/wc2/wc2-harvest-matrix.md` + `wc2-harvest-plan.md`

### DataBrowser Improvements (7 items + CSS migration)
1. doSafeSelect after delete — select adjacent record
2. Reset Layout button — loads initial/alice_guess view
3. Operator vocabulary — `filterOperators.ts` + `filter_operators.py` (single source of truth)
4. Widget type schema — `widgetTypes.ts` (16 types with defaults)
5. typeHint override on FieldSpec
6. Client-side validation — `validateRecord.ts` accumulates all errors
7. Full CSS migration — zero inline styles in AdminWorkbench.tsx, all via CSS custom properties

### Field Widget Suite (16 components)
- `React2025/src/components/fields/` — standalone, reusable, point at any field
- `getWidget(typeName)` registry + `renderField()` dynamic entry point
- The field_access Setting IS the instruction set — Alice controls rendering

### BOM System (operational)
- 5 new services: expand_tree, propagate_cost_up, consume_bom, find_top_level_assemblies, calc_net_build_qty
- 4 new API endpoints
- DataGrid tree mode (treeColumn + levelField + childFlag)
- Live example: BB200 Baseball Kit multi-level BOM working
- Readme: `webClerk3/apps/products/readmes/bom_operations.md`

### Serial Number Services (built)
- 12 operations in `serial_services.py`
- Status lifecycle: available→issued→returned | available→referenced
- Warranty at issue time, search by customer/vendor, full audit log

### Architecture Decisions
- Spawn pattern: desktop=window.open, mobile=tabs, driven by spawn_links in field_access Setting
- JSON-schema-defines-forms confirmed as r25 foundation
- CSS > inline styles (Bill directive)
- Time tracking = outside apps/APIs
- 95 models exist; only 10 new ones needed; gap is workflows not models

## Alice Training Ready
5 topics, 8 quiz questions loaded. Alice trains Bill tomorrow.

## Next Steps
1. Alice trains Bill on DataBrowser + BOM + Serials + Widgets + Spawn pattern
2. Wire BOM tree view into DataBrowser
3. Wire serial services to API endpoints + DataBrowser with spawn_links
4. CSS migration of DataGrid and BehaviorField
5. Per-user layouts (separate PR — Setting model migration)
6. Stage 1 integrity fixes: invoice type enum, AuditLog wiring, version conflict, webhook dedup

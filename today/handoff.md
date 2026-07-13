# Handoff — 2026-07-12

## Where We Left Off

Two major sessions back-to-back:

**Session 1 (2026-07-10/11) — WC3 Architecture:**
DataBrowser is now the sole list engine. 63 ModelList.tsx deleted. `/db/:model` routing. Template resolution API. WCHQ Setting. Small-Stings. Five subform types. Calculated column approval chain. All committed and pushed.

**Session 2 (2026-07-11/12) — MeshMobility + CrashHarvester:**
Built CrashHarvester as standalone data supply chain. 309 datasets registered. Drawing tools for designer-drawn corridor networks. 566 lines of government code removed from api.py. Crash Mesh algorithm. Threshold slider. DC network iterations.

## Do This First Next Session

### If WC3 Polish:
1. Review printable forms — Report records now have `parent_model`, demo records (zz-demo-*) seeded with lines
2. Add print icon to DataBrowser rows — click → pick template → render PDF for that record
3. Wire BrowserDetail row-click cascade — `detail_route` + `detail_mode` already set on 13 workbench_fields Settings
4. Keyboard modifiers — Cmd+Shift+Click (BrowserDetail), Cmd+Shift+Option+Click (ModelDetail)
5. Polish Dashboard — Action POLISH-DASHBOARD (#339)

### If MeshMobility Release:
1. Move `mobility_data/` into `CrashHarvester/` as one app
2. Run FARS + HPMS harvesters for all 50 states
3. Remove fake crash data (crashes:fatal ratio < 3:1)
4. Test end-to-end: DC, Greenville SC, Tulsa OK
5. Target: Tuesday July 15 release

## WC3 Architecture Decisions (permanent — from 07-10/11 session)

- **No ModelList.tsx** — DataBrowser at `/db/:model` is the only list engine
- **Five subform types** — flat, JSON, BOM/tree, grouped, calculated columns
- **JS display, backend saves** — front-back mismatch is FAULT
- **zz/qq never tally** — permanent exclusion rule
- **JSON viewer read-only default** — authority-gated unlock
- **WCHQ Setting #439** — monthly admin review with dt_approved
- **Small-Stings** — `file_small_sting` manage action, Alice reports to WCHQ
- **Template API** — `/wcapi/resolve-template/` and `/wcapi/template-fields/`
- **Letters/emails** — WC3 is data source, Word/Pages for composition
- **Keyboard modifiers** — Cmd+Shift=BrowserDetail, Cmd+Shift+Option=ModelDetail
- **Calculated functions** — Athena approval chain, Setting purpose='calculated_function'
- **Alice metadata.alice** — predictions, actuals, gap, retrospection per record
- **Alice metadata.features** — report.metadata.features for print, transaction.metadata.features for data
- **DataBrowser detail cascade** — detail_route in workbench_fields Setting, detail_mode='custom' or 'databrowser'

## Database State

- 32 Report records with parent_model set
- 8 zz-demo-* transaction records + 12 lines (metadata.alice.demo=True)
- 13 workbench_fields Settings with detail_route + detail_mode
- WCHQ Setting #439 seeded
- Payment, Receipt, PaymentMethod, PaymentTerm added to model_registry.py
- Action POLISH-DASHBOARD (#339), STING test (#340)
- Alice observations 88-95 promoted

## Open Problems

- Router.tsx has duplicate route definitions overlapping protectedRoutesConfig.tsx — needs consolidation
- Some `/db/orgs.Employee` style routes use dotpath model names — verify wcapi registry resolves
- DataBrowser detail pane doesn't navigate to custom Detail.tsx yet — cascade logic not wired in useDataBrowser
- wrapperPage.ts still exports CustomerDetailPage/AddPage/EditPage — verify these routes still work

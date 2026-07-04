# Handoff — 2026-07-04 (Final)

## Where We Left Off
Completed the entire harvest plan list — every item documented with readmes (Claude+Allie) and training (Alice, 69 observations, ~80 quiz questions). Built 30+ services, 16 field widgets, Commerce Dashboard, JSON viewer, BOM panel, spawn links, app bootstrap. Stage 1 data integrity complete (invoice type, version conflicts, webhook dedup, PaymentApplication guard, AuditLog auto-wiring). All pushed to git across 3 repos (35+ commits). Last commits: forecasting readme, community contributions readme, EDI-replaced-by-sync decision, email-as-actions design, saved searches design, commission design, QA system design, source_name attribution field, Action.task rename, app bootstrap with dt_changed flag, tax jurisdiction on OrgBase.

## Do This First Next Session
1. Browser-test everything — CSS migration, field widgets, BOM panel, JSON viewer, Commerce Dashboard, spawn links. None have been tested in a browser yet.
2. Wire app bootstrap `get_app_bootstrap` manage action into manage_view.py _ACTION_DISPATCH — the service exists but isn't registered as a callable action.
3. Build QAResult model — design documented at `apps/docs/readmes/qa_operations.md`, needs the model + services + API endpoints.
4. Build document promotion chain (proposal→order→invoice) — Stage 2 core commerce, the `promote_to_order` and `promote_to_invoice` manage actions.
5. Alice training session with Bill — 15 topics, 80 quiz questions loaded. Run `alice_quiz` on inventory, BOM, pricing, serials, GL, DataBrowser.

## Open Problems
- BehaviorField legacy paths still use inline styles (field widgets are CSS but old code paths aren't migrated)
- DataGrid still receives theme as JS object (child component CSS migration next)
- Per-user layout persistence deferred — Setting model needs contact_id FK (separate PR)
- N+1 queries in WCAPIGetView list path — no select_related/prefetch_related
- Campaign model still raw SQL — needs ORM migration
- Connection execution layer not built (Stage 5) — blocks Ingrid, sync bundles, vendor exchange
- Forecast service not built — design documented at `readmes/forecasting.md`
- Report runner (server-side PDF via pdfme) not built
- Calendar interface for Actions/ScheduledTasks on TODO
- QAResult model not built — design documented
- Email send service not built — design documented at `readmes/email-operations.md`

## What Was Decided (and Why)
- **Layer not stack** — layers accumulate/erode/split; stack implies push/pop (wrong metaphor)
- **Margin velocity as real fields** — too important for JSON drilling; must be sortable/filterable
- **Below-margin alerts never block shipment** — commerce must flow; flag and ship, review in dashboard
- **UUID immutable after creation** — product identity across all systems; changing breaks everything
- **One UUID per product regardless of vendor** — Ingrid resolves identity first, maps vendors second
- **Price cascade first-match-wins, no stacking** — clear, testable, auditable
- **Guides not policemen** — users know their business; we report margins, don't block transactions
- **Emails are actions** — no EmailTemplate/EmailQueue models; Report stores templates, Action tracks sends
- **Saved searches are Report records** — no SavedSearch model; fewer tables is good
- **EDI replaced by sync bundles** — EDI is flawed; JSON via Connection model is better
- **Action.action renamed to Action.task** — avoids collision with model name; task = what to do
- **Nothing hardcoded in React** — all defaults/lists from server via bootstrap; dt_changed flag for admin refresh
- **Every feature gets docs + training** — no retrospection without baseline markers
- **Alice writes training, Claude+Allie write readmes** — standing rule, no exceptions
- **source_name field on Contact + all transactions** — simple dropdown for attribution; provide tool, don't force
- **Tax on OrgBase as real fields** — tax_jurisdiction FK + tax_exempt_code; propagates to transactions
- **QA = Wisdom of the Many** — unique_id (local) + uuid (cross-company); enables preemption

## Files Changed This Session
Too many to list individually (35+ commits across 3 repos). See `readmes/session-2026-07-03-04.md` for the complete inventory. Key new files:

**Services:** bom_services.py, serial_services.py, inventory_services.py, inventory_reservations.py, price_resolver.py, sales_dashboard.py, purchasing_dashboard.py, app_bootstrap.py, audit_signals.py, filter_operators.py

**React:** AdminWorkbench.css, JsonViewer.tsx, CommerceDashboard.tsx, useAppBootstrap.ts, windowChannel.ts, validateRecord.ts, filterOperators.ts, widgetTypes.ts, 16 field widgets in components/fields/, StatementPrintDocument.tsx, TaxReportPrintDocument.tsx

**Readmes:** bom_operations.md, serial_operations.md, pricing_operations.md, inventory_operations.md, gl_accounting_operations.md, tax_operations.md, databrowser-guide.md, app-bootstrap.md, source-attribution.md, commission-operations.md, email-operations.md, saved-searches.md, community-contributions.md, edi-replaced-by-sync.md, forecasting.md, qa_operations.md, session-2026-07-03-04.md

# Handoff — 2026-08-06

## Where We Left Off

Massive evening session: packing workflow (pick/pack/ship + scale hook), four carrier API integrations (UPS/FedEx/USPS/DHL), markdown template engine, Alice escalation protocol, Connection records, contact detail Kanban/Gantt tabs, Support+Accounting dashboard merge, commission security audit, `done.md` files for both wc3 and r25, and the quantity.active scar. Sidebar nav fix still open — console.log added but Bill went to sleep before checking output.

## Do This First Next Session

1. **Wire ManageActionPanel into TransactionDetail** — the component exists with Convert to Order/Invoice/PO and Ship Order buttons all working. It's only imported in archived detail pages. Import and render it in the active `TransactionDetail.tsx`. ~30 min. Go-live blocker.
2. **Build Spreedly hosted fields payment UI** — the single remaining go-live blocker. Backend is complete. Need: SDK script tag, iframe mount in Apply Payment dialog, token callback to `POST /payments/process/`. Card data never touches WC3 JS.
3. **Fix sidebar nav** — Kanban/Gantt not showing (from prior session). Console.log at `AppSidebar.tsx:159` for diagnosis. Remove after fixing.
4. **Run seeds on Andi** — `seed_connections`, `seed_template_reports` not yet run against the database.

## Open Problems

- **ManageActionPanel not in active TransactionDetail** — conversion chain works backend but users can't trigger it. Component is built, just needs connecting.
- **Payment UI not built** — Spreedly service complete, no card capture frontend.
- **Carrier APIs untested** — 4 implementations written, no test credentials configured.
- **Rate shopping / label / tracking UI not built** — backend complete, manual entry works.
- **Sidebar nav not showing Kanban/Gantt** — unresolved from prior session.

## What Was Decided (and Why)

- **Commission is internal-only, enforced at every layer** — `_STAFF_ONLY_ACTIONS` on manage_view, `_require_staff()` on ViewSet actions, `RoleAwareModelSerializer.to_representation()` strips commission keys from JSON envelopes, bootstrap returns empty commissions for non-staff, frontend C toggle/columns/totals/panels hidden, all commission reports require `role_required: 'admin'`. Reason: commission rates and amounts are competitive intelligence — customers and external users must never see them.
- **Commission reports live on rep and employee models, not transactions** — reps and employees are the people who earn commissions. Reports on their model pages, not buried in invoice reports. Three reports on rep (statement, summary, sales credited), one on employee.
- **Auth endpoints now return is_staff/is_superuser** — added to both login response and /me endpoint. `mapApiProfileToUser` maps them. `User` interface in `authSlice.ts` gained both fields. Reason: frontend needs this to gate commission visibility and future staff-only features.
- **todo-go-live rebuilt from code audit** — prior version had two drifting phase tables, stale priorities on completed sections, checked items hiding unchecked work, and duplicate items across sections. New version has three sections: Go-Live Gate, What's Built (verified), What's Not Built. Single source of truth.

## Files Changed This Session

**webClerk3:**
- `apps/core/views/manage_view.py` — `_STAFF_ONLY_ACTIONS` gate for commission + commission report endpoints; `get_commission_report` action added
- `apps/core/views/bootstrap_view.py` — commissions config returns `{}` for non-staff
- `apps/core/views/auth_views.py` — login + /me responses now include `is_staff`, `is_superuser`
- `apps/transactions/views/transaction_views.py` — `_require_staff()` on all 3 `populate_commission` ViewSet actions
- `apps/transactions/services/commission.py` — added `get_commission_report()` for period-based report data gathering
- `common/base_serializers.py` — `to_representation()` strips commission fields from cost/finance/commission envelopes for non-staff

**React2025:**
- `src/store/slices/authSlice.ts` — `User` interface gains `is_staff?`, `is_superuser?`
- `src/api/auth.ts` — `mapApiProfileToUser` maps `is_staff`, `is_superuser`
- `src/apps/transactions/components/detail/LineCardRenderer.tsx` — C toggle + commission footer hidden for non-staff
- `src/apps/transactions/components/detail/TabsRenderer.tsx` — commission row hidden for non-staff
- `src/apps/transactions/components/SummaryCard.tsx` — `cost.commissions` hidden for non-staff
- `src/apps/transactions/components/TransactionDetail.tsx` — commission auto-populate + toast gated to staff
- `src/apps/orgs/components/OrgFinancialsPanel.tsx` — rep commission section gated to staff; employee commission section removed
- `src/apps/transactions/components/print/CommissionReportPrintDocument.tsx` — rewritten: two modes (company summary + individual rep statement with invoice detail)
- `src/apps/transactions/components/print/index.ts` — export `CommissionDetailLine` type
- `src/config/reportLists.ts` — commission reports require `role_required: 'admin'`; added rep model (3 reports) and employee commission report
- `readmes/topics/transactions/commissions.md` — added reports, security, endpoints documentation
- `readmes/todo-go-live.md` — rebuilt from code audit (old version at `_archive/todo-go-live-2026-08-05.md`)

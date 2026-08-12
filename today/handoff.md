# Handoff — 2026-08-12

## Where We Left Off

Major UI consolidation session. Auth fix, data-driven dashboards, formatter consolidation, dead code cleanup.

### Completed
- **Auth redirect fix** — dead loop when token expired (`"/"` → `"/login"`)
- **Token expiration warning** — amber banner in MacTopBar when session within 3 days
- **dd-card Setting** — one record (id=649), 20 cards, 8 dashboards. `seed_dd_cards.py`
- **DDCardDashboard** — generic dashboard component, replaced 6 custom dashboards
- **7 dead dashboard files deleted** — -1,872 lines
- **`formatField(value, type)`** — master dispatcher for all display formatting
- **`formatDt(value, mode, field)`** — canonical date formatter, all high-traffic components migrated
- **DropDown.tsx deleted** — migrated 2 usages to Select
- **dateUtils.ts deleted** — superseded by fieldFormatters.ts
- **PhoneInput deleted** — unused form component
- **CollectionsQueue.tsx deleted** — orphaned by AccountingDashboard removal
- **UI scrub** — debug logs, stale routes, dead imports cleaned

### Architecture Established
- **One behavior, one record** — dd_card:base Setting, not 60 per-model copies
- **Pattern of behavior, not schema** — group by what it does, not what model it serves
- **Master funnel pattern** — `formatField()` is the single entry point; individual formatters are internal
- **CSS rule** — `.db-*` variables for theme, Tailwind for layout, inline only when CSS can't do it
- **Date rule** — local display, UTC storage, `formatDt()` everywhere

## Do This First Next Session

1. **BehaviorField → field widget delegation** — The one remaining big item. BehaviorField (495 lines, 76 inline styles) reimplements all 18 field types that already exist as widget components. Should dispatch to WIDGET_REGISTRY instead. Plan at `readmes/68-ui-widget-consolidation.md`.
2. **Prior carryover** — alice.md readme update, `on_reciept` typo fix, alice_notes `data` vs `config` bug
3. **dd-card polish** — live with the data, then decide which metrics matter before adding visual hierarchy

## Open Problems
- BehaviorField has 76 inline styles — works but doesn't follow CSS standard
- CommerceDashboard (656 lines, 5 tabs) is the last complex hardcoded dashboard
- alice_notes service bug: `Setting() got unexpected keyword arguments: 'data'` (uses `config` not `data`)
- `on_reciept` typo in Item model (line 168)

## Files Changed This Session

### WC3 Backend
- `apps/core/views/cookie_token_refresh.py` — refresh_expires in response
- `apps/core/management/commands/seed_dd_cards.py` — new

### React2025 Frontend — Created
- `src/components/common/DDCard.tsx`
- `src/pages/Dashboard/DDCardDashboard.tsx`

### React2025 Frontend — Modified
- `src/utils/fieldFormatters.ts` — formatField(), formatDt(), parseDtInput()
- `src/routes/PrivateRoute.tsx`, `Router.tsx`, `Routes.ts`, `protectedRoutesConfig.tsx`
- `src/store/slices/authSlice.ts`, `src/api/axios.ts`
- `src/layout/MacTopBar.tsx`, `src/layout/AppSidebar.tsx`
- `src/components/header/UserDropdown.tsx`
- `src/hooks/useDataBrowser.ts`, `src/hooks/useGoBack.ts`
- `src/pages/admin/DataBrowser.tsx`
- `src/components/common/DataGrid.tsx`, `BehaviorField.tsx`
- `src/components/fields/TimestampField.tsx`, `ReadonlyField.tsx`
- `src/components/wrapper.ts`, `src/pages/wrapperPage.ts`
- `src/apps/transactions/components/SummaryCard.tsx`

### React2025 Frontend — Deleted (2,385 lines removed)
- `src/pages/Dashboard/Home.tsx` (556)
- `src/pages/admin/AccountingDashboard.tsx` (225)
- `src/pages/admin/OperationsDashboard.tsx` (367)
- `src/apps/products/pages/ProductsDashboard.tsx` (170)
- `src/apps/orgs/pages/OrgsDashboard.tsx` (218)
- `src/apps/transactions/pages/TransactionsDashboard.tsx` (226)
- `src/apps/support/pages/SupportDashboard.tsx` (110)
- `src/components/form/group-input/PhoneInput.tsx` (141)
- `src/components/form/input/DropDown.tsx` (100)
- `src/components/collections/CollectionsQueue.tsx` (143)
- `src/utils/dateUtils.ts` (129)

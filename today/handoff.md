# Handoff — 2026-08-12

## Where We Left Off

### Auth Fix — Token Expiration
- **Root cause:** PrivateRoute redirected to `"/"` on auth failure, but `"/"` is inside the PrivateRoute layout — dead redirect loop. Fixed to redirect to `"/login"`.
- **Same fix applied to:** MacTopBar logout, UserDropdown logout, `PageRoutes.login` constant.
- **Token expiration warning:** Backend returns `refresh_expires` in token refresh response. Frontend shows amber "Session expires in Nd/Nh" button in MacTopBar when within 3 days.
- **Files:** `PrivateRoute.tsx`, `MacTopBar.tsx`, `UserDropdown.tsx`, `Routes.ts`, `authSlice.ts`, `axios.ts`, `cookie_token_refresh.py`

### Data-Driven Cards (dd-card) — Major Feature
- **Architecture:** One Setting record (`dd_card:base`, id=649), one behavior pattern. Two sections: `cards` (20 model definitions) and `dashboards` (8 compositions).
- **DDCard component:** `components/common/DDCard.tsx` — compact 2-column metrics with distribution buckets.
- **DDCardDashboard:** `pages/Dashboard/DDCardDashboard.tsx` — reads Setting, renders DDCards + real DataBrowser.
- **DataBrowser:** now accepts `defaultModel` prop/param.
- **Seed:** `seed_dd_cards.py` management command.
- **6 dashboards replaced, 7 dead files deleted (1,872 lines).**
- **3 kept:** InventoryDashboard, AliceDashboard, HelpDashboard — legitimate custom logic.

### Principles Established
- **No scattering:** One base Setting, not 60+ per-model copies.
- **Pattern of behavior drives architecture, not schema.**

## Do This First Next Session

1. **UI scrub** — in progress. Continue polishing theme consistency, remaining hardcoded constants.
2. **alice_notes service bug** — `Setting() got unexpected keyword arguments: 'data'` — uses `config` not `data`. Fix.
3. **Prior session carryover** — alice.md readme update, `on_reciept` typo fix, codemap purchase GAP.

## Open Problems
- CommerceDashboard.tsx (656 lines, 5 tabs) still hardcoded — keep for now, evaluate later
- Reason codes in InventoryDashboard should be Settings
- Large forms (ActionsModal 934, LineDetailsModal 888) — future DynamicForm candidates
- alice_notes `data` vs `config` field mismatch

## Files Changed This Session

### WC3 Backend
- `apps/core/views/cookie_token_refresh.py` — added `refresh_expires` to response
- `apps/core/management/commands/seed_dd_cards.py` — new: seed dd_card:base Setting

### React2025 Frontend
- `src/routes/PrivateRoute.tsx` — redirect to `/login` not `/`
- `src/routes/Routes.ts` — `PageRoutes.login` corrected to `/login`
- `src/routes/Router.tsx` — 6 dashboards → DDCardDashboard, removed dead imports
- `src/routes/protectedRoutesConfig.tsx` — same dashboard replacements
- `src/store/slices/authSlice.ts` — added `refreshExpires` + `setRefreshExpires`
- `src/api/axios.ts` — capture `refresh_expires` on token refresh
- `src/layout/MacTopBar.tsx` — token expiration warning, logout → `/login`
- `src/components/header/UserDropdown.tsx` — logout → `/login`
- `src/components/common/DDCard.tsx` — new: data-driven card component
- `src/pages/Dashboard/DDCardDashboard.tsx` — new: generic dashboard
- `src/hooks/useDataBrowser.ts` — `defaultModel` parameter
- `src/pages/admin/DataBrowser.tsx` — `defaultModel` prop
- `src/pages/wrapperPage.ts` — removed Home export

### Deleted (dead code)
- `src/pages/Dashboard/Home.tsx` (556 lines)
- `src/pages/admin/AccountingDashboard.tsx` (225 lines)
- `src/pages/admin/OperationsDashboard.tsx` (367 lines)
- `src/apps/products/pages/ProductsDashboard.tsx` (170 lines)
- `src/apps/orgs/pages/OrgsDashboard.tsx` (218 lines)
- `src/apps/transactions/pages/TransactionsDashboard.tsx` (226 lines)
- `src/apps/support/pages/SupportDashboard.tsx` (110 lines)

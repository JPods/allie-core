# Handoff — 2026-08-02 (Session 2)

## Where We Left Off
Massive session: Statement Sorter upgrades deployed to webclerk.com/sort (sticky headers, light/dark theme, best-effort CSV parser, PDF prompt, folder drops, file log). Then shifted to wc3/r25 — built the JSON-driven order form end to end. TransactionDetail renders from layout Setting JSON. Company bootstrap endpoint (`/wcapi/bootstrap/`) serves currency, order defaults, price levels, behavior — loaded once at login, versioned. Customer keyword search working with comma-AND, pipe-OR fragments. Currency precision driven from company prefs (unit_price 2dp, unit_cost 5dp). Print view renders standalone HTML in new window. Save was broken by audit_log null user_agent — fixed. Pending model `data=` → `config=` fixed. Both repos pushed to `bill_dev`.

## Do This First Next Session
1. **Scrub r25/wc3 dead code** — old OrderDetail, InvoiceDetail, etc. .tsx files are replaced by TransactionDetail. Remove them and their imports from protectedRoutesConfig. Also clean unused imports from TransactionDetail.tsx.
2. **Apply order layout to proposal, invoice, purchase, requisition** — create detail_layout Settings for each model. Same three-column header pattern, adjust field names (vendor vs customer for purchase). The renderer is model-agnostic — it reads the layout JSON.
3. **Test save on all transaction types** — order save works now. Test invoice, proposal, purchase. Each may have model-specific fields that need stripping in wcapi.ts.
4. **Wire select lists for Terms, Type Sale, Status, Price Level** — these show as text inputs. Add `options` arrays to the layout JSON fields, same pattern as ShipVia and Conditions.
5. **Report framework action** — print works as standalone HTML window. Next step: Report model query for the dropdown, multiple output formats (print, email, label, clone).

## Open Problems
- `useDefaultCompany` retries on 401 in a loop before redirect fires — needs a max-retry or auth-check guard.
- Statement Sorter folder drop only works on https (webclerk.com), not file:// — browser security restriction, not fixable.
- Bootstrap endpoint returns `schema_map` purpose Setting which isn't in the purpose choices — save fails on that Setting. Added to choices but migration may be needed.
- Print view doesn't include logo image (path is in bootstrap but img tag references `/images/logo/webclerk.png` which won't resolve in the popup window without a base URL).
- Bulk edit via Shift+click on DataGrid headers — wired but needs testing with actual price/qty changes and save verification.

## What Was Decided (and Why)
- **UUID never sent to React** — sync-only field. Stripped from save payload. Backend strips from GET response (future). Documented in `wc3/readmes/topics/architecture/uuid-policy.md`.
- **Currency precision in company Setting, not code** — `prefs.currency` on Setting #438. React reads via bootstrap. Change precision without code changes.
- **Keyword search uses icontains on JSON arrays** — PostgreSQL `istartswith` doesn't work on individual array elements. `icontains` is safe because keywords are individual tokens.
- **Conditions stored as pointer** `name|id|version` in `conditions_description` — no redundant text on every order. Text resolved at print time from Setting by id+version. User pref chooses pointer vs embed.
- **Label conventions** — blue=select, green=action, bold=search, italic=readonly/calculated. Shift+hover=help. Stored in company `prefs.layout.label_styles`, user override in contact prefs.
- **Print is a separate renderer** — not CSS @media print. Layout JSON + record data → standalone HTML window. Fighting React's DOM tree with print CSS doesn't work.
- **Auto-edit pref** at `user.prefs.layout.detail.auto_edit` — loads at login only, not refreshed mid-session.

## Files Changed This Session
**React2025** (106 files, key changes):
- `src/routes/Router.tsx` — added /kanban, /gantt, /signin routes; lazy-loaded KanbanBoardPage, UnifiedGanttPage
- `src/routes/PrivateRoute.tsx` — bootstrap fetch on auth, /kanban title
- `src/store/slices/companySlice.ts` — NEW: Redux slice for company bootstrap data
- `src/store/index.ts` — added company reducer
- `src/api/auth.ts` — added prefs to mapApiProfileToUser
- `src/api/wcapi.ts` — uuid/metadata/refs/prefs stripped from save payload, line stripping
- `src/apps/transactions/components/TransactionDetail.tsx` — Edit/Add/Save, customer search, auto-edit, print view, bulk edit, label styles, conditions, FieldRow with options/help/fieldType
- `src/hooks/useLineCard.ts` — currency precision from company state, bulkEditable flags, bulk edit apply
- `src/components/common/DataGrid.tsx` — currency/number formatting with precision, calculated italic, header bulk edit, uniform row selection, Tab/Enter cell navigation
- `src/layout/AppSidebar.tsx` — /kanban path
- `readmes/topics/currency-precision.md` — NEW: currency precision architecture

**webClerk3** (136 files, key changes):
- `apps/core/views/bootstrap_view.py` — NEW: /wcapi/bootstrap/ endpoint
- `apps/core/urls.py` — bootstrap route
- `apps/core/choices.py` — conditions_sales, conditions_purchase purposes
- `apps/core/constants/keyword_requirements.py` — purpose='keywords' (was refs_setup)
- `apps/core/services/keywords.py` — phone normalization, FK fallback, max_related cap, dict ID extraction
- `apps/core/models/audit.py` — null user_agent/ip_address/id_session fix
- `apps/transactions/services/transaction_save.py` — Pending data→config
- `apps/transactions/views/wcapi.py` — traceback in 500 response
- `common/search_utils.py` — pipe OR syntax, istartswith→icontains for keywords
- `readmes/topics/architecture/uuid-policy.md` — NEW: uuid is sync-only

**Statement Sorter** (`sites/statement_sorter/index.html`):
- Sticky headers, light/dark theme, best-effort CSV parser, PDF prompt dialog, file log, folder drops, headerless CSV detection, Athena re-signed

**Allie**:
- `sites/statement_sorter/index.html` — deployed to webclerk.com/sort

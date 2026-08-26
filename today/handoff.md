# Handoff — 2026-08-26

## Where We Left Off

Built the full PJPV selectlist pipeline (three-tier inheritance: model → category profile → record) and the Setting Parade reference tool at `/setting-parade`. Wrote a transaction envelope reorganization plan at `readmes/topics/architecture/transaction-envelope-reorganization.md` — tax, commission, flow, source each get their own header envelope; `totals` stays pure arithmetic; lines stay as-is (they feed upward). Plan includes full UI audit and `status` propagation to all layouts. Migration strategy: big bang, no legacy fallback.

## Do This First Next Session

1. **Restart Django** — new `TransactionShipping` schema, updated `_pjpv_fields/` endpoint (serves all three schema maps now), and `_selectlists/` three-tier resolver all need server restart to take effect.
2. **Build `TransactionTax` schema** — move tax config from `finance` into its own envelope per the reorganization plan. First envelope to migrate.
3. **Add `status` to all model layouts** — write management command `add_status_to_layouts` to batch-update all Setting records with `purpose='wc:list_column_config'` and `wc:workbench_fields'`.
4. **Test VCard import company linking** — `VCardImportDialog` now passes `customerId` from TransactionDetail; code is in place but untested in browser.
5. **Review `unit`/`unit_base` naming collision** — `LinePrice.unit` (currency) vs item scalar `unit` (uom). PJPV leaf behaviors inject `price.unit` correctly as dot-path but name-guessing fallback may still hit bare `unit` on models without a Setting.

## Open Problems

- `ContactPanel` export was fixed (named + default) but the root cause is `withDevIdentifier` wrapping — any new panel using this pattern will have the same issue.
- Three frontend endpoints were broken by the PJPV compliance commit (`86fe942d`): `_model_list`, `_model_detail`, `_search_presets` — all fixed this session, but other endpoints renamed in that commit may have been missed in non-wcapi.ts files.
- `seed_coaching` management command has a bug (`Document() got unexpected keyword arguments: 'model_name'`) — coaching tips created manually this session.
- Shipping `selectlist_key` values (`shipping_status`, `shipping_carrier`, `shipping_service`, `weight_unit`) declared in schema but no corresponding select list entries exist yet in Settings or `selectLists.ts`.

## What Was Decided (and Why)

- **Three-tier selectlist inheritance** — model Setting → record's `selectlist_profile` (rich object with id/ida/purpose) → record's own `config.selectlists`. Because different product categories need wildly different dropdown options (paint vs electronics vs plumbing).
- **`totals` holds arithmetic only; domain envelopes hold detail** — `totals.shipping` is the dollar charge, `shipping` envelope is the logistics. Same pattern applies to tax, commission. Because mixing computed summaries with domain config in one object violated single-responsibility.
- **Lines keep tax/commission/totals together** — lines are computational inputs that sum upward to the parent. The complexity that justifies separate envelopes lives at the header level, not the line level.
- **Big bang migration, no fallback** — no production data to protect. Move JSON keys in-place, update all code to new paths only, delete old paths. No lazy migration.
- **Cmd+click any label = quick select list** — opens BehaviorOverrideDialog pre-set to `select` type. Cmd+Shift+click = full behavior editor. Shift+click = field help. Because select list creation must be frictionless.
- **Setting Parade is a reference tool, not operational** — research/comprehension, not editing. Feedback (understood/needs_work/dont_understand) is a training gap metric for Alice.

## Files Changed This Session

### WebClerk Backend
- `apps/core/views/system_dispatch.py` — `selectlist_key` passthrough in PJPV; serve all three schema maps
- `apps/core/views/selectlist_view.py` — `resolve_selectlists()` three-tier resolution + record-level query params
- `apps/core/views/setting_parade_view.py` — NEW: manifest, preview, feedback endpoints for Setting Parade
- `apps/core/urls.py` — registered setting parade + shipping schema import
- `apps/core/services/field_behaviors.py` — added `shipping` to LEAF_MAP for transaction models
- `common/schemas/transaction_envelopes.py` — `TransactionShipping` schema; `selectlist_key` on OrgAddress.type; `selectlist_key` in `schema_to_leaf_behaviors()`
- `readmes/topics/architecture/selectlist-inheritance.md` — NEW: three-tier selectlist architecture
- `readmes/topics/architecture/selectlist-management.md` — NEW: user guide for select list creation/editing
- `readmes/topics/architecture/setting-parade.md` — NEW: Setting Parade spec
- `readmes/topics/architecture/transaction-envelope-reorganization.md` — NEW: plan for tax/commission/flow/source envelopes + UI audit + status propagation

### WebClerk Frontend
- `src/api/wcapi.ts` — endpoint fixes (`_model_list`, `_model_detail`, `_search_presets`); `PjpvFieldMeta.selectlist_key`; `getResolvedSelectlists()`
- `src/hooks/useDataBrowser.ts` — PJPV selectlist_key auto-lookup from SELECT_LIST_MAP; record-level three-tier useEffect
- `src/pages/tools/SettingParade.tsx` — NEW: full reference tool with grouped behaviors, envelope leaf visualization, PJPV schemas, feedback
- `src/pages/tools/SettingParade.css` — NEW: theme-compliant CSS variables
- `src/routes/Routes.ts` — added `settingParade` route
- `src/routes/protectedRoutesConfig.tsx` — registered SettingParade
- `src/components/fields/BaseField.tsx` — Cmd+click = quick select list (presetType)
- `src/components/fields/BehaviorOverrideDialog.tsx` — accepts `presetType` prop
- `src/components/common/VCardImportDialog.tsx` — `customerId` prop for company linking
- `src/apps/transactions/components/TransactionDetail.tsx` — passes `customerId` to VCardImportDialog
- `src/apps/common/components/panels/ContactPanel.tsx` — named export fix
- `src/pages/admin/AliceDashboard.tsx` — coaching tips with clickable link buttons
- `src/layout/AppSidebar.tsx` — maps added for parade/selectlist routes (not in default nav — accessed via Alice coaching)

# Handoff — 2026-08-27

## Where We Left Off

PJPV schema enforcement is live. All Pydantic schemas use `extra="forbid"`. The enforcement command reshaped 20,877 records. Setting records have a three-layer protection wall (model save guard, enforcement exclusion, double confirmation on replace). `status` consolidated to CoreModel — removed from 13 individual models. All 77 wc:model Setting layouts now include `status` in column definitions. `settings-bundle.json` re-packed with 100 healthy Settings.

Flowchart suite expanded to 45 charts on US Letter, deployed to `webclerk.com/flowcharts/`. Auto-sync agent (`com.allie.andi-static-sync`) deployed — watches sites/ and flowcharts/, auto-deploys to Andi.

## Do This First Next Session

1. **Verify the UI renders correctly** — open DataBrowser for several models (invoice, order, contact, item, customer). Confirm `status` column appears. Confirm layouts load. Check that the `[PJPV]` console warnings in dev mode identify any fields that lost their formatting after `_nameGuessFieldSpec` was stripped of format guessing.

2. **Address any `[PJPV]` console warnings** — these are fields that were rendering correctly by name-guessing but now need explicit Pydantic `json_schema_extra` declarations. Fix the most visible ones first (likely: phone, email, price, cost, date fields on models without custom schemas).

3. **Check the 1,371 unknown keys** moved to `prefs.userdefined._moved_from_*` by the enforcement command. Are any of them keys that should be promoted to schema? Run: `python manage.py audit_schema_compliance --enforce --dry-run` to see current state.

4. **Release prep** — Bill mentioned hoping to release tomorrow (2026-08-28) or Friday. Verify webclerk.com/app/ renders, API responds, demo mode works.

## Open Problems

- `BillOfMaterial` and `Warehouse` had missing BaseModel columns — fixed manually + via migration, but root cause (initial migration created before CoreModel evolved) may affect other models added early. Audit recommended.
- Frontend fields that relied on name-guessing for format (phone → phone format, price → currency) will now render as plain text until Pydantic declarations are added. This is correct behavior per PJPV but may look wrong to users.

## Scar From This Session

**Scar #73**: `enforce_pjpv_schemas` emptied 100 Setting configs. Recovered. Wall built. Principle: dual confirmation + external bundle + interactive review for sweeping data changes. Never bulk-modify Setting records without explicit per-record authorization.

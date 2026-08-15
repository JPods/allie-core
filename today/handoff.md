# Handoff — 2026-08-15

## Where We Left Off

Major data architecture cleanup session. All JSON envelopes standardized across 24,477 records in 50 tables. Pydantic schemas, default factories, and runtime enforcement are now in sync. Setting and Report models gained `explanation` and `paths` columns — all records populated.

## What Was Built

- `common/schemas/defaults.py` — `get_envelope_default()` function
- `common/models.py` — factories synced (default_metadata, default_refs, default_prefs)
- `common/schemas/envelopes.py` — MetadataBase gained userdefined + images; ConfigBase.images removed; ImportProvenance got lifecycle fields
- `common/schemas/setting.py` — SettingRefs updated with all relationship fields
- `common/schemas/touch.py`, `common/schemas/other_org.py` — new schema files
- `common/schemas/transaction.py` — deleted (orphaned)
- `apps/core/models/setting.py` — added explanation + paths columns (migration 0043)
- `apps/core/models/report.py` — added explanation + paths columns (migration 0044)
- `apps/ai_assistant/models_alice.py` — upgraded 3 models to BaseModel (migration 0013)
- `apps/core/constants/model_registry.py` — fixed linkage, project paths; removed doc duplicate; commented out template, purchase_receipt
- `apps/core/views/save_view.py` — fixed version conflict (update_fields now includes version + dt_modified); fixed userdefined not deleted when empty
- `apps/core/services/image_library.py` — switched from config.images to metadata.images
- `React2025/src/hooks/useDataBrowser.ts` — layout fallback to wc:model; resetLayout looks for "default" first
- Action model curated: db.list (18 fields), db.detail (58 fields), "default" named view

## Open Problems

1. **React bundle not rebuilt** — DataBrowser layout fallback and resetLayout changes in useDataBrowser.ts need a build to take effect
2. **Startup health check** — Design approved but not built. WC3 needs a startup validator for Setting records with Fix from Git / Fix from WC_HQ / Quit dialog
3. **Other models need curated layouts** — Only action has a curated db.list/db.detail. Other 74 models still have seed/alice_guess layouts
4. **project_association table missing** — Model registered but table never migrated

## Do This First Next Session

1. Build and deploy the React bundle so DataBrowser layout changes take effect
2. Start the startup health check function — validate Setting records, bootstrap dialog
3. Curate db.list layouts for the real-data models: contact, order, invoice, item, payment, purchase, proposal

## Scars Paid

- Scar #58/#59 — Layouts are data (fields, order, widths), never behavior. Isolate layouts, combine into views. Do not mix defining UI elements with combining them.

## Files Changed (WC3)

```
common/models.py
common/schemas/defaults.py (new)
common/schemas/envelopes.py
common/schemas/setting.py
common/schemas/touch.py (new)
common/schemas/other_org.py (new)
common/schemas/transaction.py (deleted)
apps/core/models/setting.py
apps/core/models/report.py
apps/core/constants/model_registry.py
apps/core/views/save_view.py
apps/core/services/image_library.py
apps/ai_assistant/models_alice.py
React2025/src/hooks/useDataBrowser.ts
```

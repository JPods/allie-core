# Handoff — 2026-08-20 (updated)

## Where We Left Off

Major Setting consolidation session. The WC3 Setting architecture is now clean:

### What Was Done

1. **One Setting per model** — deleted 77 `field_access` records and 19 `detail_layout` records. All data merged into `wc:model` Settings. `seed_field_access.py` deleted.

2. **Field behaviors as service** — extracted from seed command into `apps/core/services/field_behaviors.py`. Auto-detects widget types from Django model metadata (no DB hit). Setting stores only overrides.

3. **Audit command** — `manage.py audit_field_behaviors` flags UNTYPED, BAD_LOOKUP, ORPHAN_OVR, EMPTY_OPTS, OVERRIDE, PHONE_NAME. Started at 304 flags, fixed service to get to 8 (all legitimate).

4. **BehaviorOverrideDialog** — Cmd+Shift+click on any field label opens admin dialog. Shows computed behavior, allows override. Saves to `wc:model` Setting's `config.behaviors`.

5. **Duplicate fix** — found and fixed bug where `seed_model_definitions` created duplicate `wc-model-bundle` records every run (meta.key vs MODEL_REGISTRY key mismatch). Deleted 4 dupes + stale `wc-model-doc`.

6. **Company profile** — added `config.company.address_ship_to` to company-profile Setting.

7. **Documentation** — rewrote `readmes/setting-policy.md`, created `readmes/topics/architecture/field-behaviors-service.md`.

### Backup Files (just-in-case)
- `field_access_backup_20260819.json` — 77 field_access records
- `detail_layout_backup_20260819.json` — 19 detail_layout records

## Open Items

1. **`audit_select_lists` command** — export all select lists organized by model/field/source. Same pattern as audit_field_behaviors. Bill asked for this.

2. **Superuser reload button** — add to BehaviorOverrideDialog footer. Invalidates useDataBrowser behavior cache so changes take effect without switching models.

3. **Wire audit into Alice** — `audit_field_behaviors --json` output feeds Alice's code_standards scanner.

4. **8 remaining audit flags** — `bill_of_material.scrap_factor`/`yield_pct` (deliberately excluded DecimalFields), `contact.groups`/`user_permissions` (Django auth M2M), `inventory_layer` not in MODEL_REGISTRY (3 models reference it).

5. **Select list registry design** — Bill asked whether select list options should move from hardcoded constants to a separate registry or Setting. Current: hardcoded in `field_behaviors.py` + merged from `config.select_lists` at load time.

## Key Files Changed

| File | Change |
|------|--------|
| `apps/core/services/field_behaviors.py` | NEW — service for computing field behaviors |
| `apps/core/management/commands/audit_field_behaviors.py` | NEW — audit command |
| `React2025/src/components/fields/BehaviorOverrideDialog.tsx` | NEW — admin override dialog |
| `React2025/src/components/fields/BaseField.tsx` | Added Cmd+Shift+click handler |
| `React2025/src/components/fields/fields.css` | Added .bov-* dialog styles |
| `apps/core/management/commands/seed_model_definitions.py` | Imports from service, meta.key fix |
| `apps/core/management/commands/seed_field_access.py` | DELETED |
| `apps/core/services/setting_resolver.py` | Added computed wc:field_behaviors fallback |
| `React2025/src/hooks/useDataBrowser.ts` | Removed wc:field_access legacy fallback |
| `apps/core/choices.py` | Removed wc:field_access and wc:detail_layout |
| `readmes/setting-policy.md` | Rewritten for consolidated architecture |
| `readmes/topics/architecture/field-behaviors-service.md` | NEW — full documentation |

## Architecture After This Session

```
Django model metadata (field types, names, FKs)
    ↓ computed by service function (no DB hit)
field_behaviors.py → get_field_behaviors(model_key)
    ↓ overrides merged from Setting
wc:model Setting → config.behaviors (exceptions only)
    ↓ fetched by React
useDataBrowser → renderField() → Widget Registry (18 types)
    ↓ admin correction
Cmd+Shift+click → BehaviorOverrideDialog → saves override
    ↓ Alice monitors
audit_field_behaviors → flags drift
```

## Also Done (second half of session)

8. **`audit_select_lists` command** — 48 select fields, 9 unique names, DRIFT/EMPTY/ORPHAN flags
9. **Admin tool dispatch** — `run_admin_tool` action in manage_view.py, allowlisted commands, superuser-only
10. **Report records for admin tools** — 4 seeded (audit field behaviors, audit select lists, seed model definitions, seed company settings), `category='utility'`, `model_name='setting'`
11. **AdminTools page** (`/admin-tools`) — card selector, parameter inputs, run button, JSON result viewer
12. **Company Profile flight sim card** — shows config section status (✓/—), opens Setting for editing
13. **Admin Tools flight sim card** — navigates to `/admin-tools`
14. **Superuser reload** — BehaviorOverrideDialog fires `wc:reload-behaviors` event, DataBrowser re-fetches
15. **Readmes** — `readmes/topics/architecture/admin-tools.md`, updated `field-behaviors-service.md`

## TODO — Next Session

### High Priority (Setting consolidation cleanup)

1. **Consolidate 3 stale `wc:workbench_fields` records into `wc:model`**
   - `proposal` (DEV-852), `setting` (2 records)
   - Export, merge into wc:model layout, delete, remove from salvage list

2. **Audit and prune `choices.py` purpose list**
   - 30+ purpose choices, only 6 have records in the database
   - Many are legacy from before consolidation: `wc:schema_map`, `wc:db_defaults`, `compact_layout`, `field_registry`, `wc:view_edit`, `seed`, etc.
   - Remove choices with zero records and no code references
   - Keep choices that are in `setting_resolver._WC_MODEL_SECTIONS` (legacy fallback)

3. **Consolidate remaining non-wc:model Settings**
   - `wc:admin` (2 records: admin-console, popup_choices) — should these be in wc:model?
   - `wc:system` (2 records: country_master, wc-views) — system-level, probably stay separate
   - `wc:dd_card` (1 record: dd_card:base) — dashboard card config, probably stays separate

### Medium Priority (Flight sim cards for Setting purposes)

4. **Flight sim cards for each Setting purpose type**
   Each purpose is a different "thing a user needs to understand." Cards:
   
   | Purpose | Card name | What user learns |
   |---------|-----------|-----------------|
   | `wc:model` | Model Definition | What behaviors, layouts, access roles govern each model |
   | `wc:company_profile` | Company Profile | DONE — name, address, ship-to, logos, receivables |
   | `wc:workbench_fields` | Saved Layouts | How list/detail column layouts work, how to save/load views |
   | `wc:system` | System Settings | Country master, database views, system-level config |
   | `wc:admin` | Admin Console | Admin-level configuration, popup choices |
   | `wc:dd_card` | Dashboard Cards | How dashboard card definitions work |
   
   Each card: left panel shows what's configured vs empty, right panel opens the record for editing

5. **Wire `audit_field_behaviors --json` into Alice's code_standards scanner**

6. **Add superuser reload button** visible in AdminTools result viewer (re-run same tool)

### Lower Priority

7. **Select list registry design** — should hardcoded options in `field_behaviors.py` move to a Setting or a separate registry? Current: STATUS_OPTIONS, TX_STATUS_OPTIONS, etc. are constants in the service. Pro of constants: no DB hit, single source of truth in code. Pro of registry: users can customize without code changes.

8. **8 remaining audit_field_behaviors flags** — `bill_of_material.scrap_factor`/`yield_pct` (deliberately excluded DecimalFields), `contact.groups`/`user_permissions` (Django auth M2M not in registry), `inventory_layer` not in MODEL_REGISTRY (3 models reference it)

## Key Insight for Next Session

The Setting model accumulated many purpose types over time. The consolidation into `wc:model` absorbed the per-model purposes (field_access, detail_layout, schema_map, etc.). What remains are **cross-model** purposes:

- `wc:company_profile` — one per installation
- `wc:system` — system-level config (countries, DB views)
- `wc:admin` — admin console config
- `wc:dd_card` — dashboard card definitions
- `wc:workbench_fields` — user-saved layouts (stale — should be in wc:model)

Each is legitimate as a separate purpose because they don't belong to a single model. The flight sim cards help users understand each one. The audit of choices.py will reveal which purposes are truly dead vs just unused-so-far.

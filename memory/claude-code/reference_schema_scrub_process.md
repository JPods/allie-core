---
name: Schema scrub process
description: Three-command audit for WC3 Pydantic/Setting health; fix source then re-seed --force; common root causes and 2026-08-26 baseline
type: reference
---

## Schema Scrub — Three Audit Commands

```bash
cd ~/Documents/CommerceExpert/WebClerk/backend

# 1. Schema compliance — pydantic paths, field_access, inheritance
./venv/bin/python manage.py audit_schema_compliance

# 2. Field behaviors — computed vs stored overrides
./venv/bin/python manage.py audit_field_behaviors --detail

# 3. Select lists — option coverage and drift
./venv/bin/python manage.py audit_select_lists
```

## Fix Workflow

1. Fix SOURCE CODE (field_behaviors.py constants, seed command logic)
2. Re-seed: `./venv/bin/python manage.py seed_model_definitions --force`
   - Without `--force`, all 77 models skip (exists guard)
3. Re-audit to verify

## Common Root Causes

- `NEVER_EDIT` list in `field_behaviors.py` missing a read-only field (health_rating was missing — caused 225 violations)
- `_ENVELOPE_FIELDS` set not matching actual envelope fields (caused 150 OVERRIDE flags for actions/comments)
- Stale stored overrides surviving in Settings (orphan overrides for virtual fields like phone/domain/address_full on org models — cleared by re-seed)
- Missing Pydantic schema files in `common/schemas/` (import_error)

## 2026-08-26 Baseline (post-fix)

| Audit | Result |
|-------|--------|
| Schema compliance | 6 violations (all import_error for missing schema files) |
| Field behaviors | 8 flags (5 BAD_LOOKUP, 2 UNTYPED, 1 PHONE_NAME) |
| Select lists | 33 flags (20 EMPTY shipping, 13 DRIFT) |

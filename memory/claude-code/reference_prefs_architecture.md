---
name: Prefs/metadata/refs architecture and Setting policy
description: Three-tier Setting system (wc/model/feature), JSON envelope policy (.prefs/.metadata/.refs), Pydantic schema mandate, schema_map Setting per model, Alice review cycle
type: reference
---

**Three-tier Setting system** (established 2026-07-31):
- **System**: Setting(parent_model='wc', purpose='system') -- company identity, currency, timezone
- **Model**: Setting(parent_model=X, purpose='field_access') -- defaults, behaviors, select lists, GL maps
- **Feature**: Setting(parent_model='gantt'/'databrowser', purpose='feature') -- non-model feature config

**JSON envelope policy** on every BaseModel record:
- `.prefs` -- user writes, UI reads (userdefined fields, tags, pinned)
- `.metadata` -- system writes, system reads (GL postings, audit trail, sync state, import provenance)
- `.refs` -- relationship cache, secondary to FKs (links, source pointer)

**Setting.prefs.defaults** -- installation-level defaults for new records. Company decides, not individual user. Alice recommends changes based on usage patterns.

**Pydantic schema mandate** -- every JSON envelope gets a typed schema at common/schemas/{model}.py. Schema is the contract. New keys require schema update first.

**Every model gets a schema_map Setting** (established 2026-08-05):
- Setting with `parent_model='{model}', purpose='schema_map', scope='system'`
- `config.pydantic_schema` -- module path to Pydantic schemas
- `config.{model}_actions` -- actions that can be performed (name, status_result, document_type, direction, captures, reversibility)
- `config.{model}_statuses` -- valid statuses with labels and descriptions
- `config.behaviors` -- model-specific rules (e.g. warranty_starts_on, require_notes_on_scrap)
- Seeded via `seed_{model}_settings.py`, included in `seed_freshstart.py`
- Serial is the exemplar: `common/schemas/serial.py`, `seed_serial_settings.py`, Setting id=545
- Flagged in leftshoe -- check for missing schema_map Settings at session start

**System maintenance project** -- #31062 with 6 quarterly review actions. Alice re-creates closed actions for next quarter. Escalates overdue at 7 days. Forces admin to review schemas, defaults, GL mappings, envelope health, field behaviors, onboarding.

**Key files:**
- readmes/prefs-architecture.md -- Mermaid flow charts
- readmes/setting-policy.md -- Setting registry and rules
- readmes/json-envelope-policy.md -- envelope policy + Pydantic mandate + Alice review cycle
- readmes/onboarding.md -- Alice's admin + user onboarding guide
- common/schemas/envelopes.py -- shared Pydantic base types
- common/schemas/serial.py -- Serial envelope schemas + DEFAULT_SERIAL_ACTIONS (exemplar)
- common/schemas/payment.py -- Payment envelope schemas
- common/schemas/_template.py -- copy for each new model

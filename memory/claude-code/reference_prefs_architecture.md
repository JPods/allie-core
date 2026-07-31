---
name: Prefs/metadata/refs architecture and Setting policy
description: Three-tier Setting system (wc/model/feature), JSON envelope policy (.prefs/.metadata/.refs), Pydantic schema mandate, schema_map Setting, Alice review cycle
type: reference
---

**Three-tier Setting system** (established 2026-07-31):
- **System**: Setting(parent_model='wc', purpose='system') — company identity, currency, timezone
- **Model**: Setting(parent_model=X, purpose='field_access') — defaults, behaviors, select lists, GL maps
- **Feature**: Setting(parent_model='gantt'/'databrowser', purpose='feature') — non-model feature config

**JSON envelope policy** on every BaseModel record:
- `.prefs` — user writes, UI reads (userdefined fields, tags, pinned)
- `.metadata` — system writes, system reads (GL postings, audit trail, sync state, import provenance)
- `.refs` — relationship cache, secondary to FKs (links, source pointer)

**Setting.prefs.defaults** — installation-level defaults for new records. Company decides, not individual user. Alice recommends changes based on usage patterns.

**Pydantic schema mandate** — every JSON envelope gets a typed schema at common/schemas/{model}.py. Schema is the contract. New keys require schema update first.

**Schema map Setting** — Setting #469 (schema_map:wc). Registry of all Pydantic schemas across all models. Alice reads it, flags deviations, shares with WC_HQ. WC_HQ reviews across installations, corrects before bad patterns spread.

**System maintenance project** — #31062 with 6 quarterly review actions. Alice re-creates closed actions for next quarter. Escalates overdue at 7 days. Forces admin to review schemas, defaults, GL mappings, envelope health, field behaviors, onboarding.

**Key files:**
- readmes/prefs-architecture.md — Mermaid flow charts
- readmes/setting-policy.md — Setting registry and rules
- readmes/json-envelope-policy.md — envelope policy + Pydantic mandate + Alice review cycle
- readmes/onboarding.md — Alice's admin + user onboarding guide
- common/schemas/envelopes.py — shared Pydantic base types
- common/schemas/payment.py — Payment envelope schemas
- common/schemas/_template.py — copy for each new model

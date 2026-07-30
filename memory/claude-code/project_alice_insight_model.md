---
name: AliceInsight model
description: Multi-agent per-user per-subject insight records — Alice, Athena, custom agents; extends BaseModel for MCP/sync; alice_insights table
type: project
---

AliceInsight model created 2026-07-29. Extends BaseModel (full MCP envelope).

**Why:** Alice needs records at multiple granularities per user — not just one profile, but per model, per flow, per sync. Athena needs security/risk records. Users may add custom agents.

**How to apply:** `apps/ai_assistant/models_alice.py` — class AliceInsight(BaseModel)

Schema: agent (open CharField, no choices constraint) + contact FK + subject_type + subject_key. Unique together on all four.

Subject types: user, model, flow, sync, coaching, security, risk, system

Agent field is open — alice, athena, or user-defined. Users may add their own agents.

Alice.everywhere and Alice.wchq share this schema. WC_HQ aggregates anonymized insights across installations. Common frame of reference = subject_type + subject_key vocabulary.

System insights: Alice can recommend machine cleanup, extension removal, etc. "Not my primary function, but you might want to..."

Migration applied: ai_assistant.0006_add_alice_insight (creates table), core.0021 (renames action.task → action.action)

Also added to Project model: dt_start, dt_end, id_parent (FK self), percent_complete. Migration: transactions.0013_project_timeline_hierarchy (fake-applied, columns existed).

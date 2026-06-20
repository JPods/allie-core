---
name: Agent LLM architecture
description: All agents share gpt-oss:20b base model; identity comes from Modelfile system prompt; registry and futures in readmes/40-agent-llm-architecture.md
type: reference
---

All named agents (`allie`, `athena`, and future agents) use `FROM gpt-oss:20b` as their base.

- **Base model:** `gpt-oss:20b` — 20.9B params, MXFP4, 131K context, thinking enabled
- **Modelfiles:** `/Users/williamjames/Allie/config/allie.Modelfile` (and future per-agent files)
- **Registry + futures:** `readmes/40-agent-llm-architecture.md`
- **allie:latest** built 2026-05-06; `allie-reflect.py` now uses it (was deepseek-r1:8b)
- **Temperature:** 0.1 for critics/operators (Athena, Noelle, Natalie, Nora); 0.3 for Allie; 0.2 for Alice
- **Rebuild any agent:** `ollama create <name> -f config/<name>.Modelfile`

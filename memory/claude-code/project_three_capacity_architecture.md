---
name: Three-capacity agent architecture
description: All 6 agents (Alice, Allie, Noelle, Natalie, Nora, Sally) have ops/hc/librarian capacities — 18 Ollama models, facets, HC vector stores, leftshoe integration
type: project
---

Three-capacity architecture deployed 2026-08-28. Every agent gets three voices:
- **ops** (temp 0.1) — enforce standards, validate, reject violations
- **hc** (temp 0.4) — hippocampus: learn patterns, propose deviations, build long-term memory
- **librarian** (temp 0.2) — record intent, measure outcomes, grade A-F

**Why:** A single-voice agent cannot both enforce and innovate honestly. Productive tension between enforcement and innovation, with measurement closing the loop. Bill's design: "operating and hippocampus capacities" plus librarian for accountability.

**How to apply:**
- 18 Ollama models: `{agent}-ops`, `{agent}-hc`, `{agent}-lib` for all 6 agents
- Modelfiles in `config/{agent}-{capacity}.Modelfile`
- Facets in `facets/{agent}/facet.json` with ops/hc/librarian sections
- HC vector stores at `.chroma_db_{agent}_hc/`
- Alice MCP server v2.0 routes tools by capacity (6 new tools: alice_learn, alice_hypothesize, alice_debate, alice_record_intent, alice_measure, alice_report)
- `scripts/agent-build.py` builds any agent's capacities from Modelfiles
- `scripts/alice-hc-consolidate.py` nightly memory consolidation
- Leftshoe TEAM LEARNING section surfaces all agent facet data at session start
- `config/agent-capacities.json` defines the universal pattern

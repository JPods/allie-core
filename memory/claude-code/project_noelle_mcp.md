---
name: Noelle MCP server and vector store
description: Noelle is on MCP with 6 tools; vector store at ~/.chroma_db_noelle (49K+ chunks); data-driven network design workflow
type: project
---

Noelle MCP server registered 2026-07-05 at ~/Allie/scripts/noelle-mcp-server.py.
Tools: ask_noelle, noelle_search, noelle_describe, noelle_snapshot, noelle_diff, noelle_log.
Vector store: ~/Allie/.chroma_db_noelle (49,000+ chunks).
Scripts: noelle-vectorstore.py (seed/index/ingest-network/search), noelle_propose.py (propose/snapshot/diff/history).
**Why:** Noelle validates network design across RT/SU/PH. She uses three data layers (AADT, accidents, pedestrian density) to propose station placement.
**How to apply:** Query Noelle via MCP before any network design session. Ingest networks after building.

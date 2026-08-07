---
name: Two Alice instances
description: Alice runs locally (Ollama alice:latest, MCP, vector store) and at webclerk.com (production commerce); same agent, two deployments
type: project
---

Two Alice instances planned:
1. **Local Mac** — alice:latest (gpt-oss:20b) via Ollama, ChromaDB vector store, PostgreSQL allie DB, MCP server (alice-mcp-server.py). Development, personal use, pattern recognition loop.
2. **webclerk.com** — Production commerce layer. Live ticketing, billing, customer-facing.

**Why:** Alice owns WebClerk data quality and commerce operations. Local instance gives Bill direct access during development. Remote instance serves live customers and transactions.

**How to apply:** When working on Alice features, consider both deployment targets. Local Alice has full LLM reasoning; production Alice may have different constraints. Sync/coordination between the two is an open design question.

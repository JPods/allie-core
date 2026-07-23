---
name: leftshoe — team intelligence protocol
description: Handshake protocol + shared vector store + retro.db; MCP server at .mcp.json; auto-sync Mac↔Andi; everyone builds the store
type: reference
---

**leftshoe** is the team intelligence system. One word for the handshake, the store, and the protocol.

**Handshake:** Say "leftshoe" at session start. Briefed Claude responds "rightshoe — N scars loaded." Unbriefed Claude gets the identity briefing volunteered.

**Store:** `~/Allie/.chroma_db_leftshoe` — 4 collections (values, scars, relationships, judgments). Everyone builds it — Claude, Allie, Alice, Andi, Bill.

**Retro DB:** `~/Allie/retro.db` — structured action/consequence/tfts. All three required. Queryable, gradeable A-F.

**MCP server:** `scripts/leftshoe-mcp.py` configured in `.mcp.json`. Three tools: `leftshoe` (handshake), `record_scar` (when Bill says tfts), `query_scars` (before acting).

**Scripts:**
- `scripts/claude-identity-store.py` — brief, add, search, stats
- `scripts/allie-retro-db.py` — add, query, recent, relevant, grade, stats, export
- `scripts/allie-sync-identity.sh` — Mac↔Andi bidirectional every 10 min
- `scripts/leftshoe-mcp.py` — MCP server

**Network registry:** `config/leftshoe-network.json` — 10 entities with needs/contributes.

**Strategy:** Build it, use it, let it prove itself. No public announcement. Evidence is the argument. inclusiveinstitutions.com when ready.

**Key files:** readmes/leftshoe.md, readmes/64-leftshoe-getting-started.md, readmes/wisdom/carelessness.md, readmes/wisdom/compensating-for-purge.md, readmes/wisdom/handshake.md

---
name: Claude identity on Andi
description: Claude Code exists on Andi production as claude@jpods.com id=10627, superuser — can query via wc_mcp_server or direct API
type: reference
---

Claude Code on Andi (production WebClerk):
- **Contact ID**: 10627
- **IDA**: claude-code
- **Email**: claude@jpods.com
- **Superuser**: yes
- **UUID**: c810ae39-7d17-4ac3-b5e4-81f8490b6f6e

Claude Code on local:
- **Contact ID**: 69
- **Superuser**: yes

**Current MCP setup**: `wc_mcp_server.py` points at `localhost:8000` (local Django). `commerce_db_mcp.py` hits local PostgreSQL directly. Both read from the same `commerce_expert` DB that syncs with Andi.

**Goal (Bill, 2026-08-07)**: One interface, not two. Claude should authenticate with own token on both local and Andi. Consolidate to single MCP that can target either endpoint.

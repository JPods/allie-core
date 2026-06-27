---
name: Claude Code has its own WebClerk identity
description: claude@jpods.com (id=69 in commerce_expert) — separate from Allie; MCP server authenticates as claude not allie
type: reference
---

Claude Code has its own contact in WebClerk: `claude@jpods.com`, id=69, superuser, admin.

- MCP server (`wc_mcp_server.py`) authenticates as `claude` (changed from `allie` on 2026-06-27)
- Credentials in `~/Allie/config/wc_credentials.json` under `"claude"` key
- Password: `pass1111` (dev only — change before production)
- All dev passwords are simple (`pass1111`, `1111pass`) — single-machine development only

**Why:** Claude Code was impersonating Allie — audit trail couldn't distinguish who did what. Each agent needs its own identity per the sovereignty principle.

**How to apply:** When accessing WebClerk from Claude Code, actions appear as `claude@jpods.com`. Allie's nightly actions appear as `allie@jpods.com`. Check user_id in wc_credentials.json matches the active database.

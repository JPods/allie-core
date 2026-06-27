---
name: Database consolidation — single local PostgreSQL
description: WC3 uses only commerce_expert on local PostgreSQL; bill and agent_bill DBs deleted; runserver.sh defaults to local; no SQLite
type: project
---

As of 2026-06-27, WebClerk3 uses a single PostgreSQL database: `commerce_expert` on `localhost:5432`.

- `bill` and `agent_bill` databases were dropped
- `DB_MODE=bill` removed from settings.py, .env, and runserver.sh
- `runserver.sh` defaults to `local`; pass `remote` only for production
- No SQLite in use anywhere
- Production cutover checklist at `readmes/topics/infrastructure/production-cutover.md`

**Why:** Multiple databases caused user ID mismatches between environments (Allie was id=43 in bill, id=48 in commerce_expert). The RBAC layer silently denied all queries when the wrong DB was active. One database eliminates the scramble.

**How to apply:** Never create additional local databases. All dev work uses `commerce_expert`. Remote DB is for production only.

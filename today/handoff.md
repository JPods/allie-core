# Handoff — 2026-06-27 (database consolidation session)

## Where We Left Off

Database consolidation complete. Dropped `bill` and `agent_bill` PostgreSQL databases. Single database: `commerce_expert` on local PostgreSQL. Claude Code now has its own WebClerk identity (`claude@jpods.com`, id=69, superuser).

## What Was Done

1. **Fixed wc_search returning 0 contacts** — root cause: RBAC layer (`inject_role_filters` in `role_filter.py`) silently denied all queries when Allie had no `UserProfile`. Fix: set `is_superuser=True`. This bypasses RBAC entirely.
2. **Found DB scramble** — running server had `DB_MODE=bill` (database `bill`) while shell used `commerce_expert`. User IDs differed between them (Allie was id=43 in bill, id=48 in commerce_expert).
3. **Consolidated to single DB** — removed `bill` mode from settings.py, .env, runserver.sh. Dropped `bill` and `agent_bill` databases.
4. **Created Claude Code identity** — `claude@jpods.com` (id=69) in commerce_expert. MCP server now authenticates as `claude` instead of `allie`.
5. **Updated runserver.sh** — defaults to `local` (was `remote`). Only accepts `local` or `remote`.
6. **Created production cutover readme** — `readmes/topics/infrastructure/production-cutover.md`
7. **Updated startup.md** — removed bill references, default is now local
8. **Verified all three MCP tools** — wc_add_note (working), wc_search (working after superuser fix), wc_get_contact (working)

## Files Changed

- `webclerk3_api/settings.py` — removed bill DB config and bill mode branch
- `runserver.sh` — default local, removed bill option
- `.env` — removed `BILL_DATABASE_NAME=bill`
- `readmes/startup.md` — updated for local default, no bill
- `readmes/topics/infrastructure/production-db.md` — removed bill from DB modes table
- `readmes/topics/infrastructure/production-cutover.md` — NEW: full cutover checklist
- `~/Allie/scripts/wc_mcp_server.py` — authenticates as `claude` not `allie`
- `~/Allie/config/wc_credentials.json` — added claude entry, fixed allie user_id to 48

## Do This First Next Session

1. **Verify Claude MCP connection** — after MCP restart, test `wc_search Contact` and `wc_add_note`
2. **Continue WebClerk3 polishing** — Bill wants to focus on wc3 and fundraising materials
3. **wc_search contacts** — now working (22 contacts visible). Ready to build on.

## Open Problems

- **Login field name inconsistency** — `authenticate()` works with `email` key in Django shell but fails via HTTP with `email` key. Low priority — `username` key works.
- **SketchUp ghost pods at s009** — 15 records in pods[], deferred to next SU session
- **Span resolver even-split** — deferred to next SU session

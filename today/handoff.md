# Handoff — 2026-06-26 (late session)

## Where We Left Off

WebClerk3 connection established. Fixed two bugs: `api_response()` missing `error_code` parameter (common/api_responses.py), and MCP `wc_add_note` sending `body` instead of `name` to the `/wcapi/ai/note/` endpoint (wc_mcp_server.py). Allie's wcapi token works — login via `allie@jpods.com` / `pass1111` on local DB. Need MCP server restart to pick up the note fix.

## Do This First Next Session

1. **Test wc_add_note** — after MCP restart, verify note creation works end-to-end (Claude Code → Alice → WebClerk Setting record)
2. **Test wc_search contacts** — 22 contacts exist in local DB but search returned 0. May be org scoping issue with Allie's token. Check if Allie's user (id=43) has the right org/connection.
3. **Start polishing WebClerk3** — Bill wants to focus on wc3 and fundraising materials
4. **Login field name** — the wcapi login endpoint works with `username` key but NOT `email` key via HTTP, even though the view code handles both. Investigate middleware interference.

## Open Problems

- **wc_search returns 0 contacts** — local DB has 22 but Allie's token scope may not see them
- **Login field name inconsistency** — `authenticate()` works in Django shell with either key, fails via HTTP with `email` key. Middleware stack may be modifying request body.
- **Alice note endpoint** — `error_code` fix applied but untested via MCP (needs restart)
- **SketchUp ghost pods at s009** — 15 records in pods[], deferred to next SU session
- **Span resolver even-split** — deferred to next SU session

## What Was Decided (and Why)

- **`error_code` added to `api_response()`** — many callers already pass it (ai_assistant, jpods views). Rather than fix every caller, accept the parameter and fold it into the error dict. Backward compatible.
- **MCP note tool sends `name` not `body`** — the wcapi endpoint expects `name` as the note content field. The MCP tool's `body` parameter was misnamed vs the API. Fixed at the MCP layer, not the API, because the API convention is established.
- **Allie password reset to `pass1111`** in local DB — was `1111pass`, didn't match Bill's expectation.

## Files Changed This Session

- `webClerk3/common/api_responses.py` — added `error_code` parameter to `api_response()`
- `webClerk3/apps/core/views/auth_views.py` — debug print added and removed (no net change)
- `~/Allie/scripts/wc_mcp_server.py` — `wc_add_note` sends `name` instead of `body`
- `~/Allie/config/wc_credentials.json` — updated Allie password + user_id for local DB

### Earlier this session (SketchUp)
- `su_jpods/compute/compute_geometry.rb` — Compute rewrite, pure math from cp_markers
- `su_jpods/natalie/natalie.rb` — fleet registry
- `su_jpods/sally/sally_station.rb` — validate!, snapshot
- `su_jpods/animation/animation.rb` — Rule 24 fixes
- `su_jpods/jpod_log.rb` — defect logging system
- `su_jpods/jpod_console.rb` — Flag/Show/Validate/Dump callbacks
- `su_jpods/dialogs/console.html` — defect toolbar, removed dashboard
- `su_jpods/CLAUDE.md` — Rule 24
- `su_jpods/readmes/sketchup/startup.md` — new startup guide
- `~/Allie/readmes/physical/lessons-from-su-animation-2026-06-26.md` — physical network lessons

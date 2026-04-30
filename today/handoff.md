# Handoff — 2026-04-29

## Where We Left Off

Complete session. Built the full JPods trip API, browser phone app, SketchUp dispatch server,
talent system, design tokens, session handoff protocol, `/retrospection` and `/handoff` skills,
and the WebClerk MCP server. All code is written and on disk but not yet committed.

SketchUp had CP regression issues during the session (documented in retrospection 2026-04-29):
- Bug 1: scan-order-dependent tangent direction fixed by using stub tangent averages
- Bug 2: spurious BEAM_WIDTH/2 cross-track shift removed (midpoint is already correct)
- Platform detection was empty on one export — recovery protocol documented

The WebClerk MCP server is registered in `~/.claude/settings.json` and will be active
after Claude Code restarts. It requires Django to be running at localhost:8000.

## Do This First Next Session

1. **Restart Claude Code** — needed to activate the WebClerk MCP server
   (`settings.json` was updated; MCP won't connect until restart).

2. **Test the MCP** — after restart, run: "use wc_jpods_stations to list stations"
   If Django is running you should see S001–S003 and S097–S100.

3. **Commit this session's work** — large batch of new files:
   dispatch_server.rb, views_ui.py, dispatch.py, trip_app.html, readmes 35-39,
   design-tokens.json, wc_mcp_server.py, ~/.claude/commands/. Use `/commit` or
   `git commit` with a message like "JPods trip API, phone app, dispatch pipeline, talent system".

4. **Test the full dispatch flow** — start SketchUp, load plugin, seed demo data,
   open `/jpods/trip/`, select Adult → S097 → S098 → Travel.
   Watch Ruby console for `[JPods DispatchServer]` lines.

5. **Spawn NORA_DISPATCH_1** — pod component with `vehicle_id = NORA_DISPATCH_1`
   must exist in the SketchUp model at station S097 before dispatch test.

## Open Problems

- SketchUp CP regressions fixed but not fully retested — re-export followme.json
  and confirm `platforms[]` is non-empty before dispatch test.
- `dispatch_server.rb` fallback nora_id is `NORA_DISPATCH_1` — must exist in model.
- Route-Time travel time in confirmation box requires a prior simulation run for the O-D pair.
- Physical dispatch (Natalie inbound API on RPi) is a placeholder only.
- WEBrick degrades gracefully if unavailable in SketchUp Ruby runtime (logs a warning).

## What Was Decided (and Why)

- **Queue + UI.start_timer** in dispatch_server.rb — SketchUp model API is not thread-safe;
  WEBrick runs on background thread; model calls must execute on main thread.
- **Port 5051 for WEBrick; port 5050 is Route-Time** — never swap.
- **Item-based pricing** — trips use standard WC3 Item/Invoice; no custom model.
- **fire-and-log dispatch** — dispatch failure never cancels the Alice invoice.
- **myCarryOn token in contact.metadata** — no separate auth model.
- **MCP uses Allie's venv** (`/Users/williamjames/Allie/.venv`) — system Python
  is PEP 668 protected; venv is the right approach; `.venv` now gitignored.
- **Midpoint is authoritative for stub_pair CP** — no correction after midpoint;
  any BEAM_WIDTH/2 shift after the midpoint is a regression by definition.

## Files Changed This Session

### WebClerk (Django)
- `apps/jpods/models.py` — emptied; Item model replaces JpodPricingRule
- `apps/jpods/services/pricing.py` — Item-based price lookup
- `apps/jpods/services/invoice_service.py` — Invoice + InvoiceLine with item_fk
- `apps/jpods/services/dispatch.py` — fire-and-log dispatch router (new)
- `apps/jpods/views_ui.py` — full UI API: ContactsView, IdentifyView, StationsView, UIPriceView, TravelView (new)
- `apps/jpods/templates/jpods/trip_app.html` — mobile trip booking app (new)
- `apps/jpods/urls.py` — all jpods routes
- `apps/jpods/management/commands/seed_jpods_demo.py` — Items + myCarryOn contacts

### Route-Time
- `route_time/gui/api.py` — POST /api/trip/dispatch endpoint

### SketchUp Plugin
- `JPods/dispatch_server.rb` — WEBrick on 5051, queued main-thread handler (new)
- `JPods/main.rb` — dispatch_server added to load list; LoadError handling improved

### Allie Readmes
- `readmes/35-jpods-alice-trip-api.md` — updated for Item model
- `readmes/36-jpods-dynamic-pricing-load-balancing.md` — new
- `readmes/37-jpods-sketchup-dispatch-server.md` — new
- `readmes/38-talents.md` — talent system (new)
- `readmes/39-session-handoff.md` — handoff protocol (new)
- `readmes/design-tokens.json` — shared UI design tokens (new)
- `readmes/sketchup/jpods-cp-regression-guard.md` — CP regression guard (new)
- `readmes/retrospections/2026-04-29.md` — full session retrospection

### Allie Infrastructure
- `scripts/wc_mcp_server.py` — WebClerk MCP server (new)
- `.venv/` — Python venv for MCP (gitignored)
- `.gitignore` — added .venv, __pycache__, *.pyc
- `today/handoff.md` — this file
- `~/.claude/commands/retrospection.md` — skill (new)
- `~/.claude/commands/handoff.md` — skill (new)
- `~/.claude/settings.json` — MCP server registered

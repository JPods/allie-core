---
name: Talent system
description: Named capability registry for Claude Code and Allie — what each can do, what's been built, what's recommended next
type: project
---

Talent system defined 2026-04-29. See `readmes/38-talents.md` for the full registry.

**Active Claude Code talents:** code read/write, architect, front-end build, MCP consumer, subagent dispatch, web search.

**Active Allie talents:** personal memory, WebClerk agent, pattern recognition, knowledge matrix, agent coordination, voice interface.

**Built this session:** dispatch_server.rb (WEBrick on 5051), trip_app.html, design-tokens.json.

**Recommended next (Claude Code):** `/retrospection` skill, `/route-check` skill, WebClerk MCP server, session handoff skill.

**Recommended next (Allie):** Watchdog (process monitor), retrospection analyst (cross-session patterns), session handoff reader.

**Design tokens:** `/Users/williamjames/Allie/readmes/design-tokens.json` — all JPods/WebClerk UIs draw from this. Color law: red=inbound, blue=outbound.

**Handoff protocol:** Claude Code writes `today/handoff.md` at session end. Allie reads it and briefs Bill at session start. See `readmes/39-session-handoff.md`.

**Why:** Talents make agent capabilities explicit and transferable. Without naming them, they exist only in the code — the next session has to rediscover what was built and what the conventions are.

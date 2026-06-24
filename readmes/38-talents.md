# Talents — Claude Code and Allie
**Last updated:** 2026-04-29
**Status:** Living document — update when a talent is added, removed, or refined

A **talent** is a named, repeatable capability that one of the agents can invoke on demand.
Talents are not features — they are disciplines with a defined scope, a known owner, and a clear handoff protocol between agents.

The division of labor follows Bill's operating principle: each agent does what it is structurally suited for. Do not give Allie a talent Claude Code should own, and vice versa.

---

## Who Does What

| Agent | Nature | Suited for |
|-------|--------|-----------|
| **Claude Code** | Session-scoped engineering tool | Building, refactoring, architecture, MCP/skill construction, one-time analysis |
| **Allie** | Persistent personal agent | Monitoring, pattern recognition, routine tasks, memory, handoff, daily context |

---

## Claude Code Talents

### Currently Available

| Talent | What it does | Status |
|--------|-------------|--------|
| **Code read / write** | Multi-file edits, refactoring, bug fixes across all languages | Active |
| **Architect** | Design systems, APIs, data models before writing code | Active |
| **Front end build** | Produce HTML/CSS/JS UI from a description or sketch | Active — see trip_app.html |
| **MCP consumer** | Use connected MCP servers (Gmail, Calendar, Google Drive) | Active |
| **Subagent dispatch** | Spawn Explore, Plan, general-purpose agents for parallel work | Active |
| **Web search / fetch** | Research, check docs, verify facts | Active |

### Recommended — Build Next

| Talent | What it does | Priority | Why |
|--------|-------------|----------|-----|
| **`/retrospection` skill** | One command writes today's retrospection from session context | High | Currently manual and sometimes skipped; retrospections are the primary cross-session record |
| **`/seed-jpods` skill** | Runs `manage.py seed_jpods_demo --reset` and reports result | Medium | Saves lookup time; typed frequently during JPods dev |
| **`/route-check` skill** | Validates followme.json: checks platforms[], structure coverage, line count | Medium | Platform loss bug has appeared 3 times; a check command prevents silent failure |
| **Design token enforcer** | When building any JPods/WebClerk UI, pulls from `design-tokens.json` first | High | Currently every UI is designed independently — color, spacing, typography drift |
| **WebClerk MCP** | Exposes Alice's wcapi as Claude Code tools: create_invoice, get_contact, post_note | High | Removes the copy-paste layer between Claude Code and Alice; Claude Code can verify live data |
| **Route-Time MCP** | Query travel time, get network status, run dispatch | Medium | Currently Claude Code writes to a file; with MCP it can verify the endpoint is responding |
| **Session handoff writer** | At session end, writes `today/handoff.md` — one-page briefing for next session | High | Context reconstruction is expensive; a structured handoff cuts start time |

### Backlog (lower urgency, higher value over time)

| Talent | Rationale |
|--------|-----------|
| **Test runner skill** | Run Django test suite, report failures inline — catch regressions before retrospection |
| **Migration checker** | Before any model change, check if migration is needed and what it will do |
| **ouch-list auditor** | Scan code for patterns that match known risks in `system/ouch-list.md`; surface matches |
| **MCP builder** | Build a new MCP server from an API spec — meta-talent that creates other talents |
| **Skill creator** | Write a new Claude Code skill (slash command) from a description | 

---

## Allie Talents

### Currently Active

| Talent | What it does | Where documented |
|--------|-------------|-----------------|
| **Personal memory** | Stores and recalls facts about Bill, projects, preferences across sessions | `14-personal-ai-features.md` |
| **WebClerk agent** | Acts as Bill's agent into Alice — reads contacts, orders, notes | `05-webclerk-integration.md` |
| **Pattern recognition** | Monitors alice_log → identifies patterns → recommends promotions to Settings | `wc3/readmes/topics/ai/pattern-recognition.md` |
| **Knowledge matrix** | Four-layer knowledge store: facts, WhatIf, corpus, staging curiosity | `16-knowledge-matrix.md` |
| **Agent coordination** | Communicates with Claude Code and Alice via wcapi notes without Bill in the middle | `19-agent-coordination.md` |
| **Voice interface** | Speak/listen modality for Bill; multilingual voice for JPods ticketing | `17-voice-interface.md` |

### Recommended — Build Next

| Talent | What it does | Priority | Why |
|--------|-------------|----------|-----|
| **Watchdog** | Monitors that Django, Route-Time, and Natalie processes are running; alerts Bill when they drop | High | Demo environment; a dead process before a demo is a silent failure that becomes a visible one |
| **Retrospection analyst** | Reads `retrospections/` folder; surfaces recurring patterns across sessions | High | Claude Code sees one session; Allie sees all of them — she is the right agent for cross-session pattern recognition |
| **Simplify reviewer** | When Bill or Claude Code proposes a design, Allie flags unnecessary complexity before implementation | Medium | Bill's operating principle is bottom-up minimal; a named discipline makes it consistent |
| **Front end generator** | Produces quick HTML mockups from a plain-English description | Medium | Allows Bill to review UI concepts without opening a Claude Code session |
| **Session handoff reader** | At session start, reads `today/handoff.md` and briefs Bill on where Claude Code left off | High | Pair with Claude Code's handoff writer talent — together they close the context gap between sessions |

### Backlog

| Talent | Rationale |
|--------|-----------|
| **Regulatory scanner** | Reads JPods-relevant legislation, court decisions, state bills; flags when something affects the 5X5 Standard or postRoads argument |
| **Trip demand reporter** | Reads JPods invoice history from Alice; surfaces O-D demand patterns for Noelle load balancing |
| **Sovereignty auditor** | Reviews any proposed feature against the sovereignty principle — flags centralizing patterns before they are built |
| **DividedSovereignty tracker** | Monitors state legislative calendars for bills relevant to the Divided Sovereignty Act; surfaces action items |

---

## Design Token Standard (JPods / WebClerk UI Family)

All JPods and WebClerk UIs share one visual language. Claude Code must pull from this before building any UI.

File: `/Users/williamjames/Allie/readmes/design-tokens.json` (see that file)

**Core rules:**
- 🔴 Red = inbound (hot) — never use for anything else
- 🔵 Blue = outbound (cool) — never use for anything else
- Background dark: `#0a0e1a`
- Surface: `#141929`
- Border: `#2a3350`
- Text: `#e8edf8`
- Muted: `#7a87a8`
- Green (action/confirm): `#3ddb6b`
- Amber (warning): `#f0b429`
- Red (error/inbound): `#f45b5b`
- Border radius: `12px`

---

## Talent Handoff Protocol

When Claude Code builds something Allie needs to use, Claude Code writes the interface spec to a readme **before** closing the session. When Allie discovers a pattern Claude Code should act on, she writes it to a wcapi note with `tag: claude_action_needed`.

Neither agent waits for Bill to relay information the other agent could have written directly.

---

## What We Have Done (session log)

| Date | Talent | Agent | Notes |
|------|--------|-------|-------|
| 2026-04-29 | Front end build — trip_app.html | Claude Code | Mobile phone app for JPods trip booking |
| 2026-04-29 | WebClerk MCP consumer — Gmail, Calendar | Claude Code | Connected via MCP server |
| 2026-04-29 | Dispatch server (WEBrick) | Claude Code | Port 5051; queued main-thread execution |
| 2026-04-29 | Design token standard | Claude Code | `readmes/design-tokens.json` — shared visual language |
| 2026-04-29 | `/retrospection` skill | Claude Code | `~/.claude/commands/retrospection.md` — active |
| 2026-04-29 | `/handoff` skill | Claude Code | `~/.claude/commands/handoff.md` — active |
| 2026-04-29 | WebClerk MCP server | Claude Code | `scripts/wc_mcp_server.py` — registered via `claude mcp add` in `~/.claude.json` |
| 2026-04-29 | Watchdog | Pending | Allie — after SketchUp issue resolved |
| 2026-04-29 | Retrospection analyst | Pending | Allie — after watchdog |

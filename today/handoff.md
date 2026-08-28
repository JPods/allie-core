# Handoff — 2026-08-28

## Where We Left Off

Session 4: Three-capacity agent architecture fully deployed. 18 Ollama models built (6 agents × ops/hc/lib). Alice MCP v2.0 with 12 tools. Weekly agent sprint system live with 10 proposed actions on the Agent Operations Kanban board. Allie wired as scrum master in allie-reflect.py. Touch-based agent prompts working. All agents acknowledged all actions.

## What Was Built (Session 4)

- **18 Ollama models**: alice/allie/noelle/natalie/nora/sally × ops/hc/lib capacities
- **Alice MCP v2.0**: 12 tools routed by capacity (ops/hc/lib)
- **agent-sprint.py**: seed, create-sprint, propose, review, approve, reject, execute, run-prompts, status, gantt, prompt, touches
- **Touch system**: channel='agent', out/in pairs, Connection.rules gate interactions
- **Agent contacts**: Noelle=10709, Natalie=10710, Nora=10711, Sally=10712
- **Connections**: Claude API (55), agent prompt interfaces (56-61)
- **Agent Operations project** (id=68): permanent July 2026–June 2027, Gantt-visible
- **10 actions proposed**: 4 Alice, 2 Allie, 1 each Noelle/Natalie/Nora/Sally — all acknowledged
- **Allie scrum master**: nightly HC consolidation + propose + SLA check; Wednesday boundary
- **Leftshoe TEAM LEARNING**: agent facets surfaced at session start
- **HELP-AGENTS document** (id=965): updated with full architecture
- **Readme**: readmes/84-agent-sprint-architecture.md + flowchart .dot/.svg

## Do This First Next Session

1. Review 10 proposed actions on Agent Operations board — approve/reject
2. Sync Modelfiles to Andi and run agent-build.py --all
3. Add Anthropic API key to config/allie_api_keys.json for Claude escalation
4. Add launchd timer for alice-hc-consolidate.py (after alice-patterns, before allie-reflect)
5. Bill's UI walkthrough (carried from prior sessions)

## Still Open

- Andi pending.status column issue (faked migration)
- 20 Faker-generated garbage Connection records need cleanup
- Terms/direction/line_type value normalization
- profitbubbles.com needs Hostinger DNS setup
- Agent-sprint gantt export needs update for permanent project model
- Nightly consolidation scripts needed for agents beyond Alice

## Key IDs

- Agent Operations project: id=68
- Sprint W35 (internal): id=67 (archived)
- Connections: Claude API=55, Alice=56, Allie=57, Noelle=58, Natalie=59, Nora=60, Sally=61
- Agent contacts: Alice=10628, Allie=10629, Claude=10627, Noelle=10709, Natalie=10710, Nora=10711, Sally=10712

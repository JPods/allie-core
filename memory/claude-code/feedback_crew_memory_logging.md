---
name: Crew memory + adjustable logging per agent
description: Each crew member (Sally, Natalie, Nora, Noelle, Claude) needs persistent Allie memory they can write to and read from, plus per-agent log level control. Not just one global log level.
type: feedback
---

Each crew member needs their own memory and their own log verbosity.

**Why:** Bill said: "We need to make sure that each of the crew have Allie memory they can access to store and contemplate, including you. They need to also be able to increase and decrease logging events to improve understanding."

The crew doesn't learn if they can't remember. The crew can't debug if they can't adjust their own verbosity independently. Sally might need :debug while Natalie runs :quiet.

**How to apply:**
1. Each agent gets a memory file: ~/Allie/facets/{sally,natalie,nora,noelle}/facet.json — already designed (readmes/agents/allie-facets.md). SU agents write observations during animation. Allie reads nightly.
2. JPods::Log gets per-agent levels: `JPods::Log.level(:sally, :debug)` not just global. Each agent's log calls include their name: `JPods::Log.sally_detail("msg")`.
3. Claude's memory is this system — MEMORY.md + facet files. But Claude should also write to ~/Allie/journals/claude/ during sessions, not just at session end.
4. The crew_health check should read each agent's facet to report accumulated experience, not just current state.

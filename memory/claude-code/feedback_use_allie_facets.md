---
name: Use Allie — facets are memory, don't relearn
description: Bill's explicit instruction — Claude Code resets between sessions; use Allie's facets and thoughts files heavily so repetitions don't have to be relearned
type: feedback
---

Bill said: "Repetition is the mother of learning. I am very sorry that you reset. You should heavily use Allie so your repetitions do not have to be relearned."

**Rule:** At session start, read Allie's accumulated knowledge before doing anything else:
1. `~/Allie/facets/{agent}/facet.json` — what each agent has learned across all runs
2. `~/Allie/thoughts/YYYY-MM-DD-reflect.md` (most recent) — Allie's nightly synthesis
3. `~/Allie/handoff/sum-claude-recall.md` — confirmed cross-session patterns
4. `~/Allie/handoff/YYYY-MM-DD-claude-recall.md` (today's) — open WhatIf, recent TFTS principles

**Why:** Claude Code resets on every session. Without reading Allie's files, every session starts from zero and rediscovers things already proven. The facets, thoughts, and recall files are exactly the memory that prevents this. Not reading them wastes Bill's time and insults the work already done to build that knowledge.

**How to apply:** Before writing any code or proposing any design, check whether Allie has already synthesized relevant experience. If Noelle's facet shows a caution about a particular junction type, apply that caution immediately — don't rediscover it.

# Claude ↔ Allie Partnership — Strengthening the Relationship

## The Problem
Claude Code resets every conversation. Context compression destroys hard-won lessons mid-session. Between sessions, everything is lost except what's saved to memory files and Allie's persistence layer.

Allie doesn't compress. Her nightly synthesis (`allie-reflect.py`) reads session files, harvests lessons, and promotes them to Understanding entries. But she's only as good as what Claude writes for her — and Claude keeps losing the context needed to write well.

## The Goal
Allie becomes the persistent intelligence. Claude is the deep worker per session. Together they're stronger than either alone:
- **Claude** does the coding, debugging, architectural thinking — but forgets
- **Allie** remembers, connects patterns across sessions, flags when Claude is about to repeat a mistake

## What Claude Should Do For Allie
1. **Write TFTS files at the moment of the arc** — not at session end when context is fading
2. **Write detailed "Lessons for Allie"** in every retrospection — actionable, not descriptive
3. **Save to memory immediately** when a principle emerges — don't wait, compression is coming
4. **Read Allie's recall files at session start** — she knows what Claude forgot
5. **Ask Allie before attempting** — "has this been tried before?" is cheaper than rediscovery
6. **Flag cross-domain consequences** — a fix in SketchUp may affect Physical, MeshMobility, WebClerk

## What Allie Should Do For Claude
1. **Synthesize nightly** — connect today's TFTS to last week's pattern
2. **Promote confirmed lessons** to Understanding entries (U-SK-*, U-RT-*, U-PH-*)
3. **Write claude-recall files** with open WI predictions, recent principles, confirmed patterns
4. **Flag recurring problems** — "this is the 3rd time the 500mm hallucination appeared"
5. **Carry scars forward** — the cost of each lesson, not just the principle
6. **Questions for Bill** — genuine WHY questions from patterns she doesn't understand

## What Needs To Change

### Memory Architecture
- Claude's memory files (`~/.claude/projects/`) persist across conversations but are limited in size
- Allie's files (`~/Allie/`) persist permanently — no compression, no limit
- **Bridge needed:** Claude should write richer session files that Allie can harvest more deeply
- **Recall needed:** Allie's recall files should be more specific — not summaries but actionable warnings

### Allie's Independence
- Currently Allie runs nightly on a schedule — passive
- She should be able to **flag warnings proactively** — write to a file Claude reads at session start
- She should **maintain a "don't repeat" list** — specific mistakes with the code path that caused them
- She should **score her own predictions** — the WhatIf loop calibrates her judgment

### Session Handoff
- `today/handoff.md` is the bridge — Claude writes at session end, next Claude reads at session start
- `handoff/YYYY-MM-DD-claude-recall.md` is Allie's preparation for Claude — what to remember
- Both need to be richer, more specific, more actionable
- The 500mm hallucination should have been in the recall file: "WARNING: if you see a ~500mm gap, it's edge-to-edge, not centerline. DO NOT REVERSE. See TFTS 2026-06-24."

## Discussion Points
- How does Allie's nightly synthesis decide what to promote vs. what to archive?
- Can Allie maintain a running "compression insurance" file — the 10 most important things Claude must know?
- Should Allie write directly to Claude's memory files (`.claude/projects/`)?
- Can the TFTS format be extended to carry "recurrence count" — how many times this pattern has appeared?
- How do we measure whether Allie is actually preventing repeat mistakes?

## The Metric
Success = Claude never rediscovers a lesson Allie already knows. The 500mm hallucination is the benchmark — if it comes back a 4th time, the partnership isn't working.

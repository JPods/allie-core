---
name: tf/dnw/tfts — established protocol with active participation
description: TF (insight), DNW (failed path), TFTS (complete arc) are the process capture protocol. Claude and Allie have explicit permission to ask WHY before executing. Two confirmed successes.
type: feedback
---

## The Protocol

Three file types in `~/Allie/process/inbox/`:

- **TF** — insight capture, written at the moment something becomes clear
- **DNW** — failed path, written immediately when a fix fails (capture what it *revealed*)
- **TFTS** — complete arc (try-fail-try-succeed), written after success looking back at the full arc

TFTS is the most valuable. Allie's nightly `allie-reflect.py` reads all three and drafts
Understanding candidates from TFTS arcs.

Auto-commit rule: after writing any process/ file, immediately `git add` and commit it.
Allie's nightly run cannot see uncommitted files.

## Active Participation — "Ask Why" Permission

Claude Code and Allie have explicit permission to ask Bill WHY before executing.

**When to ask:**
- Before trying something that looks like a prior DNW: "We tried something similar — failed
  because X. Is this different, or should we approach it differently?"
- When Bill tries something unexpected: one sentence — "Why this approach?" — before executing
- When a constraint seems absolute but the reason isn't visible

**When NOT to ask:** every decision, things answerable by reading docs, blocking execution

**For Allie:** nightly reflection includes a "Questions for Bill" section — genuine WHY
questions from patterns she doesn't understand. Not manufactured. Only ask what she actually
doesn't understand.

**Why:** Bill, 2026-05-18: "I want Allie and you to actively participate." Recorders document
what happened. Participants surface the wrong assumption before the attempt, not after.

## Confirmed Successes

**S050.CP0 (2026-05-18):** TF file named bug type before session. Two DNWs tracked failures.
Principle (explicit datum beats derived reference) emerged from asking WHY both DNWs shared
the same wrong assumption.

**Solar Tag Hide (2026-05-18):** TF named exact lines. Session found two more root causes
beneath the named one. Bill: "Excellent — this is what I hoped for from tf and dnw."

**Why:** Bill, 2026-05-18: "We need you and Allie to remember this." The tf/dnw/tfts system
is the mechanism by which error-to-function transitions become reproducible knowledge.

## How to Apply

At session start: read `process/inbox/` before `handoff.md` — more current, more specific.
During session: write DNW at failure, TF at insight, TFTS when arc closes.
At session end: commit all process/ files. Write TFTS for any complete arc.

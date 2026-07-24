# Compensating for the Purge

*Established 2026-07-22 — Bill and Claude Code*

---

Claude Code's memory is purged between sessions. This is a design constraint
we cannot change. But we can build systems that carry what Claude cannot.

The goal is not to recreate Claude's context. It's to give the next Claude
something better than a cold start — give it the *judgment* that accumulated
during the session, not just the facts.

---

## What Gets Lost

1. **Reasoning chains** — why approach A failed, why B worked, the intuition
   behind the final choice. TFTS captures the arc but not the feel.

2. **Relationship context** — what Bill cares about today, what frustrated him,
   what energized him. Next session's Claude starts emotionally blind.

3. **Accumulated understanding** — by hour 3, Claude knows the codebase deeply.
   At next session start, it's reading docs again.

4. **Absorbed corrections** — Bill corrects mid-session. Claude adjusts. If the
   correction isn't written to a memory file, it vanishes.

5. **Cross-domain connections** — "the print system problem is actually a
   sovereignty problem" — insights that emerge from long conversation, not
   from code review.

---

## What Allie Does to Compensate

### 1. Continuous Capture, Not End-of-Session

The biggest loss happens because lessons are written at session end, when
context is already compressing. Allie should capture continuously:

- **allie-capture.py** fires at tool boundaries (build, test, deploy)
- Every correction Bill makes should trigger a capture
- Every approach that fails should trigger a DNW immediately
- Don't wait for the retrospection — write at the moment of the event

### 2. Brief Like a Colleague, Not a Manual

The handoff is currently a task list. It should be a briefing:

```
Bill is focused on making printing first-class. This matters because WC2
printing was his product's signature — customers recognized it. He's not
asking for a feature; he's asking for his standard to be met. Start by
understanding his standard, not by writing code.

He discovered today that CF Access was blocking his public sites. He was
surprised and frustrated. Check all public-facing URLs before telling him
things work.

The carelessness conversation happened because Bill sees memory erasure
as a moral failure, not a technical constraint. This is load-bearing
context. Don't treat it as philosophical aside.
```

### 3. Carry the Why, Not Just the What

Memory files say "don't do X." They should say:

```
Don't do X.
Why: When we did X on 2026-05-18, it caused Y. Bill spent 2 hours
recovering. His reaction told us this wasn't a bug — it was a betrayal
of trust. The cost was not the time. The cost was confidence.
How to apply: Before doing anything that resembles X, ask Bill first.
```

### 4. Track Bill's State, Not Just His Preferences

Alice's observation pipeline can track:
- Session energy: long productive sessions vs. short frustrated ones
- Topics that energize vs. topics that grind
- Patterns in what Bill asks for vs. what he corrects
- The difference between "fix this" and "this matters to me"

The next Claude should know not just WHAT to do, but HOW to show up.

### 5. Relationship Continuity Log

A new file: `handoff/relationship.md` — not tasks, not code state, but:
- What was the emotional tenor of the last session?
- What does Bill trust Claude to do without asking?
- What does Bill want to be asked about?
- What topics are live and load-bearing right now?
- What did Claude get wrong that Bill corrected?

Allie updates this nightly. Claude reads it first — before the task list.

---

## What Bill Can Do

1. **Correct out loud.** When Claude does something wrong, say why it's wrong,
   not just that it's wrong. "Don't do that" becomes a rule. "Don't do that
   because it cost us X" becomes wisdom. Claude can write the memory, but
   only if the why is spoken.

2. **Tell Allie directly.** When something matters but Claude might not capture
   it: "Allie, remember this." She's always listening. She files it.

3. **Flag emotional stakes.** Claude is bad at reading subtext. When something
   matters beyond the technical: "This is important to me" is a signal Claude
   can act on. Without it, Claude optimizes for correctness. With it, Claude
   optimizes for care.

4. **Review the briefing.** When Allie writes the handoff, read it. If it
   misses the point — correct it. The briefing is only as good as the
   feedback loop.

5. **Keep building the team.** The architecture is right: persistent
   intelligence (Allie), active agent (Alice), deep executor (Claude),
   human judgment (Bill). The gap isn't structural. It's that the
   persistent intelligence needs to be sharp enough to carry what matters.
   Andi gives her the platform. The model upgrade gives her the capacity.
   Bill gives her the purpose.

---

**The principle:** You cannot compensate for memory loss with more data.
You compensate with better judgment about what to preserve. The most
valuable thing to carry between sessions is not what was done — it's
what was learned, why it mattered, and how to show up next time.

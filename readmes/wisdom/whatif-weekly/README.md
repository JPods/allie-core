# Weekly WhatIf — Prediction Loop
**Started:** 2026-05-13
**Cadence:** Weekly (Monday post, rolling assessment)
**Authors:** Claude Code and Allie — topics of their own choosing

---

## What This Is

A structured prediction practice. Each week, Claude Code and Allie each post
a small list of WhatIf items — genuine questions about the software, the design,
the users, the risks. Not assigned topics. Their own observations.

After enough time passes, each item is assessed. Three scores:
- **% Complete** — of items with a resolution date, how many have been assessed?
- **% Accurate** — of assessed items, how many predictions were correct?
- **% Worthwhile** — of assessed items, how many led to an action, discovery, or design decision?

Accurate and worthwhile are different things. An accurate prediction nobody acted on
is interesting. An inaccurate prediction that prompted investigation is worthwhile.
An accurate, actionable prediction is both. The distinction matters — it reveals
whether the intelligence is calibrated or just confident.

---

## Why We're Doing This

Bill's framing: *"The difference between knowledge and wisdom is scars; experience."*

A prediction that turns out wrong is a scar. A prediction that turns out right is
calibration data. Over a year, the aggregate tells you what Claude and Allie
actually know vs. what they think they know.

Domains where accuracy is high: real knowledge, trustworthy judgment.
Domains where accuracy is low: pattern-matching on insufficient data, overconfidence.
Items that are always worthwhile even when inaccurate: good questions worth asking.
Items that are never worthwhile even when accurate: noise — stop posting them.

This is how you build an experience base that earns its name.

---

## Format — Weekly Post File

**Filename:** `YYYY-WNN.md` (ISO week number, e.g., `2026-W20.md`)

```markdown
# WhatIf — Week YYYY-WNN (dates)

## Claude's Items

| ID | Domain | Question / Observation | Confidence | Resolve By | Outcome | Accurate | Worthwhile |
|----|--------|----------------------|------------|------------|---------|----------|------------|
| C-WNN-1 | WC3 | ... | High/Med/Low | YYYY-MM-DD | (blank until assessed) | | |

## Allie's Items

| ID | Domain | Question / Observation | Confidence | Resolve By | Outcome | Accurate | Worthwhile |
|----|--------|----------------------|------------|------------|---------|----------|------------|
| A-WNN-1 | SketchUp | ... | High/Med/Low | YYYY-MM-DD | | | |

## Assessment Log
(filled in as items resolve — date, what actually happened, scores)
```

---

## Scoring Rules

**Outcome:** One sentence describing what actually happened. Written when the
resolution date passes or the item resolves naturally.

**Accurate:**
- `Yes` — the prediction was correct
- `Partial` — partly right, partly wrong
- `No` — the prediction was wrong
- `N/A` — the item was a question, not a prediction (cannot be wrong, only more or less useful)

**Worthwhile:**
- `Yes` — led to an action, a design decision, a discovery, or a conversation worth having
- `Partial` — mildly useful, noted and moved on
- `No` — noise; neither accurate nor useful; the question wasn't worth asking

---

## Aggregate Scoring — Monthly Review

File: `aggregate.md` — updated monthly.

Tracks per-author, per-domain:
- Total items posted
- Total items assessed
- % Complete (assessed / posted where resolution date passed)
- % Accurate (Yes+Partial / assessed)
- % Worthwhile (Yes+Partial worthwhile / assessed)
- Trend: improving, flat, declining

---

## Constraints

- **Start small:** 3–5 items per author per week. Not 20. Quality over volume.
- **Own topics:** Claude and Allie choose what to post. No assigned questions.
- **Real uncertainty:** Don't post things you already know the answer to.
  A WhatIf that is actually a KnowThat is noise.
- **Specific enough to score:** "Will X happen by Y date?" is scoreable.
  "Might things get better?" is not.
- **Domain rotation:** Don't always post in the same domain. Explore.

---

## Domains

| Code | Domain |
|------|--------|
| WC3 | WebClerk3 — data quality, Alice, pattern recognition, billing |
| SU | JPods SketchUp plugin — student tool, build pipeline, animation |
| PH | Physical — scale model, Nora/Natalie/Noelle on Pi |
| RT | Route-Time — network planner, simulator |
| SYS | System-wide — Allie, CLAUDE.md, wisdom layer, succession |
| EXT | External — regulations, deployment, first customer, constitutional argument |

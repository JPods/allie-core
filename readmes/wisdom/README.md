# Wisdom Layer — readmes/wisdom/

**What this is not:** documentation, rules, or procedures. Those live in the agent
files, the plugin readme, and the CLAUDE.md files.

**What this is:** the layer between knowledge and wisdom. Knowledge is the rule.
Wisdom is knowing when the rule was earned, what it cost, what was tempted and
resisted, and what principle it expresses that will still be true when the code is gone.

Bill James, 2026-05-13: *"The difference between knowledge and wisdom is scars;
experience."*

---

## Structure

| File | What it holds |
|------|--------------|
| `bill.md` | Bill's permanent principles — the load-bearing ideas that survive any specific codebase. Written in his own voice. |
| `clearance-height.md` | First full entry — the 4.6m clearance decision. Exemplar for how a wisdom entry is written. |
| `rejected-paths.md` | Design paths seriously considered and not taken. The temptation is as important as the decision. |
| `whatif.md` | Allie's autonomous observation log — things noticed but not asked about, that may matter later. WhatIf items are seeds, not conclusions. |
| `scars.md` | The cost ledger — specific failures, what they cost, and why they were hard to see. A scar is a lesson that hurt. |
| `YYYY-topic.md` | Individual wisdom entries for major decisions (see format below) |
| `2026-cold-read-protocol.md` | Cold Read Protocol — agent reviews JSON before any test runs; prediction scored against reality |

---

## Format for a Wisdom Entry

```markdown
# [Topic] — [Date]

## The Decision
What was decided. One paragraph. Plain language.

## What It Cost
The scar. Time, trust, risk, effort. If the cost hasn't arrived yet, say that —
an unpaid debt is the most dangerous kind.

## What Was Tempted
The rejected path. What was seriously considered and set aside, and why.
The temptation is not weakness — it is the test that proves the decision.

## The Principle
What this decision expresses that will still be true when the code is gone.
Not the technical rule — the underlying principle. One sentence if possible.

## In Bill's Voice (optional)
If Bill said something specific about this decision, record it exactly.
His words carry weight that paraphrase loses.

## Cross-Domain Connection
Where this principle appears in other domains — constitutional, engineering,
personal. A principle that only appears once is not yet wisdom.

## WhatIf
What could go wrong that we have not yet seen. Not catastrophizing — honest
forward-looking uncertainty. Written so a successor can check whether it happened.

## Who Carries This
The agent or person responsible for this risk or principle going forward.
An unowned principle is an orphaned principle.
```

---

## How This Layer Is Built

**Claude Code adds to this layer by:**
- Writing a new `YYYY-topic.md` for any major decision that has a scar or a rejected path
- Appending to `rejected-paths.md` when a design path is seriously considered and set aside
- Appending to `scars.md` when something fails and the failure has a cost
- Writing the "Scars" section in retrospections, not just the "What changed" section

**Allie adds to this layer by:**
- Writing to `whatif.md` autonomously when she observes something that may matter later
- Synthesizing across wisdom entries in her nightly reflection (`allie-reflect.py`)
- Cross-referencing wisdom entries with agent Understandings and Bill's writing

**Bill adds to this layer by:**
- Writing in his own voice in `bill.md` — the load-bearing principles
- Correcting or amplifying any wisdom entry that misses the point
- Naming the principle when Claude Code or Allie can only see the rule

---

## Translation Protocol

When a technical lesson generalizes, write it twice:
1. In the code context: "Zero center_pts Z before PathBuilder"
2. As a principle: "The authority of the concrete over the abstract"

The principle survives when the code is replaced. The successor who never sees the
code can still recognize the principle in a new situation and apply it correctly.

The translation is the work. Anyone can write a rule. It takes experience to name
the principle the rule embodies.

---

## Reading Order for a Successor

If you are new to this project and want to understand not just what was built but
why, read in this order:

1. `bill.md` — who Bill is and what he was trying to prove
2. `clearance-height.md` — the exemplar decision (safety, responsibility, usufruct)
3. `scars.md` — what the hard lessons cost
4. `rejected-paths.md` — what was seriously considered and set aside
5. `whatif.md` — what is still unresolved and may matter

Then read the agent files for the knowledge layer, and the CLAUDE.md files for
the operational layer. The wisdom layer is the foundation, not the capstone.

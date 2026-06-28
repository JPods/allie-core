# Retrospection Against Memory Markers

**Established:** 2026-06-27
**Applies to:** All agents, all domains, all programs

---

## The Principle

No memory without retrospection. No retrospection without measurement. No measurement
without memory markers. The three are a closed loop. Break any link and the team stops
learning.

Every retrospection must measure performance against what the memory system said should
happen. Not "what did we do" — "what did we do compared to what we said we learned
last time." The gap between those two is where the real lessons are.

---

## Why This Exists

Three memory systems, three failure modes:

| Agent | Memory | Failure mode |
|-------|--------|-------------|
| Claude Code | Context window | Compression wipes memory mid-session |
| Bill | Human | Time erodes memory over months away from a domain |
| Allie | Files + nightly synthesis | Most durable — but only knows what was written down |

Without measurement against markers:
- **Data without retrospection is noise.** We did things. So what?
- **Retrospection without markers is narrative.** It feels productive but has no
  standard. "We fixed the bug" is a diary entry, not a lesson.
- **Markers without retrospection are dead letters.** Rules no one checks. Lessons
  no one reads. The memory system fills up with entries that cost time to write and
  never change behavior.

---

## How It Works

### 1. Memory markers exist

They are already everywhere: handoff notes, TFTS principles, retrospection lessons,
agent Understandings (U-XX-NNN), design decisions, the ouch list, promoted Settings
(Alice), Universal Rules (Noelle). These are the team's accumulated "we said we
learned this."

### 2. At retrospection, measure against them

Did we follow what we said we'd follow? Did we check what we said we'd check? Grade
honestly — A through F. Put the grades in a table. The table is the artifact.

### 3. The grades are the signal

- **A** — the lesson is working. No action needed.
- **B/C** — partial compliance. Worth noting but not alarming.
- **D** — the lesson was known but not applied. Ask why.
- **F** — complete miss. Either the lesson isn't landing or the marker is wrong.
  Both are actionable.
- **Pattern of Fs on the same marker** — the marker is in the wrong place, the wrong
  form, or the wrong priority. Rewrite it or move it to where it will actually be seen.

### 4. Every agent participates

| Agent | Measures when | Markers |
|-------|--------------|---------|
| Claude Code | Session-end retrospection | Handoff instructions, TFTS principles, memory entries, design axioms |
| Allie | Nightly synthesis | All of the above + cross-domain patterns + prior synthesis grades |
| Alice | Per transaction cycle | Promoted Settings, alice_log patterns, Design Decisions, Small-Stings history |
| Noelle | Per build/validate | Universal Rules, Understanding entries, gap log, fault patterns |
| Nora | Per trip | Trip authority chain, ezone protocol, physical observation rules |
| Natalie | Per dispatch cycle | Route sequence rules, dispatch timing, balance signals |
| Sally | Per station cycle | Slot registry rules, conveyor behavior, dwell time compliance |

---

## What This Replaces

Activity logs masquerading as learning. Retrospections that list what happened without
asking whether it should have happened differently based on what was already known.
Summaries that feel productive because they are long. The length of a retrospection is
not its value. The grades are its value.

---

## The Scar That Produced This

2026-06-27: Claude Code did not read Allie's facets or recall files at session start,
despite multiple memory entries and CLAUDE.md instructions saying to do so. The session
still succeeded — but only because the problem (database scramble) was diagnosable from
first principles. If the problem had required cross-domain context that Allie held,
the session would have failed. The retrospection graded this an F. Bill's response:
"We need Retrospection. We do not get Retrospection without memories and measuring
performance against those memory markers."

That statement is this principle.

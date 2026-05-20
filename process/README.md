# Process Knowledge

**Purpose:** Capture the reasoning chain through failed → partial → successful approaches,
not just the outcome. The outcome is the last sentence of the story. The process is the story.

*"Knowing the outcome is much less valuable than knowing the process."* — Bill James, 2026-05-18

---

## The Full Cycle

```
FAULT  → the system reported a problem
DNW    → a fix was tried and failed
TF     → the insight that made the solution visible
TFTS   → the complete arc, written after success
```

FAULT comes first — it is the problem statement. DNW and TF come after.
A FAULT with no TFTS is an open wound. Allie watches for them.

---

## Inbox Files (`process/inbox/`)

Written at the moment of the event — not at session end.

| File suffix | Type | When to write |
|---|---|---|
| `-fault.md` | **Fault Found** | The moment the system reports a problem: Noelle faults[], trip errors, build failures, Nora anomalies |
| `-dnw.md` | **Did Not Work** | The moment a fix attempt fails — before trying the next approach |
| `-tf.md` | **That Fixed It** | The moment an insight emerges — what made it clear |
| `-tfts.md` | **Try-Fail-Try-Succeed** | After success — the complete arc, including all DNW steps |

### FAULT format

```markdown
# FAULT — YYYY-MM-DDTHH:MM:SS

system:      SU | PH | RT | WC3 | SYS | ALLIE
detected_by: Noelle | Nora | Natalie | Claude | Allie | Bill | Alice
fault:       one-line description
context:     what was happening when the fault occurred
resolved_at: (leave blank until resolved)
```

`fault` = what the system said. Not what you think caused it. Cause comes in DNW/TF.

### DNW format

```markdown
# DNW — YYYY-MM-DDTHH:MM:SS

intent:   what fix was being attempted
code:     file:line or system component
result:   what actually happened
revealed: what the failure showed (this is the valuable part)
```

### TF format

```markdown
# TF — YYYY-MM-DDTHH:MM:SS

summary: the principle, in one sentence
code:    file:line where it applies
```

### TFTS format

```markdown
# TFTS — YYYY-MM-DDTHH:MM:SS

problem:   one-line description
fault_ref: TIMESTAMP of the originating fault file (if applicable)
arc:
  - try:      what was attempted
    result:   failed
    revealed: what the failure showed
  - try:      what was attempted
    result:   succeeded
principle: the rule that made the final attempt obvious in retrospect
domain:    SU | RT | PH | SYS | WC3
```

---

## Shell Aliases

```bash
alias fault='bash ~/Allie/scripts/allie-fault.sh'
alias dnw='bash ~/Allie/scripts/allie-dnw.sh'
alias tf='bash ~/Allie/scripts/allie-tf.sh'
```

TFTS files are written manually (they synthesize an arc — no script shortcut).

Usage:
```bash
fault "Noelle: S013 missing detectable platform guideways"
dnw   "Added platform_guideways tag to S013 group"  "noelle.rb:410"
tf    "Tag must be on the component definition, not the group instance"
```

---

## Longer-form Problem Folders (`process/sk/`, `rt/`, `ph/`)

Each sustained problem gets its own folder. Name it for the symptom, not the solution:
`bezier-height/` not `zero-center-pts-z/` — you don't know the solution when you start.

| File | What it contains |
|---|---|
| `problem.md` | Symptom, context, what was known going in |
| `attempt-NN.rb` (or `.py`, `.json`) | The code that was tried |
| `narrative.md` | The reasoning chain — **this is the most valuable file** |

### `narrative.md` format

```markdown
# Problem: [symptom]

## What we knew going in
[Context, prior assumptions, what the system should have been doing]

## Attempt 1 — [what was tried]
Result: [what happened]
What this told us: [the insight the failure produced]

## Solution — [what finally worked]
Why this works where the others didn't: [structural reason]

## Rule derived
[The axiom this produced — pointer to CLAUDE.md, noelle.md, etc.]
```

---

## What Allie Does with Inbox Files Nightly

| File type | Allie action |
|---|---|
| `fault` with no matching `tfts` | Flags as unresolved → ouch-list candidate |
| `fault` + `tfts` pair | Extracts fault class + resolution → Understanding candidate |
| `dnw` sequence | Traces the arc; if followed by `tfts`, extracts full arc |
| `tf` alone | Extracts principle; links to prior `dnw` if close in time |
| `tfts` alone (no `fault`) | Development arc — Understanding candidate |

The `fault_ref` field in TFTS links the resolution back to the originating fault.
Allie uses this to calculate resolution time and classify recurring vs. one-off faults.

---

## Signal vs. Noise

Record the **key shift** at each attempt — the moment a failure revealed something.
Not every error. Not the stack trace. The insight the crash produced.

**The test:** would a reader who skipped this entry miss something they could not derive
from surrounding entries? If no, cut it.

---

## When to Write

**During the session, at the moment of the event.** Not at session end.
A fault logged at the moment of detection records the context that caused it.
A fault logged the next day describes the outcome from memory.

FAULT and DNW especially lose value quickly — write them before the next attempt, not after.

---

## Integration with Understanding Entries

When a process arc produces a rule, the Understanding entry gets a `process_ref:` field:

```markdown
## U-SK-007 — Zero center_pts Z before PathBuilder
**Rule:** All Z in center_pts must be zeroed before PathBuilder.apply_vertical_profile.
**process_ref:** process/sk/bezier-height/narrative.md
```

---

## Backfill Owed

| Problem | Folder | Key shift to capture |
|---|---|---|
| Bezier height at 7.5m | `sk/bezier-height/` | Grade corridor uses center_pts Z as seed, not just anchor_z |
| `Vector3d * Float` crash | `sk/vector3d-multiply/` | No coerce; both `.rb` files have independent copies |
| LayerManager never existed | `sk/layer-manager-missing/` | All `if defined?` guards silently falling through |
| CP anchor Z alternatives | `sk/cp-anchor-z/` | Three alternatives failed; committed code was correct |

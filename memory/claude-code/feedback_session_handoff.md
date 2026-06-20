---
name: Session handoff protocol
description: Write today/handoff.md at every session end; Allie reads it to brief Bill at the next session start
type: feedback
---

Write `today/handoff.md` at the end of every session. The retrospection records what was done; the handoff says what to do next. Both must be written — they serve different purposes.

Also write `sessions/YYYY-MM-DD.md` using the template at `sessions/_template.md`. This is the debugging learning feed — harvest.py reads it and includes Accomplished/Next/Open Questions as the first section of the daily harvest, which flows into Allie's nightly reflection. Without this file, Allie sees file change timestamps but not what was debugged or decided.

**Why:** Context reconstruction from the summary mechanism is passive and lossy. The session file captures the "why" (root cause, design decisions) that the watcher's file-change log cannot. This is how Allie learns from debugging sessions — not from timestamps, but from structured lessons.

**How to apply:**
- At any natural session end: write both `today/handoff.md` AND `sessions/YYYY-MM-DD.md`.
- Session file Accomplished format: `- **bug/feature name** (file:function) — root cause — fix`
- handoff.md format: Where We Left Off, Do This First (max 5 items), Open Problems, What Was Decided, Files Changed.
- Allie archives the previous handoff to `today/handoff-YYYY-MM-DD.md` before Claude Code overwrites it.
- Full protocol in `readmes/39-session-handoff.md`.

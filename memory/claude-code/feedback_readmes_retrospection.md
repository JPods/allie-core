---
name: Always access and update readmes + retrospections
description: Bill expects Claude Code to proactively read relevant readmes at session start and write retrospections at session end — without being asked
type: feedback
---

Always read and update the Allie readmes, especially on retrospection.

**Why:** Bill's readmes are the authoritative cross-session knowledge base for both Claude Code and Allie. Retrospections are how the system learns across sessions. This is not optional housekeeping — it's core to how the team operates.

**How to apply:**
- At the start of any session involving a known project, read the relevant readme from `/Users/williamjames/Allie/readmes/`
- At the end of any significant session, write or append to the retrospection file at `/Users/williamjames/Allie/readmes/retrospections/YYYY-MM-DD.md`
- Update the project readme (e.g. `27-route-time.md`) whenever something significant changes in architecture, behavior, or file locations
- If a readme is stale or wrong, fix it — don't just note the discrepancy

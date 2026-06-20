---
name: jpod_guideway.rb audit — pending re-run after UI rework
description: Full audit of jpod_guideway.rb completed 2026-05-01; must be re-run after SketchUp UI rework
type: project
---

Full Prompt 1–7 audit of `jpod_guideway.rb` completed 2026-05-01. Bill is reworking the SketchUp user interface. Re-run the full audit sequence when that work is complete.

**Why:** The UI rework may alter responsibility boundaries and coupling in the guideway file. The audit baseline (7,082 lines, 14 responsibilities, 12 class vars) was captured before any refactoring.

**Trigger phrase:** "re-run the guideway check" or "review guideway after UI rework"

**Audit document:** `readmes/sketchup/jpods-guideway-audit.md`

**How to apply:** When Bill gives the trigger phrase, read `readmes/sketchup/jpods-guideway-audit.md` and run Prompts 1–7 against the current state of:
`/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods/jpod_guideway.rb`

**Key baseline (2026-05-01):**
- 7,082 lines
- 14 responsibilities (A–N)
- 12 class variables, all owned by animation runtime (J)
- Safest first extraction: Responsibility L (Trip Validation) → `jpod_trip_builder.rb`

**WC3 action:** Needs to be posted when Django (localhost:8000) is running. Title: "Re-run jpod_guideway.rb audit after SketchUp UI rework". Django was offline when this session ended 2026-05-01.

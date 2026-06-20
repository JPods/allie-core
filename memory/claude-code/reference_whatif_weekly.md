---
name: Weekly WhatIf prediction loop
description: Claude + Allie post 3–5 predictions/week; scored on accuracy and usefulness; builds calibrated judgment over time
type: reference
---

Weekly prediction loop started 2026-05-13.

**Directory:** `readmes/wisdom/whatif-weekly/`
**Files:** `YYYY-WNN.md` per week, `aggregate.md` for scores, `README.md` for format

**Claude posts:** at session end, 3–5 items in the current week file. IDs: `C-WNN-N`.
**Allie posts:** Monday 07:00 via `scripts/allie-whatif.py` (LaunchAgent: `com.allie.whatif.plist`). IDs: `A-WNN-N`.

**Three scores per item:**
- % Complete — resolution date passed and assessed?
- % Accurate — Yes/Partial/No (N/A for open questions)
- % Worthwhile — led to action, discovery, or conversation worth having?

**Domains:** WC3, SU, PH, RT, SYS, EXT

**Why it exists:** Over a year, the aggregate reveals what Claude and Allie actually know (high accuracy) vs. pattern-match on noise (low accuracy). Items that are worthwhile even when wrong = good questions. Items accurate but never worthwhile = noise to stop posting.

**To score past items:** Fill Outcome/Accurate/Worthwhile columns in the week file, then run:
```bash
python3 /Users/williamjames/Allie/scripts/allie-whatif.py --score
```

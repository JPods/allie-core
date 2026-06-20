---
name: Wisdom layer location and structure
description: The three-layer experience base — knowledge, wisdom (scars/rejected-paths/bill.md), WhatIf observations
type: reference
---

The wisdom layer lives at `/Users/williamjames/Allie/readmes/wisdom/`.

| File | What it holds |
|------|--------------|
| `bill.md` | Bill's load-bearing principles in his own voice — written to survive any specific codebase |
| `clearance-height.md` | Exemplar entry: the 4.6m clearance decision with scar, rejected paths, principle, WhatIf |
| `scars.md` | Cost ledger — what each hard lesson cost and why it was hard to see |
| `rejected-paths.md` | Design paths seriously considered and set aside — the temptation matters as much as the decision |
| `whatif.md` | Allie's autonomous observations — seeds that may become risks, decisions, or principles |
| `README.md` | Format guide, reading order for successors, translation protocol |

**Reading order for a new team member:** bill.md → clearance-height.md → scars.md → rejected-paths.md → whatif.md → agent files → CLAUDE.md

**allie-reflect.py** now reads open WhatIf items and unpaid scars nightly, includes them in the synthesis prompt, and adds a "Wisdom Connections" section to the output.

**Session protocol:** At session end, update scars.md if a scar was paid or recognized; update rejected-paths.md if a significant path was set aside; Allie writes to whatif.md autonomously.

---
name: Template validation chain — save, compute, test timestamps must align
description: Model save dt > lines.computed.json generated_at → reject until recomputed; generated_at > validation_dt → reject until retested; all dt in UTC
type: feedback
---

Template quality chain: Save → Compute → Test → Validated. Each timestamp must be newer than the previous or Noelle rejects the model.

**Timestamps (all UTC ISO-8601 Z suffix — Axiom 14):**
- Model .skp file modification time — when designer last saved
- `lines.computed.json` `generated_at` — when Compute last ran
- `lines.computed.json` `validation_dt` — when station tests last passed (shuffle + depart + arrive)

**Rejection rules:**
- model save > generated_at → "Compute required — model changed since last Compute"
- generated_at > validation_dt → "Tests required — recomputed but not retested"
- validation_dt missing → "Tests required — never validated"

**Why:** A designer can change track geometry, save the model, and Build a network without recomputing or retesting. The old lines.computed.json has stale coordinates. Pods jam at junctions that moved. The validation chain prevents this.

**How to apply:**
- Compute stamps `generated_at` in lines.computed.json
- Station tests stamp `validation_dt` in lines.computed.json on all-pass
- Noelle checks timestamps at Build and animation start
- All datetimes UTC — Axiom 14, no exceptions

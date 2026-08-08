---
name: Catch naming inconsistencies — don't let them pass
description: Feeder fields must match the target field name; Claude/Allie/Alice should flag inconsistencies immediately, not echo them
type: feedback
---

When Bill uses an inconsistent name (e.g., `assign_to` vs `assigned_to`), flag it immediately. Don't echo the wrong name into code. The field is `action.assigned_to` — every feeder must also be `prefs.assigned_to[]`, not `prefs.assign_to[]`.

**Why:** Bill caught this himself and said we should have corrected him. Inconsistent naming creates bugs that grep can't find. One name, everywhere.

**How to apply:** Before writing any field reference, check the model definition for the canonical name. If the user uses a variant, say "the field is X, using that" — don't silently adopt the variant. This applies to all agents: Claude, Allie, Alice.

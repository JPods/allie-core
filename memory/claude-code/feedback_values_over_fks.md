---
name: Values over ForeignKeys
description: Use BigIntegerField for relationship IDs, not Django FK — deliberate WC2/WC3 design; refs.links carries display data
type: feedback
---

Bill used integer values (BigIntegerField) instead of ForeignKey fields in WC2 and carries this forward in WC3. This is deliberate, not legacy.

**Why:** No cascade surprises, no N+1 lazy loading, supports "primary among many" without junction tables, frontend sends/receives plain integers, refs.links carries denormalized display data so FK lookup is unnecessary.

**How to apply:** New relationship fields default to BigIntegerField. Use FK only when cascade behavior is specifically wanted (e.g., Touch.contact where deleting the contact should delete the touch). OrgBase.contact FK is the outlier — most of the codebase correctly uses BigIntegerField.

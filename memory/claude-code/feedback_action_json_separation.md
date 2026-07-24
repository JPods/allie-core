---
name: Action JSON field separation
description: metadata=behavior, config=content, project_metadata=parent's, retrospection=learning; never cross
type: feedback
---

Four JSON fields on Action, four distinct purposes. Never cross them.

- `metadata` — how the record behaves (quality_type, workflow_step, quality_number, workflow state)
- `config` — what the record contains (form-specific data: NCR item details, CAR root cause, PO line items). Field needs to be added to Action model.
- `project_metadata` — belongs to the parent project. Hands off. Do not use for action-level data.
- `retrospection` — structured learning after close (16 fields: intent, harms, benefits, grade, tfts, etc.)

**Why:** Bill said "project_metadata is for its parent" — it was being considered for form data, which would have violated the parent relationship.

**How to apply:** When storing quality/support form data on an Action, use metadata for now (keys don't collide with workflow state). When config field is added, migrate form data there.

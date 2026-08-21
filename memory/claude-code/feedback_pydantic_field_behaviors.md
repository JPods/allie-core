---
name: Pydantic owns field behaviors
description: Field labels, formatting, widget types belong in Pydantic schema code, not in database Settings — one place, version controlled, not user-configurable
type: feedback
---

Field behaviors (labels, formatting, widget types, visibility) belong in the Pydantic schema files (`common/schemas/*.py`), not in database Settings or runtime-computed services.

**Why:** Users don't customize field labels — that's a WebClerk product revision, not a per-installation config. Putting behaviors in code means version control, code review, testability. Putting them in the database means a bad save can break validation for an entire model — a stability risk with no user benefit.

**How to apply:**
- Pydantic schema files = single source of truth for data structure AND field presentation
- Settings (`wc:model`) = layouts only (which fields to show, in what order, at what width)
- `field_behaviors.py` service reads from Pydantic schema metadata, not Django model introspection
- `BehaviorOverrideDialog` (Cmd+Shift+click) becomes a layout tool, not a behavior tool
- This makes field behavior changes a code revision (PR, review, deploy), not a database mutation

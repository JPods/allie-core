---
name: field_access Setting pattern
description: One Setting per model with role-based view/edit/query_scope/publish matrix; seeded via seed_field_access; wcapi enforces on every request
type: reference
---

Each model gets one Setting record (purpose='field_access') defining who can view/edit what fields and what query scope restricts their data access.

Structure: `data.roles.<role> = { view, edit, create, delete }` + `data.query_scope.<role> = { filter_field: "$user.org_ids.<type>" }` + `data.publish.<channel> = [fields]`

Seeder: `./bin/python manage.py seed_field_access` (61 models, 8 roles each)
Readme: `webClerk3/readmes/wcapi-query-scoping.md`
Choices: `field_access` and `seed` added to SETTING_PURPOSE_CHOICES in `apps/core/choices.py`

wcapi/get injects role filters on every query. External users only see their own data. Superusers bypass all filters. See inline comments in wcapi.py.

---
name: List field priority — action, who, what, why, where, when, status
description: List columns follow journalism priority: action/ida first, then who (customer/contact), what (item/description), why (purpose/source), where (address), when (date), status. Show scalar values from JSON objects, not the object. Max 10 fields.
type: feedback
---

List field selection priority order:
1. **ida** — the action identifier (what record is this)
2. **who** — customer, vendor, contact, attention, display_name
3. **what** — item, description, name, amount, total
4. **why** — purpose, source, campaign, project
5. **where** — address, warehouse, territory
6. **when** — dt_created, dt_deadline, dt_due
7. **status** — status, kanban_column, priority

**JSON objects:** Show the most useful scalar value, not the whole object. Example: show `quantity.active` not `quantity`, show `price.unit` not `price`, show `cost.standard` not `cost`.

**Max 10 fields** per list. More than 10 makes the list unreadable.

**Export settings as JSON:** After reworking, export all Setting records as JSON to git repo for version control. Note: do this after each major settings update.

**How to apply:** All seed_databrowser list fields must follow this priority. BehaviorField and DataGrid should surface scalar values from JSON when possible.

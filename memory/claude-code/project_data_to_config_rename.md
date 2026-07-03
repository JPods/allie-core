---
name: data→config field rename
description: All 16 model JSONFields renamed from data to config; eliminates API data wrapper collision; DB columns, Python, React all updated 2026-07-03
type: project
---

Renamed `data` JSONField to `config` on 16 models (Setting, Pending, Document, Tag, Serial, SerialLog, Project, Report, Template, Notification, OrgItem, OrgBase, InventoryCheck, InventoryCheckLine, DeliveryVisit, DeliveryLine). Database columns renamed via direct SQL ALTER TABLE. Django migrations generated and faked. ~55 Python files and ~31 React files updated.

**Why:** The `data` field name collided with wcapi's `data` request envelope wrapper. `saveRecord` in React had to use a `record` wrapper hack to distinguish `payload.data` (envelope) from `setting.data` (field). Renaming to `config` eliminates the collision permanently.

**How to apply:** Field is now `model.config` everywhere. DB column is `config`. Use `config.views`, `config.list`, `config.detail` in dot-path operations.

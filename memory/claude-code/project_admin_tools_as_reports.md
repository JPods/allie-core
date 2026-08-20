---
name: Admin tools as Report records
description: Utility tools (audits, seeds, system checks) are Report records with category=admin_tool — dispatched to management commands, no new UI
type: project
---

Admin utility tools are Report records on the Setting model (`model_name='setting'`, `category='admin_tool'`, `output_type='json'`).

**Why:** Reports are discoverable (show up in Reports list), syncable (new installations get them via Bundle), Alice-trackable (usage, frequency, who), and configurable (parameters in config). No new admin console UI needed — the existing Report runner handles dispatch.

**How it works:**
- Report.config contains `{"command": "audit_field_behaviors", "args": ["--json"]}` 
- The runner calls the management command, captures JSON output, renders in the Report viewer
- Parameters (--model, --detail, --force) are configurable per-run
- Seeded by `seed_admin_tool_reports` management command

**How to apply:** When building a new admin utility, create it as a management command with `--json` output, then add a Report record that maps to it. Don't build custom admin pages.

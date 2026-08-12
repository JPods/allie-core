---
name: Touch model — communications event log
description: New Touch model in WC3 communications app for calls, emails, visits, texts; separate from Action; tel/mailto/sms URI launchers; TouchBar in AdminWorkbench
type: project
---

Touch model added 2026-08-11 to apps/communications/models/touch.py.

**What it is:** Contact event log — records that a communication happened. NOT an Action (work to be done). An Action may trigger a Touch, and a Touch may spawn an Action.

**Key fields:** contact FK, channel (call/email/visit/text/meeting), direction (in/out), subject, summary, duration (minutes), email_message_id (paste from email program), action FK (optional), org_id + org_model (polymorphic org link — customer/vendor/manufacturer/rep/employee), project_id, logged_by. Table: `touches`.

**URI launchers:** `tel:`, `mailto:`, `sms:` — universal across all OS/browsers. Apple Continuity makes Mac→iPhone seamless, but the URIs work everywhere (Android, Windows, etc.).

**UI:** TouchBar component in AdminWorkbench.tsx shows phone/email/text icons on Action, Contact, Customer, Vendor, Manufacturer, Rep, and Employee detail panes when the record has phone/email. Clicking fires the URI then opens a Touch record form pre-filled with contact, channel, direction, linked action_id (from Action) or org_id+org_model (from org records).

**Reports in reportLists.ts:** Call Summary, Email Draft, Visit Report, Touch History, Touch Export.

**Registered in:** model_registry.py, settings.py WCAPI_MODEL_MAP, field_access seeded, SPAWN_CONFIG (action→touches, contact→touches).

**Why:** Actions were being flooded with routine call/email logs. Actions are work items (kanban, priority, retrospection). Touches are events (timestamp, summary, done).

**How to apply:** Use Touch for logging communications. Use Action for work to be done. Link them via Touch.action FK when a call is triggered by an Action.

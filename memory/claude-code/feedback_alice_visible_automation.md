---
name: Alice automation must be visible and controllable
description: Every automated Alice function needs readme, admin dashboard, enable/disable, history — no invisible background processes
type: feedback
---

Every automated function Alice performs must be documented, visible, and controllable by the admin.

**Why:** Nuclear plants don't have invisible background processes. Gordy's quality principle applied to AI. If Alice breaks something, the admin must see which task ran and turn it off. If she's not doing something, the admin sees it's disabled.

**How to apply:**
- Each automated function = a Setting record with schedule, enabled, last_run, result
- Alice admin dialog shows: task name, schedule, last run, next run, pass/fail, enable/disable toggle
- Admin can force "Run Now" on any task
- Readme lists all automated functions with what/when/affects
- Celery tasks for: phone/email/zip normalization, ZeroBounce validation, address verification, dedup scan, import scrubbing
- Two layers: widget normalizes on client (instant), Alice normalizes on server (completeness)

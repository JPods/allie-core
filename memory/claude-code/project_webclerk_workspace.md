---
name: WebClerk combined workspace
description: WebClerk is at /Users/williamjames/Documents/CommerceExpert/WebClerk/ — backend+frontend in one dir; webClerk3 and React2025 are RETIRED
type: project
---

WebClerk codebase reorganized 2026-08-22 into a combined workspace.

**Active paths (use these):**
- Backend: `/Users/williamjames/Documents/CommerceExpert/WebClerk/backend/`
- Frontend: `/Users/williamjames/Documents/CommerceExpert/WebClerk/frontend/src/`
- Start: `/Users/williamjames/Documents/CommerceExpert/WebClerk/start.sh` (Django + Celery + Vite)

**Retired paths (DO NOT EDIT):**
- `webClerk3/` — old backend copy, may still exist on disk
- `React2025/` — old frontend copy, may still exist on disk

**Why:** Scar #70. We spent 45 minutes debugging 404s because we edited webClerk3/ while start.sh ran from WebClerk/backend/. Two copies of a codebase is two sources of truth.

**How to apply:** Before editing ANY WC3 file, verify the path starts with `/Users/williamjames/Documents/CommerceExpert/WebClerk/`. If you find yourself in `webClerk3/` or `React2025/`, stop — you're in the wrong place.

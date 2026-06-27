---
name: RBAC silently denies queries without UserProfile or is_superuser
description: inject_role_filters returns deny-all Q(pk__isnull=True) when user has no UserProfile; agents must be is_superuser=True
type: feedback
---

The RBAC layer in `apps/core/services/role_filter.py` has two gatekeepers:
1. `policy.inject_constraints` — bypassed by is_superuser, is_staff, or role=admin
2. `inject_role_filters` (line ~1000 in wcapi.py) — **only** bypassed by is_superuser

If a user has no `UserProfile`, `build_user_context` returns empty roles, and `get_user_filter_config` returns `None` → `Q(pk__isnull=True)` → zero results. No error, no warning.

**Why:** Discovered 2026-06-27 when Allie's wcapi search returned 0 contacts despite 22 existing. The fix was `is_superuser=True`.

**How to apply:** Any agent account that queries wcapi (Allie, Claude, Alice, Athena) must have `is_superuser=True` in the database, OR have a properly configured UserProfile with roles. Superuser is the simpler path for agents.

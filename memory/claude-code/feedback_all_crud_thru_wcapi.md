---
name: All CRUD flows through wcapi
description: No direct model access from React — every create, read, update, delete goes through wcapi endpoints which enforce RBAC, query scoping, field filtering, and audit
type: feedback
---

ALL data operations flow through wcapi. No exceptions. No traditional Django CRUD (ViewSets, per-model serializers, per-model permissions).

**Why:** Traditional Django CRUD means one ViewSet per model — 50+ copies of the same logic with 50 places to forget the security check. wcapi is ONE gate: wcapi/get, wcapi/save, wcapi/delete, wcapi/manage. inject_role_filters runs once, in one place. Field access checked once. Audit logged once. Bill's view: too much repetitive code and no single gate to protect.

**How to apply:** React calls wcapi/get, wcapi/save, wcapi/delete — model_name is a parameter, not a URL path. Never create per-model REST endpoints. Never create per-model ViewSets or serializers. Never bypass wcapi for any CRUD operation. If a new feature needs data, route it through wcapi and let the existing RBAC chain do its job. The only per-model code is in the field_access Setting record (data, not code).

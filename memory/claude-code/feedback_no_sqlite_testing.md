---
name: Test against PostgreSQL, not SQLite
description: SQLite wastes time on compatibility shims that don't apply to production; JSON filters, raw SQL, and FK behavior differ
type: feedback
---

Test against PostgreSQL, not SQLite. SQLite lacks JSON `__contains` filter, handles raw SQL differently, and has FK behavior differences that cause false failures.

**Why:** Bill: "This is why I do not want to deal with SQLite." Three separate SQLite-vs-Postgres friction points in one session (2026-06-27): JSON __contains in training cleanup, raw SQL LEFT JOIN in orphan detection, stale test database conflicts.

**How to apply:** Use `PYTEST_FORCE_DB=1` when running tests that touch JSON fields, raw SQL, or complex FK operations. Better yet, configure pytest.ini to default to PostgreSQL. The existing test DB name is `test_commerce_expert_new`.

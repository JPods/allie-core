---
name: refs and metadata are secondary to PKs
description: refs.links and metadata are denormalized caches derived from FK/PK relationships — never authoritative; PKs win on conflict
type: feedback
---

refs.links and metadata JSON fields are clever denormalization for fast UI display and keyword search, but they are always SECONDARY to standard PK/FK relationships. If refs disagree with the FK, the FK wins. refs are a cache, not a source of truth.

**Why:** Bill designed wc3 with PKs as authority and refs as derived pointers. This avoids the wc2 trap of denormalized fields becoming the de facto source of truth. The `audit_fk_values` command and `refs_mismatch_log` model exist to detect drift.

**How to apply:** When writing code that creates or updates relationships, always set the FK first, then update refs as a secondary step. Never read refs to determine a relationship — use the FK/ORM query. When writing tests, assert on FK values, not refs content.

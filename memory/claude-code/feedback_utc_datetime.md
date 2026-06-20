---
name: UTC datetime standard
description: All stored datetimes must be UTC ISO-8601 with Z suffix; display converts to local at render time; timezone stored as offset if needed
type: feedback
---

All stored datetimes — files, logs, attributes, databases — are UTC, ISO-8601 with Z suffix: `YYYY-MM-DDTHH:MM:SSZ`.

**Why:** Comparisons (expires_at, stale detection, billing) only work in a single reference frame. Multiple machines (Mac, Pi fleet, Alice server) may be in different zones or have misconfigured local clocks. UTC is immune to both.

**Ruby:** `Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')` — never `Time.now.strftime(...)` without `.utc`

**Python:** `datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')` — never `datetime.now().isoformat()`

**Display:** Convert UTC→local at render time only. The stored record is always UTC.

**Timezone metadata:** If physical location matters, store `utc_offset_minutes: -420` alongside the UTC dt. Never use local time as the primary record.

**How to apply:** Before writing any datetime field, confirm it uses `.utc` (Ruby) or `timezone.utc` (Python). Flag any `Time.now.strftime` without `.utc` as a bug. This applies to Noelle, Nora, Natalie, Alice, Allie, and Claude Code session files.

Established: 2026-05-20. Axiom 14 in CLAUDE.md.

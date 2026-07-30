# JPods UTC Datetime Standard

## The Rule

All datetimes stored in any file, database, attribute, or log record are UTC, ISO-8601 format with Z suffix:

```
YYYY-MM-DDTHH:MM:SSZ
```

This applies to every agent in the system: Noelle, Nora, Natalie, Alice, Allie, Athena, Claude Code.

---

## Why

- **Correctness of comparisons:** `expires_at`, `followme_hash`, stale detection, billing timestamps — all require a single reference frame. That frame is UTC.
- **Multiple machines:** Mac, Pi fleet, Alice server may be in different time zones or have misconfigured local clocks. UTC comparisons are immune.
- **Multi-agent:** Allie's nightly reflection (Mac) and Nora's observations (Pi in the field) produce records that are compared directly. They must share a reference frame.

---

## Patterns

### Ruby (SketchUp, Nora, Natalie, Noelle)

```ruby
# CORRECT
Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')

# WRONG — local time, no zone marker, not comparable across machines
Time.now.strftime('%Y-%m-%dT%H:%M:%S')
```

### Python (Allie, Pi agents, Alice scripts)

```python
# CORRECT
from datetime import datetime, timezone
datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# WRONG — local time, ambiguous
datetime.now().isoformat()
datetime.utcnow().isoformat()  # also wrong — no Z suffix, misleadingly named
```

---

## Display is a Rendering Concern

User-facing timestamps convert UTC to local at render time. The stored record is always UTC. Never store local time as the primary record because a user is in a particular timezone.

---

## Timezone Context (when location matters)

If the physical location of an event is meaningful (e.g., a Nora anomaly observation logged from a Pi that will eventually run in a different city), store the UTC offset alongside the UTC datetime:

```json
{
  "observed_at": "2026-05-20T18:30:00Z",
  "utc_offset_minutes": -420
}
```

`utc_offset_minutes` is a signed integer: -420 = UTC-7 (PDT), -480 = UTC-8 (PST), 0 = UTC.

Never store a timezone name string (`"America/Los_Angeles"`) as the primary record — names change with DST. The offset at the moment of the event is the authoritative record.

---

## What Counts as a "Stored Datetime"

These must be UTC:

| Field pattern | Examples | Location |
|---|---|---|
| `_at` suffix | `generated_at`, `exported_at`, `created_at`, `updated_at` | Any JSON file |
| `_at` suffix | `logged_at`, `observed_at`, `checked_at` | Log and physical observation records |
| `_at` suffix | `expires_at`, `trip_assigned_at`, `arrived_at` | Trip and dispatch records |
| `_at` suffix | `learned_at`, `reviewed_at`, `ran_at` | Agent state records |
| `_on` suffix | Any field carrying a full datetime | Any record |

These may be local (they are display or file-naming constructs, not stored data records):

| Usage | Example | Why local is acceptable |
|---|---|---|
| Filename slugs | `bundle-20260520-143022/` | Human readability; not compared programmatically |
| Console output | `puts "Audit — #{Time.now.strftime('%Y-%m-%d')}"` | Not a stored record |
| Log file names | `jpods-log-2026-05-20.log.json` | File naming only; contents still UTC |

---

## Verified Clean — 2026-05-20

All data-field timestamps fixed in the following files:

| File | Fields corrected |
|---|---|
| `noelle.rb` | `reviewed_at` |
| `jpod_vehicle_runtime.rb` | `created_at` |
| `jpod_animator.rb` | `created_at` |
| `jpod_structure_tool.rb` | `generated_at` |
| `jpod_followme_exporter.rb` | `exported_at`, `updated_at`, `generated_at` (4 instances) |
| `jpod_network_editor.rb` | `_generated` |
| `jpod_oversight.rb` | `ran_at` |

---

## Schema Fields Requiring UTC — Reference

The following fields appear in JSON schemas across the system. All are UTC-required.

### map.json / map-v2

| Field | Writer | Description |
|---|---|---|
| `generated_at` | Noelle | Timestamp of last Build or Validate |
| `last_physical_survey` | Nora | Timestamp of last Nora traversal |
| `exported_at` | FollowMe exporter | When the followme.json was last written |

### trip.json / trip-v2

| Field | Writer | Description |
|---|---|---|
| `generated_at` | TripPlanner | When the trip file was produced |
| `expires_at` | TripPlanner | When the trip file is considered stale |
| `trip_assigned_at` | Natalie | When dispatch assigned the trip to a pod |
| `arrived_at` | Nora | When the pod completed the trip |

### physical.json

| Field | Writer | Description |
|---|---|---|
| `logged_at` | Nora | When the physical observation was recorded |
| `observed_at` | Nora | When the physical event occurred (may differ from logged_at if buffered) |

### feature.json

| Field | Writer | Description |
|---|---|---|
| `generated_at` | Noelle | When Noelle last wrote the feature declarations |

### Agent state records (Allie, Athena)

| Field | Writer | Description |
|---|---|---|
| `reviewed_at` | Athena | Timestamp of last security review sign-off |
| `ran_at` | Allie / scripts | Timestamp of last nightly reflect run |
| `learned_at` | Allie | Timestamp of when an Understanding was promoted |

---

## Enforcement

Any code review (Athena, Allie, Claude Code) that finds `Time.now.strftime` without `.utc` in a data-field context is a bug. Flag immediately. Do not defer.

Checklist for any new field that carries a datetime:

1. Does the field name end in `_at` or `_on`?
2. Is the value produced by `Time.now.utc.strftime(...)` (Ruby) or `datetime.now(timezone.utc).strftime(...)` (Python)?
3. Does the value end in `Z`?
4. Is the field documented in the relevant schema readme?

All four must be true. If any is false, it is a bug before the field ships.

---

CLAUDE.md Axiom 14 — established 2026-05-20.

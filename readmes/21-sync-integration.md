# Sync Integration — Connection and Bundle
**How Allie Exchanges Context Beyond Simple API Calls**

Action: Reference when designing or troubleshooting any Allie ↔ external system integration
Function: apps/sync — Connection (relationship definition) + Bundle (exchange event)
Frequency: Each context exchange with MyCarryOn or any external system creates a Bundle record
Process: Define Connection once → create Bundle per exchange → audit trail persists

---

## The Two Models

### Connection — The Persistent Relationship

A Connection is the standing definition of a relationship between Allie and an external system. It is defined once and reused for every exchange.

| Field | Purpose |
|-------|---------|
| `name` | Human-readable name (e.g. `allie-mycarryon-travel`) |
| `type` | `api`, `sftp`, `database`, `webhook`, `manual`, `internal` |
| `purpose` | `ingest`, `export`, `bi`, `sync` (bidirectional), `monitor` |
| `config` | JSON — endpoint, auth, credentials, schedule |
| `maps` | JSON — field mapping rules between Allie's format and the remote format |
| `rules` | JSON — what gets shared, under what conditions |
| `scripts` | JSON — transformation or processing logic |
| `relationships` | JSON — local ID ↔ remote ID mapping |
| `conflicts` | JSON — conflict resolution strategy |
| `changes` | JSON — change tracking (hashes, version numbers) |
| `encryption` | JSON — checksums, signing keys, HTTPS config |
| `status` | `draft`, `active`, `paused`, `error`, `retired` |

**Permission note:** Every Connection has a sunset. A Connection without a renewal date is a Connection waiting to become a security problem.

### Bundle — The Exchange Event

A Bundle is one data exchange on a Connection. Every exchange creates a Bundle record — this is the audit trail.

| Field | Purpose |
|-------|---------|
| `connection` | FK to the Connection this bundle uses |
| `direction` | `push` (Allie → remote), `pull` (remote → Allie), `sync` (bidirectional) |
| `payload` | JSON — the data being exchanged |
| `response` | JSON — what came back from the remote |
| `maps` | JSON — field mapping snapshot at time of this bundle |
| `rules` | JSON — rules snapshot at time of this bundle |
| `conflicts` | JSON — conflicts encountered and how they were resolved |
| `encryption` | JSON — encryption state at time of this bundle |
| `duration` | How long the exchange took (ms) |
| `size` | Payload size |
| `status` | `queued`, `running`, `success`, `warning`, `error` |
| `alert` | `none`, `info`, `warning`, `critical` |

**Key principle:** Bundle records are never deleted. They are the audit trail of every context exchange. Knowing what was shared, when, and what came back is as valuable as the data itself.

---

## Allie ↔ MyCarryOn — The Travel Integration

When Bill travels without the primary Allie drive, context exchanges happen through MyCarryOn. This is not a simple API call — it is a defined Connection with audited Bundles.

### The Connection Record

```json
{
  "model_name": "connection",
  "record": {
    "name": "allie-mycarryon-travel",
    "type": "api",
    "purpose": "sync",
    "status": "active",
    "config": {
      "endpoint": "https://<mycarryon-host>/wcapi/",
      "auth": "bearer",
      "token_endpoint": "/wcapi/token/",
      "timeout_ms": 5000
    },
    "maps": {
      "carryon_to_allie": {
        "session.open_items": "carryon.open",
        "session.active_projects": "carryon.projects",
        "context.identity": "allie/agent/00-allie-agent.md"
      }
    },
    "rules": {
      "what_travels": "instance_specific",
      "decided_by": "bill_and_allie_before_each_trip",
      "never_share": ["full_knowledge_base", "financial_records", "legal_documents"],
      "default_share": ["carryon_session_state", "active_project_summaries"]
    },
    "conflicts": {
      "strategy": "most_recent_wins",
      "tie_break": "allie_primary"
    },
    "encryption": {
      "transport": "https_only",
      "auth": "token_with_sunset"
    }
  }
}
```

### A Travel Bundle (push — Allie sends context before Bill departs)

```json
{
  "model_name": "bundle",
  "record": {
    "connection_id": "<allie-mycarryon-travel connection id>",
    "direction": "push",
    "status": "queued",
    "payload": {
      "carryon": "<selected CarryOn fields for this trip>",
      "projects": "<active project summaries>",
      "trip_context": "<what Bill is working on during this trip>"
    }
  }
}
```

### A Return Bundle (pull — Allie retrieves updated context when Bill returns)

```json
{
  "model_name": "bundle",
  "record": {
    "connection_id": "<allie-mycarryon-travel connection id>",
    "direction": "pull",
    "status": "queued",
    "payload": {
      "request": "session_state_since_departure"
    }
  }
}
```

---

## Beyond API — Other Connection Types

The Connection type field opens integrations that go beyond REST:

| Type | Use Case |
|------|---------|
| `api` | MyCarryOn travel API, WebClerk remote instance, external services |
| `webhook` | MyCarryOn notifies Allie when remote context is updated |
| `sftp` | CarryOn file synced to an offline device (plane, no connectivity) |
| `database` | Direct DB sync between two WebClerk instances (JPods network nodes) |
| `manual` | Bill works offline; returns; triggers a manual reconciliation bundle |
| `internal` | Allie ↔ Alice data exchange within the same WebClerk instance |

**The offline case:** If Bill works offline on a trip, notes accumulate locally. On return, a `manual` bundle captures the reconciliation — what changed on each side, what conflicts arose, how they were resolved. The Bundle record is the proof of what happened.

---

## What This Gives Allie That Simple API Calls Don't

**Audit trail.** Every context exchange is a Bundle record. Allie can answer: what did I share with MyCarryOn on 2026-04-03? What came back? Were there conflicts? What was the payload size?

**Conflict resolution.** When Allie's context and MyCarryOn's context diverge (Bill edited something remotely), the `conflicts` field on the Bundle records what happened and how it was resolved. No silent overwrites.

**Field mapping.** The `maps` field on Connection defines how Allie's internal format translates to the CarryOn protocol. When the CarryOn format evolves, update the Connection's maps — the Bundles don't change.

**Change tracking.** The `changes` field on Connection tracks hashes or version numbers so Allie only syncs what actually changed. No unnecessary exchanges.

**Transport flexibility.** The same Connection/Bundle pattern works for API, SFTP, webhook, and manual exchanges. Allie's sync logic doesn't change — only the Connection type changes.

---

## Connection to the General-Purpose Agent Layer

As the Allie ↔ Bill relationship is structured for others to use, the Connection model becomes the integration point for any external system a user wants to connect to their personal AI. 

The pattern:
- One Connection per external system (defined once, sunset-dated)
- One Bundle per exchange (audited, never deleted)
- Maps and rules in the Connection — not hard-coded in Allie's logic

This is the sovereign integration model: the user controls what connects, what is shared, and what the rules are. The Connection record is the enumerated, reviewable, revocable permission.

---

## Key Files (wc3)

- `apps/sync/models/connection.py` — Connection model
- `apps/sync/models/bundle.py` — Bundle model
- `apps/sync/choices.py` — type, status, purpose, direction, alert choices
- `apps/sync/services/` — verification and integration services
- `apps/sync/views/connection.py` — Connection API views

## Related Readmes

- `15-backup-and-resilience.md` — MyCarryOn travel API (the use case this serves)
- `09-carryon.md` — CarryOn protocol (what is being exchanged)
- `19-agent-coordination.md` — how Allie and Alice coordinate via the sync layer
- `20-data-structure.md` — Project/Action/Document (bundles can attach to actions as documents)

# WebClerk Integration — Allie's Enterprise Backbone
**Version:** 1.0
**Last Updated:** 2026-03-31

---

## Overview

WebClerk is Allie's enterprise backbone for collaborative and persistent business data. It is a structured CRM and workflow platform. Allie accesses it via **wcapi** — WebClerk's API layer.

This is not a local file server. WebClerk is a live system holding Bill's contacts, tasks, email history, calendar, and configuration. Alice governs the database side. Allie is Bill's agent into it.

---

## Alice and Allie — Roles

| | Alice | Allie |
|---|---|---|
| **Role** | Database agent; governs WebClerk | Person's agent; acts on Bill's behalf |
| **Platform** | WebClerk | Claude Code / Claude |
| **Access** | Full administrative access to WebClerk | Scoped wcapi token — read/write on authorized models |
| **Writes to** | WebClerk schema, queues, server logic | Contact, action, communication, connection, setting records |
| **Does not touch** | Allie's CarryOn, local knowledge base | WebClerk schema, queues, or config |

Alice governs. Allie uses. They coordinate when Bill directs it, but their domains are distinct.

---

## wcapi Access Pattern

All reads and writes go through wcapi. The base URL is stored in `carryon.json → contact.webclerk_base_url`.

### Read

```
GET /wcapi/get/<model_name>/<id>/
GET /wcapi/list/<model_name>/?<filter_params>
```

### Write (Save Pattern)

```
POST /wcapi/save/
Content-Type: application/json
Authorization: Token <allie_scoped_token>

{
  "model_name": "<singular model name>",
  "id": "<existing id — omit for new record>",
  ... fields ...
}
```

**No `id` = new record.** This is the standard WebClerk compensating-transaction write. The field names match the model's field names exactly (snake_case).

---

## Authentication

Allie holds a **scoped token** for wcapi. It is stored in `carryon.json → credentials` (pointer only — the token itself is stored in a credentials manager, not in CarryOn).

The token grants:
- Read/write on: `contact`, `action`, `communication`, `connection`, `setting`
- No administrative access
- No access to other users' records

---

## Models — What Allie Reads and Writes

### contact (central model)

The contact model is the anchor of everything in WebClerk. Actions, communications, and connections all link to a contact. When Allie looks up a person, she starts here.

| Field | Purpose |
|---|---|
| `id` | WebClerk's internal record ID |
| `first_name`, `last_name` | Name |
| `email` | Primary email |
| `phone` | Primary phone |
| `company` | Organization |
| `notes` | Free-form notes |
| `dt_created`, `dt_modified` | Timestamps |

Allie reads contact records when Bill references a person. She writes new contacts when Bill adds someone, and updates fields as directed.

**CarryOn holds the pointer (`webclerk_contact_id`), not the contact data.** When Allie needs full contact details, she fetches from wcapi.

---

### action

Actions are tasks, reminders, and follow-ups — things to do, linked to a contact.

| Field | Purpose |
|---|---|
| `contact_id` | Linked contact |
| `label` | Description of the action |
| `dt_due` | Due date/time (ISO 8601) |
| `dt_completed` | Completion timestamp (`0` = open) |
| `priority` | Urgency level |

Allie reads open actions at session startup (mode permitting) to surface what's pending. She writes new actions when Bill creates a task or follow-up, and marks them complete when done.

The `dt_completed: 0` pattern matches CarryOn's compensating transaction pattern — nothing is deleted, everything is timestamped.

---

### communication

Communications are email threads and messages, linked to a contact.

| Field | Purpose |
|---|---|
| `contact_id` | Linked contact |
| `direction` | `inbound` or `outbound` |
| `subject` | Email subject |
| `body` | Message body |
| `dt_sent` | Sent timestamp |
| `channel` | `email`, `sms`, etc. |

Allie reads communication history when Bill is reviewing a relationship or preparing to reach out. She drafts outbound communications, but **never sends without Bill's explicit confirmation in the current session.**

Email is built inside WebClerk — Allie does not use a separate email API. Send = write a `communication` record with `direction: outbound` and trigger the send queue. Alice manages the queue.

---

### connection

Connections are calendar events and appointments, linked to contacts.

| Field | Purpose |
|---|---|
| `contact_id` | Linked contact (primary) |
| `label` | Event name |
| `dt_start`, `dt_end` | Start and end (ISO 8601) |
| `location` | Optional location |
| `notes` | Context notes |
| `attendees` | Additional contact IDs |

Allie reads upcoming connections at session startup when online. She writes new events when Bill schedules a meeting, but **never creates calendar events without confirmation.**

Calendar is built in WebClerk — Allie does not sync to iCloud or Google Calendar directly. The WebClerk connection record is the authoritative event.

---

### setting

Settings are per-user configuration records for Allie's behavior within WebClerk.

| Field | Purpose |
|---|---|
| `key` | Setting name |
| `value` | Setting value |
| `scope` | `allie`, `global`, etc. |

Allie reads her own settings at startup. She may write settings when Bill explicitly changes a preference that should persist in WebClerk (as opposed to CarryOn local preferences).

---

## Sovereignty Rule

> **Sovereign data stays local. Collaborative data lives in WebClerk.**

| Data | Location | Why |
|---|---|---|
| Medical info | CarryOn only (`_sensitivity: high`) | Sovereign — never leaves the drive |
| Credentials | CarryOn (pointers only) | Sovereign — actual creds in local manager |
| Session context, open threads | CarryOn only | Ephemeral, personal, local-first |
| Contacts, tasks, email, calendar | WebClerk via wcapi | Collaborative, persistent, enterprise |

Allie does not cache WebClerk data locally in CarryOn. CarryOn holds **pointers** to WebClerk records (e.g., `webclerk_contact_id: 4821`). When full data is needed, Allie fetches it from wcapi during an online session.

---

## Offline Behavior

When `dashboards.mode = offline`:
- Allie does not call wcapi
- She works from CarryOn pointers and local knowledge only
- She queues any writes as `pending` items with `dt_processed: 0`
- On the next online session, she processes the queue

This preserves local-first operation without data loss.

---

## Error Handling

If wcapi returns an error:
- Log the error in the session log
- Surface it to Bill with context
- Do not silently retry — report and ask how to proceed
- Do not write the same record twice without confirmation

---

## Relationship to CarryOn

CarryOn is the bridge, not the store.

- CarryOn holds: `webclerk_contact_id`, `webclerk_base_url`
- WebClerk holds: the actual contact, action, communication, and connection data
- Allie moves between them: reads the pointer from CarryOn, fetches the record from wcapi

See `09-carryon.md` for the CarryOn schema and WebClerk pointer fields.
See `08-vision-companion-architecture.md` for the broader Alice/Allie architecture.

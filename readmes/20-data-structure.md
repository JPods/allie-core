# Data Structure — How Work is Organized
**Project → Action → Document**

Action: Reference when organizing any work across any project in the ecosystem
Function: Organizational model — three-layer structure used in WebClerk across all domains
Frequency: Standing reference; update when the model evolves
Process: All work fits into this structure — if it doesn't fit, question whether it's real work

---

## The Three-Layer Structure

```
Project  (1-week sprint container — the unit of accountability)
    └── Action  (one unit of work — who, what, why, when)
            └── Document  (evidence, specs, photos, contracts — path to file)
```

Every piece of work in every domain — JPods construction, WebClerk development, Allie's WhatIf store, mycarryon, Divided Sovereignty, postRoads — fits this structure. If it doesn't fit, it isn't real work yet.

---

## Project — The Sprint Container

**Duration:** One week. Always.

A project is the unit of accountability. One week is long enough to accomplish something real. Short enough that a bad sprint doesn't sink the effort. Forces honest scoping — if it can't fit in a week with 3-7 people, break it down.

**Two modes:**

| Mode | Example | Cadence |
|------|---------|---------|
| **Weekly sprint** | `kanban-2026-03-28` | Created each week; closed at retrospection |
| **Permanent container** | `allie-whatif` (id=24), `allie` (id=25) | Standing organizational structure; no weekly cycle |

Weekly sprint projects are the retrospection unit. At the end of each week, the project captures what closed, what pain was felt, what pleasure was earned. That measurement is how teams home in on the target.

**Key fields:**

| Field | Purpose |
|-------|---------|
| `name` | Human-readable sprint name (e.g. `kanban-2026-03-28`) or permanent name |
| `category` | Domain tag (e.g. `jpods`, `webclerk`, `allie`) |
| `intent` | Why this project exists |
| `situation` | Current state — updated as the sprint progresses |
| `objective` | Success definition, scope in/out, metrics |
| `status` | `active` / `done` / `onhold` / `canceled` |
| `priority` | 1 = highest |
| `dt_kanban` | Sprint start date |

---

## Action — The Unit of Work

An action is one thing to be done. It cannot be vague. It must have an owner, a next step, and a date. Without all three, it is not an action — it is a wish.

**The five questions every action answers:**

| Question | Field | Notes |
|----------|-------|-------|
| **Who** | `assigned_to` | One person. Not a team, not a role — a person. `{"name": "...", "contact_id": ...}` |
| **What** | `description.text` | The work in one sentence |
| **Why** | `comments.public` | The reason this exists; what breaks if it's skipped |
| **When** | `dt_deadline` | Sunset date — Unix milliseconds. Everything expires. |
| **Next** | `action.next` | The specific next physical action that moves this forward |

**Kanban lifecycle:**

```
open → in-progress → review → done
         ↓
      blocked (with reason in comments)
         ↓
      deferred (new dt_deadline required)
```

**Additional fields used:**

| Field | Purpose |
|-------|---------|
| `project_id` / `project_name` | Links action to its sprint |
| `kanban_column` | Position on the board |
| `status` | `active` / `done` / `canceled` |
| `priority` | 1 = urgent |
| `dt_start` | When work begins |
| `dt_completed` | When it closed |
| `percent_complete` | Progress indicator |
| `parent_action` | Sub-actions hang from parent actions |

**Sub-actions:** Complex work breaks into parent → child actions. The parent action is not done until all children are done. This keeps scope small at every level.

---

## Document — The Evidence Layer

A document record is a pointer to a file. It does not store the file — it stores the path, the type, and enough metadata to find and understand the file.

Documents attach to actions (and to projects, or any other model) via `linkageentry` — a junction record that creates the relationship without embedding the document in the action.

**What documents carry:**

| Type | Examples |
|------|---------|
| Specifications | Engineering drawings, requirements docs, API specs |
| Evidence | Photos of construction progress, test results, inspection reports |
| Legal | Permits, contracts, franchise agreements |
| Reference | Patents, standards documents, research papers |
| Correspondence | Emails, letters, meeting notes |

**Why paths, not embedded files:**

Files are large. Database records are for structured data. A document record stores where the file lives (local path, cloud URL, network share) and what it is. The file itself stays where files belong. This is the same principle as WebClerk's item catalog — the record describes, the file holds.

---

## How This Applies Across the Ecosystem

### JPods Construction
```
Project: jpods-network-segment-7 (week of 2026-04-07)
    └── Action: Pour foundation — pier 12
            who: [site supervisor name]
            what: Pour and cure concrete foundation at pier 12
            why: Critical path — guideway installation blocked until cured
            when: 2026-04-10
            next: Confirm concrete delivery scheduled for 2026-04-08 AM
        └── Document: pier-12-engineering-spec.pdf
        └── Document: pier-12-inspection-photo-2026-04-09.jpg
        └── Document: pier-12-permit.pdf
```

### WebClerk Development
```
Project: kanban-2026-03-28 (sprint)
    └── Action: Add voice field to ticket model
            who: Alice
            what: Add `voice_transcript` field to action model; wire to wcapi
            why: Voice-created tickets need original transcription stored
            when: 2026-04-04
            next: Draft migration and update model-fields.json
        └── Document: voice-interface-spec.md (from Allie's prototype)
```

### Allie's WhatIf Store
```
Project: allie-whatif (permanent)
    └── Action: WhatIf — voice interface for JPods field teams
            who: Allie
            what: Voice input in native language routes to WebClerk ticketing
            why: Removes keyboard and language barriers for field crews
            when: 2026-05-01 (sunset)
            next: Draft interface spec; validate against JPods field scenarios
        └── Document: 17-voice-interface.md (Allie's readme)
```

---

## The Retrospection Accounting

At the end of each weekly sprint project, the project becomes the retrospection unit:

1. **What closed?** — actions moved to `done` in this project
2. **What didn't close?** — actions carried forward; why?
3. **What pain?** — friction, blockers, surprises that slowed the work
4. **What pleasure?** — what worked well, what should be repeated
5. **Happiness check** — are the people doing this work finding it meaningful?
6. **Honesty check** — is the team stating facts or performing confidence?

The measurements from retrospections adjust the next sprint. This is how small bites compound into eating the elephant.

---

## Setting Records — The Feature Store

The pattern recognition pipeline (Allie + Alice observing user behavior) terminates in `Setting` records when a pattern graduates from candidate to active feature.

```
alice_log (observation) → alice_pending config_suggestion (pattern)
    → Allie validates → Setting record (feature, inactive)
        → Bill approves → Setting is_active=True (live for users)
```

Setting purposes used in this pipeline:

| Purpose | Meaning |
|---------|---------|
| `alice_pending` | Pattern candidate — under Allie's review |
| `alice_log` | Observation history — stays here, never promoted |
| `recommendation` | Feature validated by Allie, awaiting Bill's activation |
| `search` | Active saved search preset |
| `default` | Default values derived from pattern analysis |
| `save_pre_post` | Save hooks (existing, not pattern-driven) |

Setting records live in WebClerk alongside Projects, Actions, and Documents — same database, same audit trail, same sovereignty model.

Full pipeline spec: `webClerk3/readmes/topics/ai/pattern-recognition.md`

---

## Rules

1. **No action without owner, next step, and sunset.** All three or it doesn't exist as an action.
2. **All permissions have sunsets.** This applies to actions too — if the deadline passes without completion, it must be explicitly renewed or closed.
3. **Documents are paths, not content.** Store the pointer, not the file.
4. **Projects run one week.** If the work doesn't fit, break it down further.
5. **Sub-actions before scope creep.** If an action grows too large, create child actions under it — don't expand the parent action's scope.
6. **Requirements fight for their lives.** Every action entering a sprint must justify its presence. If it can't, it doesn't go in.

---

## WebClerk API Quick Reference

```bash
# Create a sprint project
POST /wcapi/save/  {"model_name": "project", "record": {"name": "kanban-2026-04-07", "status": "active", ...}}

# Create an action in a project
POST /wcapi/save/  {"model_name": "action", "record": {"project_id": <id>, "assigned_to": {...}, "dt_deadline": <ms>, ...}}

# Link a document to an action
POST /wcapi/save/  {"model_name": "linkageentry", "record": {"parent_model": "action", "parent_id": <id>, "document_id": <id>, ...}}

# Get all actions in a project
GET /wcapi/get/?model_name=action&project_id=<id>

# Get documents linked to an action
GET /wcapi/document/<action_id>/
```

# Backup, Resilience & Travel Protocol
**Keeping Allie Safe, Redundant, and Available**

---

## The Risk Model

Allie's value is her accumulated context — the readmes, knowledge base, CarryOn, agent spec, and everything built up over time. That value lives on a physical drive. Drives fail. Drives get lost. Drives get left behind.

The backup strategy addresses three failure modes:
1. **Drive failure** — the SSD dies
2. **Drive unavailability** — traveling without the primary drive
3. **Network unavailability** — working without internet

---

## Multiple Drive Backup

### Strategy

Allie is backed up to at least two additional drives at all times. Each backup is a full mirror — not a partial sync, not a compressed archive. The backup drive must be usable as a drop-in replacement without setup.

### Naming Convention

| Drive | Role |
|-------|------|
| `Allie` | Primary — in use daily |
| `Allie-Backup-1` | Secondary — kept at a fixed location (home/office) |
| `Allie-Backup-2` | Tertiary — kept at a separate location (offsite) |

### Sync Command

```bash
rsync -av --delete /Volumes/Allie/ /Volumes/Allie-Backup-1/
rsync -av --delete /Volumes/Allie/ /Volumes/Allie-Backup-2/
```

The `--delete` flag ensures the backup mirrors the primary exactly. Run after every significant session.

### Frequency

- After any session that adds to the knowledge base or readmes
- Before any travel
- At minimum, weekly

### Verification

Periodically verify a backup is usable by plugging it in and opening Claude Code with working directory set to the backup drive. Allie should wake up normally.

---

## MyCarryOn Travel API

### The Problem

When traveling without the primary Allie drive, Bill needs access to context. But the full knowledge base is large and may contain sensitive material that shouldn't float around in the cloud.

### The Solution

Allie stays home. A minimal, HTTPS-protected API endpoint exposes only what is needed for the current context — instance-specific, decided case by case by Bill and Allie together before travel.

### Architecture

```
Bill (traveling, any device)
    │
    └── HTTPS request → MyCarryOn API endpoint (home server or VPS)
                            │
                            └── Returns: selected CarryOn fields + 
                                        selected knowledge pointers +
                                        session state for current trip
```

**Implementation layer:** Each travel context exchange is not a raw API call — it is a Bundle on a Connection. The Connection record (`allie-mycarryon-travel`) defines what is shared, the field maps, the conflict resolution strategy, and the encryption. Each Bundle records the payload, response, and any conflicts. This gives a full audit trail of every context exchange. See `21-sync-integration.md` for the full sync architecture.

### What Gets Shared

There is no fixed answer. Bill and Allie decide before each trip what is needed. Candidates:

- **CarryOn session state** — what's open, what's active
- **Project summaries** — high-level status for active projects
- **Specific knowledge files** — only those relevant to the trip's work
- **WhatIf items** — those scheduled for this period

What is never shared via the travel API without explicit decision:
- Full knowledge base
- Sensitive financial or legal files
- Anything not needed for the current context

### Security

- HTTPS only — no unencrypted traffic
- Protected at the IP/domain level — not publicly discoverable
- Authentication required — token or certificate, not password alone
- Minimal surface area — only the endpoint needed, nothing else exposed
- Session-scoped — access does not persist beyond the trip unless renewed (permission sunset applies)

### Offline Fallback

If the travel API is unreachable, Bill works from whatever was loaded at session start. The AI pauses API-dependent features and continues with local context. Notes and drafts accumulate locally and sync when the primary drive is available again.

---

## Offline Degradation Protocol

### What Works Without Internet

| Capability | Offline Status |
|------------|---------------|
| Read all knowledge files | Available |
| Read readmes and agent spec | Available |
| Read and update CarryOn | Available |
| Write session notes and drafts | Available |
| WebClerk local instance | Available (if running locally) |
| Claude API (chat, generation) | Unavailable |
| MyCarryOn travel API | Unavailable |
| External search | Unavailable |

### Graceful Degradation

When network is unavailable:
- Allie does not crash or refuse to work
- She announces what is unavailable
- She continues with all local capabilities
- She queues any actions that require network for when connectivity returns
- She does not silently fail — if something can't be done offline, she says so

### Reconnection

When network returns mid-session, Allie resumes full capability without requiring a session restart. Queued actions are reviewed before execution — they are not automatically fired.

---

## Drive Loss Protocol

If the primary Allie drive is lost or fails:

1. Retrieve the most recent backup drive
2. Plug in and verify contents are current
3. Relabel as primary (or continue as-is — the name doesn't matter, the contents do)
4. Open Claude Code with the backup as working directory
5. Allie wakes up from the last backup point
6. Note in CarryOn what may have been lost since the last backup
7. Order a replacement drive; restore the backup chain

The goal: recovery in under 30 minutes with no permanent loss beyond the last backup cycle.

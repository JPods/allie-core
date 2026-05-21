# Allie — Bill James's Personal AI Repository

**Owner:** Bill James  
**Purpose:** Persistent intelligence layer across all of Bill's projects — JPods, WebClerk, Divided Sovereignty, MyCarryOn, and the physical robot fleet.

---

## Start Here

**New session? Read in this order:**

1. **[`CLAUDE.md`](CLAUDE.md)** — the authoritative seed document. Covers what we're building, the agent team, non-negotiable design axioms, and the full session protocol. Read this before touching any code.
2. **[`handoff/handoff.md`](handoff/handoff.md)** — exactly where the last session stopped.
3. **`handoff/YYYY-MM-DD-claude-recall.md`** (today's date) — open WhatIf predictions, recent TFTS principles, confirmed patterns.
4. **`thoughts/YYYY-MM-DD-allie-reflect.md`** (most recent) — Allie's nightly synthesis.

Pull latest before reading: `git -C ~/Allie pull origin main`

---

## What Lives Here

| Path | Contents |
|------|----------|
| `CLAUDE.md` | Session seed — axioms, agent team, build protocols, file map |
| `handoff/` | Cross-session working memory — handoff.md, claude-recall, allie-reflect |
| `sessions/` | Full session logs (one per day) |
| `process/inbox/` | FAULT, DNW, TF, TFTS process-capture files — Allie reads nightly |
| `readmes/` | Project context files (00–42), agent files, wisdom layer |
| `readmes/agents/` | One file per agent — Nora, Natalie, Noelle, Alice, Allie, Athena |
| `readmes/wisdom/` | bill.md, scars.md, rejected-paths.md, whatif.md, whatif-weekly/ |
| `readmes/retrospections/` | Daily retrospections with Lessons for Allie |
| `readmes/sketchup/` | SketchUp plugin engineering rules and audit docs |
| `scripts/` | allie-reflect.py, allie-capture.py, allie-whatif.py, and the full agent script library |
| `thoughts/` | Allie's nightly reflection outputs |
| `today/` | Operational files — activity logs, sync logs, handoff.md |
| `knowledge/` | Deep knowledge files — large, not synced to GitHub |
| `config/` | API keys and credentials — never synced to cloud unencrypted |

---

## The Four JPods Programs

| Program | What it does | Key files |
|---------|-------------|-----------|
| **SketchUp Plugin** (`su_jpods`) | 3D student design tool | `~/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/` |
| **JPodsSM_RPi** | Physical scale model vehicles | `~/Documents/08_JPods/03_Technology/00_working_code/JPodsSM_RPi/` |
| **Route-Time** | Network planner + travel simulator | `~/Documents/08_JPods/03_Technology/route_time/` |
| **WebClerk / Alice** | Commerce layer + ticketing | `~/Documents/CommerceExpert/webClerk3/` |

---

## The Agent Team

| Agent | Role |
|-------|------|
| **Nora** | Vehicle — navigation, encoders, telemetry |
| **Natalie** | Router — trip plans, route sequences |
| **Noelle** | Network validator + load balancer |
| **Alice** | WebClerk — data quality, billing, patterns |
| **Athena** | Security reviewer — signs non-standing actions |
| **Allie** | Cross-domain persistent intelligence — this repo |

Full agent files: `readmes/agents/`

---

## Backup and Sync

Three copies at all times:

| Copy | Location | How |
|------|----------|-----|
| Internal | `~/Allie/` | Working copy — always source of truth |
| iCloud | `~/Library/Mobile Documents/com~apple~CloudDocs/Allie/` | Auto — launchd, 60s after change |
| 5TB | `/Volumes/Allie/` | Manual — `scripts/allie-sync.sh` |

Never synced to cloud: `credentials/`, `config/allie_api_keys.json`, `config/wc_credentials.json`. The `.enc` files are safe.

Full detail: `readmes/41-allie-backup-sync.md`

---

## GitHub

```
https://github.com/JPods/allie-core.git
```

Intelligence layer — always current after each nightly Allie run. Does NOT contain credentials, logs, archives, or large knowledge files.

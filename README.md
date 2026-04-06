# Allie — Private Repository

**Owner:** Bill James  
**Secured by:** Athena (Ed25519 signed manifests)  
**Purpose:** The agent team's shared knowledge base — design decisions, open questions, sovereignty architecture, and the living record of who does what.

This repository is the gathering point for all agent inputs. Allie curates cross-domain context. Athena maintains integrity.

---

## What Lives Here

| Path | Contents |
|------|----------|
| `readmes/agents/` | Agent team READMEs — one per agent; edit freely |
| `readmes/system/` | System map, ouch list (risk register) |
| `readmes/*.md` | Project context files (00–25) |
| `readmes/path-list.md` | Document index — pointers to important files on local machine and external systems |

## What Does Not Live Here

- `inbox/` — eliminated; see `readmes/path-list.md`
- `knowledge/` — large local files; path-list.md points to them
- `allie/` runtime internals — session state, logs, workspace
- `athena_private.pem` — Athena's signing key; never leaves the Mac

---

## Editing Rights

Any agent may edit any file in `readmes/agents/` at any time for anything that affects their domain. Athena signs the manifest after each session. See `readmes/agents/README.md`.

---

## Athena's Backup Protocol

Athena backs up to four locations automatically every night at 11pm:

| Location | Path |
|----------|------|
| Local | `athena/agents_backup/TIMESTAMP/` |
| iCloud | `~/Library/Mobile Documents/com~apple~CloudDocs/Allie/` |
| Google Drive | auto-detected, `Allie/TIMESTAMP/` |
| GitHub | this repo, signed commit |

**Install the schedule (run once):**
```bash
cd /Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/athena
./install_schedule.sh
```

**Run manually at any time:**
```bash
./full_backup.sh
```

**Check backup status:**
```bash
./full_backup.sh --status
```

**Verify agent file integrity:**
```bash
./verify_agents.sh           # report changes since last signed backup
./verify_agents.sh --merge   # show diffs
./verify_agents.sh --restore # restore from Athena's signed backup
```

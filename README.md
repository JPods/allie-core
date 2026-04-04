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

## Athena's Integrity Protocol

After any editing session, Athena runs:
```bash
cd /Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/athena
./backup_agents.sh
```
This hashes all agent files, signs the manifest with Athena's Ed25519 private key, and updates `readmes/agents/athena_hashes.json`. That signed file is committed to this repo.

To verify the current state of agent files:
```bash
./verify_agents.sh           # report changes
./verify_agents.sh --merge   # show diffs
./verify_agents.sh --restore # restore from signed backup
```

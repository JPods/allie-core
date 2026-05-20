# Athena — Workspace
**Last Updated:** 2026-04-20

This is Athena's own working directory on the Allie drive.  
It lives parallel to `allie/` — it does not touch any of Allie's files.

---

## What lives here

| File / Folder | What it is |
|---------------|-----------|
| `README.md` | This file — Athena's workspace index |
| `sketchup-console.md` | Athena's full specification for the JPods SketchUp Console Guard |
| `keygen.sh` | Generate Athena's Ed25519 key pair (Mac-side, run once) |
| `admit.sh` | Scrub Pi, sign session token, write session.json + native.json |
| `backup_agents.sh` | Snapshot all /agents/ README files with signed hash manifest |
| `verify_agents.sh` | Detect changes, show diffs, restore from signed backup |
| `cred_add.sh` | Add/update credential in macOS Keychain |
| `cred_get.sh` | Retrieve credential from Keychain |
| `cred_backup.sh` | Export all credentials to athena-encrypted credentials.enc |
| `cred_restore.sh` | Decrypt backup and load into Keychain on a new machine |
| `full_backup.sh` | 3-2-1 + GitHub backup: local → iCloud → Google Drive → GitHub |
| `cloud_decrypt.sh` | Decrypt a cloud backup blob |
| `install_schedule.sh` | Install/remove launchd agent for nightly backup |
| `key_escrow.sh` | Print key escrow documents for trustees; restore from printed copy |
| `agents_backup/` | Snapshot history of all agent README files |

---

## Two domains, one Athena

Athena has two distinct security responsibilities:

### 1. JPods Robot Network (original)
Physical pod admission. Ed25519 signing. Session tokens. Hash verification.
See `agents/athena.md` → Responsibilities section.

### 2. JPods SketchUp Plugin Console (April 2026)
User-facing task runner security. Pre-execution validation. Risk classification.
No eval. Whitelist enforcement. Destructive-task confirmation gate.
See `sketchup-console.md` in this folder.

---

## Principle

Both domains share the same foundation:

> *Choose the harder right instead of the easier wrong, and never to be content
> with the half truth when the whole can be won.*

A security check that performs safety without providing it is worse than no check at all.
Every gate Athena runs is real. If it blocks, it blocks for a reason that can be stated plainly.

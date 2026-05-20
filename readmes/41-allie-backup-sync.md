# Allie Backup and Sync
**Added:** 2026-05-18

---

## Three Copies

| Copy | Location | Role |
|------|----------|------|
| Internal | `~/Allie/` | Working copy — always present, always current |
| 5TB | `/Volumes/Allie/` | Home base archive — full history, 4.5 TB headroom |
| iCloud | `~/Library/Mobile Documents/com~apple~CloudDocs/Allie/` | Automatic offsite — working files only, no archive |

The Lexar drive (`/Volumes/ALLIE_LEXAR/`) is no longer a mirror. It holds the old archive and a queue directory for direct Mac ↔ 5TB transfers when both are connected. See [Queue](#lexar-as-queue) below.

---

## iCloud Sync (automatic)

**Script:** `scripts/allie-icloud-sync.sh`
**Plist:** `~/Library/LaunchAgents/com.allie.icloud-sync.plist`

launchd watches `~/Allie/` for changes. When anything changes it waits 60 seconds (to let a burst of writes settle), then rsyncs to iCloud Drive. Also runs once at every login.

### What syncs to iCloud

```
sessions/       thoughts/       readmes/        today/
logs/           knowledge/      config/         scripts/
sources/        training/       inbox/
CLAUDE.md       README.md       *.enc
```

### What never syncs to iCloud

| Excluded | Reason |
|----------|--------|
| `archive/` | 108 GB — historical data, not active knowledge |
| `venv/` `and/` | Python environments — reproducible, not knowledge |
| `.git/` | Version control internals |
| `credentials/` | Raw credential files |
| `config/allie_api_keys.json` | Plain-text API keys |
| `config/wc_credentials.json` | Plain-text WC credentials |

The `.enc` files (`credentials.enc`, `leftear.enc`) are already encrypted — safe in cloud.

### Managing the launchd agent

```bash
# Check it is running
launchctl list | grep com.allie.icloud-sync

# Watch the log
tail -f ~/Allie/logs/icloud-sync.log

# Force an immediate sync
bash ~/Allie/scripts/allie-icloud-sync.sh

# Stop (survives reboot unless unloaded)
launchctl unload ~/Library/LaunchAgents/com.allie.icloud-sync.plist

# Restart
launchctl load ~/Library/LaunchAgents/com.allie.icloud-sync.plist
```

The log rotates automatically at 1 MB.

---

## 5TB Direct Sync

**Script:** `scripts/allie-sync.sh`

Bidirectional, newest-file-wins, no deletions. Run manually when the 5TB is connected and you want to bring it fully current.

```bash
bash ~/Allie/scripts/allie-sync.sh          # auto — syncs whatever is mounted
bash ~/Allie/scripts/allie-sync.sh status   # show drive presence
bash ~/Allie/scripts/allie-sync.sh push     # internal → all mounted drives
bash ~/Allie/scripts/allie-sync.sh pull     # all mounted drives → internal
```

---

## Lexar as Queue

**Script:** `scripts/allie-queue.sh`

The Lexar is a physical message carrier between Mac Allie and 5TB Allie. Use it when you want to push a specific set of changes to the 5TB without running the full mirror sync — or when you need to carry updates between machines.

```bash
bash ~/Allie/scripts/allie-queue.sh status    # show drive presence and queue depth
bash ~/Allie/scripts/allie-queue.sh enqueue   # internal → Lexar outbox
bash ~/Allie/scripts/allie-queue.sh dequeue   # Lexar outbox → 5TB (clears outbox)
bash ~/Allie/scripts/allie-queue.sh respond   # 5TB → Lexar inbox
bash ~/Allie/scripts/allie-queue.sh receive   # Lexar inbox → internal (clears inbox)
bash ~/Allie/scripts/allie-queue.sh sync      # full cycle (all three connected)
```

Queue directories live at `/Volumes/ALLIE_LEXAR/queue/outbox/` and `.../inbox/`. The Lexar archive is never touched by queue operations.

---

## What Goes Where

| Data | iCloud | 5TB | Lexar |
|------|--------|-----|-------|
| Session logs | ✓ auto | ✓ on sync | via queue |
| Thoughts / reflections | ✓ auto | ✓ on sync | via queue |
| Readmes | ✓ auto | ✓ on sync | via queue |
| Config (non-secret) | ✓ auto | ✓ on sync | via queue |
| API keys (plain text) | ✗ never | ✓ | via queue |
| Encrypted secrets | ✓ auto | ✓ on sync | via queue |
| Archive (108 GB) | ✗ never | ✓ | ✓ already there |
| venv | ✗ never | ✓ on sync | ✗ |

---

## Recovery Scenario

**Mac lost or wiped:**
1. Mount 5TB or connect to iCloud Drive
2. Restore `~/Allie/` from either — iCloud has everything except archive and plain-text keys
3. Pull `credentials/` and `config/allie_api_keys.json` from 5TB
4. Reload the launchd agent: `launchctl load ~/Library/LaunchAgents/com.allie.icloud-sync.plist`

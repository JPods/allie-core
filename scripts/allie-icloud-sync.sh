#!/usr/bin/env bash
# allie-icloud-sync.sh — Push Allie working files to iCloud Drive
#
# Triggered by launchd WatchPaths whenever ~/Allie changes.
# ThrottleInterval lets a burst of changes settle before syncing.
#
# iCloud target: ~/Library/Mobile Documents/com~apple~CloudDocs/Allie/
#
# What syncs:   sessions, thoughts, readmes, today, logs, knowledge,
#               config (minus plain-text keys), scripts, sources,
#               training, inbox, CLAUDE.md, README.md, .enc files
#
# What never syncs:
#   archive/      — 108 GB of historical data
#   venv/         — Python environment, not knowledge
#   .git/         — version control internals
#   and/          — Python venv alias
#   credentials/  — directory of raw credential files
#   config/allie_api_keys.json
#   config/wc_credentials.json

INTERNAL="$HOME/Allie"
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Allie"
LOG="$INTERNAL/logs/icloud-sync.log"

mkdir -p "$ICLOUD" "$INTERNAL/logs"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [iCloud] $*" >> "$LOG"
}

# Rotate log if over 1 MB
if [[ -f "$LOG" ]] && [[ $(stat -f%z "$LOG" 2>/dev/null || echo 0) -gt 1048576 ]]; then
  mv "$LOG" "${LOG%.log}-$(date +%Y%m%d).log"
fi

log "BEGIN sync → iCloud"

rsync -a --update \
  --exclude='.DS_Store' \
  --exclude='.Spotlight-V100' \
  --exclude='.Trashes' \
  --exclude='.fseventsd' \
  --exclude='*.tmp' \
  --exclude='*.pyc' \
  --exclude='__pycache__/' \
  --exclude='.git/' \
  --exclude='archive/' \
  --exclude='venv/' \
  --exclude='and/' \
  --exclude='credentials/' \
  --exclude='config/allie_api_keys.json' \
  --exclude='config/wc_credentials.json' \
  "$INTERNAL/" "$ICLOUD/" \
  && log "DONE sync ($(find "$ICLOUD" -type f | wc -l | tr -d ' ') files in iCloud)" \
  || log "ERROR: rsync failed (exit $?)"

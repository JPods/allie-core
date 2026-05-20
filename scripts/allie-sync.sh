#!/usr/bin/env bash
# allie-sync.sh — Three-drive sync for Allie
#
# Drives:
#   Internal  $HOME/Allie           — always-available primary (working copy)
#   5TB       /Volumes/Allie        — home base archive
#   Lexar     /Volumes/ALLIE_LEXAR  — travel companion
#
# Usage:
#   allie-sync.sh           — same as auto
#   allie-sync.sh auto      — sync whatever drives are mounted
#   allie-sync.sh status    — show which drives are present
#   allie-sync.sh push      — push internal → all mounted drives
#   allie-sync.sh pull      — pull all mounted drives → internal (newest wins)

INTERNAL="$HOME/Allie"
FIVTB="/Volumes/Allie"
LEXAR="/Volumes/ALLIE_LEXAR"

RSYNC_EXCLUDES=(
  --exclude='.DS_Store'
  --exclude='.Spotlight-V100'
  --exclude='.Trashes'
  --exclude='.fseventsd'
  --exclude='.DocumentRevisions-V100*'
  --exclude='*.tmp'
  --exclude='*.pyc'
  --exclude='__pycache__/'
)

# ── Logging ───────────────────────────────────────────────────────────────────

log() {
  local ts; ts=$(date +"%H:%M:%S")
  local today; today=$(date +%Y-%m-%d)
  local log_dir="$INTERNAL/today"
  local log_file="$log_dir/${today}-sync.log"
  mkdir -p "$log_dir"
  echo "[$ts] [SYNC] $*" | tee -a "$log_file"
}

# ── Core sync: bidirectional, newest file wins ─────────────────────────────────
# Runs rsync A→B then B→A with --update (skip files newer on destination).
# Net effect: each file ends up at its most recent version on both sides.
# Deletions are NOT propagated — files can only be added or updated, not removed.
# The 5TB drive is the long-term archive; nothing is ever auto-deleted from it.

sync_pair() {
  local label="$1"
  local a="$2"
  local b="$3"

  if [[ ! -d "$a" ]]; then
    log "SKIP [$label]: source missing — $a"
    return
  fi
  if [[ ! -d "$b" ]]; then
    log "SKIP [$label]: destination missing — $b"
    return
  fi

  log "BEGIN [$label]: $a ↔ $b"

  rsync -a --update "${RSYNC_EXCLUDES[@]}" "$a/" "$b/" \
    && log "  → pushed newer files from internal to $label" \
    || log "  WARN: push to $label had errors (partial sync)"

  rsync -a --update "${RSYNC_EXCLUDES[@]}" "$b/" "$a/" \
    && log "  ← pulled newer files from $label to internal" \
    || log "  WARN: pull from $label had errors (partial sync)"

  log "DONE [$label]"
}

# ── Commands ──────────────────────────────────────────────────────────────────

status() {
  local int_status fivtb_status lexar_status
  int_status=$( [[ -d "$INTERNAL" ]] && echo "OK" || echo "MISSING" )
  fivtb_status=$( [[ -d "$FIVTB"   ]] && echo "MOUNTED" || echo "not mounted" )
  lexar_status=$( [[ -d "$LEXAR"   ]] && echo "MOUNTED" || echo "not mounted" )
  echo "Internal : $int_status    — $INTERNAL"
  echo "5TB      : $fivtb_status  — $FIVTB"
  echo "Lexar    : $lexar_status  — $LEXAR"
}

auto() {
  if [[ ! -d "$INTERNAL" ]]; then
    log "ERROR: internal Allie missing at $INTERNAL — run initial setup first"
    exit 1
  fi

  # Give macOS a moment to fully settle the mount
  sleep 3

  local synced=0

  if [[ -d "$FIVTB" ]]; then
    sync_pair "5TB" "$INTERNAL" "$FIVTB"
    synced=1
  fi

  if [[ -d "$LEXAR" ]]; then
    sync_pair "Lexar" "$INTERNAL" "$LEXAR"
    synced=1
  fi

  if [[ $synced -eq 0 ]]; then
    log "No Allie drives mounted — nothing to sync"
  fi
}

push() {
  [[ ! -d "$INTERNAL" ]] && { echo "Internal missing."; exit 1; }
  [[ -d "$FIVTB"  ]] && { log "Push → 5TB";   rsync -av --update "${RSYNC_EXCLUDES[@]}" "$INTERNAL/" "$FIVTB/";  }
  [[ -d "$LEXAR"  ]] && { log "Push → Lexar"; rsync -av --update "${RSYNC_EXCLUDES[@]}" "$INTERNAL/" "$LEXAR/"; }
}

pull() {
  [[ ! -d "$INTERNAL" ]] && { echo "Internal missing."; exit 1; }
  [[ -d "$FIVTB"  ]] && { log "Pull ← 5TB";   rsync -av --update "${RSYNC_EXCLUDES[@]}" "$FIVTB/"  "$INTERNAL/"; }
  [[ -d "$LEXAR"  ]] && { log "Pull ← Lexar"; rsync -av --update "${RSYNC_EXCLUDES[@]}" "$LEXAR/" "$INTERNAL/"; }
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

case "${1:-auto}" in
  auto)   auto ;;
  status) status ;;
  push)   push ;;
  pull)   pull ;;
  *)
    echo "Usage: allie-sync.sh [auto|status|push|pull]"
    exit 1
    ;;
esac

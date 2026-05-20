#!/usr/bin/env bash
# allie-queue.sh — Lexar as async message queue between Mac Allie and 5TB Allie
#
# The Lexar drive is NOT a full mirror.  It is a physical message carrier:
#
#   Mac Allie   →  enqueue  →  ALLIE_LEXAR/queue/outbox/
#                              (carry Lexar to where 5TB is connected)
#   5TB Allie   ←  dequeue  ←  ALLIE_LEXAR/queue/outbox/  (merge + clear)
#   5TB Allie   →  respond  →  ALLIE_LEXAR/queue/inbox/
#   Mac Allie   ←  receive  ←  ALLIE_LEXAR/queue/inbox/   (merge + clear)
#
# The archive/ on the Lexar is never touched by this script.
#
# Usage:
#   allie-queue.sh status              — show queue depth and drive presence
#   allie-queue.sh enqueue             — Mac Allie → outbox  (run when leaving home)
#   allie-queue.sh dequeue             — outbox → 5TB Allie  (run when 5TB is connected)
#   allie-queue.sh respond             — 5TB Allie → inbox   (run after dequeue to reply)
#   allie-queue.sh receive             — inbox → Mac Allie   (run when back home)
#   allie-queue.sh sync                — full cycle: enqueue + dequeue + respond + receive
#                                        (run when all three are connected)

INTERNAL="$HOME/Allie"
FIVTB="/Volumes/Allie"
LEXAR="/Volumes/ALLIE_LEXAR"
OUTBOX="$LEXAR/queue/outbox"
INBOX="$LEXAR/queue/inbox"
MANIFEST="$LEXAR/queue/MANIFEST.json"

# Directories Mac Allie produces that 5TB Allie should know about.
# These are text/knowledge files only — no archive, no venv, no binaries.
QUEUE_DIRS=(
  sessions
  thoughts
  readmes
  today
  logs
  knowledge
  config
  scripts
  inbox
)

RSYNC_EXCLUDES=(
  --exclude='.DS_Store'
  --exclude='.Spotlight-V100'
  --exclude='.Trashes'
  --exclude='.fseventsd'
  --exclude='*.tmp'
  --exclude='*.pyc'
  --exclude='__pycache__/'
  --exclude='.git/'
  --exclude='venv/'
)

# ── Helpers ───────────────────────────────────────────────────────────────────

log() {
  local ts; ts=$(date +"%H:%M:%S")
  echo "[$ts] [QUEUE] $*"
}

require_lexar() {
  if [[ ! -d "$LEXAR" ]]; then
    echo "ERROR: Lexar not mounted at $LEXAR"
    exit 1
  fi
  mkdir -p "$OUTBOX" "$INBOX"
}

require_internal() {
  if [[ ! -d "$INTERNAL" ]]; then
    echo "ERROR: internal Allie not found at $INTERNAL"
    exit 1
  fi
}

require_5tb() {
  if [[ ! -d "$FIVTB" ]]; then
    echo "ERROR: 5TB not mounted at $FIVTB"
    exit 1
  fi
}

count_files() {
  find "$1" -type f 2>/dev/null | wc -l | tr -d ' '
}

write_manifest() {
  local ts; ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local out_count; out_count=$(count_files "$OUTBOX")
  local in_count;  in_count=$(count_files "$INBOX")
  cat > "$MANIFEST" <<EOF
{
  "updated_at": "$ts",
  "outbox_files": $out_count,
  "inbox_files": $in_count
}
EOF
}

# ── Commands ──────────────────────────────────────────────────────────────────

status() {
  local int_ok fivtb_ok lexar_ok
  int_ok=$( [[ -d "$INTERNAL" ]] && echo "OK"      || echo "MISSING" )
  fivtb_ok=$([[ -d "$FIVTB"   ]] && echo "MOUNTED" || echo "not mounted" )
  lexar_ok=$([[ -d "$LEXAR"   ]] && echo "MOUNTED" || echo "not mounted" )

  echo "Internal : $int_ok    — $INTERNAL"
  echo "5TB      : $fivtb_ok  — $FIVTB"
  echo "Lexar    : $lexar_ok  — $LEXAR"

  if [[ -d "$OUTBOX" ]]; then
    echo "Outbox   : $(count_files "$OUTBOX") file(s) pending for 5TB"
  else
    echo "Outbox   : (not initialised)"
  fi
  if [[ -d "$INBOX" ]]; then
    echo "Inbox    : $(count_files "$INBOX") file(s) waiting for Mac"
  else
    echo "Inbox    : (not initialised)"
  fi
}

# Mac Allie → outbox: copy newer working files from internal to outbox.
# Safe to run repeatedly — only newer files are transferred.
enqueue() {
  require_internal
  require_lexar
  log "BEGIN enqueue: internal → outbox"

  for dir in "${QUEUE_DIRS[@]}"; do
    src="$INTERNAL/$dir"
    dst="$OUTBOX/$dir"
    [[ -d "$src" ]] || continue
    mkdir -p "$dst"
    rsync -a --update "${RSYNC_EXCLUDES[@]}" "$src/" "$dst/" \
      && log "  queued: $dir" \
      || log "  WARN: $dir had errors"
  done

  # Top-level files (CLAUDE.md, README.md, etc.)
  rsync -a --update "${RSYNC_EXCLUDES[@]}" \
    --include='*.md' --include='*.json' --include='*.txt' --exclude='*' \
    "$INTERNAL/" "$OUTBOX/" \
    && log "  queued: top-level files" \
    || log "  WARN: top-level files had errors"

  write_manifest
  log "DONE enqueue — $(count_files "$OUTBOX") file(s) in outbox"
}

# outbox → 5TB Allie: merge outbox into 5TB, then clear outbox.
# Run when Lexar and 5TB are both connected.
dequeue() {
  require_lexar
  require_5tb

  local n; n=$(count_files "$OUTBOX")
  if [[ $n -eq 0 ]]; then
    log "outbox is empty — nothing to dequeue"
    return
  fi

  log "BEGIN dequeue: outbox ($n files) → 5TB"
  rsync -a --update "${RSYNC_EXCLUDES[@]}" "$OUTBOX/" "$FIVTB/" \
    && log "  merged into 5TB" \
    || { log "  ERROR: merge failed — outbox NOT cleared"; exit 1; }

  # Clear outbox only after confirmed success
  rm -rf "${OUTBOX:?}"/*
  mkdir -p "$OUTBOX"
  write_manifest
  log "DONE dequeue — outbox cleared"
}

# 5TB Allie → inbox: copy any updates from 5TB that Mac Allie should receive.
# Run after dequeue to let the 5TB "respond" before disconnecting.
respond() {
  require_5tb
  require_lexar
  log "BEGIN respond: 5TB → inbox"

  for dir in "${QUEUE_DIRS[@]}"; do
    src="$FIVTB/$dir"
    dst="$INBOX/$dir"
    [[ -d "$src" ]] || continue
    mkdir -p "$dst"
    rsync -a --update "${RSYNC_EXCLUDES[@]}" "$src/" "$dst/" \
      && log "  staged: $dir" \
      || log "  WARN: $dir had errors"
  done

  write_manifest
  log "DONE respond — $(count_files "$INBOX") file(s) in inbox"
}

# inbox → Mac Allie: merge inbox into internal, then clear inbox.
receive() {
  require_internal
  require_lexar

  local n; n=$(count_files "$INBOX")
  if [[ $n -eq 0 ]]; then
    log "inbox is empty — nothing to receive"
    return
  fi

  log "BEGIN receive: inbox ($n files) → internal"
  rsync -a --update "${RSYNC_EXCLUDES[@]}" "$INBOX/" "$INTERNAL/" \
    && log "  merged into internal" \
    || { log "  ERROR: merge failed — inbox NOT cleared"; exit 1; }

  rm -rf "${INBOX:?}"/*
  mkdir -p "$INBOX"
  write_manifest
  log "DONE receive — inbox cleared"
}

# Full cycle when all three are connected.
sync_all() {
  log "BEGIN sync (all three connected)"
  enqueue
  dequeue
  respond
  receive
  log "DONE sync"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

case "${1:-status}" in
  status)  status   ;;
  enqueue) enqueue  ;;
  dequeue) dequeue  ;;
  respond) respond  ;;
  receive) receive  ;;
  sync)    sync_all ;;
  *)
    echo "Usage: allie-queue.sh [status|enqueue|dequeue|respond|receive|sync]"
    exit 1
    ;;
esac

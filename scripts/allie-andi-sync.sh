#!/usr/bin/env bash
# allie-andi-sync.sh — Sync Allie knowledge from Mac to Andi (IT15)
#
# Mac is source of truth for knowledge files.
# Andi is source of truth for its own services (WC3, MeshMobility).
#
# Usage:
#   allie-andi-sync.sh              — sync knowledge + rebuild vector stores
#   allie-andi-sync.sh knowledge    — sync knowledge files only (fast)
#   allie-andi-sync.sh vectors      — rebuild vector stores on Andi only
#   allie-andi-sync.sh apps         — sync app code (CrashHarvester, MeshMobility readmes)
#   allie-andi-sync.sh status       — check Andi connectivity and store sizes
#   allie-andi-sync.sh full         — everything: knowledge + apps + vectors
#
# Designed to run manually or via launchd on a schedule.
# Runtime: ~2 min for knowledge, ~10 min for vectors, ~15 min for full.

set -euo pipefail

INTERNAL="$HOME/Allie"
ANDI_HOST="andi"
ANDI_ROOT="/opt/andi"
LOG="$INTERNAL/logs/andi-sync.log"

# Code paths on Mac
CRASH_HARVESTER="$HOME/Documents/08_JPods/03_Technology/00_working_code/crash_harvester"
MESH_MOBILITY="$HOME/Documents/08_JPods/03_Technology/00_working_code/mesh_mobility"

RSYNC_OPTS=(
  -az
  --delete
  --exclude='.DS_Store'
  --exclude='*.pyc'
  --exclude='__pycache__/'
  --exclude='.git/'
  --exclude='venv/'
  --exclude='*.tmp'
)

# Never sync these to Andi
KNOWLEDGE_EXCLUDES=(
  --exclude='archive/'
  --exclude='credentials/'
  --exclude='config/allie_api_keys.json'
  --exclude='config/wc_credentials.json'
  --exclude='.chroma_db*'
  --exclude='*.enc'
)

mkdir -p "$INTERNAL/logs"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ANDI-SYNC] $*" | tee -a "$LOG"
}

# ── Connectivity check ───────────────────────────────────────────────────────

check_andi() {
  if ! ssh -o ConnectTimeout=5 "$ANDI_HOST" "echo ok" &>/dev/null; then
    log "ERROR: Cannot reach Andi at $ANDI_HOST"
    echo "Cannot reach Andi. Check network or SSH config (~/.ssh/config)."
    exit 1
  fi
}

# ── Knowledge sync: Mac → Andi ────────────────────────────────────────────────

sync_knowledge() {
  log "BEGIN knowledge sync → Andi"

  local dirs=(
    readmes
    knowledge
    handoff
    sessions
    thoughts
    facets
    specs
    process
    scripts
  )

  local synced=0
  for dir in "${dirs[@]}"; do
    local src="$INTERNAL/$dir/"
    if [[ -d "$src" ]]; then
      log "  syncing $dir/"
      rsync "${RSYNC_OPTS[@]}" "${KNOWLEDGE_EXCLUDES[@]}" \
        "$src" "$ANDI_HOST:$ANDI_ROOT/$dir/"
      ((synced++))
    fi
  done

  # Also sync top-level files
  rsync "${RSYNC_OPTS[@]}" \
    --include='CLAUDE.md' \
    --include='README.md' \
    --exclude='*' \
    "$INTERNAL/" "$ANDI_HOST:$ANDI_ROOT/"

  log "DONE knowledge sync — $synced directories"
}

# ── App sync: CrashHarvester + MeshMobility readmes ──────────────────────────

sync_apps() {
  log "BEGIN app sync → Andi"

  # CrashHarvester library + configs (not the raw data downloads)
  if [[ -d "$CRASH_HARVESTER" ]]; then
    log "  syncing CrashHarvester"
    rsync "${RSYNC_OPTS[@]}" \
      --exclude='library/' \
      --exclude='*.geojson' \
      "$CRASH_HARVESTER/" "$ANDI_HOST:$ANDI_ROOT/apps/crash_harvester/"
  fi

  # MeshMobility readmes (Noelle vector store indexes these)
  if [[ -d "$MESH_MOBILITY/readmes" ]]; then
    log "  syncing MeshMobility readmes"
    rsync "${RSYNC_OPTS[@]}" \
      "$MESH_MOBILITY/readmes/" "$ANDI_HOST:$ANDI_ROOT/apps/mesh_mobility/readmes/"
  fi

  log "DONE app sync"
}

# ── Vector store rebuild on Andi ──────────────────────────────────────────────

rebuild_vectors() {
  log "BEGIN vector store rebuild on Andi"

  local stores=("allie" "claude" "alice")
  for store in "${stores[@]}"; do
    log "  indexing $store"
    ssh "$ANDI_HOST" "cd $ANDI_ROOT && python3 scripts/${store}-vectorstore.py index 2>&1 | tail -3" \
      && log "  $store: done" \
      || log "  $store: FAILED"
  done

  # Noelle: seed then index (takes longest)
  log "  indexing noelle (seed + index — may take several minutes)"
  ssh "$ANDI_HOST" "cd $ANDI_ROOT && python3 scripts/noelle-vectorstore.py seed 2>&1 | tail -1 && python3 scripts/noelle-vectorstore.py index 2>&1 | tail -3" \
    && log "  noelle: done" \
    || log "  noelle: FAILED"

  log "DONE vector store rebuild"
}

# ── Status check ──────────────────────────────────────────────────────────────

show_status() {
  check_andi
  echo "Andi connection: OK"
  echo ""

  echo "Vector stores on Andi:"
  ssh "$ANDI_HOST" "python3 -c \"
import chromadb, os
stores = {
    'Allie':  ('/opt/andi/.chroma_db',        'allie_knowledge'),
    'Claude': ('/opt/andi/.chroma_db_claude',  'claude_session_knowledge'),
    'Alice':  ('/opt/andi/.chroma_db_alice',   'alice_commerce_knowledge'),
    'Noelle': ('/opt/andi/.chroma_db_noelle',  'noelle_network_design'),
}
for name, (path, col_name) in stores.items():
    if os.path.exists(path):
        try:
            c = chromadb.PersistentClient(path=path)
            col = c.get_collection(col_name)
            print(f'  {name:8s} {col.count():>6,} chunks')
        except Exception as e:
            print(f'  {name:8s} ERROR: {e}')
    else:
        print(f'  {name:8s} not built yet')
\" 2>/dev/null"
  echo ""

  echo "Knowledge dirs on Andi:"
  ssh "$ANDI_HOST" "for d in readmes knowledge handoff sessions thoughts facets specs process; do
    if [ -d /opt/andi/\$d ]; then
      count=\$(find /opt/andi/\$d -type f 2>/dev/null | wc -l)
      printf '  %-12s %s files\n' \"\$d/\" \"\$count\"
    else
      printf '  %-12s not synced\n' \"\$d/\"
    fi
  done"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

case "${1:-full}" in
  knowledge)
    check_andi
    sync_knowledge
    ;;
  vectors)
    check_andi
    rebuild_vectors
    ;;
  apps)
    check_andi
    sync_apps
    ;;
  full)
    check_andi
    sync_knowledge
    sync_apps
    rebuild_vectors
    log "FULL SYNC COMPLETE"
    ;;
  status)
    show_status
    ;;
  *)
    echo "Usage: allie-andi-sync.sh [knowledge|vectors|apps|full|status]"
    exit 1
    ;;
esac

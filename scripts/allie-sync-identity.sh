#!/bin/bash
# Sync identity stores and retro.db between Mac and Andi (IT15)
#
# Runs both directions — Mac and Andi both contribute.
# Everyone builds the store. This script makes sure everyone has
# what everyone else added.
#
# Usage:
#   bash allie-sync-identity.sh              # bidirectional sync
#   bash allie-sync-identity.sh push         # Mac → Andi only
#   bash allie-sync-identity.sh pull         # Andi → Mac only
#   bash allie-sync-identity.sh status       # show what would sync
#
# Runs automatically via launchd every 10 minutes.
# Can also be triggered manually or by git post-commit hook.

set -e

ANDI_HOST="andi@192.168.1.114"
ANDI_BASE="/opt/andi/allie"

MAC_BASE="$HOME/Allie"

# What to sync
IDENTITY_STORE=".chroma_db_leftshoe"
RETRO_DB="retro.db"
WISDOM_DIR="readmes/wisdom"
PROCESS_INBOX="process/inbox"
HANDOFF_DIR="handoff"
FACETS_DIR="facets"

LOG="$MAC_BASE/logs/identity-sync.log"
mkdir -p "$(dirname "$LOG")"

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

log() { echo "$(ts) $1" | tee -a "$LOG"; }

# Check Andi is reachable
check_andi() {
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$ANDI_HOST" "echo ok" >/dev/null 2>&1; then
        return 0
    else
        log "WARN: Andi not reachable at $ANDI_HOST"
        return 1
    fi
}

# Ensure Andi has the directory structure
ensure_andi_dirs() {
    ssh "$ANDI_HOST" "mkdir -p $ANDI_BASE/{.chroma_db_claude_identity,readmes/wisdom,process/inbox,handoff,facets,logs}" 2>/dev/null
}

# Push: Mac → Andi
push() {
    log "PUSH: Mac → Andi"

    # Identity store (chroma DB files)
    rsync -az --delete \
        "$MAC_BASE/$IDENTITY_STORE/" \
        "$ANDI_HOST:$ANDI_BASE/$IDENTITY_STORE/" 2>&1 | tail -1
    log "  identity store synced"

    # Retro DB
    if [ -f "$MAC_BASE/$RETRO_DB" ]; then
        rsync -az \
            "$MAC_BASE/$RETRO_DB" \
            "$ANDI_HOST:$ANDI_BASE/$RETRO_DB" 2>&1
        log "  retro.db synced"
    fi

    # Wisdom files
    rsync -az \
        "$MAC_BASE/$WISDOM_DIR/" \
        "$ANDI_HOST:$ANDI_BASE/$WISDOM_DIR/" 2>&1 | tail -1
    log "  wisdom synced"

    # Process inbox (recent captures)
    rsync -az \
        "$MAC_BASE/$PROCESS_INBOX/" \
        "$ANDI_HOST:$ANDI_BASE/$PROCESS_INBOX/" 2>&1 | tail -1
    log "  process inbox synced"

    # Handoff files
    rsync -az \
        "$MAC_BASE/$HANDOFF_DIR/" \
        "$ANDI_HOST:$ANDI_BASE/$HANDOFF_DIR/" 2>&1 | tail -1
    log "  handoff synced"

    # Facets
    rsync -az \
        "$MAC_BASE/$FACETS_DIR/" \
        "$ANDI_HOST:$ANDI_BASE/$FACETS_DIR/" 2>&1 | tail -1
    log "  facets synced"

    log "PUSH complete"
}

# Pull: Andi → Mac
pull() {
    log "PULL: Andi → Mac"

    # Retro DB — Andi may have entries from Alice/Andi agents
    if ssh "$ANDI_HOST" "test -f $ANDI_BASE/$RETRO_DB" 2>/dev/null; then
        # Merge strategy: Andi's entries get pulled into Mac's DB
        # For SQLite, we pull the whole file only if Andi's is newer
        local andi_mtime=$(ssh "$ANDI_HOST" "stat -c %Y $ANDI_BASE/$RETRO_DB 2>/dev/null || echo 0")
        local mac_mtime=0
        if [ -f "$MAC_BASE/$RETRO_DB" ]; then
            mac_mtime=$(stat -f %m "$MAC_BASE/$RETRO_DB" 2>/dev/null || echo 0)
        fi
        if [ "$andi_mtime" -gt "$mac_mtime" ]; then
            # Pull Andi's retro.db, merge into Mac's
            scp "$ANDI_HOST:$ANDI_BASE/$RETRO_DB" "/tmp/andi_retro.db" 2>/dev/null
            if [ -f "$MAC_BASE/$RETRO_DB" ]; then
                # Merge: insert Andi entries that don't exist locally (by dt + action)
                python3 -c "
import sqlite3
src = sqlite3.connect('/tmp/andi_retro.db')
dst = sqlite3.connect('$MAC_BASE/$RETRO_DB')
for row in src.execute('SELECT * FROM experience'):
    exists = dst.execute('SELECT 1 FROM experience WHERE dt=? AND action=?', (row[1], row[2])).fetchone()
    if not exists:
        dst.execute('INSERT INTO experience (dt,action,consequence,tfts,domain,tags,agent,session,severity,grade,grade_note,grade_dt,related_ids) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)', row[1:])
        print(f'  merged: {row[2][:60]}')
dst.commit()
" 2>&1
            else
                cp "/tmp/andi_retro.db" "$MAC_BASE/$RETRO_DB"
            fi
            rm -f "/tmp/andi_retro.db"
            log "  retro.db merged from Andi"
        fi
    fi

    # Process inbox — Andi may have fault/dnw/tf files from agents
    rsync -az \
        "$ANDI_HOST:$ANDI_BASE/$PROCESS_INBOX/" \
        "$MAC_BASE/$PROCESS_INBOX/" 2>&1 | tail -1
    log "  process inbox pulled"

    # Facets — agents on Andi may have updated their facets
    rsync -az \
        "$ANDI_HOST:$ANDI_BASE/$FACETS_DIR/" \
        "$MAC_BASE/$FACETS_DIR/" 2>&1 | tail -1
    log "  facets pulled"

    log "PULL complete"
}

# Status: show what would sync
status() {
    echo "=== Identity Sync Status ==="
    echo "Mac:  $MAC_BASE"
    echo "Andi: $ANDI_HOST:$ANDI_BASE"
    echo ""

    if check_andi; then
        echo "Andi: REACHABLE"
    else
        echo "Andi: NOT REACHABLE"
        return 1
    fi

    echo ""
    echo "Mac identity store:"
    if [ -d "$MAC_BASE/$IDENTITY_STORE" ]; then
        echo "  $(du -sh "$MAC_BASE/$IDENTITY_STORE" | cut -f1) in $IDENTITY_STORE"
    else
        echo "  (not found)"
    fi

    echo "Mac retro.db:"
    if [ -f "$MAC_BASE/$RETRO_DB" ]; then
        local count=$(sqlite3 "$MAC_BASE/$RETRO_DB" "SELECT COUNT(*) FROM experience" 2>/dev/null || echo "?")
        echo "  $count entries"
    else
        echo "  (not found)"
    fi

    echo ""
    echo "Andi retro.db:"
    local andi_count=$(ssh "$ANDI_HOST" "sqlite3 $ANDI_BASE/$RETRO_DB 'SELECT COUNT(*) FROM experience' 2>/dev/null || echo '(not found)'")
    echo "  $andi_count entries"

    echo ""
    echo "Last sync: $(tail -1 "$LOG" 2>/dev/null || echo 'never')"
}

# Main
main() {
    case "${1:-sync}" in
        push)
            check_andi && ensure_andi_dirs && push
            ;;
        pull)
            check_andi && pull
            ;;
        status)
            status
            ;;
        sync|"")
            if check_andi; then
                ensure_andi_dirs
                push
                pull
                log "SYNC complete (bidirectional)"
            fi
            ;;
        *)
            echo "Usage: allie-sync-identity.sh [push|pull|status|sync]"
            exit 1
            ;;
    esac
}

main "$@"

#!/usr/bin/env bash
# allie-memory-save.sh — periodic memory reinforcement save
#
# Runs every 2 hours via system crontab.
# 1. Syncs Claude Code memory files → ~/Allie/memory/claude-code/
#    so Allie's nightly allie-reflect.py can read them.
# 2. Commits any uncommitted changes in ~/Allie/process/inbox/
#    (captures fault/tf/tfts files written mid-session without explicit commit).
# 3. Commits the memory sync.
# 4. Logs to ~/Allie/logs/memory-save.log (rolling, keeps last 200 lines).
#
# Does nothing if git is clean — no empty commits.

set -euo pipefail

ALLIE="$HOME/Allie"
CLAUDE_MEM="$HOME/.claude/projects/-Users-williamjames-Allie/memory"
DEST="$ALLIE/memory/claude-code"
LOG="$ALLIE/logs/memory-save.log"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

log() {
  echo "[$TS] $*" | tee -a "$LOG"
}

# ── Ensure destination exists ─────────────────────────────────────────────────
mkdir -p "$DEST"
mkdir -p "$(dirname "$LOG")"

# ── Sync Claude Code memory → Allie tree ─────────────────────────────────────
if [ -d "$CLAUDE_MEM" ]; then
  rsync -a --checksum "$CLAUDE_MEM/" "$DEST/"
  log "memory sync: $(ls "$DEST" | wc -l | tr -d ' ') files in place"
else
  log "memory sync: Claude Code memory dir not found at $CLAUDE_MEM — skipping"
fi

# ── Commit any pending changes in Allie repo ─────────────────────────────────
cd "$ALLIE"

# Check for anything to commit (memory sync + any uncommitted inbox files)
CHANGED=$(git status --short 2>/dev/null | wc -l | tr -d ' ')

if [ "$CHANGED" -eq 0 ]; then
  log "nothing to commit — clean"
else
  git add memory/claude-code/ process/inbox/ today/ 2>/dev/null || true
  STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  if [ "$STAGED" -gt 0 ]; then
    git commit -m "memory-save $TS: $STAGED file(s)" --no-verify 2>/dev/null
    log "committed $STAGED file(s)"
  else
    log "nothing staged after add — clean"
  fi
fi

# ── Roll log to 200 lines ────────────────────────────────────────────────────
if [ -f "$LOG" ]; then
  LINES=$(wc -l < "$LOG")
  if [ "$LINES" -gt 200 ]; then
    tail -200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  fi
fi

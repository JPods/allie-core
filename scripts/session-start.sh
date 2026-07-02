#!/bin/bash
# session-start.sh — Session briefing for Claude Code
# Recovers context from agent bus, vector store, handoff, and allie DB.
# Usage: bash ~/Allie/scripts/session-start.sh

set -euo pipefail

ALLIE_HOME="$HOME/Allie"
PYTHON="$ALLIE_HOME/source/bin/python"
HANDOFF_DIR="$ALLIE_HOME/handoff"
DB_NAME="allie"
DB_USER="williamjames"
DB_HOST="localhost"

NOW=$(date -u +"%Y-%m-%d %H:%M UTC")

echo "## Session Briefing — $NOW"
echo ""

# --- 1. Agent message bus ---
echo "### Unread Messages"
MSG_OUTPUT=""
if [ -f "$ALLIE_HOME/scripts/agent_bus.py" ]; then
    MSG_OUTPUT=$("$PYTHON" "$ALLIE_HOME/scripts/agent_bus.py" inbox claude 2>/dev/null || true)
    if [ -n "$MSG_OUTPUT" ]; then
        # Also check 'all' messages
        ALL_OUTPUT=$("$PYTHON" "$ALLIE_HOME/scripts/agent_bus.py" inbox all 2>/dev/null || true)
        if [ -n "$ALL_OUTPUT" ]; then
            MSG_OUTPUT="$MSG_OUTPUT"$'\n'"$ALL_OUTPUT"
        fi
    else
        MSG_OUTPUT=$("$PYTHON" "$ALLIE_HOME/scripts/agent_bus.py" inbox all 2>/dev/null || true)
    fi
fi

if [ -n "$MSG_OUTPUT" ] && [ "$MSG_OUTPUT" != "[]" ] && [ "$MSG_OUTPUT" != "No messages" ]; then
    echo "$MSG_OUTPUT"
else
    echo "- None"
fi
echo ""

# --- 2. Vector store recall ---
echo "### Recent Memories (top 5)"
RECALL_OUTPUT=""
if [ -f "$ALLIE_HOME/scripts/claude-vectorstore.py" ]; then
    RECALL_OUTPUT=$("$PYTHON" "$ALLIE_HOME/scripts/claude-vectorstore.py" recall --n 5 2>/dev/null || true)
fi

if [ -n "$RECALL_OUTPUT" ]; then
    echo "$RECALL_OUTPUT"
else
    echo "- Vector store unavailable"
fi
echo ""

# --- 3. Open items from allie DB ---
echo "### Open Items"

# Unresolved TFTS
TFTS_COUNT=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -qAt \
    -c "SELECT COUNT(*) FROM tfts WHERE resolved = false" 2>/dev/null || echo "?")
echo "- $TFTS_COUNT unresolved TFTS"

# Open observations
OBS_COUNT=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -qAt \
    -c "SELECT COUNT(*) FROM observations WHERE resolved = false" 2>/dev/null || echo "?")
echo "- $OBS_COUNT open observations"

# Unread agent messages (from DB as cross-check)
UNREAD_COUNT=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -qAt \
    -c "SELECT COUNT(*) FROM agent_messages WHERE to_agent IN ('claude','all') AND read = false" 2>/dev/null || echo "?")
echo "- $UNREAD_COUNT unread agent messages"
echo ""

# --- 4. Latest handoff ---
echo "### Last Handoff"

# Find most recent dated handoff file (YYYY-MM-DD pattern), fall back to handoff.md
LATEST_HANDOFF=""
if [ -d "$HANDOFF_DIR" ]; then
    LATEST_HANDOFF=$(ls -1 "$HANDOFF_DIR"/*-handoff.md 2>/dev/null | sort -r | head -1)
    if [ -z "$LATEST_HANDOFF" ]; then
        # Fall back to handoff.md
        if [ -f "$HANDOFF_DIR/handoff.md" ]; then
            LATEST_HANDOFF="$HANDOFF_DIR/handoff.md"
        fi
    fi
fi

if [ -n "$LATEST_HANDOFF" ] && [ -f "$LATEST_HANDOFF" ]; then
    echo "*$(basename "$LATEST_HANDOFF")*"
    echo ""
    head -c 500 "$LATEST_HANDOFF"
    FILESIZE=$(wc -c < "$LATEST_HANDOFF" | tr -d ' ')
    if [ "$FILESIZE" -gt 500 ]; then
        echo ""
        echo "... (truncated — $(( FILESIZE - 500 )) more bytes)"
    fi
else
    echo "- No handoff file found"
fi
echo ""
echo "---"
echo "*Run \`cat ~/Allie/handoff/handoff.md\` for full handoff.*"

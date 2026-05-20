#!/usr/bin/env bash
# allie-dnw.sh — "Did Not Work"
#
# Captures a failed attempt at the moment of failure.
# Pair with `tf` (That Fixed it) to bracket the arc from intent to solution.
#
# Usage:
#   dnw "intent: what you were trying to do"
#   dnw "intent: reduce Z drift in bezier"  "jpod_network.rb:bezier_spline_pts"
#   dnw   (no args — opens $EDITOR)
#
# Output: ~/Allie/process/inbox/TIMESTAMP-dnw.md
#         ~/Allie/logs/events.jsonl  (one JSONL line)
#
# Alias: alias dnw='bash ~/Allie/scripts/allie-dnw.sh'

INBOX="$HOME/Allie/process/inbox"
CAPTURE="$HOME/Allie/scripts/allie-capture.py"
TS=$(date '+%Y-%m-%dT%H:%M:%S')
TS_FILE=$(date '+%Y%m%dT%H%M%S')
FILE="$INBOX/${TS_FILE}-dnw.md"

mkdir -p "$INBOX"

INTENT="$1"
CODE_REF="$2"

if [[ -z "$INTENT" ]]; then
  TMPFILE=$(mktemp /tmp/dnw-XXXXXX.md)
  cat > "$TMPFILE" <<EOF
# DNW — $TS

intent:

code:

EOF
  ${EDITOR:-nano} "$TMPFILE"
  CONTENT=$(grep -v "^#\|^$" "$TMPFILE" | grep -v "^intent: $\|^code: $" | tr -d '[:space:]')
  if [[ -z "$CONTENT" ]]; then
    rm "$TMPFILE"
    echo "[dnw] nothing written — cancelled"
    exit 0
  fi
  cp "$TMPFILE" "$FILE"
  rm "$TMPFILE"
  INTENT=$(grep "^intent:" "$FILE" | sed 's/^intent: *//' | head -1)
  CODE_REF=$(grep "^code:" "$FILE" | sed 's/^code: *//' | head -1)
else
  {
    echo "# DNW — $TS"
    echo ""
    echo "intent: $INTENT"
    [[ -n "$CODE_REF" ]] && echo "code:   $CODE_REF"
  } > "$FILE"
fi

# Log to events.jsonl
if [[ -f "$CAPTURE" ]]; then
  DATA="{\"intent\":\"${INTENT//\"/\\\"}\",\"code\":\"${CODE_REF//\"/\\\"}\"}"
  python3 "$CAPTURE" \
    --source "dnw" \
    --event  "did_not_work" \
    --message "${INTENT:0:200}" \
    --data    "$DATA" \
    2>/dev/null
fi

echo "[dnw] → $(basename "$FILE")"

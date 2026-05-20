#!/usr/bin/env bash
# allie-tf.sh — "That Fixed it"
#
# Captures the solution at the moment it works.
# Pair with `dnw` (Did Not Work) to bracket the arc from intent to solution.
#
# Usage:
#   tf "summary: what worked"
#   tf "zero center_pts Z before PathBuilder, not inside it"  "jpod_network.rb:242"
#   tf   (no args — opens $EDITOR)
#
# A sequence of dnw → dnw → tf entries in the inbox is a draft process narrative.
# Allie reads the inbox during nightly synthesis and can trace the arc.
#
# Output: ~/Allie/process/inbox/TIMESTAMP-tf.md
#         ~/Allie/logs/events.jsonl  (one JSONL line)
#
# Alias: alias tf='bash ~/Allie/scripts/allie-tf.sh'

INBOX="$HOME/Allie/process/inbox"
CAPTURE="$HOME/Allie/scripts/allie-capture.py"
TS=$(date '+%Y-%m-%dT%H:%M:%S')
TS_FILE=$(date '+%Y%m%dT%H%M%S')
FILE="$INBOX/${TS_FILE}-tf.md"

mkdir -p "$INBOX"

SUMMARY="$1"
CODE_REF="$2"

if [[ -z "$SUMMARY" ]]; then
  TMPFILE=$(mktemp /tmp/tf-XXXXXX.md)
  cat > "$TMPFILE" <<EOF
# TF — $TS

summary:

code:

why it worked (vs. what didn't):

EOF
  ${EDITOR:-nano} "$TMPFILE"
  CONTENT=$(grep -v "^#\|^$" "$TMPFILE" | grep -v "^summary: $\|^code: $\|^why" | tr -d '[:space:]')
  if [[ -z "$CONTENT" ]]; then
    rm "$TMPFILE"
    echo "[tf] nothing written — cancelled"
    exit 0
  fi
  cp "$TMPFILE" "$FILE"
  rm "$TMPFILE"
  SUMMARY=$(grep "^summary:" "$FILE" | sed 's/^summary: *//' | head -1)
  CODE_REF=$(grep "^code:" "$FILE" | sed 's/^code: *//' | head -1)
else
  {
    echo "# TF — $TS"
    echo ""
    echo "summary: $SUMMARY"
    [[ -n "$CODE_REF" ]] && echo "code:    $CODE_REF"
  } > "$FILE"
fi

# Log to events.jsonl
if [[ -f "$CAPTURE" ]]; then
  DATA="{\"summary\":\"${SUMMARY//\"/\\\"}\",\"code\":\"${CODE_REF//\"/\\\"}\"}"
  python3 "$CAPTURE" \
    --source "tf" \
    --event  "that_fixed_it" \
    --message "${SUMMARY:0:200}" \
    --data    "$DATA" \
    2>/dev/null
fi

echo "[tf] → $(basename "$FILE")"

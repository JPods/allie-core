#!/usr/bin/env bash
# allie-fault.sh — "Fault Found"
#
# Logs a detected fault at the moment of detection.
# A FAULT is what the system reports, not what the developer tried.
# Sources: Noelle faults[], trip planning errors, build failures,
#          vehicle anomalies, Nora sensor faults, hardware errors.
#
# This is different from DNW (Did Not Work), which is a developer's failed fix attempt.
# FAULT comes first — it is the problem statement. DNW comes after.
#
# The arc:
#   fault "description"   →  process/inbox/TIMESTAMP-fault.md
#   dnw   "fix attempt"   →  ... (if fix fails)
#   tf    "what worked"   →  ... (if insight reached)
#   tfts  (full arc)      →  process/inbox/TIMESTAMP-tfts.md
#
# Allie reads fault files nightly:
#   - Recurring unresolved faults  → ouch-list candidates
#   - FAULT + TFTS pairs           → Understanding candidates
#
# Usage:
#   fault "Noelle: S013 missing detectable platform guideways"
#   fault "Trip planner: no route S048→S050" "SU"
#   fault   (no args — opens $EDITOR for full form)
#
# Fields:
#   system:      SU | PH | RT | WC3 | SYS | ALLIE
#   detected_by: Noelle | Nora | Natalie | Claude | Allie | Bill | Alice
#   fault:       one-line description
#   context:     what was happening when the fault occurred
#
# Output: ~/Allie/process/inbox/TIMESTAMP-fault.md
#         ~/Allie/logs/events.jsonl
#
# Alias: alias fault='bash ~/Allie/scripts/allie-fault.sh'

INBOX="$HOME/Allie/process/inbox"
CAPTURE="$HOME/Allie/scripts/allie-capture.py"
TS=$(date '+%Y-%m-%dT%H:%M:%S')
TS_FILE=$(date '+%Y%m%dT%H%M%S')
FILE="$INBOX/${TS_FILE}-fault.md"

mkdir -p "$INBOX"

FAULT_DESC="$1"
SYSTEM="$2"

if [[ -z "$FAULT_DESC" ]]; then
  TMPFILE=$(mktemp /tmp/fault-XXXXXX.md)
  cat > "$TMPFILE" <<EOF
# FAULT — $TS

system:      SU
detected_by: Noelle
fault:
context:
resolved_at:

EOF
  ${EDITOR:-nano} "$TMPFILE"
  CONTENT=$(grep -v "^#\|^$" "$TMPFILE" | grep -v "^system: SU$\|^detected_by:\|^fault: $\|^context: $\|^resolved_at:" | tr -d '[:space:]')
  if [[ -z "$CONTENT" ]]; then
    rm "$TMPFILE"
    echo "[fault] nothing written — cancelled"
    exit 0
  fi
  cp "$TMPFILE" "$FILE"
  rm "$TMPFILE"
  FAULT_DESC=$(grep "^fault:" "$FILE" | sed 's/^fault: *//' | head -1)
  SYSTEM=$(grep "^system:" "$FILE" | sed 's/^system: *//' | head -1)
else
  {
    echo "# FAULT — $TS"
    echo ""
    echo "system:      ${SYSTEM:-SU}"
    echo "detected_by: "
    echo "fault:       $FAULT_DESC"
    echo "context:     "
    echo "resolved_at: "
  } > "$FILE"
fi

# Log to events.jsonl
if [[ -f "$CAPTURE" ]]; then
  DATA="{\"fault\":\"${FAULT_DESC//\"/\\\"}\",\"system\":\"${SYSTEM//\"/\\\"}\"}"
  python3 "$CAPTURE" \
    --source "fault" \
    --event  "fault_found" \
    --message "${FAULT_DESC:0:200}" \
    --data    "$DATA" \
    2>/dev/null
fi

echo "[fault] → $(basename "$FILE")"

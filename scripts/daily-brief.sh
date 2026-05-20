#!/usr/bin/env bash
# daily-brief.sh
# Generates or updates today's daily brief at /Users/williamjames/Allie/today/YYYY-MM-DD.md
#
# Requires: gcalcli (brew install gcalcli) — configured with Google OAuth
# Optional: mutt or a Gmail token for email highlights (see readmes/google-integration.md)
#
# Run at session start, or any time during the day to refresh the calendar section.

set -euo pipefail

ALLIE="/Users/williamjames/Allie"
TODAY=$(date +%Y-%m-%d)
BRIEF="$ALLIE/today/$TODAY.md"
TEMPLATE="$ALLIE/today/_template.md"

# ── Verify Allie drive is mounted ────────────────────────────────────────────
if [[ ! -d "$ALLIE" ]]; then
  echo "ERROR: /Users/williamjames/Allie not mounted. Plug in the Allie drive and retry."
  exit 1
fi

# ── Create brief from template if it does not exist ─────────────────────────
if [[ ! -f "$BRIEF" ]]; then
  sed "s/YYYY-MM-DD/$TODAY/g" "$TEMPLATE" > "$BRIEF"
  echo "Created: $BRIEF"
fi

# ── Pull calendar events via gcalcli ────────────────────────────────────────
if ! command -v gcalcli &>/dev/null; then
  echo "WARNING: gcalcli not installed. Calendar section will be empty."
  echo "  Install: brew install gcalcli"
  echo "  Configure: see /Users/williamjames/Allie/readmes/google-integration.md"
  CAL_BLOCK="_gcalcli not installed. Run: brew install gcalcli_"
else
  # Pull today's events — start of day to end of day
  START="${TODAY}T00:00"
  END="${TODAY}T23:59"
  CAL_RAW=$(gcalcli agenda "$START" "$END" --nocolor --nodeclined 2>/dev/null || echo "")

  if [[ -z "$CAL_RAW" ]]; then
    CAL_BLOCK="_No events found for $TODAY._"
  else
    # Format as a code block for clean rendering in markdown
    CAL_BLOCK="\`\`\`
$CAL_RAW
\`\`\`"
  fi
fi

# ── Inject calendar block into the brief ─────────────────────────────────────
# Replace the placeholder line with the actual calendar data.
# Uses a Python one-liner for safe multi-line replacement (avoids sed limitations).
python3 - <<PYEOF
import re, pathlib

brief = pathlib.Path("$BRIEF")
content = brief.read_text()

placeholder = "_Run \`scripts/daily-brief.sh\` to populate._"
replacement = """$CAL_BLOCK"""

if placeholder in content:
    content = content.replace(placeholder, replacement, 1)
    brief.write_text(content)
    print("Calendar section updated in $BRIEF")
else:
    print("Calendar section already populated — skipping replacement.")
PYEOF

# ── Pull Gmail highlights (requires token — see google-integration.md) ───────
GMAIL_SCRIPT="$ALLIE/scripts/gmail-highlights.py"
if [[ -f "$GMAIL_SCRIPT" ]]; then
  python3 "$GMAIL_SCRIPT" "$BRIEF" && echo "Email highlights updated."
else
  echo "NOTE: Gmail highlights script not yet configured."
  echo "  See: /Users/williamjames/Allie/readmes/google-integration.md"
fi

echo ""
echo "Daily brief ready: $BRIEF"
echo "Open with: code \"$BRIEF\""

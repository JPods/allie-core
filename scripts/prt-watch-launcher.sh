#!/usr/bin/env bash
# prt-watch-launcher.sh
# Ensures WebClerk is running before the weekly PRT digest, then runs it.

ALLIE="/Users/williamjames/Allie"
WC_DIR="/Users/williamjames/Documents/CommerceExpert/webClerk3"
WC_PYTHON="$WC_DIR/bin/python3"
WC_URL="http://localhost:8000/wcapi/login/"
LOG="$ALLIE/logs/prt-watch-cron.log"

echo "=== $(date) — prt-watch-launcher ===" >> "$LOG"

# ── Check if WebClerk is up ────────────────────────────────────────────────────
if curl -s --max-time 5 "$WC_URL" -X POST \
    -H "Content-Type: application/json" \
    -d '{"email":"allie@jpods.com","password":"1111pass"}' \
    | grep -q '"login successful"'; then
  echo "WebClerk: already running." >> "$LOG"
else
  echo "WebClerk: not responding — launching..." >> "$LOG"
  cd "$WC_DIR" || { echo "ERROR: $WC_DIR not found" >> "$LOG"; exit 1; }
  nohup "$WC_PYTHON" manage.py runserver >> /tmp/webclerk-autolaunch.log 2>&1 &
  echo "WebClerk: launched (PID $!), waiting 10s..." >> "$LOG"
  sleep 10
  # Confirm it came up
  if curl -s --max-time 5 "$WC_URL" -X POST \
      -H "Content-Type: application/json" \
      -d '{"email":"allie@jpods.com","password":"1111pass"}' \
      | grep -q '"login successful"'; then
    echo "WebClerk: up." >> "$LOG"
  else
    echo "WebClerk: WARNING — still not responding after launch. Continuing anyway." >> "$LOG"
  fi
fi

# ── Run PRT digest ─────────────────────────────────────────────────────────────
cd "$ALLIE" || { echo "ERROR: $ALLIE not found" >> "$LOG"; exit 1; }
"$ALLIE/venv/bin/python3" "$ALLIE/scripts/allie-prt-watch.py" >> "$LOG" 2>&1
echo "=== done ===" >> "$LOG"

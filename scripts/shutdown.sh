#!/bin/bash
# shutdown.sh — Graceful shutdown for the team
# Sends SIGTERM (which triggers rightshoe) before stopping services.
# Usage: bash ~/Allie/scripts/shutdown.sh

ALLIE_DIR="$HOME/Allie"
WC3_DIR="$HOME/Documents/CommerceExpert/webClerk3"

echo "═══════════════════════════════════════════"
echo "  Team Shutdown — rightshoe"
echo "═══════════════════════════════════════════"

# 1. Allie API — send SIGTERM (triggers rightshoe handler)
ALLIE_PID=$(lsof -ti:5001 2>/dev/null || true)
if [ -n "$ALLIE_PID" ]; then
  echo "Allie API (PID $ALLIE_PID): sending SIGTERM (rightshoe)..."
  kill -TERM $ALLIE_PID 2>/dev/null || true
  sleep 2
  # Verify stopped
  if lsof -ti:5001 >/dev/null 2>&1; then
    echo "  Allie didn't stop — sending SIGKILL"
    kill -KILL $ALLIE_PID 2>/dev/null || true
  else
    echo "  Allie: shutdown complete"
  fi
else
  echo "Allie API: not running"
fi

# 2. Alice — flush observations via Django management command
if [ -f "$WC3_DIR/venv/bin/python" ]; then
  echo "Alice: flushing pending observations..."
  cd "$WC3_DIR"
  DJANGO_SETTINGS_MODULE=webclerk3_api.settings "$WC3_DIR/venv/bin/python" -c "
import django; django.setup()
import datetime, json, pathlib
ts = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
log = pathlib.Path.home() / 'Allie' / 'config' / 'agent_log.jsonl'
try:
    with open(log, 'a') as f:
        f.write(json.dumps({'event': 'rightshoe', 'ts': ts, 'source': 'alice', 'message': 'Graceful shutdown'}) + '\n')
    print('  Alice: agent_log written')
except Exception as e:
    print(f'  Alice: agent_log failed: {e}')
" 2>/dev/null || echo "  Alice: flush skipped (Django not available)"
  cd "$ALLIE_DIR"
else
  echo "Alice: WC3 venv not found, skipping"
fi

# 3. React dev server
REACT_PID=$(lsof -ti:5173 2>/dev/null || true)
if [ -n "$REACT_PID" ]; then
  echo "React dev server (PID $REACT_PID): stopping..."
  kill -TERM $REACT_PID 2>/dev/null || true
  echo "  React: stopped"
else
  echo "React: not running"
fi

# 4. Celery
CELERY_PIDS=$(pgrep -f "celery -A webclerk3_api" 2>/dev/null || true)
if [ -n "$CELERY_PIDS" ]; then
  echo "Celery: stopping..."
  pkill -f "celery -A webclerk3_api" 2>/dev/null || true
  echo "  Celery: stopped"
else
  echo "Celery: not running"
fi

# 5. Django
DJANGO_PID=$(lsof -ti:8000 2>/dev/null || true)
if [ -n "$DJANGO_PID" ]; then
  echo "Django (PID $DJANGO_PID): stopping..."
  kill -TERM $DJANGO_PID 2>/dev/null || true
  echo "  Django: stopped"
else
  echo "Django: not running"
fi

# Note: Ollama stays running — it's a system service, not session-specific

echo ""
echo "═══════════════════════════════════════════"
echo "  Team shutdown complete"
echo "  Ollama left running (system service)"
echo "  Restart with: $WC3_DIR/runserver.sh"
echo "═══════════════════════════════════════════"

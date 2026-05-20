#!/usr/bin/env bash
# watcher-start.sh — start the Allie activity watcher in the background

ALLIE="/Users/williamjames/Allie"
PID_FILE="/tmp/allie-watcher.pid"

if [[ ! -d "$ALLIE" ]]; then
  echo "ERROR: /Users/williamjames/Allie not mounted."
  exit 1
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Watcher already running (PID $(cat "$PID_FILE"))."
  exit 0
fi

nohup bash "$ALLIE/scripts/watcher.sh" >> "/tmp/allie-watcher-stderr.log" 2>&1 &
sleep 2
if [[ -f "$PID_FILE" ]]; then
  echo "Watcher started (PID $(cat "$PID_FILE"))."
  echo "Log: /Users/williamjames/Allie/today/$(date +%Y-%m-%d)-activity.log"
else
  echo "ERROR: Watcher failed to start. Check /tmp/allie-watcher-stderr.log"
fi

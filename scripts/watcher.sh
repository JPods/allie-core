#!/usr/bin/env bash
# watcher.sh — Allie + Athena background activity daemon.
# Watches everything Bill does across all projects.
# Projects: jpods-plugin, jpods-docs, webclerk3, react2025, allie, politics
# Apps: SketchUp, VS Code, Zoom, Chrome
# Harvest: python3 /Users/williamjames/Allie/scripts/harvest.py
# Compatible: bash 3.2+ (macOS system bash)

ALLIE="/Users/williamjames/Allie"
PID_FILE="/tmp/allie-watcher.pid"

# Project dirs (parallel vars — bash 3.2 has no associative arrays)
PROJ_NAMES="jpods-plugin jpods-docs webclerk3 react2025 allie politics docs desktop"
DIR_jpods_plugin="$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods"
DIR_jpods_docs="$HOME/Documents/08_JPods"
DIR_webclerk3="$HOME/Documents/CommerceExpert/webClerk3"
DIR_react2025="$HOME/Documents/CommerceExpert/React2025"
DIR_allie="/Users/williamjames/Allie"
DIR_politics="$HOME/Documents/Politics"
DIR_docs="$HOME/Documents"
DIR_desktop="$HOME/Desktop"

proj_dir() {
  local key
  key=$(echo "$1" | tr '-' '_')
  eval echo "\$DIR_${key}"
}

SKETCHUP_WAS_RUNNING=false
CODE_WAS_RUNNING=false
ZOOM_WAS_RUNNING=false
CHROME_WAS_RUNNING=false
WORD_WAS_RUNNING=false
EXCEL_WAS_RUNNING=false
AFFINITY_DESIGNER_WAS_RUNNING=false
AFFINITY_PUBLISHER_WAS_RUNNING=false
AFFINITY_PHOTO_WAS_RUNNING=false
MESSENGER_WAS_RUNNING=false
WHATSAPP_WAS_RUNNING=false

# App session timers (seconds since app opened, 0 = not running)
CODE_OPEN_TS=0
WORD_OPEN_TS=0
EXCEL_OPEN_TS=0

LAST_CAL_CHECK=0
CAL_CHECK_INTERVAL=3600

LAST_DOC_CHECK=0
DOC_CHECK_INTERVAL=60    # query active document every 60 seconds

# ── Active document query (AppleScript) ───────────────────────────────────────

active_vscode_doc() {
  # VS Code: get frontmost window title, which contains "filename — folder — Visual Studio Code"
  osascript -e 'tell application "System Events"
    set f to first application process whose frontmost is true
    if name of f contains "Code" then
      set t to title of first window of f
      return t
    end if
    return ""
  end tell' 2>/dev/null || true
}

active_word_doc() {
  # "if application is running" does NOT launch the app; "tell application" does.
  osascript -e 'if application "Microsoft Word" is running then
    tell application "Microsoft Word"
      if (count of documents) > 0 then
        return name of active document
      end if
    end tell
  end if
  return ""' 2>/dev/null || true
}

active_excel_doc() {
  osascript -e 'if application "Microsoft Excel" is running then
    tell application "Microsoft Excel"
      if (count of workbooks) > 0 then
        return name of active workbook
      end if
    end tell
  end if
  return ""' 2>/dev/null || true
}

active_chrome_title() {
  # Returns title of frontmost Chrome tab — catches Google Docs/Sheets/Slides
  osascript -e 'tell application "Google Chrome"
    if (count of windows) > 0 then
      return title of active tab of front window
    end if
    return ""
  end tell' 2>/dev/null || true
}

# ── Startup ───────────────────────────────────────────────────────────────────

if [[ ! -d "$ALLIE" ]]; then
  echo "Allie drive not mounted. Watcher exiting."
  exit 0
fi

echo $$ > "$PID_FILE"
TODAY=$(date +%Y-%m-%d)
LOG="$ALLIE/today/${TODAY}-activity.log"
mkdir -p "$ALLIE/today"
touch "$LOG"

log() {
  local level="$1"; shift
  local ts; ts=$(date +"%H:%M:%S")
  echo "[$ts] [$level] $*" >> "$LOG"
}

log "START" "Watcher started (PID $$). Projects: $PROJ_NAMES"

# ── Cleanup ───────────────────────────────────────────────────────────────────

cleanup() {
  log "STOP" "Watcher stopped (PID $$)."
  rm -f "$PID_FILE"
  # Kill only the fswatch child, not the whole process group
  [[ -n "${FSWATCH_PID:-}" ]] && kill "$FSWATCH_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── File classifier ───────────────────────────────────────────────────────────

classify_change() {
  local project="$1"
  local path="$2"
  case "$path" in
    *.skb|*.bak|*.pyc|*.DS_Store) return ;;
    *__pycache__*|*toolbar_icons*) return ;;
  esac

  local base
  base=$(proj_dir "$project")
  local rel="${path#$base/}"

  case "$project" in
    jpods-plugin)
      case "$path" in
        *.rb)   log "CODE[$project]" "Ruby: $rel" ;;
        *.html) log "CODE[$project]" "Dialog: $rel" ;;
        *.skp)  log "MODEL[$project]" "Model: $rel" ;;
        *.json) log "DATA[$project]" "JSON: $rel" ;;
      esac ;;
    jpods-docs)
      case "$path" in
        *.skp)               log "MODEL[$project]" "$rel" ;;
        *.md|*.txt|*.docx)   log "WRITE[$project]" "$rel" ;;
      esac ;;
    webclerk3)
      case "$path" in
        *.py)         log "CODE[$project]" "Python: $rel" ;;
        *.html)       log "CODE[$project]" "Template: $rel" ;;
        *.js|*.ts)    log "CODE[$project]" "JS/TS: $rel" ;;
        *.json)       log "DATA[$project]" "$rel" ;;
        *.md)         log "WRITE[$project]" "$rel" ;;
      esac ;;
    react2025)
      case "$path" in
        *.tsx|*.jsx|*.ts|*.js)  log "CODE[$project]" "$rel" ;;
        *.css|*.scss)           log "CODE[$project]" "Style: $rel" ;;
      esac ;;
    allie)
      case "$path" in
        *today/*-activity.log) return ;;
        *.md)        log "ALLIE" "Doc updated: $rel" ;;
        *.py|*.sh)   log "ALLIE" "Script: $rel" ;;
      esac ;;
    politics)
      case "$path" in
        *.md|*.txt|*.docx) log "WRITE[$project]" "$rel" ;;
      esac ;;
    docs|desktop)
      case "$path" in
        # Skip jpods/webclerk subdirs already covered above
        *08_JPods*|*webClerk*|*React2025*|*Politics*) return ;;
        *.docx)  log "DOC[word]"  "Changed: $rel" ;;
        *.xlsx)  log "DOC[excel]" "Changed: $rel" ;;
        *.pptx)  log "DOC[ppt]"   "Changed: $rel" ;;
        *.pdf)   log "DOC[pdf]"   "Changed: $rel" ;;
        # Affinity file types
        *.afdesign) log "DOC[affinity-designer]" "Changed: $rel" ;;
        *.afpub)    log "DOC[affinity-publisher]" "Changed: $rel" ;;
        *.afphoto)  log "DOC[affinity-photo]"     "Changed: $rel" ;;
      esac ;;
  esac
}

# ── File watcher ──────────────────────────────────────────────────────────────

FSWATCH_BIN="/opt/homebrew/bin/fswatch"
if [[ ! -x "$FSWATCH_BIN" ]]; then
  log "WARN" "fswatch not found at $FSWATCH_BIN — file watching disabled. Run: brew install fswatch"
else
  WATCH_DIRS=""
  for proj in $PROJ_NAMES; do
    dir=$(proj_dir "$proj")
    if [[ -d "$dir" ]]; then
      WATCH_DIRS="$WATCH_DIRS $dir"
    else
      log "WARN" "Dir missing, skipping: $proj"
    fi
  done

  "$FSWATCH_BIN" --recursive --event=Updated --event=Created --event=Removed --latency=2.0 $WATCH_DIRS \
  | while read -r changed_path; do
      matched_project=""
      matched_len=0
      for proj in $PROJ_NAMES; do
        dir=$(proj_dir "$proj")
        dir_len=${#dir}
        if [[ "$changed_path" == "$dir"* ]] && (( dir_len > matched_len )); then
          matched_project="$proj"
          matched_len=$dir_len
        fi
      done
      [[ -n "$matched_project" ]] && classify_change "$matched_project" "$changed_path"
    done &
  FSWATCH_PID=$!
fi

# ── Main poll loop ────────────────────────────────────────────────────────────

while true; do
  [[ ! -d "$ALLIE" ]] && { log "STOP" "Allie drive unmounted."; exit 0; }

  NEW_TODAY=$(date +%Y-%m-%d)
  if [[ "$NEW_TODAY" != "$TODAY" ]]; then
    TODAY="$NEW_TODAY"
    LOG="$ALLIE/today/${TODAY}-activity.log"
    touch "$LOG"
    log "START" "New day — log rolled over."
  fi

  NOW_TS=$(date +%s)

  # ── SketchUp ──────────────────────────────────────────────────────────────
  if pgrep -x "SketchUp" > /dev/null 2>&1; then
    [[ "$SKETCHUP_WAS_RUNNING" == "false" ]] && { log "APP" "SketchUp opened — JPods/models work"; SKETCHUP_WAS_RUNNING=true; }
  else
    [[ "$SKETCHUP_WAS_RUNNING" == "true" ]] && { log "APP" "SketchUp closed."; SKETCHUP_WAS_RUNNING=false; }
  fi

  # ── VS Code ───────────────────────────────────────────────────────────────
  if pgrep -xq "Electron" 2>/dev/null || pgrep -f "Visual Studio Code" > /dev/null 2>&1 || pgrep -xq "Code Helper" 2>/dev/null; then
    if [[ "$CODE_WAS_RUNNING" == "false" ]]; then
      log "APP" "VS Code opened — coding session"
      CODE_WAS_RUNNING=true
      CODE_OPEN_TS=$NOW_TS
    fi
  else
    if [[ "$CODE_WAS_RUNNING" == "true" ]]; then
      elapsed=$(( NOW_TS - CODE_OPEN_TS ))
      mins=$(( elapsed / 60 ))
      log "APP" "VS Code closed (${mins}m session)."
      CODE_WAS_RUNNING=false
      CODE_OPEN_TS=0
    fi
  fi

  # ── Zoom ──────────────────────────────────────────────────────────────────
  if pgrep -f "zoom.us" > /dev/null 2>&1; then
    [[ "$ZOOM_WAS_RUNNING" == "false" ]] && { log "APP" "Zoom opened — meeting"; ZOOM_WAS_RUNNING=true; }
  else
    [[ "$ZOOM_WAS_RUNNING" == "true" ]] && { log "APP" "Zoom closed."; ZOOM_WAS_RUNNING=false; }
  fi

  # ── Chrome (catches Google Docs/Sheets/Slides/Gmail) ─────────────────────
  if pgrep -f "Google Chrome" > /dev/null 2>&1; then
    if [[ "$CHROME_WAS_RUNNING" == "false" ]]; then
      log "APP" "Chrome opened"
      CHROME_WAS_RUNNING=true
    fi
  else
    [[ "$CHROME_WAS_RUNNING" == "true" ]] && { log "APP" "Chrome closed."; CHROME_WAS_RUNNING=false; }
  fi

  # ── Microsoft Word ────────────────────────────────────────────────────────
  if pgrep -f "Microsoft Word" > /dev/null 2>&1; then
    if [[ "$WORD_WAS_RUNNING" == "false" ]]; then
      log "APP" "Word opened"
      WORD_WAS_RUNNING=true
      WORD_OPEN_TS=$NOW_TS
    fi
  else
    if [[ "$WORD_WAS_RUNNING" == "true" ]]; then
      elapsed=$(( NOW_TS - WORD_OPEN_TS ))
      mins=$(( elapsed / 60 ))
      log "APP" "Word closed (${mins}m session)."
      WORD_WAS_RUNNING=false
      WORD_OPEN_TS=0
    fi
  fi

  # ── Microsoft Excel ───────────────────────────────────────────────────────
  if pgrep -f "Microsoft Excel" > /dev/null 2>&1; then
    if [[ "$EXCEL_WAS_RUNNING" == "false" ]]; then
      log "APP" "Excel opened"
      EXCEL_WAS_RUNNING=true
      EXCEL_OPEN_TS=$NOW_TS
    fi
  else
    if [[ "$EXCEL_WAS_RUNNING" == "true" ]]; then
      elapsed=$(( NOW_TS - EXCEL_OPEN_TS ))
      mins=$(( elapsed / 60 ))
      log "APP" "Excel closed (${mins}m session)."
      EXCEL_WAS_RUNNING=false
      EXCEL_OPEN_TS=0
    fi
  fi

  # ── Affinity apps ─────────────────────────────────────────────────────────
  if pgrep -f "Affinity Designer" > /dev/null 2>&1; then
    [[ "$AFFINITY_DESIGNER_WAS_RUNNING" == "false" ]] && { log "APP" "Affinity Designer opened"; AFFINITY_DESIGNER_WAS_RUNNING=true; }
  else
    [[ "$AFFINITY_DESIGNER_WAS_RUNNING" == "true" ]] && { log "APP" "Affinity Designer closed."; AFFINITY_DESIGNER_WAS_RUNNING=false; }
  fi

  if pgrep -f "Affinity Publisher" > /dev/null 2>&1; then
    [[ "$AFFINITY_PUBLISHER_WAS_RUNNING" == "false" ]] && { log "APP" "Affinity Publisher opened"; AFFINITY_PUBLISHER_WAS_RUNNING=true; }
  else
    [[ "$AFFINITY_PUBLISHER_WAS_RUNNING" == "true" ]] && { log "APP" "Affinity Publisher closed."; AFFINITY_PUBLISHER_WAS_RUNNING=false; }
  fi

  if pgrep -f "Affinity Photo" > /dev/null 2>&1; then
    [[ "$AFFINITY_PHOTO_WAS_RUNNING" == "false" ]] && { log "APP" "Affinity Photo opened"; AFFINITY_PHOTO_WAS_RUNNING=true; }
  else
    [[ "$AFFINITY_PHOTO_WAS_RUNNING" == "true" ]] && { log "APP" "Affinity Photo closed."; AFFINITY_PHOTO_WAS_RUNNING=false; }
  fi

  # ── WhatsApp ──────────────────────────────────────────────────────────────
  if pgrep -f "WhatsApp" > /dev/null 2>&1; then
    [[ "$WHATSAPP_WAS_RUNNING" == "false" ]] && { log "APP" "WhatsApp opened"; WHATSAPP_WAS_RUNNING=true; }
  else
    [[ "$WHATSAPP_WAS_RUNNING" == "true" ]] && { log "APP" "WhatsApp closed."; WHATSAPP_WAS_RUNNING=false; }
  fi

  # ── Messenger ─────────────────────────────────────────────────────────────
  if pgrep -f "Messenger" > /dev/null 2>&1; then
    [[ "$MESSENGER_WAS_RUNNING" == "false" ]] && { log "APP" "Messenger opened"; MESSENGER_WAS_RUNNING=true; }
  else
    [[ "$MESSENGER_WAS_RUNNING" == "true" ]] && { log "APP" "Messenger closed."; MESSENGER_WAS_RUNNING=false; }
  fi

  # ── Active document check (every 60s) ────────────────────────────────────
  if (( NOW_TS - LAST_DOC_CHECK >= DOC_CHECK_INTERVAL )); then
    LAST_DOC_CHECK=$NOW_TS

    # VS Code active file
    if [[ "$CODE_WAS_RUNNING" == "true" ]]; then
      doc=$(active_vscode_doc 2>/dev/null || true)
      [[ -n "$doc" ]] && log "DOC[vscode]" "$doc"
    fi

    # Word active document
    if [[ "$WORD_WAS_RUNNING" == "true" ]]; then
      doc=$(active_word_doc 2>/dev/null || true)
      [[ -n "$doc" ]] && log "DOC[word]" "$doc"
    fi

    # Excel active workbook
    if [[ "$EXCEL_WAS_RUNNING" == "true" ]]; then
      doc=$(active_excel_doc 2>/dev/null || true)
      [[ -n "$doc" ]] && log "DOC[excel]" "$doc"
    fi

    # Chrome tab title — catches Google Docs / Sheets / Slides / Gmail
    if [[ "$CHROME_WAS_RUNNING" == "true" ]]; then
      ctitle=$(active_chrome_title 2>/dev/null || true)
      if [[ -n "$ctitle" ]]; then
        case "$ctitle" in
          *"Google Docs"*|*"Google Sheets"*|*"Google Slides"*)
            log "DOC[gdocs]" "$ctitle" ;;
          *"Gmail"*)
            log "DOC[gmail]" "Gmail active" ;;
          *"Google Calendar"*)
            log "DOC[gcal]" "Calendar active" ;;
        esac
      fi
    fi
  fi

  if (( NOW_TS - LAST_CAL_CHECK >= CAL_CHECK_INTERVAL )); then
    LAST_CAL_CHECK=$NOW_TS
    if command -v gcalcli > /dev/null 2>&1; then
      NOW_ISO=$(date +%Y-%m-%dT%H:%M)
      UPCOMING=$(gcalcli agenda "$NOW_ISO" "${TODAY}T23:59" --nocolor --nodeclined --tsv 2>/dev/null | head -5 || true)
      if [[ -n "$UPCOMING" ]]; then
        log "CAL" "Upcoming:"
        while IFS= read -r cline; do log "CAL" "  $cline"; done <<< "$UPCOMING"
      fi
    fi
  fi

  sleep 15
done

#!/usr/bin/env bash
# meeting.sh
# Attend Google Meet or Zoom meetings: open the link, record system audio, transcribe with Whisper.
#
# Commands:
#   meeting.sh start [meeting-name]   — open next meeting from calendar (or prompt), start recording
#   meeting.sh stop                   — stop recording, transcribe, inject notes into today's brief
#   meeting.sh transcribe [file]      — transcribe an existing recording file manually
#   meeting.sh prep                   — print today's upcoming meetings with links (no recording)
#
# Requirements (one-time setup — see readmes/google-integration.md § Meetings):
#   brew install gcalcli ffmpeg blackhole-2ch
#   pip3 install openai-whisper
#   Configure BlackHole multi-output device in Audio MIDI Setup (see integration guide)
#
# Recording approach:
#   BlackHole-2ch acts as a virtual audio loopback — captures both your microphone
#   and the meeting audio from your speakers simultaneously. No meeting bot required.
#   All audio stays local. Whisper runs locally. Nothing leaves the machine.

set -euo pipefail

ALLIE="/Users/williamjames/Allie"
TODAY=$(date +%Y-%m-%d)
BRIEF="$ALLIE/today/$TODAY.md"
RECORDINGS="$ALLIE/today/recordings"
PID_FILE="/tmp/allie-meeting-record.pid"
FILE_TRACKER="/tmp/allie-meeting-file.txt"

mkdir -p "$RECORDINGS"

# ── Helpers ──────────────────────────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit 1; }

check_deps() {
  local missing=()
  command -v ffmpeg    &>/dev/null || missing+=("ffmpeg (brew install ffmpeg)")
  command -v gcalcli   &>/dev/null || missing+=("gcalcli (brew install gcalcli)")
  command -v whisper   &>/dev/null || missing+=("whisper (pip3 install openai-whisper)")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing dependencies:"
    for m in "${missing[@]}"; do echo "  • $m"; done
    echo "See: /Users/williamjames/Allie/readmes/google-integration.md"
    exit 1
  fi
}

# Check BlackHole is present as an audio device
check_blackhole() {
  if ! system_profiler SPAudioDataType 2>/dev/null | grep -q "BlackHole"; then
    echo "WARNING: BlackHole audio device not found."
    echo "  Install: brew install blackhole-2ch"
    echo "  Then configure a Multi-Output Device in Audio MIDI Setup."
    echo "  See: /Users/williamjames/Allie/readmes/google-integration.md § Meetings"
    echo ""
    echo "Falling back to default microphone only (meeting audio won't be captured)."
    echo "AUDIO_SOURCE=:0"
  else
    echo "AUDIO_SOURCE=BlackHole 2ch"
  fi
}

get_meeting_links() {
  # Pull today's remaining events that contain a meeting link
  local now
  now=$(date +%Y-%m-%dT%H:%M)
  local end="${TODAY}T23:59"
  gcalcli agenda "$now" "$end" --nocolor --nodeclined --details url 2>/dev/null \
    | grep -E "https://(meet\.google\.com|.*\.zoom\.us|zoom\.us)/[^\s]+" \
    || true
}

extract_url_from_event() {
  # Given an event title fragment, find the URL
  local query="$1"
  gcalcli search "$query" --nocolor --details url 2>/dev/null \
    | grep -Eo "https://(meet\.google\.com|.*\.zoom\.us|zoom\.us)/[^ ]+" \
    | head -1 \
    || true
}

open_meeting_url() {
  local url="$1"
  echo "Opening meeting: $url"
  open "$url"
  sleep 3  # give the browser/app time to launch before recording starts
}

consent_gate() {
  # Two-party consent required in CA, IL, MD, MA, NV, OR, WA and others.
  # This prompt is not optional. Recording without it is a legal violation.
  echo ""
  echo "==========================================================="
  echo " RECORDING CONSENT REQUIRED"
  echo "==========================================================="
  echo " Before recording begins, all participants must be informed."
  echo " Say aloud or type in chat:"
  echo "   'This meeting is being recorded and transcribed by a"
  echo "    personal AI. The transcript stays on a private local"
  echo "    drive and is not shared externally. If you object,"
  echo "    please say so now and I will not record.'"
  echo "==========================================================="
  echo ""
  read -rp "All participants informed and consented? [yes/no]: " consent
  if [[ "${consent,,}" != "yes" && "${consent,,}" != "y" ]]; then
    echo "Recording cancelled. No audio captured."
    exit 0
  fi
  echo ""
}

purge_old_recordings() {
  # Auto-purge recordings and transcripts older than PURGE_DAYS.
  # Default 30 days. Override: export ALLIE_MEETING_PURGE_DAYS=N
  local PURGE_DAYS="${ALLIE_MEETING_PURGE_DAYS:-30}"
  echo "Purging recordings older than ${PURGE_DAYS} days..."
  find "$RECORDINGS" -type f \( -name "*.wav" -o -name "*.txt" \) \
    -mtime +"${PURGE_DAYS}" -print -delete
  echo "Purge complete."
}

start_recording() {
  local label="${1:-meeting}"
  local safe_label
  safe_label=$(echo "$label" | tr ' ' '_' | tr -cd '[:alnum:]_-')
  local timestamp
  timestamp=$(date +%H%M)
  local outfile="$RECORDINGS/${TODAY}_${timestamp}_${safe_label}.wav"

  # Detect BlackHole device
  local audio_device
  if system_profiler SPAudioDataType 2>/dev/null | grep -q "BlackHole"; then
    audio_device="BlackHole 2ch"
  else
    audio_device="default"
    echo "WARNING: Recording from default mic only. BlackHole not detected."
  fi

  echo "Recording to: $outfile"
  echo "Press Ctrl+C or run: meeting.sh stop"
  echo ""

  # Record in background — WAV, mono, 16kHz (optimal for Whisper)
  ffmpeg -f avfoundation -i ":${audio_device}" \
    -ar 16000 -ac 1 -c:a pcm_s16le \
    "$outfile" \
    -loglevel warning &

  local rec_pid=$!
  echo "$rec_pid" > "$PID_FILE"
  echo "$outfile"  > "$FILE_TRACKER"
  echo "Recording started (PID $rec_pid). Run 'meeting.sh stop' when done."
}

stop_recording() {
  if [[ ! -f "$PID_FILE" ]]; then
    die "No active recording found. Start one with: meeting.sh start [name]"
  fi

  local rec_pid
  rec_pid=$(cat "$PID_FILE")
  local outfile
  outfile=$(cat "$FILE_TRACKER")

  echo "Stopping recording (PID $rec_pid)..."
  kill "$rec_pid" 2>/dev/null || true
  sleep 1
  rm -f "$PID_FILE" "$FILE_TRACKER"

  echo "Recording saved: $outfile"
  transcribe_and_inject "$outfile"
}

transcribe_and_inject() {
  local audio_file="$1"
  [[ -f "$audio_file" ]] || die "Audio file not found: $audio_file"

  local base
  base=$(basename "$audio_file" .wav)
  local transcript_file="$RECORDINGS/${base}.txt"

  echo "Transcribing (this may take a minute)..."
  # whisper auto-detects language; small model is fast; medium is more accurate
  whisper "$audio_file" \
    --model small \
    --language en \
    --output_format txt \
    --output_dir "$RECORDINGS" \
    2>/dev/null

  if [[ ! -f "$transcript_file" ]]; then
    die "Transcription failed — no output file found."
  fi

  echo "Transcription complete: $transcript_file"

  # Format transcript as meeting notes block
  local meeting_time
  meeting_time=$(echo "$base" | grep -oE '[0-9]{4}_[0-9]{4}' | head -1 | tr '_' ':' | sed 's/:/T/1')
  local meeting_label
  meeting_label=$(echo "$base" | sed 's/^[0-9-]*_[0-9]*_//' | tr '_' ' ')
  local time_display
  time_display=$(echo "$base" | grep -oE '[0-9]{4}$' | head -1 | sed 's/\(..\)\(..\)/\1:\2/')

  local block
  block="### ${time_display:-??:??} — ${meeting_label}
**Recording:** \`$audio_file\`
**Transcript:** \`$transcript_file\`

**Raw transcript:**
\`\`\`
$(cat "$transcript_file")
\`\`\`

**Action items (fill in):**
- [ ] 

**Key decisions (fill in):**
- "

  # Inject into today's brief under ## Meeting Notes
  if [[ -f "$BRIEF" ]]; then
    python3 - <<PYEOF
import pathlib

brief = pathlib.Path("$BRIEF")
content = brief.read_text()
placeholder = "_No meetings yet today._"
block = """$block"""

if placeholder in content:
    content = content.replace(placeholder, block, 1)
else:
    # Append after ## Meeting Notes header
    content = content.replace("## Meeting Notes\n", "## Meeting Notes\n\n" + block + "\n\n", 1)

brief.write_text(content)
print("Meeting notes injected into $BRIEF")
PYEOF
  else
    echo "WARNING: Daily brief not found at $BRIEF"
    echo "         Transcript is at: $transcript_file"
  fi
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd="${1:-help}"

case "$cmd" in

  prep)
    echo "Today's meetings:"
    echo ""
    get_meeting_links || echo "  (none found, or gcalcli not configured)"
    ;;

  start)
    check_deps
    consent_gate
    label="${2:-}"
    if [[ -z "$label" ]]; then
      echo "Upcoming meetings:"
      get_meeting_links
      echo ""
      read -rp "Meeting name (for the notes file): " label
    fi

    # Try to find a URL for this meeting in the calendar
    url=$(extract_url_from_event "$label" || true)
    if [[ -n "$url" ]]; then
      open_meeting_url "$url"
    else
      read -rp "Paste meeting URL (or press Enter to skip): " url
      [[ -n "$url" ]] && open_meeting_url "$url"
    fi

    # Purge old recordings before starting a new one
    purge_old_recordings
    start_recording "$label"
    ;;

  purge)
    purge_old_recordings
    ;;

  stop)
    stop_recording
    ;;

  transcribe)
    check_deps
    audio_file="${2:-}"
    [[ -z "$audio_file" ]] && die "Usage: meeting.sh transcribe /path/to/recording.wav"
    transcribe_and_inject "$audio_file"
    ;;

  help|*)
    cat <<HELP
meeting.sh — Allie meeting attendance tool

Commands:
  prep                     List today's upcoming meetings with links
  start [meeting-name]     Open meeting URL, consent prompt, then record
  stop                     Stop recording, transcribe, inject into daily brief
  transcribe [file.wav]    Transcribe an existing recording manually
  purge                    Delete recordings older than 30 days (default)

One-time setup:
  brew install gcalcli ffmpeg blackhole-2ch
  pip3 install openai-whisper
  Then configure BlackHole in Audio MIDI Setup.
  See: /Users/williamjames/Allie/readmes/google-integration.md

HELP
    ;;
esac

# Allie — App Observation Architecture
**Status:** Partially operational — see status table below
**Last updated:** 2026-04-28

Allie watches everything Bill does across apps and surfaces context at session start.
This document defines what she observes, how, and what each observation means.

---

## Status by App

| App | What Allie sees | How | Status |
|-----|----------------|-----|--------|
| **VS Code** | Open/close + session duration + active file (window title) | `pgrep` + osascript every 60s | **Live** |
| **Word** | Open/close + session duration + active document name | `pgrep` + AppleScript every 60s + fswatch `.docx` | **Live** |
| **Excel** | Open/close + session duration + active workbook name | `pgrep` + AppleScript every 60s + fswatch `.xlsx` | **Live** |
| **Affinity Designer/Publisher/Photo** | Open/close + file changes | `pgrep` + fswatch `.afdesign/.afpub/.afphoto` | **Live** |
| **Google Docs/Sheets/Slides** | Active document name (from Chrome tab title) | osascript Chrome window title every 60s | **Live** |
| **Google Docs (changes)** | Which docs were modified and when | Google Drive API (`allie-gdrive-watch.py`) | **Needs OAuth setup** |
| **Gmail** | Unread, starred, sent — from/subject | Gmail API (`gmail-highlights.py`) | **Needs OAuth setup** |
| **Google Calendar** | Upcoming events for today | `gcalcli` every hour | **Needs `gcalcli` install + auth** |
| **WhatsApp** | Message summaries, action items | `allie-whatsapp-bridge.py` (unofficial) | **Needs manual setup** |
| **Messenger** | Open/close + duration | `pgrep` only | **Live (limited)** |
| **SketchUp** | Open/close | `pgrep` | **Live** |
| **Zoom** | Open/close | `pgrep` | **Live** |

---

## What Each Observation Produces

### Activity Log — `today/YYYY-MM-DD-activity.log`
Written by `watcher.sh`. Events look like:
```
[09:14:32] [APP] VS Code opened — coding session
[09:15:30] [DOC[vscode]] engine/routing.py — route_time — Visual Studio Code
[10:22:11] [APP] VS Code closed (67m session).
[10:22:11] [DOC[word]] Changed: Documents/exec-summary.docx
[10:45:00] [DOC[gdocs]] JPods Executive Summary - Google Docs
[11:00:00] [CAL] Upcoming: 14:00 Board call — Google Meet
```

These lines are what `harvest.py` reads to build the daily summary.

### Inbox — `inbox/YYYY-MM-DD-HHMMSS-whatsapp-summary.md`
Written by `allie-whatsapp-bridge.py` when run. Contains action items and priority messages.
Allie reads inbox files at session start.

---

## How Allie Uses This at Session Start

At session start, `harvest.py` reads the activity log and produces `today/YYYY-MM-DD-harvest.md`.
Allie reads the harvest. Key things she surfaces:

1. **What was being worked on** — "You spent 2h in VS Code on `engine/routing.py`"
2. **What documents were open** — "Google Docs: JPods executive summary was active for 45m"
3. **What meetings happened** — from Calendar events in the log
4. **Email context** — from `gmail-highlights.py` output
5. **WhatsApp/Messenger** — duration + action items from inbox summary (when bridge is running)

---

## What's NOT Observable (Messenger limitation)

Facebook Messenger has no API for reading message content from desktop apps.
Allie can detect when Messenger is open and log duration. She cannot read messages.

If messages from Messenger need to be in Allie's context, the options are:
1. **Manual** — copy/paste the relevant message into the session log
2. **Forward to email** — Messenger allows forwarding to Gmail; Allie reads Gmail
3. **Switch to WhatsApp** — the WhatsApp bridge gives Allie message-level visibility

---

## Setup Required for Full Coverage

### Google Drive API (for Google Docs change tracking)
The `allie-gdrive-watch.py` script needs OAuth credentials. It uses the same Google Cloud project
as `gmail-highlights.py`.

**One-time steps:**
1. In Google Cloud Console, edit your existing OAuth client (the one used for Gmail)
2. Add scope: `https://www.googleapis.com/auth/drive.metadata.readonly`
3. Download the updated credentials JSON → save as `~/Allie/credentials/gdrive_credentials.json`
4. Run: `python3 /Users/williamjames/Allie/scripts/allie-gdrive-watch.py --setup`
   A browser window opens — approve access.
5. Test: `python3 /Users/williamjames/Allie/scripts/allie-gdrive-watch.py`

**What it shows:**
- Every Google Doc, Sheet, or Slide modified in the last 24 hours
- Filename + modification time
- Allie logs this to the activity log automatically

### Gmail API
Follow the instructions in `readmes/google-integration.md` Part 2.
After setup: `python3 /Users/williamjames/Allie/scripts/gmail-highlights.py --setup`

### gcalcli (Google Calendar)
```bash
brew install gcalcli
gcalcli init
```
The watcher already polls gcalcli every hour once it's installed.

### WhatsApp Bridge
See `scripts/allie-whatsapp-bridge.py` header for full setup instructions.

**Summary:**
```bash
pip3 install webwhatsapp-py --break-system-packages
python3 /Users/williamjames/Allie/scripts/allie-whatsapp-bridge.py --setup
```
Scan the QR code with your phone. Session is cached — no QR needed after first time.

Run on demand (not as a background service yet):
```bash
python3 /Users/williamjames/Allie/scripts/allie-whatsapp-bridge.py
```
Output written to `~/Allie/inbox/`.

---

## App Skills Allie Develops from Observation

As Allie accumulates activity log data, she can answer questions at session start:

| Question | Source |
|----------|--------|
| "What was I working on yesterday?" | activity log + harvest |
| "Which Google Doc was I editing last?" | DOC[gdocs] entries in log |
| "How long was I in Affinity?" | APP entries with timestamps |
| "What files changed in Word?" | DOC[word] + fswatch entries |
| "Are there any emails that need replies?" | gmail-highlights.py output |
| "What meetings are today?" | gcalcli in watcher |
| "Did anyone send me an action item on WhatsApp?" | whatsapp bridge inbox summary |

The harvest.py script (`scripts/harvest.py`) reads all of these and synthesizes them into
`today/YYYY-MM-DD-harvest.md`, which is the primary session-start briefing document.

---

## Files Changed by This System

```
scripts/watcher.sh                          — enhanced with 8 new apps + active doc queries
scripts/allie-gdrive-watch.py               — new: Google Drive changes observer
scripts/allie-whatsapp-bridge.py            — new: WhatsApp message bridge (setup required)
readmes/34-allie-app-observation.md         — this file
```

---

## Next Step Skills (once observation is running)

1. **harvest.py enhancement** — have harvest.py call deepseek-r1:8b to write one paragraph
   about what Bill was doing across all apps since last session, not just a raw log summary.
2. **Cross-app correlation** — "You were in Gmail for 20 min, then opened Word — likely drafting
   a response." Allie learns these patterns over sessions.
3. **Document content extraction** — when a .docx file changes, extract the text with `python-docx`
   and write a short summary to the activity log (not the full content).
4. **Google Docs content** — Drive API v3 exports document content as plain text for summarization.

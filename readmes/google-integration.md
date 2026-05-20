# Google Integration — Calendar + Gmail
**For:** Allie daily brief system
**Last updated:** 2026-04-20

This file covers two integrations:
1. **Google Calendar** → `gcalcli` (CLI tool, OAuth)
2. **Gmail** → Python script using Gmail API (OAuth)

Both authenticate as Bill. Credentials live on the Allie drive only, never in git.

---

## Part 1 — Google Calendar via gcalcli

### Install
```bash
brew install gcalcli
```

### Authenticate
```bash
gcalcli init
```
A browser window opens. Sign in as Bill's Google account. Grant Calendar read access.
Credentials are stored at `~/.gcalcli_oauth` on this Mac.

### Test
```bash
gcalcli agenda today tomorrow --nocolor
```
If you see today's events, it's working.

### What the daily brief script uses
```bash
gcalcli agenda "2026-04-20T00:00" "2026-04-20T23:59" --nocolor --nodeclined
```
`--nodeclined` skips events Bill has declined (keeps the brief clean).

### Calendars shown
By default, all calendars associated with the Google account are shown.
To show only specific calendars:
```bash
gcalcli agenda --cal "Bill James" --cal "JPods" today tomorrow
```
Run `gcalcli list` to see all calendar names.

---

## Part 2 — Gmail Highlights via Python + Gmail API

### Why not gcalcli for email
gcalcli is Calendar only. Gmail requires the Gmail API with OAuth 2.0.

### One-time setup

**Step 1 — Enable Gmail API in Google Cloud Console**
1. Go to https://console.cloud.google.com
2. Create a project (or use an existing one — "Allie" is a good name)
3. Enable: APIs & Services → Library → search "Gmail API" → Enable
4. Create credentials: APIs & Services → Credentials → + Create Credentials → OAuth client ID
5. Application type: Desktop app
6. Download the JSON file → save as `/Volumes/Allie/credentials/gmail_credentials.json`

**Step 2 — Install Python dependencies**
```bash
pip3 install --upgrade google-auth-oauthlib google-auth-httplib2 google-api-python-client
```

**Step 3 — First run (opens browser for consent)**
```bash
python3 /Volumes/Allie/scripts/gmail-highlights.py --setup
```
This creates `/Volumes/Allie/credentials/gmail_token.json` — the cached token.
After the first run, the script is non-interactive.

### What the Gmail script does
- Pulls the last 24 hours of email (or since yesterday's brief, whichever is shorter)
- Filters to: unread, or read-but-starred, or from domains Bill cares about
- Produces a short summary block:
  ```
  | From | Subject | Action |
  ```
- Injects it into the `## Email Highlights` section of today's brief

### Security
- `gmail_credentials.json` and `gmail_token.json` live in `/Volumes/Allie/credentials/`
- Both are in `.gitignore` on the Allie drive — they never commit
- Read-only scope: `https://www.googleapis.com/auth/gmail.readonly`
- No email content is stored. Only From, Subject, and a one-line action note.

---

## Part 3 — Meeting Notes

Meeting notes are manual. During or after each meeting, append to the `## Meeting Notes`
section of today's brief:

```markdown
## 10:30 — [Meeting title]
**Attendees:** [names]
**Key decisions:**
- 
**Action items:**
- [ ] [what] — [who] — [by when]
```

Allie reads this section at session start and carries action items forward into the
session's **Next** list if they are Bill's to complete.

---

## Running the Daily Brief

```bash
/Volumes/Allie/scripts/daily-brief.sh
```

Run this at the start of each day, or any time during the day to refresh the calendar section.
The script creates the brief file if it does not exist, injects the calendar block, and calls
the Gmail highlights script if it is configured.

---

---

## Part 4 — Google Drive (Document Change Observer)

Allie uses `scripts/allie-gdrive-watch.py` to list which Google Docs, Sheets, and Slides
were modified in the last 24 hours. This tells Allie what Bill was writing without reading content.

### Setup

Uses the **same OAuth client** as Gmail. Just add the Drive scope.

**Step 1 — Add Drive scope to existing OAuth app**
1. Google Cloud Console → APIs & Services → Credentials
2. Edit your existing Desktop OAuth client
3. Add scope: `https://www.googleapis.com/auth/drive.metadata.readonly`
4. Download the updated JSON → save as `~/Allie/credentials/gdrive_credentials.json`

**Step 2 — Authenticate**
```bash
python3 /Users/williamjames/Allie/scripts/allie-gdrive-watch.py --setup
```
Token saved to `~/Allie/credentials/gdrive_token.json`.

**Step 3 — Test**
```bash
python3 /Users/williamjames/Allie/scripts/allie-gdrive-watch.py
```
Lists all Google Docs/Sheets/Slides modified in the last 24 hours.

**Note:** Drive scope is metadata-only — Allie sees filename and modification time.
She does not read document content through this API.

---

## Status Tracking

| Integration | Status | Notes |
|-------------|--------|-------|
| gcalcli (Calendar) | Needs install + auth | `brew install gcalcli` then `gcalcli init` |
| Gmail API | Needs OAuth setup | See Part 2 above |
| Google Drive API | Needs OAuth setup | See Part 4 above — same project as Gmail |
| Meeting notes | Ready | Manual — append to today's brief |

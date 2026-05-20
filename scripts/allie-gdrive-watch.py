#!/usr/bin/env python3
"""
allie-gdrive-watch.py — Google Drive recent changes observer

Lists Google Docs, Sheets, and Slides modified in the last N hours.
Writes a summary to today's activity log and optionally to the daily brief.

Requires:
  pip3 install --upgrade google-auth-oauthlib google-auth-httplib2 google-api-python-client
  Credentials: ~/Allie/credentials/gdrive_credentials.json (same OAuth app as Gmail)
  Token:       ~/Allie/credentials/gdrive_token.json (created on first run)

Usage:
  python3 allie-gdrive-watch.py                  # list changes in last 24h
  python3 allie-gdrive-watch.py --hours 48       # look back 48 hours
  python3 allie-gdrive-watch.py --setup          # first-run OAuth
  python3 allie-gdrive-watch.py --brief FILE.md  # inject into daily brief

OAuth scopes needed:
  https://www.googleapis.com/auth/drive.metadata.readonly
  (read-only metadata — file names and modification times only; no content access)

Note: Uses the SAME Google Cloud project and OAuth client as gmail-highlights.py.
Add drive.metadata.readonly to the existing OAuth app in Google Cloud Console,
then re-run --setup to get a new token with both scopes.
"""

import sys
import json
import pathlib
import datetime
import argparse

ALLIE       = pathlib.Path("/Users/williamjames/Allie")
CREDS_FILE  = ALLIE / "credentials" / "gdrive_credentials.json"
TOKEN_FILE  = ALLIE / "credentials" / "gdrive_token.json"
LOG_DIR     = ALLIE / "today"
AGENT_LOG   = ALLIE / "config" / "agent_log.jsonl"

SCOPES = ["https://www.googleapis.com/auth/drive.metadata.readonly"]

# File types Allie cares about
MIME_LABELS = {
    "application/vnd.google-apps.document":     "Google Doc",
    "application/vnd.google-apps.spreadsheet":  "Google Sheet",
    "application/vnd.google-apps.presentation": "Google Slides",
    "application/vnd.google-apps.form":         "Google Form",
    "application/pdf":                           "PDF",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "Word Doc",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":       "Excel",
}


# ── Auth ──────────────────────────────────────────────────────────────────────

def get_credentials():
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from google.auth.transport.requests import Request

    creds = None
    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not CREDS_FILE.exists():
                print(f"ERROR: {CREDS_FILE} not found.")
                print("Download from Google Cloud Console → APIs → Credentials → OAuth client (Desktop app)")
                print("Save as: ~/Allie/credentials/gdrive_credentials.json")
                sys.exit(1)
            flow = InstalledAppFlow.from_client_secrets_file(str(CREDS_FILE), SCOPES)
            creds = flow.run_local_server(port=0)
        TOKEN_FILE.write_text(creds.to_json())
        TOKEN_FILE.chmod(0o600)
        print(f"Token saved: {TOKEN_FILE}")
    return creds


# ── Drive query ───────────────────────────────────────────────────────────────

def list_recent_changes(service, hours_back: int = 24) -> list:
    """List files modified in the last N hours. Returns list of dicts."""
    cutoff = datetime.datetime.utcnow() - datetime.timedelta(hours=hours_back)
    cutoff_str = cutoff.strftime("%Y-%m-%dT%H:%M:%SZ")

    results = []
    page_token = None

    while True:
        try:
            params = {
                "q": (
                    f"modifiedTime > '{cutoff_str}' "
                    f"and trashed = false "
                    f"and ("
                    + " or ".join(f"mimeType = '{m}'" for m in MIME_LABELS)
                    + ")"
                ),
                "fields": "nextPageToken, files(id, name, mimeType, modifiedTime, owners)",
                "orderBy": "modifiedTime desc",
                "pageSize": 50,
            }
            if page_token:
                params["pageToken"] = page_token

            response = service.files().list(**params).execute()
            results.extend(response.get("files", []))
            page_token = response.get("nextPageToken")
            if not page_token:
                break
        except Exception as e:
            print(f"Drive API error: {e}", file=sys.stderr)
            break

    return results


# ── Format ────────────────────────────────────────────────────────────────────

def format_report(files: list, hours_back: int) -> str:
    if not files:
        return f"_No Google Drive documents modified in the last {hours_back} hours._"

    lines = [
        f"### Google Drive — {len(files)} documents changed (last {hours_back}h)",
        "",
        "| Type | Document | Modified |",
        "|------|----------|----------|",
    ]
    for f in files:
        label    = MIME_LABELS.get(f.get("mimeType", ""), f.get("mimeType", ""))
        name     = f.get("name", "(unnamed)")[:60]
        modified = f.get("modifiedTime", "")[:16].replace("T", " ")
        lines.append(f"| {label} | {name} | {modified} |")

    return "\n".join(lines)


# ── Activity log ──────────────────────────────────────────────────────────────

def write_activity_log(files: list):
    today = datetime.date.today().isoformat()
    log_path = LOG_DIR / f"{today}-activity.log"
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.datetime.now().strftime("%H:%M:%S")
    with log_path.open("a") as f:
        for doc in files:
            label    = MIME_LABELS.get(doc.get("mimeType", ""), "file")
            name     = doc.get("name", "(unnamed)")
            modified = doc.get("modifiedTime", "")[:16].replace("T", " ")
            f.write(f"[{ts}] [DOC[gdrive]] {label}: {name} (modified {modified})\n")


def log_event(files_count: int):
    import time
    entry = {
        "ts": datetime.datetime.now().isoformat(timespec="seconds"),
        "event": "allie-gdrive-watch",
        "files_found": files_count,
    }
    AGENT_LOG.parent.mkdir(parents=True, exist_ok=True)
    with AGENT_LOG.open("a") as f:
        f.write(json.dumps(entry) + "\n")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Google Drive recent changes observer")
    parser.add_argument("--setup",   action="store_true", help="First-run OAuth setup")
    parser.add_argument("--hours",   type=int, default=24, help="Look back N hours (default 24)")
    parser.add_argument("--brief",   default=None, help="Inject into daily brief file")
    parser.add_argument("--no-log",  action="store_true", help="Skip activity log write")
    args = parser.parse_args()

    if args.setup:
        get_credentials()
        print("OAuth setup complete. Token saved to ~/Allie/credentials/gdrive_token.json")
        return

    try:
        from googleapiclient.discovery import build
    except ImportError:
        print("ERROR: google-api-python-client not installed.")
        print("Run: pip3 install --upgrade google-auth-oauthlib google-auth-httplib2 google-api-python-client --break-system-packages")
        sys.exit(1)

    creds   = get_credentials()
    service = build("drive", "v3", credentials=creds)

    files   = list_recent_changes(service, hours_back=args.hours)
    report  = format_report(files, hours_back=args.hours)

    if not args.no_log:
        write_activity_log(files)
    log_event(len(files))

    if args.brief:
        brief_path = pathlib.Path(args.brief)
        if brief_path.exists():
            content = brief_path.read_text()
            marker = "## Google Drive"
            section = f"## Google Drive\n\n{report}\n\n"
            if marker in content:
                idx = content.index(marker)
                end = content.find("\n## ", idx + 1)
                content = content[:idx] + section + (content[end:] if end != -1 else "")
            else:
                content += f"\n\n{section}"
            brief_path.write_text(content)
            print(f"Brief updated: {brief_path}")
        else:
            print(f"Brief file not found: {brief_path}")
    else:
        print(report)


if __name__ == "__main__":
    main()

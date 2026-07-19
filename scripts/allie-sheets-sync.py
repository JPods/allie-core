#!/usr/bin/env python3
"""
allie-sheets-sync.py — Alice ↔ Google Sheets bridge for MOA-2026

Pushes WC3 Action records (by keyword) to a Google Sheet.
Reads changes from the sheet and syncs back to WC3.

Usage:
    python3 allie-sheets-sync.py --push          # WC3 → Sheet (initial load or refresh)
    python3 allie-sheets-sync.py --pull           # Sheet → WC3 (pick up team edits)
    python3 allie-sheets-sync.py --auth           # Run OAuth flow for Sheets scope

Requires:
    pip install gspread google-auth google-auth-oauthlib

Config:
    SHEET_ID and KEYWORD are set below. Credentials at ~/Allie/credentials/.
"""

import argparse
import csv
import json
import os
import sys
import time
from pathlib import Path

# ---------- Config ----------
SHEET_ID = '1xasXHok0uAc02Q0EPt5TzRZaVx6fmP9UJ4rFNBtwmuA'
KEYWORD = 'MOA-2026'
CREDENTIALS_DIR = Path.home() / 'Allie' / 'credentials'
CLIENT_SECRET = CREDENTIALS_DIR / 'client_secret_1066130554003-4fokk3g13p86f7kc6ih47a6rdk0tnefm.apps.googleusercontent.com.json'
SHEETS_TOKEN = CREDENTIALS_DIR / 'sheets_token.json'
CSV_PATH = Path.home() / 'Allie' / 'readmes' / 'capital-pages' / 'MOA-2026-tasks.csv'

SCOPES = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive',
]

HEADER = ['ID', 'Task', 'Owner', 'Priority', 'Status', 'Duration Estimate',
          'Dependencies', 'Category', 'Notes']


def authenticate():
    """Run OAuth flow and save token for Sheets/Drive access."""
    from google_auth_oauthlib.flow import InstalledAppFlow

    print(f"Starting OAuth flow for Google Sheets...")
    print(f"Client secret: {CLIENT_SECRET}")

    flow = InstalledAppFlow.from_client_secrets_file(str(CLIENT_SECRET), SCOPES)
    creds = flow.run_local_server(port=0)

    token_data = {
        'token': creds.token,
        'refresh_token': creds.refresh_token,
        'token_uri': creds.token_uri,
        'client_id': creds.client_id,
        'client_secret': creds.client_secret,
        'scopes': list(creds.scopes),
        'expiry': creds.expiry.isoformat() if creds.expiry else None,
    }
    SHEETS_TOKEN.write_text(json.dumps(token_data, indent=2))
    print(f"Token saved to {SHEETS_TOKEN}")
    return creds


def get_creds():
    """Load or refresh Google credentials."""
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import Request

    if not SHEETS_TOKEN.exists():
        print("No sheets token found. Run: python3 allie-sheets-sync.py --auth")
        sys.exit(1)

    token_data = json.loads(SHEETS_TOKEN.read_text())
    creds = Credentials(
        token=token_data.get('token'),
        refresh_token=token_data.get('refresh_token'),
        token_uri=token_data.get('token_uri'),
        client_id=token_data.get('client_id'),
        client_secret=token_data.get('client_secret'),
        scopes=token_data.get('scopes'),
    )

    if creds.expired and creds.refresh_token:
        creds.refresh(Request())
        token_data['token'] = creds.token
        token_data['expiry'] = creds.expiry.isoformat() if creds.expiry else None
        SHEETS_TOKEN.write_text(json.dumps(token_data, indent=2))

    return creds


def push_to_sheet():
    """Push CSV data to Google Sheet."""
    import gspread

    creds = get_creds()
    gc = gspread.authorize(creds)
    sh = gc.open_by_key(SHEET_ID)

    # Use first worksheet or create one
    try:
        ws = sh.worksheet('MOA-2026 Actions')
    except gspread.exceptions.WorksheetNotFound:
        ws = sh.add_worksheet(title='MOA-2026 Actions', rows=50, cols=len(HEADER))

    # Read CSV
    if not CSV_PATH.exists():
        print(f"CSV not found: {CSV_PATH}")
        sys.exit(1)

    with open(CSV_PATH, 'r') as f:
        reader = csv.reader(f)
        rows = list(reader)

    # Clear and write
    ws.clear()
    ws.update(range_name='A1', values=rows)

    # Format header row bold
    ws.format('A1:I1', {'textFormat': {'bold': True}})

    print(f"Pushed {len(rows)-1} actions to sheet '{ws.title}'")
    print(f"Sheet URL: https://docs.google.com/spreadsheets/d/{SHEET_ID}")


def pull_from_sheet():
    """Read sheet and report changes vs CSV."""
    import gspread

    creds = get_creds()
    gc = gspread.authorize(creds)
    sh = gc.open_by_key(SHEET_ID)

    try:
        ws = sh.worksheet('MOA-2026 Actions')
    except gspread.exceptions.WorksheetNotFound:
        print("Worksheet 'MOA-2026 Actions' not found. Run --push first.")
        sys.exit(1)

    rows = ws.get_all_records()

    # Load current CSV for comparison
    current = {}
    if CSV_PATH.exists():
        with open(CSV_PATH, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                current[row['ID']] = row

    # Diff
    changes = []
    new_rows = []
    for row in rows:
        rid = row.get('ID', '')
        if not rid:
            continue
        if rid in current:
            for field in HEADER:
                old_val = current[rid].get(field, '')
                new_val = str(row.get(field, ''))
                if old_val != new_val:
                    changes.append({
                        'id': rid,
                        'field': field,
                        'old': old_val,
                        'new': new_val,
                    })
        else:
            new_rows.append(row)

    if changes:
        print(f"\n{len(changes)} field changes detected:")
        for c in changes:
            print(f"  {c['id']}.{c['field']}: '{c['old']}' → '{c['new']}'")
    else:
        print("No changes to existing actions.")

    if new_rows:
        print(f"\n{len(new_rows)} new rows added in sheet:")
        for r in new_rows:
            print(f"  {r.get('ID', '???')}: {r.get('Task', '???')}")

    # Update CSV with sheet data
    if changes or new_rows:
        with open(CSV_PATH, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=HEADER)
            writer.writeheader()
            for row in rows:
                if row.get('ID'):
                    writer.writerow({k: row.get(k, '') for k in HEADER})
        print(f"\nCSV updated: {CSV_PATH}")

        # Write changes to Alice's inbox
        _notify_alice(changes, new_rows)

    return changes, new_rows


def _notify_alice(changes, new_rows):
    """Send changes to Alice via allie-capture."""
    capture = Path.home() / 'Allie' / 'scripts' / 'allie-capture.py'
    if not capture.exists():
        return

    import subprocess
    summary_parts = []
    if changes:
        summary_parts.append(f"{len(changes)} field changes")
    if new_rows:
        summary_parts.append(f"{len(new_rows)} new actions")
    summary = f"MOA-2026 Sheet sync: {', '.join(summary_parts)}"

    data = {
        'keyword': KEYWORD,
        'sheet_id': SHEET_ID,
        'changes': changes[:20],
        'new_rows': [r.get('ID', '') for r in new_rows],
    }

    try:
        args = ['python3', str(capture), '--source', 'SYS',
                '--event', 'sheet_sync', '--message', summary[:200],
                '--data', json.dumps(data)]
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def main():
    parser = argparse.ArgumentParser(description='Alice ↔ Google Sheets sync for MOA-2026')
    parser.add_argument('--auth', action='store_true', help='Run OAuth flow')
    parser.add_argument('--push', action='store_true', help='Push CSV → Sheet')
    parser.add_argument('--pull', action='store_true', help='Pull Sheet → CSV + notify Alice')
    args = parser.parse_args()

    if args.auth:
        authenticate()
    elif args.push:
        push_to_sheet()
    elif args.pull:
        pull_from_sheet()
    else:
        parser.print_help()


if __name__ == '__main__':
    main()

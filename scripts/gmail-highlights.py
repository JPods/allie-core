#!/usr/bin/env python3
"""
gmail-highlights.py
Reads Gmail across all five categories, logs Primary activity,
and surfaces important items from Promotions/Social/Updates/Forums.

Usage:
  python3 gmail-highlights.py --setup          first-run OAuth
  python3 gmail-highlights.py                  print summary to stdout
  python3 gmail-highlights.py BRIEF.md         inject into daily brief

Credentials: ~/Allie/credentials/ (internal primary, 5TB fallback)
"""

import sys, pathlib, datetime

# ── Credential paths — internal primary, 5TB fallback ─────────────────────────

def find_cred(filename):
    for root in [pathlib.Path.home() / "Allie", pathlib.Path("/Users/williamjames/Allie")]:
        p = root / "credentials" / filename
        if p.exists() and p.stat().st_size > 0:
            return p
    return pathlib.Path.home() / "Allie" / "credentials" / filename

CREDS_FILE = find_cred("gmail_credentials.json")
TOKEN_FILE  = find_cred("gmail_token.json")
SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]

# ── What "important" means for low-priority categories ────────────────────────

PRIORITY_DOMAINS = [
    "jpods.com", "webclerk.com", "dividedsovereignty.com",
    "reportof2026.com", "dynamiccatalogs.com", "mycarryon.io",
    "postroads.com", "github.com",
]

ALERT_KEYWORDS = [
    "invoice", "payment", "urgent", "deadline", "expires", "expiring",
    "renewal", "renew", "action required", "security alert",
    "suspended", "breach", "lawsuit", "subpoena",
    "congress", "legislature", "senator", "governor",
    "bill james", "jpods", "webclerk",
]

CATEGORIES = {
    "promotions": "CATEGORY_PROMOTIONS",
    "social":     "CATEGORY_SOCIAL",
    "updates":    "CATEGORY_UPDATES",
    "forums":     "CATEGORY_FORUMS",
}

HOURS_BACK = 24


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
                print(f"ERROR: credentials not found at {CREDS_FILE}")
                sys.exit(1)
            flow = InstalledAppFlow.from_client_secrets_file(str(CREDS_FILE), SCOPES)
            creds = flow.run_local_server(port=0)
        token_path = pathlib.Path.home() / "Allie" / "credentials" / "gmail_token.json"
        token_path.write_text(creds.to_json())
        backup = pathlib.Path("/Users/williamjames/Allie/credentials/gmail_token.json")
        if backup.parent.exists():
            backup.write_text(creds.to_json())
    return creds


# ── Gmail helpers ─────────────────────────────────────────────────────────────

def fetch_messages(service, label, max_results=50):
    cutoff = datetime.datetime.utcnow() - datetime.timedelta(hours=HOURS_BACK)
    after_ts = int(cutoff.timestamp())
    try:
        results = service.users().messages().list(
            userId="me", labelIds=[label],
            q=f"after:{after_ts}", maxResults=max_results
        ).execute()
    except Exception as e:
        return [], str(e)
    full = []
    for ref in results.get("messages", []):
        try:
            m = service.users().messages().get(
                userId="me", id=ref["id"], format="metadata",
                metadataHeaders=["From", "Subject", "Date"]
            ).execute()
            h = {x["name"]: x["value"] for x in m["payload"]["headers"]}
            full.append({
                "from":    h.get("From", "—"),
                "subject": h.get("Subject", "(no subject)"),
                "unread":  "UNREAD" in m.get("labelIds", []),
                "starred": "STARRED" in m.get("labelIds", []),
            })
        except Exception:
            continue
    return full, None


def fetch_sent(service, max_results=10):
    cutoff = datetime.datetime.utcnow() - datetime.timedelta(hours=HOURS_BACK)
    after_ts = int(cutoff.timestamp())
    try:
        results = service.users().messages().list(
            userId="me", labelIds=["SENT"],
            q=f"after:{after_ts}", maxResults=max_results
        ).execute()
    except Exception:
        return []
    sent = []
    for ref in results.get("messages", []):
        try:
            m = service.users().messages().get(
                userId="me", id=ref["id"], format="metadata",
                metadataHeaders=["To", "Subject"]
            ).execute()
            h = {x["name"]: x["value"] for x in m["payload"]["headers"]}
            sent.append({"to": h.get("To", "—"), "subject": h.get("Subject", "(no subject)")})
        except Exception:
            continue
    return sent


def is_important(msg):
    sender  = msg["from"].lower()
    subject = msg["subject"].lower()
    for domain in PRIORITY_DOMAINS:
        if domain in sender:
            return True, f"known domain ({domain})"
    # Keywords checked on subject only — avoids flagging on sender display names
    for kw in ALERT_KEYWORDS:
        if kw in subject:
            return True, f"keyword: {kw}"
    if msg["starred"]:
        return True, "starred"
    return False, ""


def trunc(s, n):
    return s[:n] + "..." if len(s) > n else s


# ── Formatters ────────────────────────────────────────────────────────────────

def format_primary(msgs, sent):
    lines = ["### Primary Inbox"]
    unread = [m for m in msgs if m["unread"]]
    read   = [m for m in msgs if not m["unread"]]

    if unread:
        lines += [f"\n**Unread ({len(unread)}):**\n",
                  "| From | Subject |", "|------|---------|"]
        for m in unread:
            lines.append(f"| {trunc(m['from'],45)} | {trunc(m['subject'],60)} |")

    if read:
        lines += [f"\n**Read ({len(read)}):**\n",
                  "| From | Subject |", "|------|---------|"]
        for m in read:
            lines.append(f"| {trunc(m['from'],45)} | {trunc(m['subject'],60)} |")

    if sent:
        lines += [f"\n**Sent ({len(sent)}) — Bill's actions:**\n",
                  "| To | Subject |", "|----|---------|"]
        for m in sent:
            lines.append(f"| {trunc(m['to'],45)} | {trunc(m['subject'],60)} |")

    if not msgs and not sent:
        lines.append("_No activity in the last 24 hours._")
    return "\n".join(lines)


def format_category(name, msgs):
    alerts = [(m, r) for m in msgs for ok, r in [is_important(m)] if ok]
    lines = [f"### {name.title()} — {len(msgs)} messages, {len(alerts)} flagged"]
    if alerts:
        lines += ["\n**Flagged:**\n", "| Reason | From | Subject |",
                  "|--------|------|---------|"]
        for m, reason in alerts:
            lines.append(f"| {reason} | {trunc(m['from'],38)} | {trunc(m['subject'],52)} |")
    else:
        lines.append("_Nothing flagged._")
    return "\n".join(lines)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    if "--setup" in sys.argv:
        get_credentials()
        print("OAuth setup complete.")
        return

    from googleapiclient.discovery import build
    service = build("gmail", "v1", credentials=get_credentials())

    sections = []
    primary_msgs, _ = fetch_messages(service, "INBOX")
    sent_msgs = fetch_sent(service)
    sections.append(format_primary(primary_msgs, sent_msgs))

    for cat, label in CATEGORIES.items():
        msgs, _ = fetch_messages(service, label)
        sections.append(format_category(cat, msgs))

    output = "\n\n".join(sections)

    brief_path = next((pathlib.Path(a) for a in sys.argv[1:]
                       if a.endswith(".md") and pathlib.Path(a).exists()), None)

    if brief_path:
        content = brief_path.read_text()
        marker = "## Email"
        new_section = f"## Email\n\n{output}\n\n"
        if marker in content:
            idx = content.index(marker)
            end = content.find("\n## ", idx + 1)
            content = content[:idx] + new_section + (content[end:] if end != -1 else "")
        else:
            content += f"\n\n{new_section}"
        brief_path.write_text(content)
        print(f"Brief updated: {brief_path}")
    else:
        print(output)


if __name__ == "__main__":
    main()

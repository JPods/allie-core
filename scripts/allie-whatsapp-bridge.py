#!/usr/bin/env python3
"""
allie-whatsapp-bridge.py — WhatsApp message observer for Allie

Connects to WhatsApp Web (unofficial), scans recent messages, writes
a summary to Allie's inbox for the next session.

HOW IT WORKS:
  WhatsApp has no public API for reading personal messages.
  This bridge uses the `whatsapp-web.py` library, which controls a Chrome
  browser session connected to WhatsApp Web. Your phone must be on the
  same network and WhatsApp must be running on it.

  First run: a QR code appears in the terminal — scan it with your phone
  via WhatsApp → Settings → Linked Devices → Link a Device.
  After that, the session is cached and runs non-interactively.

SETUP:
  pip3 install webwhatsapp-py --break-system-packages
  # OR the more actively maintained:
  pip3 install selenium --break-system-packages
  brew install --cask chromedriver

  Session cache: ~/Allie/credentials/whatsapp_session/

IMPORTANT LIMITATIONS:
  - This is an unofficial library. WhatsApp may block or break it at any time.
  - Allie reads only: sender name, timestamp, message text (first 200 chars).
  - Allie does NOT store message content long-term. Summaries only.
  - Allie does NOT reply to messages via this bridge. Read-only.
  - Phone must be connected to internet for WhatsApp Web to work.

WHAT ALLIE DOES WITH MESSAGES:
  - Identifies messages that reference active JPods/WebClerk/Allie projects
  - Flags messages that look like action items (contain words like "need", "please", "by when", "can you")
  - Writes a summary to ~/Allie/inbox/YYYY-MM-DD-HHMMSS-whatsapp-summary.md
  - Logs the observation to config/agent_log.jsonl (no message content)

Usage:
  python3 allie-whatsapp-bridge.py --setup        # first-run QR scan
  python3 allie-whatsapp-bridge.py                # scan new messages, write inbox summary
  python3 allie-whatsapp-bridge.py --hours 12    # look back 12 hours (default 24)
  python3 allie-whatsapp-bridge.py --dry-run     # print what would be written, don't save

STATUS: This script is scaffolded but requires manual setup (QR scan + library install).
The bridge is NOT yet running as a LaunchAgent.
"""

import sys
import json
import pathlib
import datetime
import argparse

ALLIE       = pathlib.Path("/Users/williamjames/Allie")
INBOX_DIR   = ALLIE / "inbox"
SESSION_DIR = ALLIE / "credentials" / "whatsapp_session"
AGENT_LOG   = ALLIE / "config" / "agent_log.jsonl"
HOURS_BACK  = 24

# Keywords that suggest action items in messages
ACTION_KEYWORDS = [
    "need", "please", "can you", "could you", "by when", "deadline",
    "asap", "urgent", "send me", "let me know", "when can", "follow up",
    "jpods", "webclerk", "allie", "meeting", "call", "schedule",
]

# Contacts/groups Allie pays close attention to (add real names later)
PRIORITY_CONTACTS = []  # e.g., ["Family", "JPods Team", "Bill's phone"]


# ── Message scanner ───────────────────────────────────────────────────────────

def is_action_item(text: str) -> bool:
    t = text.lower()
    return any(kw in t for kw in ACTION_KEYWORDS)


def is_priority(sender: str) -> bool:
    return any(p.lower() in sender.lower() for p in PRIORITY_CONTACTS)


def scan_messages(hours_back: int = 24) -> list:
    """
    Placeholder for actual WhatsApp Web scanning.
    When the library is installed, this calls the browser session
    and returns a list of recent message dicts.

    Returns:
      [{"sender": str, "timestamp": str, "text": str, "is_group": bool}]
    """
    try:
        # Library import — will fail if not installed
        # from webwhatsapp import WhatsApp
        # wa = WhatsApp(session_path=str(SESSION_DIR))
        # messages = wa.get_recent_messages(hours=hours_back)
        # return messages
        raise ImportError("whatsapp-web library not installed")
    except ImportError:
        print("WhatsApp bridge library not installed.", file=sys.stderr)
        print("Run: pip3 install webwhatsapp-py --break-system-packages", file=sys.stderr)
        print("Or see setup instructions at the top of this script.", file=sys.stderr)
        return []


# ── Summary writer ────────────────────────────────────────────────────────────

def write_inbox_summary(messages: list, hours_back: int, dry_run: bool = False) -> str:
    ts = datetime.datetime.now()
    ts_str = ts.strftime("%Y-%m-%d-%H%M%S")
    cutoff_str = (ts - datetime.timedelta(hours=hours_back)).strftime("%Y-%m-%d %H:%M")

    action_items = [m for m in messages if is_action_item(m.get("text", ""))]
    priority     = [m for m in messages if is_priority(m.get("sender", ""))]

    content = f"""# WhatsApp Summary — {ts.strftime("%Y-%m-%d %H:%M")}
**From:** allie-whatsapp-bridge
**Domain:** communications
**Priority:** {"high" if action_items or priority else "normal"}
**Covers:** {cutoff_str} → now ({len(messages)} messages)

## Action Items Found ({len(action_items)})

"""
    for m in action_items:
        content += f"- **{m.get('sender','?')}** [{m.get('timestamp','')}]: {m.get('text','')[:200]}\n"
    if not action_items:
        content += "_No action items detected._\n"

    content += f"""
## Priority Contacts ({len(priority)})

"""
    for m in priority:
        content += f"- **{m.get('sender','?')}** [{m.get('timestamp','')}]: {m.get('text','')[:200]}\n"
    if not priority:
        content += "_No messages from priority contacts._\n"

    content += f"""
## All Messages ({len(messages)})

| Sender | Time | Preview |
|--------|------|---------|
"""
    for m in messages[:30]:  # cap at 30
        preview = m.get("text", "")[:60].replace("|", "/")
        content += f"| {m.get('sender','?')} | {m.get('timestamp','')} | {preview} |\n"

    content += "\n## What Claude should do\n\nReview action items. Flag any that involve Bill's projects or require a response.\n"

    if dry_run:
        print(content)
        return ""

    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    out_path = INBOX_DIR / f"{ts_str}-whatsapp-summary.md"
    out_path.write_text(content)
    return str(out_path)


def log_event(messages_count: int, action_count: int):
    entry = {
        "ts": datetime.datetime.now().isoformat(timespec="seconds"),
        "event": "allie-whatsapp-bridge",
        "messages_scanned": messages_count,
        "action_items": action_count,
    }
    AGENT_LOG.parent.mkdir(parents=True, exist_ok=True)
    with AGENT_LOG.open("a") as f:
        f.write(json.dumps(entry) + "\n")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="WhatsApp message observer for Allie")
    parser.add_argument("--setup",   action="store_true", help="First-run QR code scan")
    parser.add_argument("--hours",   type=int, default=HOURS_BACK)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.setup:
        print("WhatsApp Web setup:")
        print("1. Install: pip3 install webwhatsapp-py --break-system-packages")
        print("2. Run this script again — a QR code will appear")
        print("3. On your phone: WhatsApp → Settings → Linked Devices → Link a Device")
        print("4. Scan the QR code")
        print(f"5. Session cached at: {SESSION_DIR}")
        print()
        print("After setup, run without --setup to scan messages.")
        return

    messages = scan_messages(hours_back=args.hours)

    if not messages:
        print("No messages retrieved (library not installed or no new messages).")
        log_event(0, 0)
        return

    action_items = [m for m in messages if is_action_item(m.get("text", ""))]
    out_path = write_inbox_summary(messages, args.hours, dry_run=args.dry_run)

    if out_path:
        print(f"Inbox summary written: {out_path}")
        print(f"Messages scanned: {len(messages)}, Action items: {len(action_items)}")

    log_event(len(messages), len(action_items))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
flight-log.py — Session flight recorder (black box)

Continuously appends tfts, lessons, insights, decisions, and observations
during a session. Sloppy is fine — excess data is cheap insurance.

At rightshoe (clean shutdown): log is cleared because lessons were
properly captured in handoff/retrospection.

On crash (no rightshoe): log survives. At next leftshoe, lessons are
extracted from the log before clearing.

Usage:
  # Append an entry during a session
  python3 flight-log.py log --source claude --type tfts --text "The bezier copies itself in two files"
  python3 flight-log.py log --source allie --type insight --text "Pattern: same bug in SU and Physical"
  python3 flight-log.py log --source claude --type decision --text "Using is_complete to cancel backlog"
  python3 flight-log.py log --source bill --type lesson --text "Post item ida, not prices"

  # Check if crash log exists (called at leftshoe)
  python3 flight-log.py check

  # Extract lessons from crash log (called at leftshoe if check finds one)
  python3 flight-log.py recover

  # Clear the log (called at rightshoe after proper handoff)
  python3 flight-log.py clear

Entry types: tfts, lesson, insight, decision, observation, fault, scar, question
"""

import sys
import json
import datetime
import pathlib
import argparse

ALLIE = pathlib.Path.home() / "Allie"
LOG_PATH = ALLIE / "today" / "session-flight-log.jsonl"
RECOVERED_DIR = ALLIE / "process" / "inbox"


def now_ts():
    return datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def log_entry(source: str, entry_type: str, text: str, context: str = ""):
    """Append an entry to the flight log."""
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    entry = {
        "ts": now_ts(),
        "source": source,
        "type": entry_type,
        "text": text,
    }
    if context:
        entry["context"] = context
    with open(LOG_PATH, "a") as f:
        f.write(json.dumps(entry) + "\n")
    print(f"[flight-log] {entry_type}: {text[:80]}")


def check():
    """Check if a crash log exists from a previous session."""
    if LOG_PATH.exists() and LOG_PATH.stat().st_size > 0:
        lines = LOG_PATH.read_text().strip().split("\n")
        count = len(lines)

        # Parse types
        types = {}
        for line in lines:
            try:
                entry = json.loads(line)
                t = entry.get("type", "unknown")
                types[t] = types.get(t, 0) + 1
            except json.JSONDecodeError:
                pass

        type_summary = ", ".join(f"{v} {k}" for k, v in sorted(types.items()))
        print(f"[flight-log] CRASH LOG FOUND: {count} entries ({type_summary})")
        print(f"[flight-log] Last session ended without rightshoe.")
        print(f"[flight-log] Run: python3 flight-log.py recover")
        return True
    else:
        print("[flight-log] No crash log. Clean startup.")
        return False


def recover():
    """Extract lessons from crash log and archive it."""
    if not LOG_PATH.exists() or LOG_PATH.stat().st_size == 0:
        print("[flight-log] Nothing to recover.")
        return

    lines = LOG_PATH.read_text().strip().split("\n")
    entries = []
    for line in lines:
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            pass

    if not entries:
        print("[flight-log] Log exists but no valid entries.")
        LOG_PATH.unlink()
        return

    # Group by type
    by_type = {}
    for e in entries:
        t = e.get("type", "unknown")
        by_type.setdefault(t, []).append(e)

    # Write recovery file to inbox for Allie's nightly to process
    RECOVERED_DIR.mkdir(parents=True, exist_ok=True)
    ts_file = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S')
    recovery_path = RECOVERED_DIR / f"{ts_file}-crash-recovery.md"

    lines_out = [
        f"# CRASH RECOVERY — {now_ts()}",
        f"",
        f"Recovered from unclean shutdown. {len(entries)} flight log entries.",
        f"",
    ]

    # Priority order: tfts > lesson > scar > insight > decision > observation > fault > question
    priority = ["tfts", "scar", "lesson", "insight", "decision", "fault", "observation", "question"]
    for t in priority:
        if t in by_type:
            lines_out.append(f"## {t.upper()} ({len(by_type[t])})")
            lines_out.append("")
            for e in by_type[t]:
                lines_out.append(f"- [{e.get('source', '?')} {e['ts']}] {e['text']}")
                if e.get("context"):
                    lines_out.append(f"  Context: {e['context']}")
            lines_out.append("")
            del by_type[t]

    # Any remaining types
    for t, items in by_type.items():
        lines_out.append(f"## {t.upper()} ({len(items)})")
        lines_out.append("")
        for e in items:
            lines_out.append(f"- [{e.get('source', '?')} {e['ts']}] {e['text']}")
        lines_out.append("")

    recovery_path.write_text("\n".join(lines_out))
    print(f"[flight-log] Recovered {len(entries)} entries to {recovery_path.name}")

    # Clear the log
    LOG_PATH.unlink()
    print("[flight-log] Crash log cleared.")


def clear():
    """Clear the flight log (called at rightshoe after proper handoff)."""
    if LOG_PATH.exists():
        LOG_PATH.unlink()
        print("[flight-log] Log cleared (rightshoe complete).")
    else:
        print("[flight-log] No log to clear.")


def main():
    parser = argparse.ArgumentParser(description="Session flight recorder")
    sub = parser.add_subparsers(dest="cmd")

    p_log = sub.add_parser("log", help="Append an entry")
    p_log.add_argument("--source", required=True, help="Who: claude, allie, alice, bill")
    p_log.add_argument("--type", required=True, help="tfts, lesson, insight, decision, observation, fault, scar, question")
    p_log.add_argument("--text", required=True, help="The content")
    p_log.add_argument("--context", default="", help="Optional context")

    sub.add_parser("check", help="Check for crash log")
    sub.add_parser("recover", help="Extract lessons from crash log")
    sub.add_parser("clear", help="Clear the log (rightshoe)")

    args = parser.parse_args()

    if args.cmd == "log":
        log_entry(args.source, args.type, args.text, args.context)
    elif args.cmd == "check":
        found = check()
        sys.exit(0 if not found else 1)
    elif args.cmd == "recover":
        recover()
    elif args.cmd == "clear":
        clear()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()

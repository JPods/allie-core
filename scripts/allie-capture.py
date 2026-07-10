#!/usr/bin/env python3
"""
allie-capture.py — Universal event capture for Allie's events.jsonl

Called by:
  - Claude Code hooks (JSON on stdin)
  - Git post-commit hooks (CLI args)
  - Application hooks in MeshMobility, JPodsSM_RPi, WebClerk3
  - SketchUp log watcher

Writes one JSONL line per event to ~/Allie/logs/events.jsonl.
allie-reflect.py reads this file as part of nightly synthesis.

Usage (CLI):
  python3 allie-capture.py --source git:su_jpods --event commit --message "Fix bezier height"
  python3 allie-capture.py --source mesh-mobility --event simulation_complete --data '{"lines": 5}'
  python3 allie-capture.py --source jpods-rpi --event trip_complete --message "NORA_0001 310mm"

Usage (stdin — Claude Code hooks pass JSON on stdin):
  echo '{...hook json...}' | python3 allie-capture.py --source claude-code --event tool_use

Never raises. Never blocks. If the log directory is missing, creates it.
If writing fails for any reason, exits silently — hooks must not interrupt the caller.
"""

import sys
import json
import datetime
import argparse
import pathlib
import os

ALLIE     = pathlib.Path.home() / "Allie"
LOG_PATH  = ALLIE / "logs" / "events.jsonl"
MAX_BYTES = 5 * 1024 * 1024   # rotate at 5 MB


def _now() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")


def _rotate_if_needed():
    if LOG_PATH.exists() and LOG_PATH.stat().st_size > MAX_BYTES:
        dated = LOG_PATH.with_name(f"events-{datetime.date.today()}.jsonl")
        LOG_PATH.rename(dated)


def _write(record: dict):
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    _rotate_if_needed()
    line = json.dumps(record, ensure_ascii=False)
    with open(LOG_PATH, "a") as f:
        f.write(line + "\n")


def capture_from_cli(args):
    """Called when invoked from git hooks, app hooks, shell scripts."""
    data = {}
    if args.data:
        try:
            data = json.loads(args.data)
        except json.JSONDecodeError:
            data = {"raw": args.data}

    record = {
        "ts":      _now(),
        "source":  args.source,
        "event":   args.event,
        "message": args.message or "",
        "data":    data,
    }
    _write(record)


def capture_from_stdin(source: str, event: str):
    """Called by Claude Code hooks — JSON payload arrives on stdin."""
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except Exception:
        payload = {}

    tool_name = payload.get("tool_name", "")
    tool_input = payload.get("tool_input", {})

    # Extract the most useful field depending on tool type
    if tool_name in ("Edit", "Write", "Read"):
        path = tool_input.get("file_path", "")
        note = tool_input.get("description", "")
        # Shorten path to be relative to home
        try:
            path = str(pathlib.Path(path).relative_to(pathlib.Path.home()))
        except ValueError:
            pass
        data = {"tool": tool_name, "path": path}
        if note:
            data["note"] = note

    elif tool_name == "Bash":
        cmd = tool_input.get("command", "")
        desc = tool_input.get("description", "")
        # Truncate long commands
        data = {"tool": "Bash", "cmd": cmd[:120] if cmd else "", "desc": desc}

    elif tool_name in ("Glob", "Grep"):
        data = {"tool": tool_name, "pattern": tool_input.get("pattern", "")}

    else:
        data = {"tool": tool_name}

    record = {
        "ts":     _now(),
        "source": source,
        "event":  event or tool_name.lower(),
        "data":   data,
    }
    _write(record)


def main():
    parser = argparse.ArgumentParser(description="Allie event capture")
    parser.add_argument("--source",  required=True, help="e.g. claude-code, git:su_jpods, mesh-mobility")
    parser.add_argument("--event",   required=True, help="e.g. commit, simulation_complete, trip_complete")
    parser.add_argument("--message", default="",    help="Human-readable description")
    parser.add_argument("--data",    default="",    help="JSON string with structured data")
    parser.add_argument("--stdin",   action="store_true", help="Read Claude Code hook JSON from stdin")
    args = parser.parse_args()

    try:
        if args.stdin:
            # Explicit flag — invoked as Claude Code hook, JSON on stdin
            capture_from_stdin(args.source, args.event)
        else:
            capture_from_cli(args)
    except Exception:
        # Never crash the caller
        pass


if __name__ == "__main__":
    main()

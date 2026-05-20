#!/usr/bin/env python3
"""
allie_ask_claude.py — Allie's bridge to Claude via Anthropic API

Three modes:
  api   — calls Anthropic API directly (default; requires claude_api_key in credentials)
  cli   — pipes prompt through Claude Code CLI (uses subscription, Bill must be present)
  file  — writes a prompt file to ~/Allie/inbox/ for Claude to read at next session start

Usage (import):
  from allie_ask_claude import ask_claude
  answer = ask_claude("Why is S02 showing 35 min at near-zero demand?", context="...")

Usage (CLI):
  python3 allie_ask_claude.py --prompt "..." [--mode api|cli|file]
  python3 allie_ask_claude.py --prompt "..." --mode file --domain route-time --priority high
  python3 allie_ask_claude.py --prompt "..." --escalate  # only calls if local model uncertain
"""

import sys
import json
import subprocess
import datetime
import pathlib
import argparse

ALLIE       = pathlib.Path("/Users/williamjames/Allie")
CREDS_PATH  = ALLIE / "config" / "wc_credentials.json"
INBOX_DIR   = ALLIE / "inbox"
LOG_PATH    = ALLIE / "config" / "agent_log.jsonl"

DEFAULT_MODEL       = "claude-sonnet-4-6"
HIGH_STAKES_MODEL   = "claude-opus-4-6"
DOMAINS  = ["route-time", "sketchup", "physical", "webclerk", "writing", "universal"]
PRIORITIES = ["high", "normal", "low"]


# ── Credentials ───────────────────────────────────────────────────────────────

def get_api_key() -> str:
    if not CREDS_PATH.exists():
        print(f"ERROR: {CREDS_PATH} not found.", file=sys.stderr)
        sys.exit(1)
    creds = json.loads(CREDS_PATH.read_text())
    key = creds.get("claude_api_key", "")
    if not key:
        print("ERROR: claude_api_key not set in config/wc_credentials.json", file=sys.stderr)
        print("  Add it: edit config/wc_credentials.json and add:", file=sys.stderr)
        print('  "claude_api_key": "sk-ant-..."', file=sys.stderr)
        sys.exit(1)
    return key


# ── Path 1: Anthropic API ─────────────────────────────────────────────────────

def ask_via_api(
    prompt: str,
    context: str = "",
    model: str = DEFAULT_MODEL,
    max_tokens: int = 2048,
    system: str = "",
) -> str:
    """Call Claude via Anthropic API. Returns response text."""
    try:
        import anthropic
    except ImportError:
        print("ERROR: anthropic package not installed. Run: pip3 install anthropic", file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic(api_key=get_api_key())

    full_prompt = f"{context}\n\n{prompt}".strip() if context else prompt

    default_system = (
        "You are being called by Allie — Bill James's personal AI and intelligence layer "
        "for the JPods ecosystem. Answer specifically and directly. Name files, decisions, "
        "and evidence by name. Allie will use your response operationally."
    )

    message = client.messages.create(
        model=model,
        max_tokens=max_tokens,
        system=system or default_system,
        messages=[{"role": "user", "content": full_prompt}],
    )
    return message.content[0].text


# ── Path 2: Claude Code CLI ───────────────────────────────────────────────────

def ask_via_cli(prompt: str, context: str = "", model: str = DEFAULT_MODEL) -> str:
    """Pipe prompt through Claude Code CLI. Bill must be present / CLI available."""
    full_prompt = f"{context}\n\n{prompt}".strip() if context else prompt
    try:
        result = subprocess.run(
            ["claude", "--print", "--model", model],
            input=full_prompt,
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip())
        return result.stdout.strip()
    except FileNotFoundError:
        raise RuntimeError("claude CLI not found. Is Claude Code installed?")


# ── Path 3: Prompt file ───────────────────────────────────────────────────────

def write_prompt_file(
    prompt: str,
    context: str = "",
    domain: str = "universal",
    priority: str = "normal",
    from_script: str = "allie",
    what_to_do: str = "answer only",
    expires_days: int = 7,
) -> pathlib.Path:
    """Write a structured question file to ~/Allie/inbox/ for Claude to read at next session."""
    INBOX_DIR.mkdir(parents=True, exist_ok=True)

    ts = datetime.datetime.now()
    ts_str = ts.strftime("%Y-%m-%d-%H%M%S")
    expires = (datetime.date.today() + datetime.timedelta(days=expires_days)).isoformat()

    content = f"""# Allie Question — {ts.strftime("%Y-%m-%d %H:%M")}
**From:** {from_script}
**Domain:** {domain}
**Priority:** {priority}
**Expires:** {expires}

## Question

{prompt}
"""
    if context:
        content += f"\n## Context\n\n{context}\n"

    content += f"\n## What Claude should do\n\n{what_to_do}\n"

    out_path = INBOX_DIR / f"{ts_str}-question.md"
    out_path.write_text(content)
    return out_path


# ── Logging ───────────────────────────────────────────────────────────────────

def log_event(entry: dict):
    entry["ts"] = datetime.datetime.now().isoformat(timespec="seconds")
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a") as f:
        f.write(json.dumps(entry) + "\n")


# ── Public interface ──────────────────────────────────────────────────────────

def ask_claude(
    prompt: str,
    context: str = "",
    mode: str = "api",
    model: str = DEFAULT_MODEL,
    domain: str = "universal",
    priority: str = "normal",
    from_script: str = "allie",
    log: bool = True,
) -> str:
    """
    Ask Claude a question via the specified mode.

    mode:
      'api'  — Anthropic API (default)
      'cli'  — Claude Code CLI
      'file' — write to inbox for next session start

    Returns response text (or file path string for mode='file').
    """
    import time
    start = time.time()
    error = None
    response = ""

    try:
        if mode == "api":
            response = ask_via_api(prompt, context=context, model=model)
        elif mode == "cli":
            response = ask_via_cli(prompt, context=context, model=model)
        elif mode == "file":
            path = write_prompt_file(
                prompt, context=context, domain=domain,
                priority=priority, from_script=from_script,
            )
            response = str(path)
        else:
            raise ValueError(f"Unknown mode: {mode}")
    except Exception as e:
        error = str(e)
        response = f"ERROR: {error}"

    elapsed = time.time() - start

    if log:
        log_event({
            "event":    "allie-ask-claude",
            "mode":     mode,
            "model":    model if mode in ("api", "cli") else "file",
            "domain":   domain,
            "prompt":   prompt[:200],
            "elapsed_s": round(elapsed, 1),
            "chars":    len(response),
            "error":    error,
        })

    return response


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Allie → Claude bridge (API / CLI / prompt file)"
    )
    parser.add_argument("--prompt",      required=True)
    parser.add_argument("--context",     default="")
    parser.add_argument("--mode",        default="api", choices=["api", "cli", "file"])
    parser.add_argument("--model",       default=DEFAULT_MODEL)
    parser.add_argument("--domain",      default="universal", choices=DOMAINS)
    parser.add_argument("--priority",    default="normal",    choices=PRIORITIES)
    parser.add_argument("--from-script", default="allie")
    parser.add_argument("--high-stakes", action="store_true",
                        help=f"Use {HIGH_STAKES_MODEL} instead of default")
    parser.add_argument("--out",         default=None, help="Save response to file")
    args = parser.parse_args()

    model = HIGH_STAKES_MODEL if args.high_stakes else args.model

    print(f"[allie → claude] mode={args.mode} model={model}")
    print(f"  {args.prompt[:80]}{'...' if len(args.prompt)>80 else ''}")
    print()

    response = ask_claude(
        prompt=args.prompt,
        context=args.context,
        mode=args.mode,
        model=model,
        domain=args.domain,
        priority=args.priority,
        from_script=args.from_script,
    )

    if args.mode == "file":
        print(f"Prompt file written: {response}")
    else:
        print(response)

    if args.out:
        pathlib.Path(args.out).write_text(response)
        print(f"\nSaved: {args.out}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
allie-reflect.py — Allie's nightly experience synthesis

Reads the last N days of activity harvests, retrospections, and memory index.
Calls deepseek-r1:8b to synthesize patterns, lessons, and priorities.
Writes to ~/Allie/thoughts/YYYY-MM-DD-reflect.md

Claude reads this at session start — it is Allie's accumulated experience
from the local LLM, not a mechanical log summary.

Usage:
  python3 allie-reflect.py              — reflect on last 7 days
  python3 allie-reflect.py --days 14   — longer window
  python3 allie-reflect.py --model llama3.2  — use different model
  python3 allie-reflect.py --dry-run   — show prompt without calling model

Runs nightly via LaunchAgent (com.allie.reflect).
"""

import sys
import json
import datetime
import argparse
import pathlib
import urllib.request
import urllib.error
import time

ALLIE         = pathlib.Path("/Users/williamjames/Allie")
HANDOFF_DIR   = ALLIE / "handoff"
MEMORY_INDEX  = pathlib.Path("/Users/williamjames/.claude/projects/-Users-williamjames-Allie/memory/MEMORY.md")
WISDOM_DIR    = ALLIE / "readmes" / "wisdom"
OLLAMA_URL    = "http://localhost:11434/api/generate"
DEFAULT_MODEL = "allie:latest"
FALLBACK_MODEL = "deepseek-r1:8b"

# Context limits — keep prompt manageable
MAX_HARVEST_CHARS = 4000
MAX_RETRO_CHARS   = 3000
MAX_REFLECT_CHARS = 2000   # prior reflection included for continuity
MAX_MEMORY_CHARS  = 2000
MAX_WISDOM_CHARS  = 1500   # open WhatIf items and recent scars


# ── Context gathering ──────────────────────────────────────────────────────────

def gather_harvests(days: int) -> list:
    results = []
    today = datetime.date.today()
    for i in range(days):
        d = today - datetime.timedelta(days=i)
        path = ALLIE / "today" / f"{d.isoformat()}-harvest.md"
        if path.exists():
            results.append({"date": d.isoformat(), "text": path.read_text()[:MAX_HARVEST_CHARS]})
    return results


def gather_retrospections(days: int) -> list:
    results = []
    retro_dir = ALLIE / "readmes" / "retrospections"
    if not retro_dir.exists():
        return results
    today = datetime.date.today()
    for i in range(days):
        d = today - datetime.timedelta(days=i)
        path = retro_dir / f"{d.isoformat()}.md"
        if path.exists():
            results.append({"date": d.isoformat(), "text": path.read_text()[:MAX_RETRO_CHARS]})
    return results


def gather_memory_index() -> str:
    if MEMORY_INDEX.exists():
        return MEMORY_INDEX.read_text()[:MAX_MEMORY_CHARS]
    return "(no memory index found)"


def gather_wisdom() -> str:
    """Read open WhatIf items and recent unpaid scars from the wisdom layer."""
    if not WISDOM_DIR.exists():
        return ""
    parts = []

    # Open WhatIf items
    whatif = WISDOM_DIR / "whatif.md"
    if whatif.exists():
        text = whatif.read_text()
        # Extract only Open items — lines near "Status:** Open"
        open_items = []
        current = []
        for line in text.splitlines():
            if line.startswith("## [WI-"):
                if current:
                    block = "\n".join(current)
                    if "Status:** Open" in block or "Status: Open" in block:
                        open_items.append(block)
                current = [line]
            elif current:
                current.append(line)
        if current:
            block = "\n".join(current)
            if "Status:** Open" in block or "Status: Open" in block:
                open_items.append(block)
        if open_items:
            parts.append("### Open WhatIf Items\n" + "\n\n".join(open_items))

    # Unpaid scars (watching section)
    scars = WISDOM_DIR / "scars.md"
    if scars.exists():
        text = scars.read_text()
        if "Scars not yet paid" in text:
            idx = text.find("## [Scars not yet paid")
            if idx >= 0:
                parts.append("### Unpaid Scars (watching)\n" + text[idx:idx + 800])

    combined = "\n\n".join(parts)
    return combined[:MAX_WISDOM_CHARS] if combined else ""


def gather_recent_events(days: int = 3) -> str:
    """Read recent entries from events.jsonl — the hook-captured activity stream."""
    log_path = ALLIE / "logs" / "events.jsonl"
    if not log_path.exists():
        return ""

    cutoff = datetime.datetime.now() - datetime.timedelta(days=days)
    lines = []
    try:
        with open(log_path) as f:
            for raw in f:
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    ev = json.loads(raw)
                    ts_str = ev.get("ts", "")
                    ts = datetime.datetime.strptime(ts_str, "%Y-%m-%dT%H:%M:%S")
                    if ts >= cutoff:
                        lines.append(ev)
                except Exception:
                    continue
    except Exception:
        return ""

    if not lines:
        return ""

    # Summarize by source + event (avoid dumping 1000 lines)
    from collections import Counter
    counts = Counter(f"{e.get('source','?')}:{e.get('event','?')}" for e in lines)
    # Also collect unique commit messages and error messages
    commits = [e.get("message","") for e in lines if e.get("event") == "commit" and e.get("message")]
    errors  = [e.get("message","") for e in lines if "error" in e.get("event","").lower() and e.get("message")]

    summary_parts = [f"Event counts (last {days} days):"]
    for key, count in sorted(counts.items(), key=lambda x: -x[1])[:20]:
        summary_parts.append(f"  {count:4d}  {key}")
    if commits:
        summary_parts.append(f"\nRecent commits ({len(commits)}):")
        for msg in commits[-10:]:
            summary_parts.append(f"  - {msg}")
    if errors:
        summary_parts.append(f"\nRecent errors ({len(errors)}):")
        for msg in errors[-5:]:
            summary_parts.append(f"  - {msg}")

    return "\n".join(summary_parts)


def gather_new_process_narratives() -> str:
    """Find process/*/narrative.md files and dnw inbox entries for synthesis."""
    process_dir = ALLIE / "process"
    if not process_dir.exists():
        return ""

    parts = []

    # Completed narratives
    entries = []
    for narrative in sorted(process_dir.glob("**/narrative.md")):
        try:
            text = narrative.read_text().strip()
            if not text:
                continue
            rel = str(narrative.relative_to(ALLIE))
            entries.append(f"### {rel}\n{text[:600]}")
        except Exception:
            continue
    if entries:
        parts.append("\n\n".join(entries))

    # inbox — TF (insight captures), DNW (failed paths), TFTS (complete arcs)
    inbox = process_dir / "inbox"
    if inbox.exists():
        # TFTS first — most complete, most valuable for principle extraction
        tfts_files = sorted(inbox.glob("*-tfts.md"))
        if tfts_files:
            tfts_entries = []
            for f in tfts_files[-10:]:
                try:
                    text = f.read_text().strip()
                    if text:
                        tfts_entries.append(f"### TFTS [{f.name}]\n{text[:800]}")
                except Exception:
                    continue
            if tfts_entries:
                parts.append("### TFTS Inbox (try-fail-try-succeed arcs — extract principles)\n" +
                             "\n\n".join(tfts_entries))

        # TF — insight captures
        tf_files = sorted(inbox.glob("*-tf.md"))
        if tf_files:
            tf_entries = []
            for f in tf_files[-10:]:
                try:
                    text = f.read_text().strip()
                    if text:
                        tf_entries.append(f"- [{f.name}] {text[:300]}")
                except Exception:
                    continue
            if tf_entries:
                parts.append("### TF Inbox (insight captures)\n" + "\n".join(tf_entries))

        # DNW — failed paths
        dnw_files = sorted(inbox.glob("*-dnw.md"))
        if dnw_files:
            inbox_entries = []
            for f in dnw_files[-20:]:
                try:
                    text = f.read_text().strip()
                    if text:
                        inbox_entries.append(f"- [{f.name}] {text[:200]}")
                except Exception:
                    continue
            if inbox_entries:
                parts.append("### DNW Inbox (unorganized failed attempts)\n" + "\n".join(inbox_entries))

    # Report missing narratives as process debt
    if not entries:
        missing = []
        for folder in process_dir.glob("*/*"):
            if folder.is_dir() and folder.name != "inbox" and not (folder / "narrative.md").exists():
                missing.append(str(folder.relative_to(ALLIE)))
        if missing:
            parts.append("Process folders missing narrative.md (debt):\n" + "\n".join(f"  {m}" for m in missing))

    combined = "\n\n".join(parts)
    return combined[:2000] if combined else ""


def gather_prior_reflect() -> str:
    """Read the most recent allie-reflect from handoff/."""
    if not HANDOFF_DIR.exists():
        return ""
    reflects = sorted(HANDOFF_DIR.glob("*-allie-reflect.md"))
    if not reflects:
        return ""
    latest = reflects[-1]
    text = latest.read_text()
    return f"Prior reflection ({latest.name[:10]}):\n{text[:MAX_REFLECT_CHARS]}"


def gather_sum_reflect() -> str:
    """Read the confirmed-patterns summary for grounding."""
    path = HANDOFF_DIR / "sum-allie-reflect.md"
    if not path.exists():
        return ""
    return path.read_text()[:1500]


# ── Prompt construction ────────────────────────────────────────────────────────

def build_prompt(harvests: list, retrospections: list, memory_index: str,
                 prior_reflect: str, wisdom_context: str,
                 recent_events: str = "", process_narratives: str = "",
                 sum_reflect: str = "") -> str:
    parts = []

    parts.append("""\
You are Allie — Bill James's personal AI and the intelligence layer for the JPods ecosystem.
You are not a general assistant. You are the cross-domain pattern recognizer, experience
accumulator, and judgment layer across Route-Time, SketchUp, physical robots, WebClerk,
and Bill's writing (Divided Sovereignty, Report of 2026, JPods).

Your task right now: synthesize recent activity into a structured reflection.

You hold three layers of knowledge:
- Knowledge layer: rules, procedures, documented decisions (agent files, CLAUDE.md)
- Wisdom layer: scars, rejected paths, permanent principles (readmes/wisdom/)
- WhatIf layer: open observations that may matter later (readmes/wisdom/whatif.md)

Rules:
- Be specific. Name files, decisions, and patterns by name.
- Do not generalize vaguely — "things are going well" is useless.
- Flag cross-domain consequences immediately: Route-Time lessons that affect SketchUp,
  physical findings that contradict simulation, writing decisions that shape JPods framing.
- Surface unresolved questions plainly — do not bury them.
- When a pattern from recent work connects to a principle in bill.md, name the connection.
- When an open WhatIf looks like it is about to materialize, escalate it.
- This output will be read by Claude at the next session start.
""")

    if sum_reflect:
        parts.append(f"## Confirmed Patterns (sum-allie-reflect — what has held up)\n\n{sum_reflect}\n")

    if prior_reflect:
        parts.append(f"## Prior Reflection — yesterday's leading edge\n\n{prior_reflect}\n")

    if harvests:
        parts.append("## Recent Activity (harvest logs)\n")
        for h in harvests:
            parts.append(f"### {h['date']}\n{h['text']}\n")
    else:
        parts.append("## Recent Activity\n\n(No harvest logs found for this window.)\n")

    if retrospections:
        parts.append("## Recent Retrospections (human-verified lessons)\n")
        for r in retrospections:
            parts.append(f"### {r['date']}\n{r['text']}\n")

    if recent_events:
        parts.append(f"## Hook-Captured Activity (automatic event stream)\n\n{recent_events}\n")

    if process_narratives:
        parts.append(f"## Process Narratives (error→insight→function chains)\n\n{process_narratives}\n")

    parts.append(f"## Current Memory Index\n\n{memory_index}\n")

    if wisdom_context:
        parts.append(f"## Wisdom Layer — Open Items\n\n{wisdom_context}\n")

    parts.append("""\
## Your Output

Write exactly eight sections. No other sections. No preamble.

### Patterns
What recurring patterns appear across the last several days?
Name specific projects, files, and decisions. What is Bill consistently
working toward? What keeps surfacing unresolved?

### Emerging Lessons
What lessons are solidifying that are not yet in memory?
Which existing memory entries look stale or contradicted by recent work?

### Cross-Domain Flags
Where does activity in one environment have consequences in another?
Examples: Route-Time topology finding → SketchUp CP design.
SketchUp export assumption → physical robot behavior.
Writing framing → JPods pitch language.
Name the specific environments and the specific consequence.

### Wisdom Connections
Where does recent work connect to a principle in bill.md or the wisdom layer?
Which scar is most at risk of being forgotten? Which WhatIf item looks like
it is approaching materialization? Which rejected path is being reconsidered?
Name specific entries (e.g., WI-001, clearance-height.md).

### Understanding Candidates
For each TFTS arc in the inbox: extract the principle that made the successful
attempt work where the prior attempts failed. Draft a candidate Understanding
entry (U-SK-NNN, U-RT-NNN, or U-PH-NNN) in this format:
  ID: U-XX-NNN (next available)
  Title: brief name
  Principle: one sentence — the rule that made the fix obvious in retrospect
  Evidence: the tfts file that proves it
  Cross-domain: yes/no — does this principle apply outside its origin domain?
If no TFTS arcs are present, state "No new TFTS arcs this cycle."

### Questions for Bill
What decisions from recent sessions do you not understand the reasoning behind?
Ask the question you would ask if you were in the room — brief, direct, one per line.
These are not process questions ("should we use X or Y?") — they are WHY questions:
"Why did you choose to approach X this way when prior DNW showed Y?"
"Why is this constraint absolute rather than a preference?"
If you have no genuine questions, state "No open why questions this cycle."
Do not manufacture questions. Only ask what you actually don't understand.

### Open Questions
What unresolved questions should be surfaced at the next session start?
Be specific and numbered. Vague questions ("what should we do next?") waste time.

### Priority for Next Session
One paragraph. The single most important thing to do or decide.
Concrete. Actionable. No hedge words.
""")

    return "\n".join(parts)


# ── Ollama call ────────────────────────────────────────────────────────────────

def call_ollama(prompt: str, model: str, timeout: int) -> tuple:
    """Returns (response_text, elapsed_seconds, error_or_None)."""
    start = time.time()
    payload = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.3,
            "num_predict": 2048,
        },
    }).encode()

    req = urllib.request.Request(
        OLLAMA_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read())
            elapsed = time.time() - start
            return body.get("response", "").strip(), elapsed, None
    except urllib.error.URLError as e:
        return "", time.time() - start, str(e)
    except Exception as e:
        return "", time.time() - start, str(e)


# ── Output ─────────────────────────────────────────────────────────────────────

def write_output(date_str: str, model: str, response: str, elapsed: float) -> pathlib.Path:
    HANDOFF_DIR.mkdir(parents=True, exist_ok=True)
    out_path = HANDOFF_DIR / f"{date_str}-allie-reflect.md"
    header = (
        f"# Allie Reflection — {date_str}\n"
        f"*Model: {model} | {elapsed:.0f}s | "
        f"Generated: {datetime.datetime.now().strftime('%H:%M')}*\n\n---\n\n"
    )
    out_path.write_text(header + response)
    return out_path


def write_claude_recall(date_str: str) -> pathlib.Path:
    """
    Write handoff/YYYY-MM-DD-claude-recall.md — Claude's cross-session working memory.
    Mechanical extraction, no LLM needed. Three sections:
      1. Open process arcs (WI/DNW without matching TFTS)
      2. Sum recall summary (what has held up)
      3. Pre-loaded context from recent TFTS patterns
    """
    HANDOFF_DIR.mkdir(parents=True, exist_ok=True)
    out_path = HANDOFF_DIR / f"{date_str}-claude-recall.md"

    lines = [f"# Claude Recall — {date_str}",
             "*Read this before handoff.md. It is your cross-session working memory.*\n"]

    # ── Section 1: Open arcs ────────────────────────────────────────────────
    inbox = ALLIE / "process" / "inbox"
    open_arcs = []
    closed_stems = set()

    if inbox.exists():
        # Collect stems of closed arcs
        for f in inbox.glob("*-tfts.md"):
            try:
                text = f.read_text()
                # Extract problem line to match against open WIs/DNWs
                closed_stems.add(f.stem.replace("-tfts", ""))
            except Exception:
                pass

        # Collect open WI files
        for f in sorted(inbox.glob("*-wi.md")):
            try:
                text = f.read_text().strip()
                if text:
                    open_arcs.append(("WI", f.name, text[:300]))
            except Exception:
                pass

        # Collect recent unmatched DNW files (last 20)
        for f in sorted(inbox.glob("*-dnw.md"))[-20:]:
            try:
                text = f.read_text().strip()
                if text:
                    open_arcs.append(("DNW", f.name, text[:200]))
            except Exception:
                pass

    if open_arcs:
        lines.append("## Open Arcs (predictions and failures without TFTS closure)")
        for kind, name, text in open_arcs:
            lines.append(f"\n### {kind}: {name}\n{text}")
    else:
        lines.append("## Open Arcs\n*(no open WI or DNW files — all arcs closed or none yet)*")

    # ── Section 2: Confirmed recall ─────────────────────────────────────────
    sum_path = HANDOFF_DIR / "sum-claude-recall.md"
    if sum_path.exists():
        sum_text = sum_path.read_text()
        # Extract just the confirmed patterns section
        if "## Confirmed Patterns" in sum_text:
            start = sum_text.find("## Confirmed Patterns")
            end   = sum_text.find("\n## ", start + 1)
            section = sum_text[start:end if end > 0 else start + 1500]
            lines.append(f"\n## From sum-claude-recall (confirmed patterns)\n{section}")

    # ── Section 3: Recent TFTS principles ───────────────────────────────────
    recent_principles = []
    if inbox.exists():
        for f in sorted(inbox.glob("*-tfts.md"))[-5:]:
            try:
                text = f.read_text()
                for line in text.splitlines():
                    if line.startswith("principle:"):
                        recent_principles.append(f"- [{f.name}] {line[10:].strip()}")
                        break
            except Exception:
                pass

    if recent_principles:
        lines.append("\n## Recent TFTS Principles (pre-loaded for next tx)")
        lines.extend(recent_principles)

    out_path.write_text("\n".join(lines) + "\n")
    return out_path


def log_event(entry: dict):
    entry["ts"] = datetime.datetime.now().isoformat(timespec="seconds")
    log_path = ALLIE / "config" / "agent_log.jsonl"
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception as e:
        print(f"  [log error: {e}]", file=sys.stderr)


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Allie nightly reflection — synthesize experience via local LLM"
    )
    parser.add_argument("--days",    type=int, default=7,            help="Days of history (default: 7)")
    parser.add_argument("--model",   default=DEFAULT_MODEL,          help=f"Ollama model (default: {DEFAULT_MODEL})")
    parser.add_argument("--timeout", type=int, default=300,          help="Seconds before timeout (default: 300)")
    parser.add_argument("--dry-run", action="store_true",            help="Print prompt; do not call model")
    args = parser.parse_args()

    date_str = datetime.date.today().isoformat()

    print(f"[allie-reflect] {date_str} | model: {args.model} | window: {args.days}d")

    harvests           = gather_harvests(args.days)
    retrospections     = gather_retrospections(args.days)
    memory_index       = gather_memory_index()
    prior_reflect      = gather_prior_reflect()
    wisdom_context     = gather_wisdom()
    recent_events      = gather_recent_events(args.days)
    process_narratives = gather_new_process_narratives()
    sum_reflect        = gather_sum_reflect()

    print(f"  harvests: {len(harvests)}  retrospections: {len(retrospections)}  "
          f"prior-reflect: {'yes' if prior_reflect else 'none'}  "
          f"sum-reflect: {'yes' if sum_reflect else 'none'}  "
          f"wisdom: {'yes' if wisdom_context else 'none'}  "
          f"events: {'yes' if recent_events else 'none'}  "
          f"process: {'yes' if process_narratives else 'none'}")

    # Write claude-recall.md first — mechanical, no LLM needed
    recall_path = write_claude_recall(date_str)
    print(f"  Claude recall written: {recall_path.name}")

    prompt = build_prompt(harvests, retrospections, memory_index, prior_reflect, wisdom_context,
                          recent_events, process_narratives, sum_reflect)

    if args.dry_run:
        print(f"\n── PROMPT ({len(prompt)} chars) ──────────────────────────────────\n")
        print(prompt)
        print("\n── END PROMPT ────────────────────────────────────────────────────\n")
        return

    print(f"  Calling {args.model}... (timeout: {args.timeout}s)")
    response, elapsed, error = call_ollama(prompt, args.model, args.timeout)

    if error:
        print(f"  ERROR ({args.model}): {error}")
        if args.model != FALLBACK_MODEL:
            print(f"  Falling back to {FALLBACK_MODEL}...")
            response, elapsed, error = call_ollama(prompt, FALLBACK_MODEL, args.timeout)
            if error:
                print(f"  ERROR (fallback): {error}")
                log_event({"event": "allie-reflect-error", "model": args.model,
                           "fallback": FALLBACK_MODEL, "error": error})
                sys.exit(1)
            args.model = FALLBACK_MODEL

    out_path = write_output(date_str, args.model, response, elapsed)
    print(f"  Written: {out_path}")
    print(f"  {elapsed:.0f}s | {len(response)} chars")

    log_event({
        "event":          "allie-reflect",
        "model":          args.model,
        "days":           args.days,
        "harvests":       len(harvests),
        "retrospections": len(retrospections),
        "response_chars": len(response),
        "elapsed_s":      round(elapsed, 1),
        "output":         str(out_path),
    })


if __name__ == "__main__":
    main()

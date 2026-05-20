#!/usr/bin/env python3
"""
allie-harvest-processors.py — Allie's librarian harvest script

Reads experience logs written by standalone Noelle/Natalie/Nora processors,
calls deepseek-r1:8b to identify lesson candidates, and prints a synthesis
report. Allie reviews the report and manually promotes lessons to the
knowledge files in readmes/processor-knowledge/.

Usage:
  python3 allie-harvest-processors.py                # all agents
  python3 allie-harvest-processors.py --agent natalie  # specific agent
  python3 allie-harvest-processors.py --since 2026-05-01  # entries after date
  python3 allie-harvest-processors.py --dry-run      # print entries without calling LLM

Experience log location:
  /Users/williamjames/Allie/logs/processor-experiences/<agent>-log.jsonl

Knowledge file location:
  /Users/williamjames/Allie/readmes/processor-knowledge/<agent>.md

LLM: deepseek-r1:8b via Ollama HTTP API (localhost:11434)
"""

import sys
import json
import time
import datetime
import pathlib
import argparse
import urllib.request
import urllib.error

ALLIE           = pathlib.Path("/Users/williamjames/Allie")
LOGS_DIR        = ALLIE / "logs" / "processor-experiences"
KNOWLEDGE_DIR   = ALLIE / "readmes" / "processor-knowledge"
OLLAMA_URL      = "http://localhost:11434/api/generate"
HARVEST_LOG     = ALLIE / "config" / "agent_log.jsonl"

AGENTS = ["noelle", "natalie", "nora"]
MODEL  = "deepseek-r1:8b"


# ── Log reading ───────────────────────────────────────────────────────────────

def read_experience_log(agent: str, since: str = None) -> list:
    """Read JSONL experience log for agent. Returns list of entries."""
    log_path = LOGS_DIR / f"{agent}-log.jsonl"
    if not log_path.exists():
        return []
    entries = []
    for line in log_path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            if since and entry.get("ts", "") < since:
                continue
            entries.append(entry)
        except json.JSONDecodeError:
            pass
    return entries


def load_knowledge_file(agent: str) -> str:
    """Read current knowledge file for agent."""
    path = KNOWLEDGE_DIR / f"{agent}.md"
    if not path.exists():
        return ""
    return path.read_text()


# ── LLM call ─────────────────────────────────────────────────────────────────

def call_ollama(prompt: str, timeout: int = 180) -> str:
    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.3, "num_predict": 2048},
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
            response = body.get("response", "").strip()
            # deepseek-r1 sometimes returns empty if all text was in <think> block
            if not response:
                response = "[LLM returned empty response — check Ollama logs]"
            return response
    except Exception as e:
        return f"[LLM call failed: {e}]"


# ── Synthesis ─────────────────────────────────────────────────────────────────

def synthesize_experiences(agent: str, entries: list, knowledge: str) -> str:
    """Call LLM to identify lesson candidates from experience entries."""
    entry_text = "\n".join(json.dumps(e) for e in entries[:50])  # cap at 50 entries

    prompt = f"""You are Allie — Bill James's personal AI and librarian for the JPods agent system.

You are reviewing experience log entries from the {agent.title()} processor.
Your job is to identify which entries represent genuine lessons worth adding to
the {agent.title()} knowledge file.

A genuine lesson:
- Reveals something not already stated in the knowledge file
- Generalizes beyond the specific session (not just "this happened once")
- Is operational (changes how the processor should behave)
- Has enough evidence to warrant confidence (not just a guess)

NOT a lesson: normal operation, expected behavior, single anomaly without pattern.

--- Current {agent.title()} Knowledge File (excerpt) ---
{knowledge[:2000]}

--- Experience Log Entries ---
{entry_text}

For each genuine lesson candidate, write:
LESSON CANDIDATE
Agent: {agent}
Title: <short title>
What: <specific, operational understanding>
Why it matters: <what breaks if you don't know this>
Evidence: <which entries support this — use ts fields>
Confidence: High | Medium | Low

If no lessons are found, say: NO NEW LESSONS — all entries show expected behavior.

Be terse. Do not summarize entries that show nothing new."""

    return call_ollama(prompt)


# ── Logging ───────────────────────────────────────────────────────────────────

def log_harvest(agent: str, entries_read: int, lessons_found: int):
    entry = {
        "ts": datetime.datetime.now().isoformat(timespec="seconds"),
        "event": "allie-harvest-processors",
        "agent": agent,
        "entries_read": entries_read,
        "lessons_found": lessons_found,
    }
    HARVEST_LOG.parent.mkdir(parents=True, exist_ok=True)
    with HARVEST_LOG.open("a") as f:
        f.write(json.dumps(entry) + "\n")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Harvest processor experience logs and identify lesson candidates"
    )
    parser.add_argument("--agent",    choices=AGENTS + ["all"], default="all")
    parser.add_argument("--since",    default=None,
                        help="Only process entries with ts >= this date (YYYY-MM-DD)")
    parser.add_argument("--dry-run",  action="store_true",
                        help="Print entries without calling LLM")
    args = parser.parse_args()

    agents_to_process = AGENTS if args.agent == "all" else [args.agent]

    for agent in agents_to_process:
        print(f"\n{'='*60}")
        print(f"HARVESTING: {agent.upper()}")
        print(f"{'='*60}")

        entries = read_experience_log(agent, since=args.since)

        if not entries:
            print(f"  No experience entries found in {LOGS_DIR}/{agent}-log.jsonl")
            print(f"  (Standalone {agent.title()} processor has not written any experience yet)")
            continue

        print(f"  Entries read: {len(entries)}")

        if args.dry_run:
            print(f"\n  --- ENTRIES (dry-run) ---")
            for e in entries[:10]:
                print(f"  {e.get('ts','')} | {e.get('event_type','')} | {e.get('notes','')}")
            if len(entries) > 10:
                print(f"  ... and {len(entries)-10} more")
            continue

        knowledge = load_knowledge_file(agent)
        print(f"  Knowledge file: {len(knowledge)} chars loaded")
        print(f"  Calling {MODEL} for synthesis...")

        start = time.time()
        synthesis = synthesize_experiences(agent, entries, knowledge)
        elapsed = round(time.time() - start, 1)

        print(f"\n--- {agent.upper()} SYNTHESIS ({elapsed}s) ---")
        print(synthesis)
        print()

        # Count lesson candidates in output
        lessons = synthesis.count("LESSON CANDIDATE")
        log_harvest(agent, len(entries), lessons)

        print(f"\n  Lessons found: {lessons}")
        print(f"  To promote a lesson, add it to:")
        print(f"  {KNOWLEDGE_DIR}/{agent}.md")
        print(f"  using the U-NNN format under ## Understandings")

    print(f"\n{'='*60}")
    print("HARVEST COMPLETE")
    print("Review LESSON CANDIDATE items above.")
    print("Manually add confirmed lessons to readmes/processor-knowledge/<agent>.md")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()

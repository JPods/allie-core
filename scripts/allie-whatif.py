#!/usr/bin/env python3
"""
allie-whatif.py — Allie's weekly WhatIf post generator

Reads recent activity, retrospections, open WhatIf items, and the aggregate
tracker. Calls the local LLM to generate 3–5 new WhatIf items for the current
week. Claude Code adds its own items at session end.

Output: appends Allie's items to the current week's file in
        readmes/wisdom/whatif-weekly/YYYY-WNN.md

Usage:
  python3 allie-whatif.py              — generate for current ISO week
  python3 allie-whatif.py --dry-run    — print prompt without calling LLM
  python3 allie-whatif.py --assess     — also assess items past their resolve date
  python3 allie-whatif.py --score      — update aggregate.md scores

Runs weekly (Monday morning) via LaunchAgent or cron.
"""

import sys
import json
import datetime
import argparse
import pathlib
import urllib.request
import urllib.error
import time
import re

ALLIE        = pathlib.Path("/Users/williamjames/Allie")
WHATIF_DIR   = ALLIE / "readmes" / "wisdom" / "whatif-weekly"
WISDOM_DIR   = ALLIE / "readmes" / "wisdom"
RETRO_DIR    = ALLIE / "readmes" / "retrospections"
THOUGHTS_DIR = ALLIE / "thoughts"
OLLAMA_URL   = "http://localhost:11434/api/generate"
DEFAULT_MODEL = "allie:latest"
FALLBACK_MODEL = "deepseek-r1:8b"

DOMAINS = {
    "WC3": "WebClerk3 — data quality, Alice, pattern recognition, billing",
    "SU":  "JPods SketchUp plugin — student tool, build pipeline, animation",
    "PH":  "Physical — scale model, Nora/Natalie/Noelle on Pi",
    "RT":  "MeshMobility — network planner, simulator",
    "SYS": "System-wide — Allie, CLAUDE.md, wisdom layer, succession",
    "EXT": "External — regulations, deployment, first customer",
}


# ── ISO week helpers ──────────────────────────────────────────────────────────

def current_iso_week() -> tuple:
    """Returns (year, week_number) for today."""
    today = datetime.date.today()
    iso = today.isocalendar()
    return iso[0], iso[1]

def week_file_path(year: int, week: int) -> pathlib.Path:
    return WHATIF_DIR / f"{year}-W{week:02d}.md"

def week_date_range(year: int, week: int) -> str:
    # ISO week starts Monday
    jan4 = datetime.date(year, 1, 4)
    start = jan4 + datetime.timedelta(weeks=week - jan4.isocalendar()[1],
                                      days=-jan4.weekday())
    end = start + datetime.timedelta(days=6)
    return f"{start.strftime('%b %-d')}–{end.strftime('%b %-d, %Y')}"


# ── Context gathering ─────────────────────────────────────────────────────────

def gather_recent_retrospections(n: int = 3) -> str:
    if not RETRO_DIR.exists():
        return ""
    files = sorted(RETRO_DIR.glob("*.md"))[-n:]
    parts = []
    for f in files:
        text = f.read_text()[:1500]
        parts.append(f"### {f.stem}\n{text}")
    return "\n\n".join(parts)

def gather_open_whatifs() -> str:
    """Read open items from whatif.md and prior week files."""
    parts = []
    # Permanent whatif.md
    wf = WISDOM_DIR / "whatif.md"
    if wf.exists():
        text = wf.read_text()
        # Pull Open items
        open_blocks = re.findall(
            r'(## \[WI-\d+\].*?)(?=## \[WI-|\Z)', text, re.DOTALL)
        for b in open_blocks:
            if "Status:** Open" in b or "Status: Open" in b:
                parts.append(b.strip()[:400])
    return "\n\n".join(parts)[:1200]

def gather_prior_week_items() -> str:
    """Read most recent week file to avoid duplicating items."""
    files = sorted(WHATIF_DIR.glob("????-W??.md"))
    if not files:
        return ""
    return files[-1].read_text()[:1000]

def gather_unpaid_scars() -> str:
    scars = WISDOM_DIR / "scars.md"
    if not scars.exists():
        return ""
    text = scars.read_text()
    idx = text.find("## [Scars not yet paid")
    if idx < 0:
        return ""
    return text[idx:idx + 600]


# ── Prompt ────────────────────────────────────────────────────────────────────

def build_whatif_prompt(year: int, week: int, context: dict) -> str:
    date_range = week_date_range(year, week)
    return f"""You are Allie — Bill James's personal AI for the JPods ecosystem.

Your task: generate 4 WhatIf items for the weekly prediction log.
Week: {year}-W{week:02d} ({date_range})

These are your own observations — not assigned topics. Choose domains where you
have genuine uncertainty. Post real predictions, not safe ones.

Rules:
- 4 items total. No more.
- Each must be specific enough to score (Yes/Partial/No) at the resolve date.
- Each must reflect genuine uncertainty — not something already known.
- Spread across at least 2 different domains.
- Confidence: High (>70% sure), Med (40–70%), Low (<40%)
- Resolve By: a specific date (1–8 weeks from now)
- Do NOT repeat items already posted in prior weeks (listed below).

Domains: {json.dumps(DOMAINS, indent=2)}

## Recent Work Context (retrospections)
{context.get('retrospections', '(none)')}

## Open WhatIf Items Already Tracking
{context.get('open_whatifs', '(none)')}

## Prior Week Items (do not duplicate)
{context.get('prior_week', '(none)')}

## Unpaid Scars (risks we accepted)
{context.get('unpaid_scars', '(none)')}

## Output Format

Return ONLY a markdown table with exactly these columns.
No preamble. No explanation. Just the table and a one-line "Why" for each item below it.

| ID | Domain | Question / Observation | Confidence | Resolve By | Outcome | Accurate | Worthwhile |
|----|--------|----------------------|------------|------------|---------|----------|------------|
| A-W{week:02d}-1 | XX | ... | High/Med/Low | YYYY-MM-DD | | | |
| A-W{week:02d}-2 | XX | ... | High/Med/Low | YYYY-MM-DD | | | |
| A-W{week:02d}-3 | XX | ... | High/Med/Low | YYYY-MM-DD | | | |
| A-W{week:02d}-4 | XX | ... | High/Med/Low | YYYY-MM-DD | | | |

**Why A-W{week:02d}-1:** one sentence
**Why A-W{week:02d}-2:** one sentence
**Why A-W{week:02d}-3:** one sentence
**Why A-W{week:02d}-4:** one sentence
"""


# ── LLM call ─────────────────────────────────────────────────────────────────

def call_ollama(prompt: str, model: str, timeout: int = 120) -> tuple:
    payload = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.4, "num_predict": 1024},
    }).encode()
    req = urllib.request.Request(
        OLLAMA_URL, data=payload,
        headers={"Content-Type": "application/json"}, method="POST")
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read())
            return body.get("response", "").strip(), time.time() - start, None
    except Exception as e:
        return "", time.time() - start, str(e)


# ── File writing ──────────────────────────────────────────────────────────────

def create_week_file(year: int, week: int) -> pathlib.Path:
    """Create the week file if it doesn't exist yet."""
    path = week_file_path(year, week)
    if path.exists():
        return path
    date_range = week_date_range(year, week)
    WHATIF_DIR.mkdir(parents=True, exist_ok=True)
    path.write_text(f"""# WhatIf — Week {year}-W{week:02d} ({date_range})
**Posted:** {datetime.date.today().isoformat()}

---

## Claude's Items

*(Claude Code adds items at session end — see CLAUDE.md session protocol)*

| ID | Domain | Question / Observation | Confidence | Resolve By | Outcome | Accurate | Worthwhile |
|----|--------|----------------------|------------|------------|---------|----------|------------|

---

## Allie's Items

| ID | Domain | Question / Observation | Confidence | Resolve By | Outcome | Accurate | Worthwhile |
|----|--------|----------------------|------------|------------|---------|----------|------------|

---

## Assessment Log

*(Items assessed as they resolve)*

---
""")
    return path

def append_allie_items(path: pathlib.Path, response: str, year: int, week: int):
    """Replace the empty Allie's Items section with the generated content."""
    text = path.read_text()
    marker = "## Allie's Items\n\n| ID | Domain"
    if marker not in text:
        # Append at end
        with path.open("a") as f:
            f.write(f"\n## Allie's Items\n\n{response}\n")
        return

    # Replace from marker through the next --- or end of section
    before = text[:text.index(marker)]
    after_start = text.index(marker) + len("## Allie's Items\n")
    # Find next section separator after the table
    rest = text[after_start:]
    sep_idx = rest.find("\n---")
    after = rest[sep_idx:] if sep_idx >= 0 else ""

    new_text = before + f"## Allie's Items\n\n{response}\n" + after
    path.write_text(new_text)


# ── Aggregate scoring ─────────────────────────────────────────────────────────

def update_aggregate():
    """Parse all week files and recompute aggregate.md scores."""
    agg_path = WHATIF_DIR / "aggregate.md"
    totals = {"Claude": {"posted": 0, "assessed": 0, "accurate": 0, "worthwhile": 0},
              "Allie":  {"posted": 0, "assessed": 0, "accurate": 0, "worthwhile": 0}}
    domain_totals = {}

    for wf in sorted(WHATIF_DIR.glob("????-W??.md")):
        text = wf.read_text()
        for line in text.splitlines():
            if not line.startswith("| "):
                continue
            cols = [c.strip() for c in line.split("|")]
            if len(cols) < 9:
                continue
            item_id = cols[1]
            if not (item_id.startswith("C-") or item_id.startswith("A-")):
                continue
            author = "Claude" if item_id.startswith("C-") else "Allie"
            domain = cols[2] if len(cols) > 2 else "?"
            outcome = cols[6] if len(cols) > 6 else ""
            accurate = cols[7] if len(cols) > 7 else ""
            worthwhile = cols[8] if len(cols) > 8 else ""

            totals[author]["posted"] += 1
            domain_totals.setdefault(domain, {"items": 0, "assessed": 0,
                                               "accurate": 0, "worthwhile": 0})
            domain_totals[domain]["items"] += 1

            if outcome.strip():  # has an outcome = assessed
                totals[author]["assessed"] += 1
                domain_totals[domain]["assessed"] += 1
                if accurate.strip().lower() in ("yes", "partial"):
                    totals[author]["accurate"] += 1
                    domain_totals[domain]["accurate"] += 1
                if worthwhile.strip().lower() in ("yes", "partial"):
                    totals[author]["worthwhile"] += 1
                    domain_totals[domain]["worthwhile"] += 1

    def pct(n, d):
        return f"{100 * n // d}%" if d > 0 else "—"

    grand_posted = sum(v["posted"] for v in totals.values())
    grand_assessed = sum(v["assessed"] for v in totals.values())
    grand_acc = sum(v["accurate"] for v in totals.values())
    grand_worth = sum(v["worthwhile"] for v in totals.values())

    lines = [
        "# WhatIf Aggregate — Scoring Dashboard",
        f"**Updated:** {datetime.date.today().isoformat()}",
        "",
        "---",
        "",
        "## All-Time Totals",
        "",
        "| Author | Posted | Assessed | % Complete | % Accurate | % Worthwhile |",
        "|--------|--------|----------|------------|------------|--------------|",
    ]
    for author, v in totals.items():
        lines.append(
            f"| {author} | {v['posted']} | {v['assessed']} | "
            f"{pct(v['assessed'], v['posted'])} | "
            f"{pct(v['accurate'], v['assessed'])} | "
            f"{pct(v['worthwhile'], v['assessed'])} |"
        )
    lines += [
        f"| **Total** | **{grand_posted}** | **{grand_assessed}** | "
        f"**{pct(grand_assessed, grand_posted)}** | "
        f"**{pct(grand_acc, grand_assessed)}** | "
        f"**{pct(grand_worth, grand_assessed)}** |",
        "",
        "---",
        "",
        "## By Domain",
        "",
        "| Domain | Items | Assessed | % Accurate | % Worthwhile |",
        "|--------|-------|----------|------------|--------------|",
    ]
    for domain, v in sorted(domain_totals.items()):
        lines.append(
            f"| {domain} | {v['items']} | {v['assessed']} | "
            f"{pct(v['accurate'], v['assessed'])} | "
            f"{pct(v['worthwhile'], v['assessed'])} |"
        )

    lines += [
        "",
        "---",
        "",
        "## What to Watch For",
        "",
        "**If % Accurate stays above 70%:** Real predictive knowledge. Trust judgment there.",
        "**If % Accurate is 40–70%:** Informed uncertainty. Use as flag, not conclusion.",
        "**If % Accurate is below 40%:** Noise. Questions too hard or domain knowledge thin.",
        "**If % Worthwhile > % Accurate:** Good questions, overconfident answers.",
        "**If % Accurate > % Worthwhile:** Predicting things that don't matter. Shift domains.",
    ]

    agg_path.write_text("\n".join(lines) + "\n")
    print(f"  aggregate.md updated — {grand_posted} items, {grand_assessed} assessed")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Allie weekly WhatIf generator")
    parser.add_argument("--model",   default=DEFAULT_MODEL)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--score",   action="store_true", help="Update aggregate.md only")
    parser.add_argument("--week",    type=int, help="Override ISO week number")
    args = parser.parse_args()

    year, week = current_iso_week()
    if args.week:
        week = args.week

    if args.score:
        update_aggregate()
        return

    print(f"[allie-whatif] {year}-W{week:02d} | model: {args.model}")

    context = {
        "retrospections": gather_recent_retrospections(3),
        "open_whatifs":   gather_open_whatifs(),
        "prior_week":     gather_prior_week_items(),
        "unpaid_scars":   gather_unpaid_scars(),
    }

    prompt = build_whatif_prompt(year, week, context)

    if args.dry_run:
        print(f"\n── PROMPT ({len(prompt)} chars) ──\n{prompt}\n── END ──\n")
        return

    print(f"  Calling {args.model}...")
    response, elapsed, error = call_ollama(prompt, args.model)

    if error:
        print(f"  ERROR: {error}")
        # Fallback
        if args.model != FALLBACK_MODEL:
            print(f"  Trying fallback: {FALLBACK_MODEL}")
            response, elapsed, error = call_ollama(prompt, FALLBACK_MODEL)
        if error:
            print(f"  FALLBACK ERROR: {error} — no items posted this week")
            return

    print(f"  Generated in {elapsed:.0f}s")

    path = create_week_file(year, week)
    append_allie_items(path, response, year, week)
    update_aggregate()

    print(f"  Written: {path}")


if __name__ == "__main__":
    main()

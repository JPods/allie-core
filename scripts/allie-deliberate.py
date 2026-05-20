#!/usr/bin/env python3
"""
allie-deliberate.py — Allie's multi-LLM deliberative loop

Three-stage hallucination probe. Each model plays a distinct role:

  Stage 1 — Reasoner  (deepseek-r1:8b)  : makes the claim or synthesis
  Stage 2 — Adversary (athena-reason)   : probes for hallucinations, contradictions, overreach
  Stage 3 — Judge     (llama3.2)        : adjudicates; produces the final verdict

Optional second round: adversary responds to the judge's verdict, judge has final word.

Usage:
  python3 allie-deliberate.py --prompt "Should JPods use MQTT for pod-to-pod comms?"
  python3 allie-deliberate.py --file thoughts/2026-04-27-reflect.md
  python3 allie-deliberate.py --prompt "..." --rounds 2
  python3 allie-deliberate.py --dry-run --prompt "..."
  python3 allie-deliberate.py --prompt "..." \\
      --reasoner deepseek-r1:8b --adversary athena-reason --judge llama3.2

Output: ~/Allie/thoughts/YYYY-MM-DD-deliberate-HHMMSS.md
Log:    ~/Allie/config/agent_log.jsonl
"""

import sys
import json
import datetime
import argparse
import pathlib
import urllib.request
import urllib.error
import time

ALLIE          = pathlib.Path("/Users/williamjames/Allie")
OLLAMA_URL     = "http://localhost:11434/api/generate"

DEFAULT_REASONER  = "deepseek-r1:8b"
DEFAULT_ADVERSARY = "athena-reason:latest"
DEFAULT_JUDGE     = "llama3.2:latest"


# ── Ollama call ────────────────────────────────────────────────────────────────

def call_ollama(prompt: str, model: str, timeout: int) -> tuple:
    """Returns (response_text, elapsed_seconds, error_or_None)."""
    start = time.time()
    payload = json.dumps({
        "model": model,
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
            return body.get("response", "").strip(), time.time() - start, None
    except urllib.error.URLError as e:
        return "", time.time() - start, str(e)
    except Exception as e:
        return "", time.time() - start, str(e)


def run_stage(label: str, model: str, prompt: str, timeout: int, dry_run: bool) -> tuple:
    """Run one stage. Returns (response, elapsed, error). Prints progress."""
    print(f"\n  [{label}] {model}...", end=" ", flush=True)
    if dry_run:
        print(f"\n── {label.upper()} PROMPT ──────────────────────────────────────────\n")
        print(prompt)
        return f"(dry-run — {label} response)", 0.0, None
    response, elapsed, error = call_ollama(prompt, model, timeout)
    if error:
        print(f"ERROR: {error}")
    else:
        print(f"{elapsed:.0f}s | {len(response)} chars")
    return response, elapsed, error


# ── Role prompts ───────────────────────────────────────────────────────────────

def prompt_reasoner(question: str) -> str:
    return f"""\
You are Allie's reasoning engine — the first voice in a three-stage deliberation.
Your job: produce the best synthesis or answer you can given the question below.

Rules:
- Be specific. Name files, decisions, and evidence by name.
- If you are uncertain, say so explicitly and say why.
- Do not hedge without reason. A vague answer is a wrong answer.
- State any assumptions you are making.

This output will be scrutinized by an adversarial model looking for hallucinations
and overreach. Write as if you will be held accountable for every sentence.

Question / Context:
{question}
"""


def prompt_adversary(question: str, claim: str) -> str:
    return f"""\
You are Athena — the adversarial observer in a three-stage deliberation.
A reasoner has produced the claim below. Your job: probe it hard.

Look specifically for:
- Hallucinations: assertions stated as fact without supporting evidence
- Contradictions: internal inconsistencies, or conflicts with the following known invariants
- Overreach: conclusions that go further than the evidence supports
- Omissions: important factors the reasoner ignored that change the answer
- Vagueness used to avoid commitment

JPods invariants you know to be non-negotiable:
1. CCW traffic circles — pods move counter-clockwise viewed from above
2. One-way guideways — inbound and outbound are never interchangeable
3. No direct south exit from a station — southbound always adds ~160m turnabout
4. Physical reality is the final arbiter when environments disagree
5. Loud failure at the boundary beats silent degradation
6. Retry is not diagnosis — repeated failure demands root cause, not re-run

How to critique:
- Quote the exact phrase you are challenging
- State what is wrong with it and why
- Do not soften. Do not award partial credit for good effort.
- If the claim is sound, say so — a false alarm wastes more time than a missed one.

Original question:
{question}

Reasoner's claim:
{claim}
"""


def prompt_judge(question: str, claim: str, critique: str, round_num: int = 1) -> str:
    round_note = f" (Round {round_num})" if round_num > 1 else ""
    return f"""\
You are the adjudicator in a three-stage deliberation{round_note}.
You have a reasoner's claim and an adversary's critique.

Your job:
1. For each critique point: rule whether it stands or fails, with one sentence of reasoning
2. Identify what the reasoner got right that the adversary did not challenge or wrongly challenged
3. Produce a revised synthesis that incorporates the valid critique points
4. State your final verdict in one of three categories:
   - SUBSTANTIALLY CORRECT: the original claim holds with minor corrections
   - PARTIALLY CORRECT: significant portions need revision (state which)
   - SUBSTANTIALLY WRONG: the claim has a fundamental flaw (state what)

Rules:
- Evidence and logic only. Do not award points for style or confidence.
- Be specific. If a critique point stands, say exactly how the synthesis changes.
- If both the reasoner and adversary are wrong, say so.

Original question:
{question}

Reasoner's claim:
{claim}

Adversary's critique:
{critique}
"""


def prompt_adversary_round2(question: str, verdict: str) -> str:
    return f"""\
You are Athena — the adversarial observer. The judge has issued a verdict.
Your job: a final check. Does the verdict itself introduce new problems?

Look for:
- New assertions in the verdict not present in the original claim
- Overreach in the judge's corrections
- Anything the judge missed that you originally flagged

If the verdict is sound, say so clearly. Do not critique for its own sake.

Original question:
{question}

Judge's verdict:
{verdict}
"""


# ── Output ─────────────────────────────────────────────────────────────────────

def write_output(thoughts_dir: pathlib.Path, date_str: str, ts_str: str,
                 question: str, stages: list, verdict: str,
                 reasoner: str, adversary: str, judge: str) -> pathlib.Path:
    thoughts_dir.mkdir(parents=True, exist_ok=True)
    out_path = thoughts_dir / f"{date_str}-deliberate-{ts_str}.md"

    lines = [
        f"# Allie Deliberation — {date_str} {ts_str[:2]}:{ts_str[2:4]}:{ts_str[4:]}",
        f"*Reasoner: {reasoner} | Adversary: {adversary} | Judge: {judge}*",
        "",
        "---",
        "",
        f"## Question",
        "",
        question,
        "",
    ]

    for stage_name, model, response, elapsed in stages:
        lines += [
            f"---",
            "",
            f"## {stage_name}  *({model}, {elapsed:.0f}s)*",
            "",
            response,
            "",
        ]

    lines += [
        "---",
        "",
        "## Final Verdict",
        "",
        verdict,
        "",
    ]

    out_path.write_text("\n".join(lines))
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
        description="Allie deliberative loop — multi-LLM hallucination probe"
    )
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--prompt", help="Question or claim to deliberate on")
    src.add_argument("--file",   help="File whose contents are used as the question/context")

    parser.add_argument("--reasoner",  default=DEFAULT_REASONER,  help=f"Stage 1 model (default: {DEFAULT_REASONER})")
    parser.add_argument("--adversary", default=DEFAULT_ADVERSARY, help=f"Stage 2 model (default: {DEFAULT_ADVERSARY})")
    parser.add_argument("--judge",     default=DEFAULT_JUDGE,     help=f"Stage 3 model (default: {DEFAULT_JUDGE})")
    parser.add_argument("--rounds",    type=int, default=1, choices=[1, 2],
                        help="Deliberation rounds (1=default, 2=adversary responds to verdict)")
    parser.add_argument("--timeout",   type=int, default=300, help="Seconds per model call (default: 300)")
    parser.add_argument("--dry-run",   action="store_true",   help="Print prompts; do not call models")
    args = parser.parse_args()

    # Resolve question
    if args.file:
        fpath = pathlib.Path(args.file)
        if not fpath.exists():
            print(f"ERROR: file not found: {fpath}")
            sys.exit(1)
        question = fpath.read_text()
        print(f"[allie-deliberate] input: {fpath.name} ({len(question)} chars)")
    else:
        question = args.prompt
        print(f"[allie-deliberate] prompt: {question[:80]}{'...' if len(question)>80 else ''}")

    print(f"  reasoner={args.reasoner}  adversary={args.adversary}  judge={args.judge}  rounds={args.rounds}")

    date_str = datetime.date.today().isoformat()
    ts_str   = datetime.datetime.now().strftime("%H%M%S")
    thoughts_dir = ALLIE / "thoughts"
    stages = []

    # ── Stage 1: Reasoner ──
    claim, elapsed, error = run_stage(
        "Stage 1 — Reasoner", args.reasoner,
        prompt_reasoner(question), args.timeout, args.dry_run
    )
    if error and not args.dry_run:
        print("  Reasoner failed — aborting.")
        sys.exit(1)
    stages.append(("Stage 1 — Reasoner", args.reasoner, claim, elapsed))

    # ── Stage 2: Adversary ──
    critique, elapsed, error = run_stage(
        "Stage 2 — Adversary", args.adversary,
        prompt_adversary(question, claim), args.timeout, args.dry_run
    )
    if error and not args.dry_run:
        print("  Adversary failed — aborting.")
        sys.exit(1)
    stages.append(("Stage 2 — Adversary", args.adversary, critique, elapsed))

    # ── Stage 3: Judge ──
    verdict, elapsed, error = run_stage(
        "Stage 3 — Judge", args.judge,
        prompt_judge(question, claim, critique), args.timeout, args.dry_run
    )
    if error and not args.dry_run:
        print("  Judge failed — aborting.")
        sys.exit(1)
    stages.append(("Stage 3 — Judge", args.judge, verdict, elapsed))

    # ── Optional Round 2 ──
    if args.rounds == 2:
        critique2, elapsed, error = run_stage(
            "Round 2 — Adversary", args.adversary,
            prompt_adversary_round2(question, verdict), args.timeout, args.dry_run
        )
        if not error or args.dry_run:
            stages.append(("Round 2 — Adversary", args.adversary, critique2, elapsed))

            verdict2, elapsed, error = run_stage(
                "Round 2 — Final Judge", args.judge,
                prompt_judge(question, verdict, critique2, round_num=2),
                args.timeout, args.dry_run
            )
            if not error or args.dry_run:
                stages.append(("Round 2 — Final Judge", args.judge, verdict2, elapsed))
                verdict = verdict2

    if args.dry_run:
        return

    # Write output
    out_path = write_output(
        thoughts_dir, date_str, ts_str,
        question, stages, verdict,
        args.reasoner, args.adversary, args.judge
    )
    print(f"\n  Written: {out_path}")

    log_event({
        "event":     "allie-deliberate",
        "rounds":    args.rounds,
        "reasoner":  args.reasoner,
        "adversary": args.adversary,
        "judge":     args.judge,
        "stages":    len(stages),
        "chars":     {s[0]: len(s[2]) for s in stages},
        "output":    str(out_path),
    })

    # Print final verdict to stdout
    print(f"\n{'─'*60}")
    print("FINAL VERDICT")
    print('─'*60)
    print(verdict)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
allie_corpus_log.py — Shared training corpus logger

Every agent (Allie, Alice, Natalie, Noelle, Nora) writes to the same corpus.
Each entry is a labeled prompt→response pair with metadata about who generated
it, whether the response was verified, and what the ground truth was.

Over time this corpus is used to fine-tune a shared local model.

Corpus file: ~/Allie/training/corpus.jsonl
One JSON object per line. Never deleted — append only.

Usage:
  from allie_corpus_log import CorpusLog
  log = CorpusLog()
  log.add(
      agent="allie",
      domain="route-time",
      prompt="Why is station S02 showing 35 min travel time at near-zero demand?",
      response="Topology bug — direct south guideway missing. Turnabout adds ~160m.",
      verified=True,
      ground_truth="diag_grid.py confirmed route ratio 1.1× after fix.",
      tags=["topology", "route-time", "diagnosis"],
  )

CLI:
  python3 allie_corpus_log.py add --agent allie --domain route-time \\
      --prompt "..." --response "..." --verified --ground-truth "..."
  python3 allie_corpus_log.py stats
  python3 allie_corpus_log.py export --format jsonl --out /tmp/corpus_export.jsonl
"""

import json
import sys
import datetime
import pathlib
import argparse

ALLIE = pathlib.Path("/Users/williamjames/Allie")
CORPUS_PATH = ALLIE / "training" / "corpus.jsonl"

AGENTS  = ["allie", "alice", "athena", "natalie", "noelle", "nora"]
DOMAINS = ["route-time", "sketchup", "physical", "webclerk", "writing", "universal"]


class CorpusLog:
    def __init__(self, path: pathlib.Path = CORPUS_PATH):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def add(
        self,
        agent: str,
        domain: str,
        prompt: str,
        response: str,
        verified: bool = False,
        ground_truth: str = "",
        tags: list | None = None,
        model: str = "",
        session_ref: str = "",
    ) -> dict:
        """
        Append one training entry to the corpus.

        verified=True means a human (Bill) or a physical outcome confirmed
        the response is correct. Only verified entries should be used for
        fine-tuning without review.

        ground_truth is the evidence: physical outcome, Bill's decision,
        diag_grid.py result, etc.
        """
        entry = {
            "ts":           datetime.datetime.now().isoformat(timespec="seconds"),
            "agent":        agent,
            "domain":       domain,
            "prompt":       prompt,
            "response":     response,
            "verified":     verified,
            "ground_truth": ground_truth,
            "tags":         tags or [],
            "model":        model,
            "session_ref":  session_ref,
        }
        with self.path.open("a") as f:
            f.write(json.dumps(entry) + "\n")
        return entry

    def stats(self) -> dict:
        if not self.path.exists():
            return {"total": 0, "verified": 0, "by_agent": {}, "by_domain": {}}
        entries = [json.loads(l) for l in self.path.read_text().splitlines() if l.strip()]
        by_agent: dict = {}
        by_domain: dict = {}
        verified = 0
        for e in entries:
            a = e.get("agent", "unknown")
            d = e.get("domain", "unknown")
            by_agent[a] = by_agent.get(a, 0) + 1
            by_domain[d] = by_domain.get(d, 0) + 1
            if e.get("verified"):
                verified += 1
        return {
            "total":     len(entries),
            "verified":  verified,
            "unverified": len(entries) - verified,
            "by_agent":  by_agent,
            "by_domain": by_domain,
            "path":      str(self.path),
        }

    def export(self, verified_only: bool = False,
               domain: str | None = None,
               agent: str | None = None) -> list:
        """Return entries as a list, optionally filtered."""
        if not self.path.exists():
            return []
        entries = [json.loads(l) for l in self.path.read_text().splitlines() if l.strip()]
        if verified_only:
            entries = [e for e in entries if e.get("verified")]
        if domain:
            entries = [e for e in entries if e.get("domain") == domain]
        if agent:
            entries = [e for e in entries if e.get("agent") == agent]
        return entries

    def export_for_finetuning(self, out_path: pathlib.Path,
                               verified_only: bool = True) -> int:
        """
        Write a fine-tuning JSONL in Ollama/llama.cpp format:
          {"prompt": "...", "response": "..."}
        Returns number of entries written.
        """
        entries = self.export(verified_only=verified_only)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w") as f:
            for e in entries:
                f.write(json.dumps({
                    "prompt":   e["prompt"],
                    "response": e["response"],
                }) + "\n")
        return len(entries)


# ── CLI ────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Allie/Alice shared corpus logger")
    sub = parser.add_subparsers(dest="cmd")

    # add
    p = sub.add_parser("add", help="Add a training entry")
    p.add_argument("--agent",        required=True, choices=AGENTS)
    p.add_argument("--domain",       required=True, choices=DOMAINS)
    p.add_argument("--prompt",       required=True)
    p.add_argument("--response",     required=True)
    p.add_argument("--verified",     action="store_true")
    p.add_argument("--ground-truth", default="")
    p.add_argument("--tags",         nargs="*", default=[])
    p.add_argument("--model",        default="")
    p.add_argument("--session-ref",  default="")

    # stats
    sub.add_parser("stats", help="Show corpus statistics")

    # export
    p = sub.add_parser("export", help="Export corpus entries")
    p.add_argument("--format",        choices=["jsonl", "finetuning"], default="jsonl")
    p.add_argument("--out",           default=None)
    p.add_argument("--verified-only", action="store_true")
    p.add_argument("--domain",        default=None, choices=DOMAINS + [None])
    p.add_argument("--agent",         default=None, choices=AGENTS + [None])

    args = parser.parse_args()
    log = CorpusLog()

    if args.cmd == "add":
        entry = log.add(
            agent=args.agent,
            domain=args.domain,
            prompt=args.prompt,
            response=args.response,
            verified=args.verified,
            ground_truth=args.ground_truth,
            tags=args.tags,
            model=args.model,
            session_ref=args.session_ref,
        )
        print(f"Added ({'verified' if entry['verified'] else 'unverified'}) "
              f"[{entry['agent']}|{entry['domain']}]: {entry['prompt'][:60]}")

    elif args.cmd == "stats":
        s = log.stats()
        print(f"\nCorpus: {s['path']}")
        print(f"  Total: {s['total']}  Verified: {s['verified']}  Unverified: {s['unverified']}")
        print(f"\n  By agent:")
        for a, n in sorted(s["by_agent"].items()):
            print(f"    {a:12} {n}")
        print(f"\n  By domain:")
        for d, n in sorted(s["by_domain"].items()):
            print(f"    {d:15} {n}")

    elif args.cmd == "export":
        out = pathlib.Path(args.out) if args.out else (
            ALLIE / "training" / f"export_{datetime.date.today().isoformat()}.jsonl"
        )
        if args.format == "finetuning":
            n = log.export_for_finetuning(out, verified_only=args.verified_only)
            print(f"Fine-tuning export: {n} entries → {out}")
        else:
            entries = log.export(
                verified_only=args.verified_only,
                domain=args.domain,
                agent=args.agent,
            )
            out.parent.mkdir(parents=True, exist_ok=True)
            with out.open("w") as f:
                for e in entries:
                    f.write(json.dumps(e) + "\n")
            print(f"Exported {len(entries)} entries → {out}")

    else:
        parser.print_help()


if __name__ == "__main__":
    main()

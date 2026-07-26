#!/usr/bin/env python3
"""leftshoe Agent API — how any agent connects to the shared store.

Every agent on the team is empowered to:
  1. ADD entries — scars, values, judgments from their domain
  2. CHALLENGE entries — flag entries they believe are wrong or stale
  3. QUERY entries — search before acting
  4. BRIEF — get the current team intelligence

Agents don't need permission. They need judgment. If an entry is wrong,
challenge it. If a lesson is learned, add it. The store improves through
use, not through gatekeeping.

Usage by any agent:

    from leftshoe_agent_api import LeftShoe

    ls = LeftShoe(agent="alice")

    # Add a lesson from commerce observations
    ls.add("values",
        text="Customers who browse the library before registering convert 3x higher",
        context="Alice observation, 2026-07-23, based on 47 registration events",
        weight=7)

    # Record a scar
    ls.record_scar(
        action="Sent invoice email without checking customer email was valid",
        consequence="Bounce rate spiked, 12 emails returned undeliverable",
        tfts="Validate email deliverability before batch sends. The cost of a bounce is trust.",
        domain="WC3", severity="scar")

    # Challenge an existing entry
    ls.challenge(collection="scars", entry_id="scars_0003",
        reason="This scar about hardcoded paths was from Mac→IT15. On Hostinger static deploy, paths are relative by design.",
        agent="andi")

    # Query before acting
    results = ls.query("nginx permissions deploy")

    # Get briefing
    brief = ls.brief()
"""
import json
import os
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

try:
    import chromadb
except ImportError:
    chromadb = None


class LeftShoe:
    """Connection to the leftshoe shared intelligence store."""

    def __init__(self, agent: str = "unknown", allie_home: str = None):
        self.agent = agent
        self.home = Path(allie_home) if allie_home else Path.home() / "Allie"
        self.store_path = self.home / ".chroma_db_leftshoe"
        self.retro_path = self.home / "retro.db"
        self.challenges_path = self.home / "process" / "inbox"
        self._client = None

    @property
    def client(self):
        if self._client is None:
            if chromadb is None:
                raise ImportError("pip install chromadb")
            self._client = chromadb.PersistentClient(path=str(self.store_path))
        return self._client

    def _collection(self, name):
        return self.client.get_or_create_collection(
            name=name, metadata={"hnsw:space": "cosine"})

    # ------------------------------------------------------------------
    # ADD — contribute to the store
    # ------------------------------------------------------------------

    def add(self, collection: str, text: str, context: str = "",
            weight: int = 5, source: str = "agent"):
        """Add an entry to a leftshoe collection."""
        if collection not in ("values", "scars", "relationships", "judgments"):
            raise ValueError(f"Collection must be values/scars/relationships/judgments, got {collection}")

        coll = self._collection(collection)
        dt = datetime.now(timezone.utc).isoformat()
        doc_id = f"{collection}_{self.agent}_{int(time.time())}"

        coll.add(
            ids=[doc_id],
            documents=[text],
            metadatas=[{
                "context": context,
                "weight": weight,
                "dt": dt,
                "source": source,
                "agent": self.agent,
            }]
        )
        return doc_id

    def record_scar(self, action: str, consequence: str, tfts: str,
                    domain: str = "", severity: str = "lesson", tags: str = ""):
        """Record a structured experience to retro.db. All three fields required."""
        if not action or not consequence or not tfts:
            raise ValueError("All three fields required: action, consequence, tfts. This is the discipline.")

        db = sqlite3.connect(str(self.retro_path))
        dt = datetime.now(timezone.utc).isoformat()
        db.execute(
            """INSERT INTO experience (dt, action, consequence, tfts, domain, tags, agent, session, severity)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (dt, action, consequence, tfts, domain, tags, self.agent,
             datetime.now(timezone.utc).strftime('%Y-%m-%d'), severity)
        )
        db.commit()
        rid = db.execute("SELECT last_insert_rowid()").fetchone()[0]
        db.close()
        return rid

    # ------------------------------------------------------------------
    # CHALLENGE — flag entries that may be wrong or stale
    # ------------------------------------------------------------------

    def challenge(self, collection: str, entry_id: str, reason: str,
                  agent: str = None):
        """Challenge an existing entry. Doesn't delete — creates a challenge
        record for team review. The team decides, not one agent."""
        challenge = {
            "type": "challenge",
            "collection": collection,
            "entry_id": entry_id,
            "reason": reason,
            "challenger": agent or self.agent,
            "dt": datetime.now(timezone.utc).isoformat(),
        }

        # Write challenge to process/inbox for team review
        self.challenges_path.mkdir(parents=True, exist_ok=True)
        ts = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S')
        path = self.challenges_path / f"{ts}-challenge-{self.agent}.json"
        path.write_text(json.dumps(challenge, indent=2))

        # Also add a note to retro.db
        self.record_scar(
            action=f"Challenged leftshoe entry {entry_id} in {collection}",
            consequence=f"Reason: {reason}",
            tfts=f"Entry may be stale or wrong. Team review needed. Challenger: {agent or self.agent}",
            domain="ALLIE", severity="lesson", tags="challenge,leftshoe"
        )
        return str(path)

    # ------------------------------------------------------------------
    # QUERY — search before acting
    # ------------------------------------------------------------------

    def query(self, text: str, n: int = 5) -> list:
        """Search across all collections for relevant entries."""
        results = []
        for coll_name in ("values", "scars", "relationships", "judgments"):
            coll = self._collection(coll_name)
            if coll.count() == 0:
                continue
            r = coll.query(query_texts=[text], n_results=min(n, coll.count()))
            for i, doc in enumerate(r["documents"][0]):
                meta = r["metadatas"][0][i]
                dist = r["distances"][0][i] if r.get("distances") else 0
                results.append({
                    "collection": coll_name,
                    "text": doc,
                    "context": meta.get("context", ""),
                    "agent": meta.get("agent", ""),
                    "weight": meta.get("weight", 0),
                    "distance": dist,
                })
        results.sort(key=lambda r: r["distance"])
        return results[:n]

    def query_retro(self, terms: str, limit: int = 5) -> list:
        """Search retro.db for relevant experiences."""
        db = sqlite3.connect(str(self.retro_path))
        db.row_factory = sqlite3.Row
        try:
            rows = db.execute("""
                SELECT e.* FROM experience_fts f
                JOIN experience e ON e.id = f.rowid
                WHERE experience_fts MATCH ?
                ORDER BY rank LIMIT ?
            """, (terms, limit)).fetchall()
            return [dict(r) for r in rows]
        except Exception:
            return []
        finally:
            db.close()

    # ------------------------------------------------------------------
    # BRIEF — get current team intelligence
    # ------------------------------------------------------------------

    def brief(self) -> str:
        """Return the full identity briefing as text."""
        lines = [f"leftshoe briefing for {self.agent}", "=" * 50, ""]
        for coll_name in ("values", "scars", "relationships", "judgments"):
            coll = self._collection(coll_name)
            if coll.count() == 0:
                continue
            result = coll.get(include=["documents", "metadatas"])
            entries = list(zip(result["documents"], result["metadatas"]))
            entries.sort(key=lambda e: e[1].get("weight", 0), reverse=True)
            top = [e for e in entries if e[1].get("weight", 0) >= 7][:5]

            lines.append(f"── {coll_name.upper()} ──")
            for doc, meta in top:
                lines.append(f"  • {doc[:120]}")
            lines.append("")

        # Recent retro.db
        db = sqlite3.connect(str(self.retro_path))
        db.row_factory = sqlite3.Row
        try:
            rows = db.execute("SELECT * FROM experience ORDER BY dt DESC LIMIT 5").fetchall()
            if rows:
                lines.append("── RECENT EXPERIENCES ──")
                for r in rows:
                    lines.append(f"  #{r['id']} [{r['domain']}] {r['tfts'][:100]}")
                lines.append("")
        except Exception:
            pass
        finally:
            db.close()

        return "\n".join(lines)

    # ------------------------------------------------------------------
    # STATS
    # ------------------------------------------------------------------

    def stats(self) -> dict:
        """Return store statistics."""
        s = {}
        for name in ("values", "scars", "relationships", "judgments"):
            s[name] = self._collection(name).count()

        db = sqlite3.connect(str(self.retro_path))
        try:
            s["retro_total"] = db.execute("SELECT COUNT(*) FROM experience").fetchone()[0]
        except Exception:
            s["retro_total"] = 0
        finally:
            db.close()

        return s


# ------------------------------------------------------------------
# CLI for agents running as scripts
# ------------------------------------------------------------------

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="leftshoe agent API")
    p.add_argument("--agent", default="cli", help="Agent name")
    sub = p.add_subparsers(dest="cmd")

    s = sub.add_parser("add")
    s.add_argument("--collection", required=True)
    s.add_argument("--text", required=True)
    s.add_argument("--context", default="")
    s.add_argument("--weight", type=int, default=5)

    s = sub.add_parser("scar")
    s.add_argument("--action", required=True)
    s.add_argument("--consequence", required=True)
    s.add_argument("--tfts", required=True)
    s.add_argument("--domain", default="")
    s.add_argument("--severity", default="lesson")
    s.add_argument("--tags", default="")

    s = sub.add_parser("challenge")
    s.add_argument("--collection", required=True)
    s.add_argument("--entry-id", required=True)
    s.add_argument("--reason", required=True)

    s = sub.add_parser("query")
    s.add_argument("terms", nargs="+")

    sub.add_parser("brief")
    sub.add_parser("stats")

    args = p.parse_args()
    ls = LeftShoe(agent=args.agent)

    if args.cmd == "add":
        doc_id = ls.add(args.collection, args.text, args.context, args.weight)
        print(f"Added: {doc_id}")
    elif args.cmd == "scar":
        rid = ls.record_scar(args.action, args.consequence, args.tfts,
                             args.domain, args.severity, args.tags)
        print(f"Recorded scar #{rid}")
    elif args.cmd == "challenge":
        path = ls.challenge(args.collection, args.entry_id, args.reason)
        print(f"Challenge filed: {path}")
    elif args.cmd == "query":
        for r in ls.query(" ".join(args.terms)):
            print(f"  [{r['collection']}] {r['text'][:100]}")
    elif args.cmd == "brief":
        print(ls.brief())
    elif args.cmd == "stats":
        for k, v in ls.stats().items():
            print(f"  {k}: {v}")
    else:
        p.print_help()

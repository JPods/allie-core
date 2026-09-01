#!/usr/bin/env python3
"""
Episode Ingestion — Seed episodic memory from existing TFTS files and retro.db scars.

Usage:
    python3 alice-episode-ingest.py              # full seed (skip existing)
    python3 alice-episode-ingest.py --force      # re-index everything
    python3 alice-episode-ingest.py --incremental # only new since last run

Sources:
    1. TFTS files in ~/Allie/process/inbox/*-tfts.md
    2. retro.db experience table (scars, lessons, wins)

Writes to:
    - PostgreSQL allie.episodes table
    - ChromaDB alice_episodes collection (in .chroma_db_alice/)

Established 2026-08-31.
"""

import sys
import os
import re
import json
import time
import hashlib
import pathlib
import sqlite3
import datetime

ALLIE_HOME = pathlib.Path.home() / "Allie"
INBOX = ALLIE_HOME / "process" / "inbox"
RETRO_DB = ALLIE_HOME / "retro.db"
CHROMA_DIR = str(ALLIE_HOME / ".chroma_db_alice")
EP_COLLECTION = "alice_episodes"
DB_NAME = "allie"
DB_USER = os.environ.get("PGUSER", os.getlogin())
DB_HOST = "localhost"


def _now_ms():
    return int(time.time() * 1000)


def _ts_from_filename(filename):
    """Extract timestamp from YYYYMMDDTHHMMSS-tfts.md filename."""
    match = re.match(r"(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})", filename)
    if match:
        y, mo, d, h, mi, s = match.groups()
        try:
            dt = datetime.datetime(int(y), int(mo), int(d), int(h), int(mi), int(s),
                                   tzinfo=datetime.timezone.utc)
            return int(dt.timestamp() * 1000)
        except Exception:
            pass
    return _now_ms()


def _parse_tfts_file(path):
    """Parse a TFTS markdown file into structured data."""
    text = path.read_text(errors="replace")
    lines = text.strip().split("\n")

    data = {
        "problem": "",
        "principle": "",
        "domain": "CROSS",
        "fault_ref": "",
        "arc": [],
    }

    current_field = None
    current_try = None

    for line in lines:
        stripped = line.strip()

        # Skip header
        if stripped.startswith("# TFTS"):
            continue

        # Field detection
        if stripped.startswith("problem:"):
            data["problem"] = stripped[len("problem:"):].strip()
            current_field = "problem"
            continue
        elif stripped.startswith("fault_ref:"):
            data["fault_ref"] = stripped[len("fault_ref:"):].strip()
            current_field = None
            continue
        elif stripped.startswith("principle:"):
            data["principle"] = stripped[len("principle:"):].strip()
            current_field = "principle"
            continue
        elif stripped.startswith("secondary principle:"):
            # Append to principle
            data["principle"] += " | Secondary: " + stripped[len("secondary principle:"):].strip()
            current_field = "principle"
            continue
        elif stripped.startswith("domain:"):
            raw = stripped[len("domain:"):].strip().strip("[]")
            data["domain"] = raw if raw else "CROSS"
            current_field = None
            continue
        elif stripped.startswith("arc:"):
            current_field = "arc"
            continue

        # Arc parsing
        if current_field == "arc":
            if stripped.startswith("- try:"):
                if current_try:
                    data["arc"].append(current_try)
                current_try = {"try": stripped[len("- try:"):].strip(), "result": "", "revealed": ""}
            elif stripped.startswith("try:"):
                if current_try:
                    data["arc"].append(current_try)
                current_try = {"try": stripped[len("try:"):].strip(), "result": "", "revealed": ""}
            elif stripped.startswith("result:") and current_try:
                current_try["result"] = stripped[len("result:"):].strip()
            elif stripped.startswith("revealed:") and current_try:
                current_try["revealed"] = stripped[len("revealed:"):].strip()
            elif current_try and stripped and not stripped.startswith("principle:") and not stripped.startswith("domain:"):
                # Continuation line
                if current_try.get("revealed"):
                    current_try["revealed"] += " " + stripped
                elif current_try.get("result"):
                    current_try["result"] += " " + stripped
            continue

        # Continuation of principle
        if current_field == "principle" and stripped:
            data["principle"] += " " + stripped

    if current_try:
        data["arc"].append(current_try)

    return data


def get_pg_conn():
    import psycopg2
    return psycopg2.connect(dbname=DB_NAME, user=DB_USER, host=DB_HOST)


def get_chroma_collection():
    import chromadb
    client = chromadb.PersistentClient(path=CHROMA_DIR)
    return client.get_or_create_collection(
        name=EP_COLLECTION,
        metadata={"hnsw:space": "cosine"},
    )


def get_existing_sources(conn):
    """Get set of source_refs already ingested."""
    with conn.cursor() as cur:
        cur.execute("SELECT source_ref FROM episodes WHERE source_ref IS NOT NULL")
        return {row[0] for row in cur.fetchall()}


def ingest_tfts_files(conn, collection, existing_sources, force=False):
    """Ingest TFTS files from process/inbox/."""
    tfts_files = sorted(INBOX.glob("*-tfts.md"))
    ingested = 0
    skipped = 0

    for path in tfts_files:
        source_ref = f"tfts:{path.name}"
        if not force and source_ref in existing_sources:
            skipped += 1
            continue

        data = _parse_tfts_file(path)
        if not data["problem"]:
            skipped += 1
            continue

        ts = _ts_from_filename(path.name)
        episode_id = f"EP-{hashlib.md5(f'tfts:{path.name}'.encode()).hexdigest()[:12]}"

        # Build narrative from arc
        narrative_parts = [f"Problem: {data['problem']}"]
        for step in data["arc"]:
            narrative_parts.append(
                f"Tried: {step['try']} → {step['result']}. "
                f"Revealed: {step['revealed']}"
            )
        narrative = "\n".join(narrative_parts)

        title = data["problem"][:200]
        principle = data["principle"] or None
        domain = data["domain"]
        outcome = "resolved" if principle else "unresolved"
        severity = "scar" if len(data["arc"]) > 2 else "lesson"

        # PostgreSQL
        try:
            with conn.cursor() as cur:
                if force:
                    cur.execute("DELETE FROM episodes WHERE source_ref = %s", (source_ref,))
                cur.execute("""
                    INSERT INTO episodes
                        (episode_id, dt_created, dt_start, episode_type, domain,
                         title, narrative, principle, actors, outcome, severity,
                         tags, source_ref)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (episode_id) DO UPDATE SET
                        narrative = EXCLUDED.narrative,
                        principle = EXCLUDED.principle
                """, (episode_id, ts, ts, "tfts", domain,
                      title, narrative, principle,
                      json.dumps(["Claude", "Bill"]),
                      outcome, severity,
                      json.dumps(["tfts", domain.lower()]),
                      source_ref))
            conn.commit()
        except Exception as e:
            print(f"  PG error for {path.name}: {e}")
            conn.rollback()
            continue

        # ChromaDB
        doc_text = f"Title: {title}\nNarrative: {narrative}\n"
        if principle:
            doc_text += f"Principle: {principle}\n"

        meta = {
            "episode_id": episode_id,
            "episode_type": "tfts",
            "domain": domain,
            "outcome": outcome,
            "severity": severity,
            "ts": datetime.datetime.fromtimestamp(
                ts / 1000, tz=datetime.timezone.utc
            ).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "source_ref": source_ref,
        }

        try:
            collection.upsert(
                ids=[episode_id],
                documents=[doc_text[:5000]],
                metadatas=[meta],
            )
        except Exception as e:
            print(f"  ChromaDB error for {path.name}: {e}")

        ingested += 1

    return ingested, skipped


def ingest_retro_scars(conn, collection, existing_sources, force=False):
    """Ingest scars/lessons/wins from retro.db."""
    if not RETRO_DB.exists():
        print("  retro.db not found, skipping")
        return 0, 0

    rdb = sqlite3.connect(str(RETRO_DB))
    rdb.row_factory = sqlite3.Row

    try:
        rows = rdb.execute(
            "SELECT id, dt, domain, severity, action, consequence, tfts, "
            "intent, tags, agent FROM experience ORDER BY id"
        ).fetchall()
    except Exception as e:
        print(f"  retro.db read error: {e}")
        rdb.close()
        return 0, 0

    ingested = 0
    skipped = 0

    for row in rows:
        source_ref = f"retro:{row['id']}"
        if not force and source_ref in existing_sources:
            skipped += 1
            continue

        rid = row["id"]
        domain = row["domain"] or "CROSS"
        severity = row["severity"] or "lesson"
        action = row["action"] or ""
        consequence = row["consequence"] or ""
        principle = row["tfts"] or ""
        intent = row["intent"] or ""
        dt_str = row["dt"] or ""
        tags_raw = row["tags"] or ""
        agent = row["agent"] or ""

        episode_id = f"EP-{hashlib.md5(f'retro:{rid}'.encode()).hexdigest()[:12]}"

        title = action[:200] if action else f"Scar #{rid}"
        narrative = f"Action: {action}\nConsequence: {consequence}"
        if intent:
            narrative = f"Intent: {intent}\n{narrative}"

        # Parse dt to ms
        ts = _now_ms()
        if dt_str:
            try:
                dt = datetime.datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
                ts = int(dt.timestamp() * 1000)
            except Exception:
                pass

        actors = ["Bill", "Claude"]
        if agent:
            actors.append(agent)

        tags = [t.strip() for t in tags_raw.split(",") if t.strip()] if tags_raw else []
        tags.append(severity)

        # PostgreSQL
        try:
            with conn.cursor() as cur:
                if force:
                    cur.execute("DELETE FROM episodes WHERE source_ref = %s", (source_ref,))
                cur.execute("""
                    INSERT INTO episodes
                        (episode_id, dt_created, dt_start, episode_type, domain,
                         title, narrative, principle, actors, outcome, severity,
                         tags, source_ref)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (episode_id) DO UPDATE SET
                        narrative = EXCLUDED.narrative,
                        principle = EXCLUDED.principle
                """, (episode_id, ts, ts, "scar", domain,
                      title, narrative, principle if principle else None,
                      json.dumps(actors),
                      "resolved" if principle else "unresolved",
                      severity,
                      json.dumps(tags),
                      source_ref))
            conn.commit()
        except Exception as e:
            print(f"  PG error for retro:{rid}: {e}")
            conn.rollback()
            continue

        # ChromaDB
        doc_text = f"Title: {title}\nNarrative: {narrative}\n"
        if principle:
            doc_text += f"Principle: {principle}\n"

        meta = {
            "episode_id": episode_id,
            "episode_type": "scar",
            "domain": domain,
            "outcome": "resolved" if principle else "unresolved",
            "severity": severity,
            "ts": dt_str or datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "source_ref": source_ref,
        }

        try:
            collection.upsert(
                ids=[episode_id],
                documents=[doc_text[:5000]],
                metadatas=[meta],
            )
        except Exception as e:
            print(f"  ChromaDB error for retro:{rid}: {e}")

        ingested += 1

    rdb.close()
    return ingested, skipped


def main():
    force = "--force" in sys.argv

    print("Episode Ingestion")
    print("=" * 50)

    # Connect
    conn = get_pg_conn()
    collection = get_chroma_collection()
    existing = get_existing_sources(conn) if not force else set()

    print(f"Existing episodes: {len(existing)}")
    print(f"Mode: {'force (re-index all)' if force else 'incremental (skip existing)'}")
    print()

    # TFTS files
    print("── TFTS Files ──")
    tfts_in, tfts_skip = ingest_tfts_files(conn, collection, existing, force)
    print(f"  Ingested: {tfts_in}, Skipped: {tfts_skip}")

    # Retro.db scars
    print("\n── Retro.db Scars ──")
    retro_in, retro_skip = ingest_retro_scars(conn, collection, existing, force)
    print(f"  Ingested: {retro_in}, Skipped: {retro_skip}")

    # Summary
    print(f"\n── Summary ──")
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM episodes")
        total = cur.fetchone()[0]
    print(f"  Total episodes in database: {total}")
    print(f"  Total episodes in ChromaDB: {collection.count()}")

    conn.close()
    print("\nDone.")


if __name__ == "__main__":
    main()

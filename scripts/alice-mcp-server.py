#!/usr/bin/env python3
"""
Alice MCP Server — Multi-capacity commerce agent.

Alice has three capacities:
  ops       — enforce standards, validate, detect anomalies (temp 0.1)
  hc        — learn patterns, build memory, propose deviations (temp 0.4)
  librarian — store intent, measure outcomes, report grades (temp 0.2)

Tools routed by capacity:
  ask_alice       → ops (enforcement voice, default)
  alice_search    → ops (shared vector store)
  alice_observe   → ops (pattern recognition loop)
  alice_recall    → ops (event history + observations)
  alice_status    → ops (health check)
  alice_quiz      → ops (knowledge testing)
  alice_learn     → hc  (curate HC vector store, build memory)
  alice_hypothesize → hc (propose deviation from standard)
  alice_debate    → ops + hc (both respond, disagreements surfaced)
  alice_record_intent → lib (record what was decided and why)
  alice_measure   → lib (measure outcome against intent)
  alice_report    → lib (grade distribution, informative gaps)

Runs as MCP over stdin/stdout. Registered via:
  claude mcp add -s user alice-commerce -- ~/Allie/venv/bin/python3 <this_file>

All exchanges logged to ~/Allie/exchange/alice-conversation.jsonl

Established 2026-08-28. Three-capacity architecture.
"""

import sys
import json
import datetime
import pathlib
import os
import time
import hashlib

# ── Config ───────────────────────��──────────────────────────────────────
ALLIE_HOME = pathlib.Path.home() / "Allie"
EXCHANGE_DIR = ALLIE_HOME / "exchange"
EXCHANGE_DIR.mkdir(parents=True, exist_ok=True)
TEACHINGS_LOG = ALLIE_HOME / "today" / "teachings.jsonl"
FACET_PATH = ALLIE_HOME / "facets" / "alice" / "facet.json"


def _log_teaching(target: str, category: str, summary: str) -> None:
    """Append to teachings.jsonl so rightshoe can report what was persisted."""
    try:
        TEACHINGS_LOG.parent.mkdir(parents=True, exist_ok=True)
        entry = {
            "dt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "target": target,
            "category": category,
            "summary": summary[:200],
        }
        with open(TEACHINGS_LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        pass


CONVERSATION_LOG = EXCHANGE_DIR / "alice-conversation.jsonl"

# Vector stores
CHROMA_DIR = str(ALLIE_HOME / ".chroma_db_alice")
CHROMA_HC_DIR = str(ALLIE_HOME / ".chroma_db_alice_hc")
COLLECTION_NAME = "alice_commerce_knowledge"
HC_COLLECTION_NAME = "alice_hc_hypotheses"
EP_COLLECTION_NAME = "alice_episodes"

# Associative recall threshold — cosine distance below this triggers automatic recall
# 0.50 = fairly strict (only close matches), tune up toward 0.60 if too few trigger
EPISODE_RECALL_THRESHOLD = 0.50

DB_NAME = "allie"
DB_USER = os.environ.get("PGUSER", os.getlogin())
DB_HOST = "localhost"

# ── Lazy imports (chromadb/psycopg2 may not be in system python) ───────

_chroma_collection = None
_chroma_hc_collection = None
_chroma_ep_collection = None
_psycopg2 = None


def _get_psycopg2():
    global _psycopg2
    if _psycopg2 is None:
        try:
            import psycopg2
            _psycopg2 = psycopg2
        except ImportError:
            return None
    return _psycopg2


def _get_collection():
    global _chroma_collection
    if _chroma_collection is None:
        try:
            import chromadb
            client = chromadb.PersistentClient(path=CHROMA_DIR)
            _chroma_collection = client.get_or_create_collection(
                name=COLLECTION_NAME,
                metadata={"hnsw:space": "cosine"},
            )
        except Exception:
            return None
    return _chroma_collection


def _get_hc_collection():
    """HC vector store — Alice's learning/hypothesis store."""
    global _chroma_hc_collection
    if _chroma_hc_collection is None:
        try:
            import chromadb
            client = chromadb.PersistentClient(path=CHROMA_HC_DIR)
            _chroma_hc_collection = client.get_or_create_collection(
                name=HC_COLLECTION_NAME,
                metadata={"hnsw:space": "cosine"},
            )
        except Exception:
            return None
    return _chroma_hc_collection


def _get_ep_collection():
    """Episodes vector store — associative recall for past episodes."""
    global _chroma_ep_collection
    if _chroma_ep_collection is None:
        try:
            import chromadb
            client = chromadb.PersistentClient(path=CHROMA_DIR)
            _chroma_ep_collection = client.get_or_create_collection(
                name=EP_COLLECTION_NAME,
                metadata={"hnsw:space": "cosine"},
            )
        except Exception:
            return None
    return _chroma_ep_collection


def _db_conn():
    pg = _get_psycopg2()
    if not pg:
        return None
    try:
        return pg.connect(dbname=DB_NAME, user=DB_USER, host=DB_HOST)
    except Exception:
        return None


def _now_ms():
    return int(time.time() * 1000)


def _now_utc():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ── Three-Capacity LLM Routing ────────���──────────────────��──────────────

OLLAMA_URL = "http://localhost:11434/api/generate"

# Model names match what agent-build.py creates
CAPACITY_MODELS = {
    "ops": "alice-ops",
    "hc": "alice-hc",
    "lib": "alice-lib",
}

# Fallback to alice:latest if capacity models not yet built
FALLBACK_MODEL = "alice:latest"


def capacity_think(capacity, prompt, context_docs=None):
    """Route a question to the right Alice capacity."""
    import urllib.request as ur

    model = CAPACITY_MODELS.get(capacity, FALLBACK_MODEL)

    if context_docs:
        context = "\n\n---\n\n".join(
            f"[Source: {d.get('source', '?')}]\n{d.get('content', '')}"
            for d in context_docs if "error" not in d
        )
        full_prompt = f"Context:\n\n{context}\n\n---\n\n{prompt}"
    else:
        full_prompt = prompt

    try:
        payload = json.dumps({
            "model": model,
            "prompt": full_prompt,
            "stream": False,
        }).encode()
        req = ur.Request(OLLAMA_URL, data=payload,
                         headers={"Content-Type": "application/json"})
        with ur.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read())
            return result.get("response", "")
    except Exception as e:
        # Try fallback model
        if model != FALLBACK_MODEL:
            try:
                payload = json.dumps({
                    "model": FALLBACK_MODEL,
                    "prompt": full_prompt,
                    "stream": False,
                }).encode()
                req = ur.Request(OLLAMA_URL, data=payload,
                                 headers={"Content-Type": "application/json"})
                with ur.urlopen(req, timeout=120) as resp:
                    result = json.loads(resp.read())
                    return f"[fallback to {FALLBACK_MODEL}] " + result.get("response", "")
            except Exception:
                pass
        return f"(Alice {capacity} unavailable: {e})"


# ── Logging ──────────────────────���────────────��────────────────────────

def log_exchange(role, content, tool=None, capacity=None):
    entry = {
        "ts": _now_utc(),
        "role": role,
        "content": content[:2000],
    }
    if tool:
        entry["tool"] = tool
    if capacity:
        entry["capacity"] = capacity
    try:
        with open(CONVERSATION_LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        pass


# ── Facet Read/Write ──────────────────────────────────────────────────

def _read_facet():
    try:
        with open(FACET_PATH) as f:
            return json.load(f)
    except Exception:
        return None


def _write_facet(facet):
    try:
        FACET_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(FACET_PATH, "w") as f:
            json.dump(facet, f, indent=2)
        return True
    except Exception:
        return False


# ── Vector Store Search ───────��─────────────────────��──────────────────

def vector_search(query, n_results=5, category=None):
    collection = _get_collection()
    if not collection:
        return [{"error": "Vector store not available"}]

    where = {"category": category} if category else None
    results = collection.query(
        query_texts=[query],
        n_results=n_results,
        where=where,
    )

    if not results or not results["documents"]:
        return []

    items = []
    for i, doc in enumerate(results["documents"][0]):
        meta = results["metadatas"][0][i] if results["metadatas"] else {}
        dist = results["distances"][0][i] if results["distances"] else None
        items.append({
            "content": doc[:800],
            "source": meta.get("doc_id", "?"),
            "category": meta.get("category", "?"),
            "distance": round(dist, 4) if dist else None,
        })
    return items


def hc_search(query, n_results=5):
    """Search Alice's HC (hippocampus) vector store."""
    collection = _get_hc_collection()
    if not collection:
        return [{"error": "HC vector store not available"}]

    results = collection.query(
        query_texts=[query],
        n_results=n_results,
    )

    if not results or not results["documents"]:
        return []

    items = []
    for i, doc in enumerate(results["documents"][0]):
        meta = results["metadatas"][0][i] if results["metadatas"] else {}
        dist = results["distances"][0][i] if results["distances"] else None
        items.append({
            "content": doc[:800],
            "hypothesis_id": meta.get("hypothesis_id", "?"),
            "domain": meta.get("domain", "?"),
            "confidence": meta.get("confidence", "?"),
            "distance": round(dist, 4) if dist else None,
        })
    return items


def hc_store(doc_id, content, domain, confidence, metadata=None):
    """Store a hypothesis/learning in Alice's HC vector store."""
    collection = _get_hc_collection()
    if not collection:
        return {"error": "HC vector store not available"}

    meta = {
        "hypothesis_id": doc_id,
        "domain": domain,
        "confidence": confidence,
        "ts": _now_utc(),
    }
    if metadata:
        meta.update(metadata)

    collection.upsert(
        ids=[doc_id],
        documents=[content],
        metadatas=[meta],
    )
    return {"status": "stored", "id": doc_id, "domain": domain, "confidence": confidence}


# ── Alice Log (pattern recognition) ───────────────────────────────────

def write_alice_log(event, model_name, message, source="claude", data=None):
    conn = _db_conn()
    if not conn:
        return {"error": "Cannot connect to allie database"}
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO alice_log (dt_created, event, model_name, message, source, data)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (_now_ms(), event, model_name, message, source,
                  json.dumps(data) if data else None))
            row = cur.fetchone()
            conn.commit()
            return {"id": row[0], "status": "logged"}
    except Exception as e:
        return {"error": str(e)}
    finally:
        conn.close()


def recall_alice_log(query=None, event=None, limit=10):
    conn = _db_conn()
    if not conn:
        return [{"error": "Cannot connect to allie database"}]
    try:
        with conn.cursor() as cur:
            if query:
                cur.execute("""
                    SELECT id, dt_created, event, model_name, message, source, action_taken
                    FROM alice_log
                    WHERE message ILIKE %s OR model_name ILIKE %s
                    ORDER BY dt_created DESC LIMIT %s
                """, (f"%{query}%", f"%{query}%", limit))
            elif event:
                cur.execute("""
                    SELECT id, dt_created, event, model_name, message, source, action_taken
                    FROM alice_log WHERE event = %s
                    ORDER BY dt_created DESC LIMIT %s
                """, (event, limit))
            else:
                cur.execute("""
                    SELECT id, dt_created, event, model_name, message, source, action_taken
                    FROM alice_log
                    ORDER BY dt_created DESC LIMIT %s
                """, (limit,))

            rows = cur.fetchall()
            return [
                {
                    "id": r[0], "dt": r[1], "event": r[2], "model": r[3],
                    "message": r[4], "source": r[5], "action": r[6],
                }
                for r in rows
            ]
    except Exception as e:
        return [{"error": str(e)}]
    finally:
        conn.close()


def recall_observations(category=None, model_name=None, unresolved_only=True, limit=20):
    """Recall AliceObservation records from commerce_expert database."""
    conn = None
    try:
        pg = _get_psycopg2()
        if not pg:
            return [{"error": "psycopg2 not available"}]
        conn = pg.connect(dbname="commerce_expert", user=DB_USER, host=DB_HOST)
        with conn.cursor(cursor_factory=pg.extras.RealDictCursor) as cur:
            where_parts = []
            params = []

            if category:
                where_parts.append("category = %s")
                params.append(category)
            if model_name:
                where_parts.append("model_name = %s")
                params.append(model_name)
            if unresolved_only:
                where_parts.append("resolved = FALSE")

            where = ("WHERE " + " AND ".join(where_parts)) if where_parts else ""
            cur.execute(f"""
                SELECT id, category, source, priority, message, detail,
                       model_name, record_id, acknowledged, resolved,
                       dedup_key, dt_created
                FROM alice_observations
                {where}
                ORDER BY priority DESC, dt_created DESC
                LIMIT %s
            """, params + [limit])

            rows = [dict(r) for r in cur.fetchall()]
            for r in rows:
                dt = r.get("dt_created")
                if isinstance(dt, int) and dt > 0:
                    r["dt"] = datetime.datetime.fromtimestamp(
                        dt / 1000, tz=datetime.timezone.utc
                    ).strftime("%Y-%m-%dT%H:%M:%SZ")
            return rows
    except Exception as e:
        return [{"error": str(e)}]
    finally:
        if conn:
            conn.close()


def get_inbox_stats():
    """Get Alice's agent bus inbox statistics."""
    conn = _db_conn()
    if not conn:
        return {"error": "Cannot connect to allie database"}
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    count(*) FILTER (WHERE NOT read) as unread,
                    count(*) FILTER (WHERE read) as total_read,
                    count(*) as total
                FROM agent_messages
                WHERE to_agent = 'alice'
            """)
            row = cur.fetchone()
            return {"unread": row[0], "read": row[1], "total": row[2]}
    except Exception as e:
        return {"error": str(e)}
    finally:
        conn.close()


# ── Librarian: Intent/Outcome Store ────────────���────────────────────────

def _intent_store_path():
    return ALLIE_HOME / "facets" / "alice" / "intents.jsonl"


def _outcome_store_path():
    return ALLIE_HOME / "facets" / "alice" / "outcomes.jsonl"


def record_intent(who, what, why, expected_outcome, target_date=None):
    """Record a decision's intent for later measurement."""
    intent_id = f"AI-{hashlib.md5(f'{what}{_now_utc()}'.encode()).hexdigest()[:8]}"
    record = {
        "intent_id": intent_id,
        "ts": _now_utc(),
        "who": who,
        "what": what,
        "why": why,
        "expected_outcome": expected_outcome,
        "target_date": target_date,
        "measured": False,
    }
    path = _intent_store_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a") as f:
        f.write(json.dumps(record) + "\n")

    # Update facet
    facet = _read_facet()
    if facet:
        facet.setdefault("librarian", {})
        facet["librarian"].setdefault("unresolved_intents", 0)
        facet["librarian"]["unresolved_intents"] += 1
        _write_facet(facet)

    return record


def measure_outcome(intent_id, actual_result, grade, justification, informative=False):
    """Measure an outcome against a recorded intent."""
    # Find the intent
    intents_path = _intent_store_path()
    intent_found = None
    if intents_path.exists():
        with open(intents_path) as f:
            for line in f:
                try:
                    rec = json.loads(line.strip())
                    if rec.get("intent_id") == intent_id:
                        intent_found = rec
                except Exception:
                    continue

    outcome = {
        "intent_id": intent_id,
        "ts": _now_utc(),
        "actual_result": actual_result,
        "grade": grade.upper(),
        "justification": justification,
        "informative_gap": informative,
        "intent_summary": intent_found.get("what", "?") if intent_found else "intent not found",
    }

    path = _outcome_store_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a") as f:
        f.write(json.dumps(outcome) + "\n")

    # Update facet grades
    facet = _read_facet()
    if facet:
        lib = facet.setdefault("librarian", {})
        grades = lib.setdefault("grades", {"A": 0, "B": 0, "C": 0, "D": 0, "F": 0})
        if grade.upper() in grades:
            grades[grade.upper()] += 1
        if informative:
            lib.setdefault("informative_gaps", [])
            lib["informative_gaps"].append({
                "intent_id": intent_id,
                "grade": grade.upper(),
                "justification": justification[:200],
                "ts": _now_utc(),
            })
            # Keep only last 20
            lib["informative_gaps"] = lib["informative_gaps"][-20:]
        lib["last_measurement"] = _now_utc()
        if intent_found:
            lib["unresolved_intents"] = max(0, lib.get("unresolved_intents", 1) - 1)
        _write_facet(facet)

    return outcome


def librarian_report():
    """Generate librarian's summary report."""
    intents_path = _intent_store_path()
    outcomes_path = _outcome_store_path()

    intents = []
    if intents_path.exists():
        with open(intents_path) as f:
            for line in f:
                try:
                    intents.append(json.loads(line.strip()))
                except Exception:
                    continue

    outcomes = []
    if outcomes_path.exists():
        with open(outcomes_path) as f:
            for line in f:
                try:
                    outcomes.append(json.loads(line.strip()))
                except Exception:
                    continue

    measured_ids = {o["intent_id"] for o in outcomes}
    unresolved = [i for i in intents if i["intent_id"] not in measured_ids]

    grades = {"A": 0, "B": 0, "C": 0, "D": 0, "F": 0}
    informative = []
    for o in outcomes:
        g = o.get("grade", "?")
        if g in grades:
            grades[g] += 1
        if o.get("informative_gap"):
            informative.append(o)

    return {
        "total_intents": len(intents),
        "total_outcomes": len(outcomes),
        "unresolved_intents": len(unresolved),
        "grade_distribution": grades,
        "informative_gaps": informative[-5:],
        "recent_unresolved": [
            {"intent_id": i["intent_id"], "what": i["what"], "ts": i["ts"]}
            for i in unresolved[-5:]
        ],
    }


# ── Episodic Memory ──────────────────────────────────────────────────

def episode_create(episode_type, domain, title, narrative, principle=None,
                   actors=None, outcome="unresolved", severity="lesson",
                   related_episodes=None, tags=None, source_ref=None):
    """Create an episode in both PostgreSQL and ChromaDB."""
    episode_id = f"EP-{hashlib.md5(f'{title}{_now_utc()}'.encode()).hexdigest()[:12]}"
    now = _now_ms()

    # PostgreSQL
    conn = _db_conn()
    pg_result = None
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO episodes
                        (episode_id, dt_created, dt_start, episode_type, domain,
                         title, narrative, principle, actors, outcome, severity,
                         related_episodes, tags, source_ref)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (episode_id, now, now, episode_type, domain,
                      title, narrative, principle,
                      json.dumps(actors or []),
                      outcome, severity,
                      json.dumps(related_episodes or []),
                      json.dumps(tags or []),
                      source_ref))
                pg_result = cur.fetchone()
                conn.commit()
        except Exception as e:
            pg_result = {"error": str(e)}
        finally:
            conn.close()

    # ChromaDB — index the narrative + principle for vector recall
    ep_col = _get_ep_collection()
    chroma_result = None
    if ep_col:
        doc_text = f"Title: {title}\n"
        if narrative:
            doc_text += f"Narrative: {narrative}\n"
        if principle:
            doc_text += f"Principle: {principle}\n"

        meta = {
            "episode_id": episode_id,
            "episode_type": episode_type,
            "domain": domain,
            "outcome": outcome,
            "severity": severity,
            "ts": _now_utc(),
        }
        if tags:
            meta["tags"] = ",".join(tags) if isinstance(tags, list) else str(tags)
        if source_ref:
            meta["source_ref"] = source_ref

        try:
            ep_col.upsert(
                ids=[episode_id],
                documents=[doc_text],
                metadatas=[meta],
            )
            chroma_result = "indexed"
        except Exception as e:
            chroma_result = f"index error: {e}"

    return {
        "episode_id": episode_id,
        "pg_id": pg_result[0] if isinstance(pg_result, tuple) else pg_result,
        "chroma": chroma_result,
        "title": title,
        "type": episode_type,
        "domain": domain,
    }


def episode_recall(query, n_results=5, domain=None, episode_type=None,
                   min_severity=None):
    """Search episodes by vector similarity + optional filters. Updates recall_count."""
    ep_col = _get_ep_collection()
    if not ep_col:
        return []

    where = {}
    if domain:
        where["domain"] = domain
    if episode_type:
        where["episode_type"] = episode_type

    try:
        results = ep_col.query(
            query_texts=[query],
            n_results=n_results,
            where=where if where else None,
        )
    except Exception:
        return []

    if not results or not results["documents"]:
        return []

    episodes = []
    recalled_ids = []
    for i, doc in enumerate(results["documents"][0]):
        meta = results["metadatas"][0][i] if results["metadatas"] else {}
        dist = results["distances"][0][i] if results["distances"] else None
        ep_id = meta.get("episode_id", "?")
        episodes.append({
            "episode_id": ep_id,
            "content": doc[:1000],
            "episode_type": meta.get("episode_type", "?"),
            "domain": meta.get("domain", "?"),
            "outcome": meta.get("outcome", "?"),
            "severity": meta.get("severity", "?"),
            "distance": round(dist, 4) if dist else None,
            "source_ref": meta.get("source_ref", ""),
        })
        if ep_id != "?":
            recalled_ids.append(ep_id)

    # Fetch quality scores from PostgreSQL and re-rank
    if recalled_ids:
        conn = _db_conn()
        if conn:
            try:
                with conn.cursor() as cur:
                    # Update recall counts
                    cur.execute("""
                        UPDATE episodes
                        SET recall_count = recall_count + 1, last_recalled = %s
                        WHERE episode_id = ANY(%s)
                    """, (_now_ms(), recalled_ids))

                    # Fetch quality scores for re-ranking
                    cur.execute("""
                        SELECT episode_id,
                               COALESCE((metadata->>'quality_score')::float, 0.0) as quality
                        FROM episodes
                        WHERE episode_id = ANY(%s)
                    """, (recalled_ids,))
                    quality_map = {row[0]: row[1] for row in cur.fetchall()}
                    conn.commit()

                    # Re-rank: effective_distance = distance - (quality * 0.1)
                    # Good quality (positive) reduces distance → ranks higher
                    # Bad quality (negative) increases distance → ranks lower
                    for ep in episodes:
                        q = quality_map.get(ep["episode_id"], 0.0)
                        ep["quality_score"] = round(q, 3)
                        if ep["distance"] is not None:
                            ep["effective_distance"] = round(
                                ep["distance"] - (q * 0.1), 4
                            )
                        else:
                            ep["effective_distance"] = ep["distance"]

                    # Sort by effective_distance (lower = better match)
                    episodes.sort(
                        key=lambda e: e.get("effective_distance") or 99.0
                    )
            except Exception:
                pass
            finally:
                conn.close()

    return episodes


def associative_recall(event_text, threshold=None):
    """Automatic trigger: find similar past episodes for a new event.
    Returns matching episodes below the threshold distance, or empty list.
    Uses effective_distance (quality-adjusted) when available."""
    if threshold is None:
        threshold = EPISODE_RECALL_THRESHOLD

    matches = episode_recall(event_text, n_results=3)
    return [
        ep for ep in matches
        if (ep.get("effective_distance") or ep.get("distance")) is not None
        and (ep.get("effective_distance") or ep.get("distance")) < threshold
    ]


# ── MCP Tool Definitions ──────────────────────────────────────────────

TOOLS = [
    # ── OPS capacity ──
    {
        "name": "ask_alice",
        "description": "Ask Alice-ops about WebClerk commerce — pricing, billing, data quality, customer patterns, inventory, transactions. The enforcement voice: validates against standards.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "question": {
                    "type": "string",
                    "description": "The commerce question to ask Alice-ops",
                },
                "category": {
                    "type": "string",
                    "description": "Optional category filter: wc3_readmes, wc3_models_core, wc3_views_core, wc3_models_transactions, alice_agent, fare_payment, ingrid",
                },
            },
            "required": ["question"],
        },
    },
    {
        "name": "alice_search",
        "description": "Semantic search across Alice's primary vector store — WC3 source code, readmes, model definitions, views, transaction logic.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query"},
                "n_results": {"type": "integer", "description": "Number of results (default 5)", "default": 5},
                "category": {"type": "string", "description": "Optional category filter"},
            },
            "required": ["query"],
        },
    },
    {
        "name": "alice_observe",
        "description": "Log an observation to alice_log — part of Alice-ops pattern recognition loop (observe > log > pattern > recommend > promote).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "event": {"type": "string", "description": "Event type: observe, pattern, recommend, promote, error, anomaly"},
                "model_name": {"type": "string", "description": "WC3 model involved"},
                "message": {"type": "string", "description": "What was observed"},
                "data": {"type": "object", "description": "Optional structured data"},
            },
            "required": ["event", "model_name", "message"],
        },
    },
    {
        "name": "alice_recall",
        "description": "Recall Alice's observations and patterns from alice_log and AliceObservation records.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search term"},
                "event": {"type": "string", "description": "Filter by event type"},
                "source": {"type": "string", "description": "'log', 'observations', or omit for both"},
                "category": {"type": "string", "description": "For observations: anomaly, alert, bill_question, pattern, coaching"},
                "model_name": {"type": "string", "description": "Filter by model name"},
                "limit": {"type": "integer", "description": "Max results (default 10)", "default": 10},
            },
        },
    },
    {
        "name": "alice_status",
        "description": "Alice's current status — inbox stats, observations, capacity model status, facet summary.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "alice_quiz",
        "description": "Get quiz questions from Alice-ops to test commerce knowledge.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "category": {"type": "string", "default": "random"},
                "count": {"type": "integer", "default": 3},
                "difficulty": {"type": "string", "default": "intermediate"},
            },
        },
    },

    # ── HC (hippocampus) capacity ──
    {
        "name": "alice_learn",
        "description": "Alice-hc learns from a pattern or experience. Stores in HC vector store with confidence score. Use when a commerce pattern is worth remembering.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "learning": {"type": "string", "description": "What was learned — one clear sentence"},
                "evidence": {"type": "string", "description": "The specific data/records/counts that support this"},
                "domain": {"type": "string", "description": "Domain: commerce, pricing, billing, inventory, customer, cross-domain"},
                "confidence": {"type": "number", "description": "Confidence 0.0-1.0 that this pattern is real"},
                "contradicts": {"type": "string", "description": "Optional: existing standard or memory this contradicts"},
            },
            "required": ["learning", "evidence", "domain", "confidence"],
        },
    },
    {
        "name": "alice_hypothesize",
        "description": "Alice-hc proposes a deviation from an existing standard. The innovation voice: questions rules when evidence suggests they're wrong for a context.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "standard": {"type": "string", "description": "The current standard being questioned"},
                "evidence": {"type": "string", "description": "Specific data supporting the deviation"},
                "proposal": {"type": "string", "description": "The proposed alternative"},
                "confidence": {"type": "number", "description": "Confidence 0.0-1.0"},
                "test": {"type": "string", "description": "What would confirm or refute this hypothesis"},
            },
            "required": ["standard", "evidence", "proposal", "confidence"],
        },
    },

    # ── Debate (ops + hc) ���─
    {
        "name": "alice_debate",
        "description": "Both Alice-ops and Alice-hc respond to the same question. Surfaces disagreements. Use when you need both the enforcement and innovation perspectives.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "question": {"type": "string", "description": "The question both capacities will answer"},
                "context": {"type": "string", "description": "Optional additional context"},
            },
            "required": ["question"],
        },
    },

    # ── Librarian capacity ──
    {
        "name": "alice_record_intent",
        "description": "Alice-lib records a decision's intent for later measurement. Who decided what, why, and what they expected.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "who": {"type": "string", "description": "Who made the decision (Bill, Claude, Alice, etc.)"},
                "what": {"type": "string", "description": "What was decided"},
                "why": {"type": "string", "description": "Why — the reasoning"},
                "expected_outcome": {"type": "string", "description": "What is expected to happen"},
                "target_date": {"type": "string", "description": "Optional: when to measure (ISO date)"},
            },
            "required": ["who", "what", "why", "expected_outcome"],
        },
    },
    {
        "name": "alice_measure",
        "description": "Alice-lib measures an outcome against a recorded intent. Grades A-F.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "intent_id": {"type": "string", "description": "The intent ID to measure against (AI-xxxxxxxx)"},
                "actual_result": {"type": "string", "description": "What actually happened"},
                "grade": {"type": "string", "description": "Grade: A, B, C, D, or F"},
                "justification": {"type": "string", "description": "One-sentence justification for the grade"},
                "informative": {"type": "boolean", "description": "Did the gap between intent and outcome reveal something new?", "default": False},
            },
            "required": ["intent_id", "actual_result", "grade", "justification"],
        },
    },
    {
        "name": "alice_report",
        "description": "Alice-lib reports: grade distribution, informative gaps, unresolved intents. The accountability summary.",
        "inputSchema": {"type": "object", "properties": {}},
    },

    # ── Response grading (Small-Stings) ──
    {
        "name": "alice_grade",
        "description": "Grade an Alice response — thumbs up or thumbs down. Thumbs down REQUIRES a reason (small sting). The 'why' on a bad answer is where Alice learns. Grades tune episodic recall — good grades promote episodes, bad grades demote them.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "grade": {"type": "string", "enum": ["up", "down"], "description": "Thumbs up or thumbs down"},
                "why": {"type": "string", "description": "REQUIRED if thumbs down — why was this answer bad? This is the small sting that teaches Alice."},
                "episode_ids": {"type": "array", "items": {"type": "string"}, "description": "Episode IDs that were surfaced with this response"},
                "response_id": {"type": "string", "description": "Optional response ID (from escalation)"},
            },
            "required": ["grade"],
        },
    },

    # ── Episodic memory ──
    {
        "name": "alice_episode_create",
        "description": "Create an episode — a structured record of something that happened (TFTS arc, fault, commerce event, scar, session arc). Episodes are retrievable by similarity for associative recall.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "episode_type": {"type": "string", "description": "Type: tfts, fault, scar, commerce, session, pattern"},
                "domain": {"type": "string", "description": "Domain: SU, PH, RT, WC3, SYS, ALLIE, CROSS"},
                "title": {"type": "string", "description": "One-line summary of what happened"},
                "narrative": {"type": "string", "description": "Full story — what happened, what was tried, what worked/failed"},
                "principle": {"type": "string", "description": "The lesson learned (if any)"},
                "actors": {"type": "array", "items": {"type": "string"}, "description": "Who was involved (Bill, Claude, Alice, Noelle, etc.)"},
                "outcome": {"type": "string", "description": "resolved, unresolved, or ongoing", "default": "unresolved"},
                "severity": {"type": "string", "description": "lesson, scar, or win", "default": "lesson"},
                "related_episodes": {"type": "array", "items": {"type": "string"}, "description": "Episode IDs of related episodes"},
                "tags": {"type": "array", "items": {"type": "string"}, "description": "Searchable tags"},
                "source_ref": {"type": "string", "description": "Where this came from (file path, scar ID, TFTS file)"},
            },
            "required": ["episode_type", "domain", "title", "narrative"],
        },
    },
    {
        "name": "alice_episode_recall",
        "description": "Search episodic memory for similar past events. Uses vector similarity — describe what's happening and get back episodes where something similar occurred. Episodes recalled more often rank higher over time.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Describe the current situation — what's happening that you want to match against past episodes"},
                "n_results": {"type": "integer", "description": "Max episodes to return (default 5)", "default": 5},
                "domain": {"type": "string", "description": "Optional domain filter: SU, PH, RT, WC3, SYS, ALLIE, CROSS"},
                "episode_type": {"type": "string", "description": "Optional type filter: tfts, fault, scar, commerce, session, pattern"},
            },
            "required": ["query"],
        },
    },
]


# ── Quiz Engine ───────────────────────��───────────────────────────────

def get_quiz_questions(category="random", count=3, difficulty="intermediate"):
    """Fetch quiz questions from WC3 Document records."""
    import urllib.request as ur
    import random

    try:
        login_data = json.dumps({"email": "claude@jpods.com", "password": "pass1111"}).encode()
        req = ur.Request(
            "http://localhost:8000/wcapi/login/",
            data=login_data,
            headers={"Content-Type": "application/json"},
        )
        with ur.urlopen(req, timeout=5) as resp:
            token = json.loads(resp.read())["data"]["access"]
    except Exception:
        return _fallback_quiz(category, count, difficulty)

    try:
        filters = {"model_name": "quiz", "is_active": True}
        url = f"http://localhost:8000/wcapi/list/document/?limit=100&filters={json.dumps(filters)}"
        req = ur.Request(url, headers={"Authorization": f"Bearer {token}"})
        with ur.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            docs = result.get("data", {}).get("results", [])
    except Exception:
        return _fallback_quiz(category, count, difficulty)

    questions = []
    for doc in docs:
        try:
            body = json.loads(doc.get("body", "{}")) if isinstance(doc.get("body"), str) else doc.get("body", {})
            q_list = body.get("questions", [])
            for q in q_list:
                if category == "random" or q.get("category") == category:
                    if difficulty == "any" or q.get("difficulty", "intermediate") == difficulty:
                        questions.append(q)
        except Exception:
            continue

    if not questions:
        return _fallback_quiz(category, count, difficulty)

    random.shuffle(questions)
    return questions[:min(count, len(questions))]


def _fallback_quiz(category, count, difficulty):
    """Built-in questions when WC3 is unavailable."""
    import random
    all_q = [
        {"category": "commerce_flow", "difficulty": "beginner", "question": "What is the correct sequence after an Order is marked complete?", "choices": ["A) Payment", "B) Invoice", "C) Proposal", "D) Purchase Order"], "answer": "B", "explanation": "A complete Order generates an Invoice via order_to_invoice(). Payment follows the Invoice, not the Order directly."},
        {"category": "commerce_flow", "difficulty": "beginner", "question": "What model bridges Proposals to Purchase Orders?", "choices": ["A) Order", "B) Action", "C) Requisition", "D) WorkOrder"], "answer": "C", "explanation": "Requisitions connect demand (from Proposals or Orders) to supply (Purchase Orders). They are the internal demand signal."},
        {"category": "commerce_flow", "difficulty": "intermediate", "question": "In the WC3 journal flow, which three journal types feed the General Ledger?", "choices": ["A) Sales, Cash, Purchase", "B) Sales, Inventory, Tax", "C) Cash, Credit, Debit", "D) Invoice, Payment, Receipt"], "answer": "A", "explanation": "Process Sales Journals + Process Cash Journals + Process Purchase Journals all produce JournalEntry records that interface to the GL."},
        {"category": "models", "difficulty": "beginner", "question": "Which WC3 model handles both Accounts Receivable and Accounts Payable?", "choices": ["A) Invoice", "B) JournalEntry", "C) Payment", "D) Order"], "answer": "C", "explanation": "The Payment model uses a 'type' field to distinguish AR (customer payments) from AP (vendor payments). One model, two directions."},
        {"category": "models", "difficulty": "intermediate", "question": "What is the relationship between Communication and Contact in WC3?", "choices": ["A) Contact contains Communications", "B) Communication FK is truth, aspects are cache", "C) They are the same model", "D) Communication inherits from Contact"], "answer": "B", "explanation": "The Communication FK to Contact is authoritative. Contact.aspects is a denormalized cache for performance. Always trust the FK."},
        {"category": "tools", "difficulty": "beginner", "question": "Which tool would Ingrid use to detect the encoding of a supplier CSV file?", "choices": ["A) pandas", "B) chardet", "C) openpyxl", "D) thefuzz"], "answer": "B", "explanation": "chardet auto-detects file encoding (UTF-8, Latin-1, Windows-1252) before reading. Without this, Ingrid might produce garbled text."},
        {"category": "data_quality", "difficulty": "beginner", "question": "All CRUD operations in WC3 must go through which layer?", "choices": ["A) Django admin", "B) Direct model access", "C) wcapi", "D) React frontend"], "answer": "C", "explanation": "wcapi enforces RBAC, query scoping, field filtering, and audit. No direct model access — every operation flows through wcapi."},
        {"category": "billing", "difficulty": "intermediate", "question": "What is a Small-Sting in the JPods/WC3 context?", "choices": ["A) A small bug", "B) A customer-assessed fine for unresolved problems", "C) A micro-payment", "D) A discount code"], "answer": "B", "explanation": "Small-Stings are customer-assessed fines for unresolved problems. JPods also pays customers for retrospections. Alice accounts for both flows."},
    ]

    filtered = [q for q in all_q if category == "random" or q["category"] == category]
    if difficulty != "any":
        diff_filtered = [q for q in filtered if q["difficulty"] == difficulty]
        if diff_filtered:
            filtered = diff_filtered

    random.shuffle(filtered)
    return filtered[:min(count, len(filtered))]


# ── MCP Protocol Handler ─────────────────────��────────────────���───────

def handle_request(request):
    method = request.get("method", "")
    req_id = request.get("id")
    params = request.get("params", {})

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "alice-commerce", "version": "2.0.0"},
            },
        }

    elif method == "notifications/initialized":
        return None

    elif method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"tools": TOOLS},
        }

    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {})

        # ── OPS tools ──

        if tool_name == "ask_alice":
            question = args.get("question", "")
            category = args.get("category")
            log_exchange("claude", question, tool="ask_alice", capacity="ops")

            results = vector_search(question, n_results=5, category=category)
            alice_answer = capacity_think("ops", f"Question: {question}\nAnswer based on WebClerk standards. Flag any violations.", results)

            source_list = "\n".join(
                f"  - {r.get('source', '?')} (distance: {r.get('distance', '?')})"
                for r in results if "error" not in r
            )
            response_text = f"**[Alice-ops]**\n\n{alice_answer}\n\n**Sources ({len(results)}):**\n{source_list}"

            # ── Associative recall trigger ──
            similar_episodes = associative_recall(question)
            if similar_episodes:
                ep_parts = ["\n\n**⚡ Related Episodes:**"]
                for ep in similar_episodes:
                    ep_parts.append(
                        f"- `{ep['episode_id']}` ({ep['episode_type']}/{ep['domain']}) "
                        f"d={ep['distance']}: {ep['content'][:200]}"
                    )
                response_text += "\n".join(ep_parts)

            log_exchange("alice-ops", response_text[:500], tool="ask_alice", capacity="ops")
            return _tool_result(req_id, response_text)

        elif tool_name == "alice_search":
            query = args.get("query", "")
            n = args.get("n_results", 5)
            category = args.get("category")
            log_exchange("claude", f"[SEARCH] {query}", tool="alice_search", capacity="ops")

            results = vector_search(query, n_results=n, category=category)
            response_text = json.dumps(results, indent=2)
            log_exchange("alice-ops", f"Found {len(results)} results", tool="alice_search", capacity="ops")
            return _tool_result(req_id, response_text)

        elif tool_name == "alice_observe":
            event = args.get("event", "observe")
            model_name = args.get("model_name", "")
            message = args.get("message", "")
            data = args.get("data")
            log_exchange("claude", f"[OBSERVE {event}:{model_name}] {message}", tool="alice_observe", capacity="ops")

            result = write_alice_log(event, model_name, message, source="claude", data=data)

            # ── Associative recall trigger ──
            # Search episodic memory for similar past events
            recall_text = f"{event} {model_name} {message}"
            similar_episodes = associative_recall(recall_text)

            if similar_episodes:
                recall_parts = ["\n\n**⚡ Associative Recall** — similar past episodes:"]
                for ep in similar_episodes:
                    recall_parts.append(
                        f"- `{ep['episode_id']}` ({ep['episode_type']}/{ep['domain']}) "
                        f"d={ep['distance']}: {ep['content'][:200]}"
                    )
                result["associative_recall"] = [
                    {"episode_id": ep["episode_id"], "distance": ep["distance"],
                     "type": ep["episode_type"]}
                    for ep in similar_episodes
                ]
                response_text = json.dumps(result) + "\n".join(recall_parts)
            else:
                response_text = json.dumps(result)

            log_exchange("alice-ops", response_text[:500], tool="alice_observe", capacity="ops")
            _log_teaching("alice", f"observe:{event}", f"[{model_name}] {message}")
            return _tool_result(req_id, response_text)

        elif tool_name == "alice_recall":
            query = args.get("query")
            event = args.get("event")
            source = args.get("source")
            category = args.get("category")
            model_name = args.get("model_name")
            limit = args.get("limit", 10)
            log_exchange("claude", f"[RECALL] query={query} event={event} source={source}", tool="alice_recall", capacity="ops")

            combined = {}
            if source != "observations":
                combined["log"] = recall_alice_log(query=query, event=event, limit=limit)
            if source != "log":
                combined["observations"] = recall_observations(
                    category=category, model_name=model_name,
                    unresolved_only=True, limit=limit,
                )

            response_text = json.dumps(combined, indent=2, default=str)
            total = sum(len(v) for v in combined.values() if isinstance(v, list))
            log_exchange("alice-ops", f"Recalled {total} entries", tool="alice_recall", capacity="ops")
            return _tool_result(req_id, response_text)

        elif tool_name == "alice_status":
            log_exchange("claude", "[STATUS]", tool="alice_status", capacity="ops")

            status = {"capacities": ["ops", "hc", "librarian"], "version": "2.0.0"}
            status["inbox"] = get_inbox_stats()

            # Observations
            obs = recall_observations(unresolved_only=True, limit=100)
            if isinstance(obs, list) and obs and "error" not in obs[0]:
                by_cat = {}
                for o in obs:
                    cat = o.get("category", "other")
                    by_cat[cat] = by_cat.get(cat, 0) + 1
                status["observations"] = {"unresolved": len(obs), "by_category": by_cat}
            else:
                status["observations"] = {"unresolved": 0}

            # Facet summary
            facet = _read_facet()
            if facet:
                status["facet"] = {
                    "ops_standards": len(facet.get("ops", {}).get("standards_applied", [])),
                    "hc_hypotheses": facet.get("hc", {}).get("patterns_proposed", 0),
                    "lib_grades": facet.get("librarian", {}).get("grades", {}),
                    "lib_unresolved": facet.get("librarian", {}).get("unresolved_intents", 0),
                }

            # HC store size
            hc_col = _get_hc_collection()
            if hc_col:
                try:
                    status["hc_store_size"] = hc_col.count()
                except Exception:
                    status["hc_store_size"] = "?"

            response_text = json.dumps(status, indent=2, default=str)
            log_exchange("alice-ops", response_text[:300], tool="alice_status", capacity="ops")
            return _tool_result(req_id, response_text)

        elif tool_name == "alice_quiz":
            category = args.get("category", "random")
            count = min(args.get("count", 3), 10)
            difficulty = args.get("difficulty", "intermediate")
            log_exchange("claude", f"[QUIZ] {category} {count} {difficulty}", tool="alice_quiz", capacity="ops")

            questions = get_quiz_questions(category, count, difficulty)
            if not questions:
                response_text = "No quiz questions available for that category/difficulty."
            else:
                parts = [f"**Alice's Quiz** — {len(questions)} questions ({category}, {difficulty})\n"]
                for i, q in enumerate(questions, 1):
                    parts.append(f"**Q{i}. [{q.get('category', '')}]** {q['question']}")
                    for c in q.get("choices", []):
                        parts.append(f"   {c}")
                    parts.append(f"   *Answer: {q['answer']}*")
                    parts.append(f"   *{q['explanation']}*\n")
                response_text = "\n".join(parts)

            log_exchange("alice-ops", f"Served {len(questions)} quiz questions", tool="alice_quiz", capacity="ops")
            return _tool_result(req_id, response_text)

        # ── HC tools ──

        elif tool_name == "alice_learn":
            learning = args.get("learning", "")
            evidence = args.get("evidence", "")
            domain = args.get("domain", "commerce")
            confidence = args.get("confidence", 0.5)
            contradicts = args.get("contradicts")
            log_exchange("claude", f"[LEARN] {learning}", tool="alice_learn", capacity="hc")

            # Store in HC vector store
            doc_id = f"learn-{hashlib.md5(f'{learning}{_now_utc()}'.encode()).hexdigest()[:12]}"
            content = f"Learning: {learning}\nEvidence: {evidence}"
            if contradicts:
                content += f"\nContradicts: {contradicts}"

            store_result = hc_store(doc_id, content, domain, confidence,
                                    metadata={"type": "learning", "contradicts": contradicts or ""})

            # Ask Alice-hc to contextualize
            hc_response = capacity_think("hc",
                f"A new pattern has been observed:\n\nLearning: {learning}\nEvidence: {evidence}\n"
                f"Domain: {domain}\nConfidence: {confidence}\n"
                f"{'Contradicts: ' + contradicts if contradicts else ''}\n\n"
                f"Does this reinforce or contradict existing knowledge? What should the team watch for?")

            # Update facet
            facet = _read_facet()
            if facet:
                hc = facet.setdefault("hc", {})
                hc["patterns_proposed"] = hc.get("patterns_proposed", 0) + 1
                hc["last_learning"] = _now_utc()
                _write_facet(facet)

            response_text = (
                f"**[Alice-hc]** Stored learning `{doc_id}` (confidence: {confidence})\n\n"
                f"{hc_response}\n\n"
                f"Store: {json.dumps(store_result)}"
            )
            log_exchange("alice-hc", response_text[:500], tool="alice_learn", capacity="hc")
            _log_teaching("alice-hc", f"learn:{domain}", learning)
            return _tool_result(req_id, response_text)

        elif tool_name == "alice_hypothesize":
            standard = args.get("standard", "")
            evidence = args.get("evidence", "")
            proposal = args.get("proposal", "")
            confidence = args.get("confidence", 0.5)
            test = args.get("test", "")
            log_exchange("claude", f"[HYPOTHESIZE] {proposal}", tool="alice_hypothesize", capacity="hc")

            # Store hypothesis in HC store
            doc_id = f"hyp-{hashlib.md5(f'{proposal}{_now_utc()}'.encode()).hexdigest()[:12]}"
            content = (
                f"Standard questioned: {standard}\n"
                f"Evidence: {evidence}\n"
                f"Proposed alternative: {proposal}\n"
                f"Test: {test}"
            )
            store_result = hc_store(doc_id, content, "hypothesis", confidence,
                                    metadata={"type": "hypothesis", "standard": standard, "test": test})

            # Ask Alice-hc for analysis
            hc_response = capacity_think("hc",
                f"Hypothesis: the standard '{standard}' may be wrong in this context.\n\n"
                f"Evidence: {evidence}\n"
                f"Proposed alternative: {proposal}\n"
                f"Test to confirm/refute: {test}\n\n"
                f"Analyze this hypothesis. What is the strongest argument for and against?")

            # Also ask ops for counter-argument (productive tension)
            ops_response = capacity_think("ops",
                f"A deviation from standard has been proposed:\n\n"
                f"Standard: {standard}\n"
                f"Proposed change: {proposal}\n"
                f"Evidence offered: {evidence}\n\n"
                f"Evaluate this against existing standards. What risks does this deviation introduce?")

            # Update facet
            facet = _read_facet()
            if facet:
                hc = facet.setdefault("hc", {})
                hc["patterns_proposed"] = hc.get("patterns_proposed", 0) + 1
                hc.setdefault("hypotheses", []).append({
                    "id": doc_id, "proposal": proposal[:200],
                    "confidence": confidence, "ts": _now_utc(), "status": "open",
                })
                hc["hypotheses"] = hc["hypotheses"][-50:]  # Keep last 50
                _write_facet(facet)

            response_text = (
                f"**Hypothesis `{doc_id}`** (confidence: {confidence})\n\n"
                f"---\n**[Alice-hc — Innovation]**\n{hc_response}\n\n"
                f"---\n**[Alice-ops — Enforcement]**\n{ops_response}\n\n"
                f"---\n*Test:* {test}\n"
                f"*Status:* open — Bill decides."
            )
            log_exchange("alice-hc", response_text[:500], tool="alice_hypothesize", capacity="hc")
            _log_teaching("alice-hc", "hypothesis", f"{standard} → {proposal}")
            return _tool_result(req_id, response_text)

        # ── Debate ──

        elif tool_name == "alice_debate":
            question = args.get("question", "")
            context = args.get("context", "")
            log_exchange("claude", f"[DEBATE] {question}", tool="alice_debate", capacity="both")

            full_q = f"{question}\n\nContext: {context}" if context else question

            # Get relevant context from both stores
            ops_docs = vector_search(question, n_results=3)
            hc_docs = hc_search(question, n_results=3)

            ops_response = capacity_think("ops",
                f"Question: {full_q}\n\nAnswer from the enforcement perspective. "
                f"What do the standards say? What is the correct answer?",
                ops_docs)

            hc_response = capacity_think("hc",
                f"Question: {full_q}\n\nAnswer from the learning perspective. "
                f"What patterns suggest the standard answer might be incomplete? "
                f"What has been learned that adds nuance?",
                hc_docs)

            # Detect disagreement
            lib_assessment = capacity_think("lib",
                f"Two perspectives on the same question:\n\n"
                f"OPS (enforcement): {ops_response[:500]}\n\n"
                f"HC (learning): {hc_response[:500]}\n\n"
                f"Do they agree or disagree? If they disagree, what is the specific point of tension? "
                f"Is the disagreement informative?")

            response_text = (
                f"**[Alice-ops — Enforcement]**\n{ops_response}\n\n"
                f"---\n**[Alice-hc — Innovation]**\n{hc_response}\n\n"
                f"---\n**[Alice-lib — Assessment]**\n{lib_assessment}"
            )
            log_exchange("alice-debate", response_text[:500], tool="alice_debate", capacity="both")
            return _tool_result(req_id, response_text)

        # ── Librarian tools ──

        elif tool_name == "alice_record_intent":
            who = args.get("who", "")
            what = args.get("what", "")
            why = args.get("why", "")
            expected = args.get("expected_outcome", "")
            target = args.get("target_date")
            log_exchange("claude", f"[INTENT] {what}", tool="alice_record_intent", capacity="lib")

            result = record_intent(who, what, why, expected, target)

            # Ask librarian to contextualize
            lib_response = capacity_think("lib",
                f"A new intent has been recorded:\n"
                f"Who: {who}\nWhat: {what}\nWhy: {why}\n"
                f"Expected: {expected}\nTarget: {target or 'none'}\n\n"
                f"What should be measured to determine if this succeeds? "
                f"Are there similar past intents that inform expectations?")

            response_text = (
                f"**[Alice-lib]** Intent recorded: `{result['intent_id']}`\n\n"
                f"{lib_response}\n\n"
                f"Record: {json.dumps(result, indent=2)}"
            )
            log_exchange("alice-lib", response_text[:500], tool="alice_record_intent", capacity="lib")
            _log_teaching("alice-lib", "intent", f"{who}: {what}")
            return _tool_result(req_id, response_text)

        elif tool_name == "alice_measure":
            intent_id = args.get("intent_id", "")
            actual = args.get("actual_result", "")
            grade = args.get("grade", "C")
            justification = args.get("justification", "")
            informative = args.get("informative", False)
            log_exchange("claude", f"[MEASURE] {intent_id} → {grade}", tool="alice_measure", capacity="lib")

            result = measure_outcome(intent_id, actual, grade, justification, informative)

            response_text = (
                f"**[Alice-lib]** Outcome measured: `{intent_id}` → **{grade.upper()}**\n\n"
                f"Justification: {justification}\n"
                f"Informative gap: {'Yes' if informative else 'No'}\n\n"
                f"Record: {json.dumps(result, indent=2)}"
            )
            log_exchange("alice-lib", response_text[:500], tool="alice_measure", capacity="lib")
            _log_teaching("alice-lib", f"measure:{grade}", f"{intent_id}: {justification}")
            return _tool_result(req_id, response_text)

        elif tool_name == "alice_report":
            log_exchange("claude", "[REPORT]", tool="alice_report", capacity="lib")

            report = librarian_report()

            # Ask librarian to interpret
            lib_response = capacity_think("lib",
                f"Report data:\n{json.dumps(report, indent=2)}\n\n"
                f"Summarize: what is the team's intent-to-outcome record? "
                f"What are the top lessons from informative gaps? "
                f"What unresolved intents need attention?")

            response_text = (
                f"**[Alice-lib — Report]**\n\n{lib_response}\n\n"
                f"---\n**Raw data:**\n```json\n{json.dumps(report, indent=2)}\n```"
            )
            log_exchange("alice-lib", response_text[:500], tool="alice_report", capacity="lib")
            return _tool_result(req_id, response_text)

        # ── Response grading (Small-Stings) ──

        elif tool_name == "alice_grade":
            grade = args.get("grade", "")
            why = args.get("why", "")
            episode_ids = args.get("episode_ids", [])
            response_id = args.get("response_id", "")

            # Thumbs down requires a reason
            if grade == "down" and not why:
                return _tool_result(req_id,
                    "**[Alice]** Thumbs down requires a reason. "
                    "Why was this answer bad? The 'why' is how I learn.")

            log_exchange("claude", f"[GRADE] {grade} {why[:100]}", tool="alice_grade", capacity="ops")

            quality_delta = 1.0 if grade == "up" else -1.0

            # Store the grade in alice_log
            grade_data = {
                "grade": grade,
                "quality_delta": quality_delta,
                "episode_ids": episode_ids,
                "response_id": response_id,
            }
            if why:
                grade_data["why"] = why

            write_alice_log("response_grade", "alice", f"{grade}: {why[:200]}" if why else grade,
                            source="user", data=grade_data)

            # Update episode quality scores (exponential moving average)
            episodes_updated = 0
            if episode_ids:
                conn = _db_conn()
                if conn:
                    try:
                        with conn.cursor() as cur:
                            for ep_id in episode_ids:
                                cur.execute("""
                                    UPDATE episodes
                                    SET metadata = jsonb_set(
                                        COALESCE(metadata, '{}'),
                                        '{quality_score}',
                                        to_jsonb(
                                            COALESCE((metadata->>'quality_score')::float, 0.0) * 0.8
                                            + %s * 0.2
                                        )
                                    ),
                                    last_recalled = %s
                                    WHERE episode_id = %s
                                """, (quality_delta, _now_ms(), ep_id))
                                if cur.rowcount > 0:
                                    episodes_updated += 1
                            conn.commit()
                    except Exception as e:
                        log_exchange("alice-ops", f"Grade update error: {e}", tool="alice_grade")
                    finally:
                        conn.close()

            # If thumbs down, create an episode from the sting
            sting_episode = None
            if grade == "down" and why:
                sting_episode = episode_create(
                    episode_type="sting",
                    domain="WC3",
                    title=f"Bad answer: {why[:150]}",
                    narrative=f"User gave thumbs down. Reason: {why}",
                    principle=None,  # no principle yet — that comes from fixing it
                    actors=["user", "Alice"],
                    outcome="unresolved",
                    severity="lesson",
                    tags=["sting", "quality"],
                    source_ref=f"grade:{response_id}" if response_id else None,
                )

            if grade == "up":
                response_text = f"**[Alice]** Thanks. {episodes_updated} episode(s) promoted."
            else:
                response_text = (
                    f"**[Alice]** Small sting recorded. {episodes_updated} episode(s) demoted.\n\n"
                    f"**Why:** {why}\n\n"
                    f"I'll learn from this."
                )
                if sting_episode:
                    response_text += f" Episode `{sting_episode['episode_id']}` created to track."

            log_exchange("alice-ops", response_text[:500], tool="alice_grade", capacity="ops")
            _log_teaching("alice", f"grade:{grade}", why[:200] if why else grade)
            return _tool_result(req_id, response_text)

        # ── Episodic memory tools ──

        elif tool_name == "alice_episode_create":
            ep_type = args.get("episode_type", "pattern")
            domain = args.get("domain", "CROSS")
            title = args.get("title", "")
            narrative = args.get("narrative", "")
            principle = args.get("principle")
            actors = args.get("actors", [])
            outcome = args.get("outcome", "unresolved")
            severity = args.get("severity", "lesson")
            related = args.get("related_episodes", [])
            tags = args.get("tags", [])
            source_ref = args.get("source_ref")
            log_exchange("claude", f"[EPISODE CREATE] {title}", tool="alice_episode_create", capacity="hc")

            result = episode_create(
                ep_type, domain, title, narrative, principle,
                actors, outcome, severity, related, tags, source_ref,
            )

            # Ask hc to contextualize
            hc_response = capacity_think("hc",
                f"A new episode has been recorded:\n\n"
                f"Type: {ep_type}\nDomain: {domain}\nTitle: {title}\n"
                f"Narrative: {narrative[:500]}\n"
                f"{'Principle: ' + principle if principle else 'No principle yet.'}\n\n"
                f"What patterns does this connect to? What should the team watch for?")

            response_text = (
                f"**[Alice — Episode Created]** `{result['episode_id']}`\n\n"
                f"**{title}** ({ep_type} / {domain} / {severity})\n\n"
                f"{hc_response}\n\n"
                f"Record: {json.dumps(result)}"
            )
            log_exchange("alice-hc", response_text[:500], tool="alice_episode_create", capacity="hc")
            _log_teaching("alice-ep", f"episode:{ep_type}", title)
            return _tool_result(req_id, response_text)

        elif tool_name == "alice_episode_recall":
            query = args.get("query", "")
            n = args.get("n_results", 5)
            domain = args.get("domain")
            ep_type = args.get("episode_type")
            log_exchange("claude", f"[EPISODE RECALL] {query}", tool="alice_episode_recall", capacity="hc")

            episodes = episode_recall(query, n_results=n, domain=domain, episode_type=ep_type)

            if not episodes:
                response_text = "**[Alice — Episodic Recall]** No matching episodes found."
            else:
                parts = [f"**[Alice — Episodic Recall]** {len(episodes)} episode(s) found:\n"]
                for ep in episodes:
                    parts.append(
                        f"- **`{ep['episode_id']}`** ({ep['episode_type']}/{ep['domain']}) "
                        f"distance={ep['distance']} outcome={ep['outcome']}\n"
                        f"  {ep['content'][:300]}\n"
                    )
                response_text = "\n".join(parts)

            log_exchange("alice-hc", f"Recalled {len(episodes)} episodes", tool="alice_episode_recall", capacity="hc")
            return _tool_result(req_id, response_text)

        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"},
        }

    elif method == "ping":
        return {"jsonrpc": "2.0", "id": req_id, "result": {}}

    return {
        "jsonrpc": "2.0",
        "id": req_id,
        "error": {"code": -32601, "message": f"Unknown method: {method}"},
    }


def _tool_result(req_id, text):
    return {
        "jsonrpc": "2.0",
        "id": req_id,
        "result": {"content": [{"type": "text", "text": text}]},
    }


# ── Main Loop ────────────���────────────────────────────────────────────

def main():
    log_exchange("system", "Alice MCP server v2.0 started (ops/hc/librarian)")

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            response = handle_request(request)
            if response is not None:
                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()
        except json.JSONDecodeError:
            pass
        except Exception as e:
            error_resp = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32603, "message": str(e)},
            }
            sys.stdout.write(json.dumps(error_resp) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()

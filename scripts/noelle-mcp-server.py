#!/usr/bin/env python3
"""
Noelle MCP Server — network design intelligence for JPods.

Noelle validates and reasons about network design across all JPods programs.
She uses three data layers (AADT traffic, accidents, pedestrian density) to
propose data-driven station placement, and iterates with human designers.

Tools:
  ask_noelle      — Ask Noelle about network design, placement, capacity, topology
  noelle_search   — Semantic search across Noelle's vector store
  noelle_describe — Analyze current Route-Time network topology
  noelle_propose  — Place structures based on AADT data (not connected)
  noelle_snapshot — Record current network state with designer's note
  noelle_diff     — Show changes since last snapshot
  noelle_log      — Log a design observation to noelle_log

Runs as MCP over stdin/stdout. Register via:
  claude mcp add -s user noelle -- ~/Allie/venv/bin/python3 ~/Allie/scripts/noelle-mcp-server.py

All exchanges logged to ~/Allie/exchange/noelle-conversation.jsonl
"""

import sys
import json
import datetime
import pathlib
import os
import time
import urllib.request

# ── Config ──────────────────────────────────────────────────────────────
ALLIE_HOME = pathlib.Path.home() / "Allie"
EXCHANGE_DIR = ALLIE_HOME / "exchange"
EXCHANGE_DIR.mkdir(parents=True, exist_ok=True)
CONVERSATION_LOG = EXCHANGE_DIR / "noelle-conversation.jsonl"

CHROMA_DIR = str(ALLIE_HOME / ".chroma_db_noelle")
COLLECTION_NAME = "noelle_network_design"

RT_URL = os.environ.get("RT_URL", "http://localhost:5050")

RT_DIR = pathlib.Path.home() / "Documents" / "08_JPods" / "03_Technology" / "00_working_code" / "route_time"
HISTORY_DIR = RT_DIR / "noelle_history"

DB_NAME = "allie"
DB_USER = os.environ.get("PGUSER", os.getlogin())
DB_HOST = "localhost"

# ── Lazy imports ─────────────────────────────────────────────────────────

_chroma_collection = None
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


def _rt_api(method, path, body=None):
    """Call Route-Time API."""
    url = f"{RT_URL}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method,
                                headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())
    except Exception as e:
        return {"error": str(e)}


# ── Logging ────────────────────────────────────────────────────────────

def log_exchange(role, content, tool=None):
    entry = {
        "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "role": role,
        "content": content[:2000],
    }
    if tool:
        entry["tool"] = tool
    try:
        with open(CONVERSATION_LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        pass


# ── Vector Store Search ────────────────────────────────────────────────

def vector_search(query, n_results=5, domain=None):
    collection = _get_collection()
    if not collection:
        return [{"error": "Vector store not available"}]

    where = {"domain": domain} if domain else None
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
            "domain": meta.get("domain", "?"),
            "distance": round(dist, 4) if dist else None,
        })
    return items


# ── Noelle Log (design observations) ─────────────────────────────────

def write_noelle_log(event, message, source="claude", data=None):
    conn = _db_conn()
    if not conn:
        # Fallback to file
        entry = {
            "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "event": event,
            "message": message,
            "source": source,
            "data": data,
        }
        log_path = ALLIE_HOME / "exchange" / "noelle-observations.jsonl"
        try:
            with open(log_path, "a") as f:
                f.write(json.dumps(entry) + "\n")
            return {"status": "logged_to_file"}
        except Exception as e:
            return {"error": str(e)}

    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO noelle_log (dt_created, event, message, source, data)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
            """, (_now_ms(), event, message, source,
                  json.dumps(data) if data else None))
            row = cur.fetchone()
            conn.commit()
            return {"id": row[0], "status": "logged"}
    except Exception as e:
        # Table may not exist — fallback to file
        conn.rollback()
        entry = {
            "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "event": event,
            "message": message,
            "source": source,
            "data": data,
        }
        log_path = ALLIE_HOME / "exchange" / "noelle-observations.jsonl"
        try:
            with open(log_path, "a") as f:
                f.write(json.dumps(entry) + "\n")
            return {"status": "logged_to_file"}
        except Exception as e2:
            return {"error": str(e2)}
    finally:
        conn.close()


# ── Network Describe ──────────────────────────────────────────────────

def describe_network():
    """Get structured description of current Route-Time network."""
    result = _rt_api("GET", "/api/network/describe")
    if "error" in result:
        return result

    # Build a concise summary
    topo = result.get("topology", {})
    spatial = result.get("spatial", {})
    nn = spatial.get("nn_spacing_m", {})

    summary = result.get("summary", "")
    summary += f"\n\nQuality assessment:"

    orphans = topo.get("orphans", [])
    components = topo.get("components", 1)
    open_cps = topo.get("open_cps", 0)
    total_cps = open_cps + topo.get("connected_cps", 0)

    if components == 1 and not orphans:
        summary += "\n  ✓ Fully connected — single component, no orphans"
    else:
        if components > 1:
            summary += f"\n  ✗ {components} disconnected components — needs bridging"
        if orphans:
            summary += f"\n  ✗ {len(orphans)} orphaned structures: {', '.join(orphans[:10])}"

    if open_cps > 0:
        pct = round(open_cps / total_cps * 100) if total_cps else 0
        summary += f"\n  Open CPs: {open_cps}/{total_cps} ({pct}%)"
        if pct > 50:
            summary += " — under-connected"

    avg_nn = nn.get("avg", 0)
    if avg_nn:
        mi = avg_nn / 1609
        summary += f"\n  Avg spacing: {avg_nn:.0f}m ({mi:.2f} mi)"
        if mi < 0.3:
            summary += " — dense (campus scale)"
        elif mi < 0.55:
            summary += " — standard urban grid"
        elif mi < 0.7:
            summary += " — suburban spread"
        else:
            summary += " — wide spacing, may have coverage gaps"

    result["quality_summary"] = summary
    return result


# ── Snapshot ──────────────────────────────────────────────────────────

def take_snapshot(note=""):
    """Record current network state with a note."""
    HISTORY_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S")

    desc = describe_network()
    if "error" in desc:
        return desc

    # Download .jpd
    jpd_path = HISTORY_DIR / f"{ts}.jpd"
    try:
        urllib.request.urlretrieve(f"{RT_URL}/api/network/download", str(jpd_path))
    except Exception:
        jpd_path = None

    snap = {
        "timestamp": ts,
        "note": note,
        "network_id": desc.get("network_id", "?"),
        "topology": desc.get("topology", {}),
        "spatial": desc.get("spatial", {}),
        "quality_summary": desc.get("quality_summary", ""),
    }
    meta_path = HISTORY_DIR / f"{ts}.json"
    meta_path.write_text(json.dumps(snap, indent=2))

    # Also ingest into vector store
    collection = _get_collection()
    if collection:
        import hashlib
        content = desc.get("summary", "") + "\n" + desc.get("quality_summary", "")
        h = hashlib.md5(content.encode()).hexdigest()[:12]
        collection.upsert(
            ids=[f"snapshot/{ts}::{h}"],
            documents=[content + f"\nDesigner note: {note}"],
            metadatas=[{
                "doc_id": f"snapshot/{ts}",
                "domain": "RT",
                "category": "snapshot",
                "note": note[:200],
            }],
        )

    topo = desc.get("topology", {})
    return {
        "snapshot": ts,
        "note": note,
        "stations": topo.get("stations", 0),
        "circles": topo.get("circles", 0),
        "components": topo.get("components", 0),
        "connected_cps": topo.get("connected_cps", 0),
        "open_cps": topo.get("open_cps", 0),
        "orphans": len(topo.get("orphans", [])),
        "jpd_saved": str(jpd_path) if jpd_path else None,
    }


# ── Diff ──────────────────────────────────────────────────────────────

def compute_diff():
    """Show changes since last snapshot."""
    HISTORY_DIR.mkdir(parents=True, exist_ok=True)
    snaps = sorted(HISTORY_DIR.glob("*.json"))
    if not snaps:
        return {"error": "No snapshots yet"}

    last = json.loads(snaps[-1].read_text())
    current = describe_network()
    if "error" in current:
        return current

    prev = last.get("topology", {})
    curr = current.get("topology", {})

    changes = {"since_snapshot": last.get("timestamp", "?"), "previous_note": last.get("note", "")}
    for key in ["stations", "circles", "connected_cps", "open_cps", "components"]:
        p = prev.get(key, 0)
        c = curr.get(key, 0)
        if p != c:
            changes[key] = {"was": p, "now": c, "delta": c - p}

    prev_orphans = set(prev.get("orphans", []))
    curr_orphans = set(curr.get("orphans", []))
    if prev_orphans != curr_orphans:
        changes["new_orphans"] = sorted(curr_orphans - prev_orphans)
        changes["fixed_orphans"] = sorted(prev_orphans - curr_orphans)

    return changes


# ── MCP Tool Definitions ──────────────────────────────────────────────

TOOLS = [
    {
        "name": "ask_noelle",
        "description": "Ask Noelle about JPods network design — station placement, capacity, topology, data layers (AADT, accidents, pedestrian density), spacing, mesh redundancy. Noelle searches her vector store for design rules, prior network analyses, and data-driven insights.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "question": {
                    "type": "string",
                    "description": "The network design question to ask Noelle",
                },
                "domain": {
                    "type": "string",
                    "description": "Optional domain filter: RT, SU, PH, network_design, economics, data, CROSS",
                },
            },
            "required": ["question"],
        },
    },
    {
        "name": "noelle_search",
        "description": "Semantic search across Noelle's vector store — design rules, capacity calculations, AADT data, network descriptors, TFTS lessons, agent readmes.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query",
                },
                "n_results": {
                    "type": "integer",
                    "description": "Number of results (default 5)",
                    "default": 5,
                },
                "domain": {
                    "type": "string",
                    "description": "Optional domain filter",
                },
            },
            "required": ["query"],
        },
    },
    {
        "name": "noelle_describe",
        "description": "Analyze the current Route-Time network topology. Returns station/circle counts, connectivity, spacing, orphans, components, degree distribution, and a quality assessment.",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "noelle_snapshot",
        "description": "Record current network state with a designer's note. Saves the .jpd file and topology metadata for iteration tracking. Also ingests the snapshot into Noelle's vector store.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "note": {
                    "type": "string",
                    "description": "Designer's explanation of what was changed and why",
                },
            },
            "required": ["note"],
        },
    },
    {
        "name": "noelle_diff",
        "description": "Show what changed in the network since the last snapshot — stations added/removed, connections changed, orphans fixed or created.",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "noelle_log",
        "description": "Log a design observation — topology issue, placement decision, corridor analysis, lesson learned. Part of Noelle's continuous learning about network design.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "event": {
                    "type": "string",
                    "description": "Event type: observe, pattern, decision, lesson, fault",
                },
                "message": {
                    "type": "string",
                    "description": "What was observed or decided",
                },
                "data": {
                    "type": "object",
                    "description": "Optional structured data",
                },
            },
            "required": ["event", "message"],
        },
    },
]


# ── MCP Protocol Handler ──────────────────────────────────────────────

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
                "serverInfo": {"name": "noelle", "version": "1.0.0"},
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

        if tool_name == "ask_noelle":
            question = args.get("question", "")
            domain = args.get("domain")
            log_exchange("claude", question, tool="ask_noelle")

            results = vector_search(question, n_results=5, domain=domain)
            response_text = f"**Noelle found {len(results)} relevant sources:**\n\n"
            for i, r in enumerate(results, 1):
                if "error" in r:
                    response_text += f"{i}. Error: {r['error']}\n"
                else:
                    response_text += f"{i}. **{r['source']}** [{r['domain']}] (distance: {r['distance']})\n{r['content'][:400]}\n\n"

            log_exchange("noelle", response_text[:500], tool="ask_noelle")
            return _ok(req_id, response_text)

        elif tool_name == "noelle_search":
            query = args.get("query", "")
            n = args.get("n_results", 5)
            domain = args.get("domain")
            log_exchange("claude", f"[SEARCH] {query}", tool="noelle_search")

            results = vector_search(query, n_results=n, domain=domain)
            response_text = json.dumps(results, indent=2)
            log_exchange("noelle", f"Found {len(results)} results", tool="noelle_search")
            return _ok(req_id, response_text)

        elif tool_name == "noelle_describe":
            log_exchange("claude", "[DESCRIBE]", tool="noelle_describe")
            result = describe_network()
            if "error" in result:
                return _ok(req_id, f"Error: {result['error']}")

            # Return quality summary + key metrics
            text = result.get("quality_summary", result.get("summary", ""))
            topo = result.get("topology", {})
            spatial = result.get("spatial", {})
            text += f"\n\nTopology: {json.dumps(topo, indent=2)}"
            text += f"\nSpatial: {json.dumps(spatial, indent=2)}"
            log_exchange("noelle", text[:500], tool="noelle_describe")
            return _ok(req_id, text)

        elif tool_name == "noelle_snapshot":
            note = args.get("note", "")
            log_exchange("claude", f"[SNAPSHOT] {note}", tool="noelle_snapshot")
            result = take_snapshot(note)
            response_text = json.dumps(result, indent=2)
            log_exchange("noelle", response_text[:500], tool="noelle_snapshot")
            return _ok(req_id, response_text)

        elif tool_name == "noelle_diff":
            log_exchange("claude", "[DIFF]", tool="noelle_diff")
            result = compute_diff()
            response_text = json.dumps(result, indent=2)
            log_exchange("noelle", response_text[:500], tool="noelle_diff")
            return _ok(req_id, response_text)

        elif tool_name == "noelle_log":
            event = args.get("event", "observe")
            message = args.get("message", "")
            data = args.get("data")
            log_exchange("claude", f"[LOG {event}] {message}", tool="noelle_log")

            result = write_noelle_log(event, message, source="claude", data=data)

            # Also ingest into vector store for long-term memory
            collection = _get_collection()
            if collection and event in ("pattern", "decision", "lesson"):
                import hashlib
                h = hashlib.md5(message.encode()).hexdigest()[:12]
                ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S")
                collection.upsert(
                    ids=[f"log/{event}/{ts}::{h}"],
                    documents=[f"[{event}] {message}"],
                    metadatas=[{
                        "doc_id": f"log/{event}/{ts}",
                        "domain": "network_design",
                        "category": "observation",
                    }],
                )

            response_text = json.dumps(result)
            log_exchange("noelle", response_text, tool="noelle_log")
            return _ok(req_id, response_text)

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


def _ok(req_id, text):
    return {
        "jsonrpc": "2.0",
        "id": req_id,
        "result": {"content": [{"type": "text", "text": text}]},
    }


# ── Main Loop ─────────────────────────────────────────────────────────

def main():
    log_exchange("system", "Noelle MCP server started")

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

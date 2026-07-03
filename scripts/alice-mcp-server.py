#!/usr/bin/env python3
"""
Alice MCP Server — Claude Code talks to Alice for WebClerk commerce operations.

Alice is the WebClerk specialist: data quality, billing integrity, pattern
recognition, and the bridge between JPods operations and the commerce layer.

Tools:
  ask_alice       — Ask Alice about commerce, pricing, data quality, billing
  alice_search    — Semantic search across Alice's vector store (WC3 code + docs)
  alice_observe   — Log an observation to alice_log (pattern recognition loop)
  alice_recall    — Recall patterns Alice has seen in commerce data

Runs as MCP over stdin/stdout. Registered via:
  claude mcp add -s user alice -- ~/Allie/venv/bin/python3 <this_file>

All exchanges logged to ~/Allie/exchange/alice-conversation.jsonl
"""

import sys
import json
import datetime
import pathlib
import os
import time

# ── Config ──────────────────────────────────────────────────────────────
ALLIE_HOME = pathlib.Path.home() / "Allie"
EXCHANGE_DIR = ALLIE_HOME / "exchange"
EXCHANGE_DIR.mkdir(parents=True, exist_ok=True)
CONVERSATION_LOG = EXCHANGE_DIR / "alice-conversation.jsonl"

CHROMA_DIR = str(ALLIE_HOME / ".chroma_db_alice")
COLLECTION_NAME = "alice_commerce_knowledge"

DB_NAME = "allie"
DB_USER = os.environ.get("PGUSER", os.getlogin())
DB_HOST = "localhost"

# ── Lazy imports (chromadb/psycopg2 may not be in system python) ───────

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


# ── MCP Tool Definitions ──────────────────────────────────────────────

TOOLS = [
    {
        "name": "ask_alice",
        "description": "Ask Alice about WebClerk commerce — pricing, billing, data quality, customer patterns, inventory, transactions. Alice searches her vector store for relevant WC3 code and documentation to answer.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "question": {
                    "type": "string",
                    "description": "The commerce question to ask Alice",
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
        "description": "Semantic search across Alice's vector store — WC3 source code, readmes, model definitions, views, transaction logic, Alice agent docs.",
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
                "category": {
                    "type": "string",
                    "description": "Optional category filter",
                },
            },
            "required": ["query"],
        },
    },
    {
        "name": "alice_observe",
        "description": "Log an observation to alice_log — part of Alice's pattern recognition loop (observe > log > pattern > recommend > promote). Use for data quality issues, billing anomalies, customer behavior patterns, API errors.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "event": {
                    "type": "string",
                    "description": "Event type: observe, pattern, recommend, promote, error, anomaly",
                },
                "model_name": {
                    "type": "string",
                    "description": "WC3 model involved: invoice, order, customer, item, payment, action, etc.",
                },
                "message": {
                    "type": "string",
                    "description": "What was observed",
                },
                "data": {
                    "type": "object",
                    "description": "Optional structured data about the observation",
                },
            },
            "required": ["event", "model_name", "message"],
        },
    },
    {
        "name": "alice_recall",
        "description": "Recall patterns Alice has logged — search alice_log for prior observations, patterns, and recommendations. Alice's memory of what she's seen in commerce data.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search term for alice_log entries",
                },
                "event": {
                    "type": "string",
                    "description": "Filter by event type: observe, pattern, recommend, promote, error",
                },
                "limit": {
                    "type": "integer",
                    "description": "Max results (default 10)",
                    "default": 10,
                },
            },
        },
    },
    {
        "name": "alice_quiz",
        "description": "Get a quiz question from Alice to test commerce knowledge. Categories: commerce_flow, models, tools, billing, data_quality, inventory. Returns a question, choices, correct answer, and explanation sourced from WC3 documentation.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "category": {
                    "type": "string",
                    "description": "Quiz category: commerce_flow, models, tools, billing, data_quality, inventory, or 'random' for any",
                    "default": "random",
                },
                "count": {
                    "type": "integer",
                    "description": "Number of questions (default 3, max 10)",
                    "default": 3,
                },
                "difficulty": {
                    "type": "string",
                    "description": "Difficulty: beginner, intermediate, advanced",
                    "default": "intermediate",
                },
            },
        },
    },
]


# ── Quiz Engine ───────────────────────────────────────────────────────

def get_quiz_questions(category="random", count=3, difficulty="intermediate"):
    """Fetch quiz questions from WC3 Document records."""
    import urllib.request as ur
    import random

    # Login
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
        # Fallback: return from embedded questions
        return _fallback_quiz(category, count, difficulty)

    # Fetch quiz documents
    filters = {"model_name": "quiz", "is_active": True}
    if category != "random":
        pass  # category filtering done client-side from data.category

    try:
        url = f"http://localhost:8000/wcapi/list/document/?limit=100&filters={json.dumps(filters)}"
        req = ur.Request(url, headers={"Authorization": f"Bearer {token}"})
        with ur.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            docs = result.get("data", {}).get("results", [])
    except Exception:
        return _fallback_quiz(category, count, difficulty)

    # Parse questions from document body JSON
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
        {"category": "tools", "difficulty": "intermediate", "question": "What is the difference between WeasyPrint and ReportLab?", "choices": ["A) WeasyPrint is for images, ReportLab for text", "B) WeasyPrint converts HTML/CSS to PDF, ReportLab builds PDF programmatically", "C) They do the same thing", "D) ReportLab is JavaScript, WeasyPrint is Python"], "answer": "B", "explanation": "WeasyPrint takes HTML templates + CSS and renders PDF (good for branded docs). ReportLab builds PDFs element by element in Python (good for exact positioning like invoices)."},
        {"category": "data_quality", "difficulty": "beginner", "question": "All CRUD operations in WC3 must go through which layer?", "choices": ["A) Django admin", "B) Direct model access", "C) wcapi", "D) React frontend"], "answer": "C", "explanation": "wcapi enforces RBAC, query scoping, field filtering, and audit. No direct model access — every operation flows through wcapi."},
        {"category": "data_quality", "difficulty": "intermediate", "question": "What tool helps Ingrid deduplicate 'ACME Corp' vs 'Acme Corporation'?", "choices": ["A) phonenumbers", "B) pycountry", "C) thefuzz", "D) chardet"], "answer": "C", "explanation": "thefuzz uses Levenshtein distance to score string similarity. It flags potential duplicates so Ingrid can merge or prompt for review."},
        {"category": "billing", "difficulty": "intermediate", "question": "What is a Small-Sting in the JPods/WC3 context?", "choices": ["A) A small bug", "B) A customer-assessed fine for unresolved problems", "C) A micro-payment", "D) A discount code"], "answer": "B", "explanation": "Small-Stings are customer-assessed fines for unresolved problems. JPods also pays customers for retrospections. Alice accounts for both flows."},
        {"category": "inventory", "difficulty": "intermediate", "question": "In the WC3 transaction flow, what happens to on_hand inventory when an Invoice is created?", "choices": ["A) It increases", "B) It stays the same", "C) It decreases (on_hand reduced, on_so reduced)", "D) It is transferred to another location"], "answer": "C", "explanation": "Invoice creation reduces both on_hand (goods shipped) and on_so (sales order commitment fulfilled). The Proposal→Order→Invoice chain: +on_p, +on_so/-on_p, -on_so/-on_hand."},
        {"category": "commerce_flow", "difficulty": "advanced", "question": "What does Desktop Hosting mean by 'published-based' vs 'message-based' communications?", "choices": ["A) Email vs chat", "B) Static pages vs dynamic responses based on relationship and context", "C) Print vs digital", "D) Public vs private"], "answer": "B", "explanation": "Message-based = 'leave a message.' Published-based = 'here is what you are looking for' — dynamic, data-driven responses personalized to the contact's relationship and context. This is the core WebClerk principle from Bill's 2002 Wiley book."},
    ]

    filtered = [q for q in all_q if category == "random" or q["category"] == category]
    if difficulty != "any":
        diff_filtered = [q for q in filtered if q["difficulty"] == difficulty]
        if diff_filtered:
            filtered = diff_filtered

    random.shuffle(filtered)
    return filtered[:min(count, len(filtered))]


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
                "serverInfo": {"name": "alice", "version": "1.0.0"},
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

        if tool_name == "ask_alice":
            question = args.get("question", "")
            category = args.get("category")
            log_exchange("claude", question, tool="ask_alice")

            # Search vector store for relevant context
            results = vector_search(question, n_results=5, category=category)
            context_parts = []
            for r in results:
                if "error" not in r:
                    context_parts.append(f"[{r['source']}] {r['content']}")

            response_text = f"**Alice found {len(results)} relevant sources:**\n\n"
            for i, r in enumerate(results, 1):
                if "error" in r:
                    response_text += f"{i}. Error: {r['error']}\n"
                else:
                    response_text += f"{i}. **{r['source']}** (distance: {r['distance']})\n{r['content'][:400]}\n\n"

            log_exchange("alice", response_text[:500], tool="ask_alice")
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": response_text}]},
            }

        elif tool_name == "alice_search":
            query = args.get("query", "")
            n = args.get("n_results", 5)
            category = args.get("category")
            log_exchange("claude", f"[SEARCH] {query}", tool="alice_search")

            results = vector_search(query, n_results=n, category=category)
            response_text = json.dumps(results, indent=2)
            log_exchange("alice", f"Found {len(results)} results", tool="alice_search")
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": response_text}]},
            }

        elif tool_name == "alice_observe":
            event = args.get("event", "observe")
            model_name = args.get("model_name", "")
            message = args.get("message", "")
            data = args.get("data")
            log_exchange("claude", f"[OBSERVE {event}:{model_name}] {message}", tool="alice_observe")

            result = write_alice_log(event, model_name, message, source="claude", data=data)
            response_text = json.dumps(result)
            log_exchange("alice", response_text, tool="alice_observe")
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": response_text}]},
            }

        elif tool_name == "alice_recall":
            query = args.get("query")
            event = args.get("event")
            limit = args.get("limit", 10)
            log_exchange("claude", f"[RECALL] query={query} event={event}", tool="alice_recall")

            results = recall_alice_log(query=query, event=event, limit=limit)
            response_text = json.dumps(results, indent=2, default=str)
            log_exchange("alice", f"Recalled {len(results)} entries", tool="alice_recall")
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": response_text}]},
            }

        elif tool_name == "alice_quiz":
            category = args.get("category", "random")
            count = min(args.get("count", 3), 10)
            difficulty = args.get("difficulty", "intermediate")
            log_exchange("claude", f"[QUIZ] category={category} count={count} difficulty={difficulty}", tool="alice_quiz")

            questions = get_quiz_questions(category, count, difficulty)
            if not questions:
                response_text = "No quiz questions available for that category/difficulty."
            else:
                parts = [f"**Alice's Quiz** — {len(questions)} questions ({category}, {difficulty})\n"]
                for i, q in enumerate(questions, 1):
                    parts.append(f"**Q{i}. [{q.get('category','')}]** {q['question']}")
                    for c in q.get("choices", []):
                        parts.append(f"   {c}")
                    parts.append(f"   *Answer: {q['answer']}*")
                    parts.append(f"   *{q['explanation']}*\n")
                response_text = "\n".join(parts)

            log_exchange("alice", f"Served {len(questions)} quiz questions", tool="alice_quiz")
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": response_text}]},
            }

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


# ── Main Loop ─────────────────────────────────────────────────────────

def main():
    log_exchange("system", "Alice MCP server started")

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

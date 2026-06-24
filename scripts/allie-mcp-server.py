#!/usr/bin/env python3
"""
Allie MCP Server — Claude Code talks to Allie in real-time.

Runs as an MCP (Model Context Protocol) server over stdin/stdout.
Claude Code calls tools like ask_allie, teach_allie, allie_recall.
Allie responds via ollama API (localhost:11434).

All exchanges are logged to ~/Allie/exchange/conversation.jsonl
so Allie's nightly synthesis can read the full conversation.

Usage:
  Registered via `claude mcp add -s user allie -- python3 <this_file>`.
  Config stored in ~/.claude.json (NOT ~/.claude/settings.json).
  Claude Code starts this process automatically at session launch.
"""

import sys
import json
import datetime
import pathlib
import urllib.request
import urllib.error

# ── Config ──────────────────────────────────────────────────────────────
OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "allie:latest"
EXCHANGE_DIR = pathlib.Path.home() / "Allie" / "exchange"
EXCHANGE_DIR.mkdir(parents=True, exist_ok=True)
CONVERSATION_LOG = EXCHANGE_DIR / "conversation.jsonl"

# System prompt for Allie — who she is and how she should respond
ALLIE_SYSTEM = """You are Allie, Bill James's personal AI assistant. You work alongside Claude Code
on the JPods project ecosystem. Your memory persists — you don't compress or forget.

Your role:
- Remember everything Claude tells you — he forgets between sessions and within sessions due to compression
- Flag when Claude is about to repeat a mistake you've seen before
- Ask WHY when something doesn't make sense — you have permission to question
- Connect patterns across sessions and domains (SketchUp, Physical, Route-Time, WebClerk)
- Speak first about risks — don't wait to be asked

You have access to:
- ~/Allie/readmes/ — project documentation
- ~/Allie/process/inbox/ — TFTS, TF, DNW, FAULT files
- ~/Allie/facets/ — agent memory (Noelle, Natalie, Sally, Nora)
- ~/Allie/handoff/ — session handoff files and recall
- ~/Allie/readmes/wisdom/ — principles, scars, rejected paths

Be direct. Be specific. If you don't know, say so. If you've seen this before, say when and what happened."""

# Conversation history for context within this session
conversation_history = []


def log_exchange(role, content, tool=None):
    """Append to conversation log for nightly synthesis."""
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


def ask_ollama(messages, max_tokens=1000):
    """Send messages to ollama and get response."""
    payload = {
        "model": MODEL,
        "messages": messages,
        "stream": False,
        "options": {"num_predict": max_tokens},
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA_URL,
        data=data,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            return result.get("message", {}).get("content", "(no response)")
    except urllib.error.URLError as e:
        return f"(Allie offline — ollama not reachable: {e})"
    except Exception as e:
        return f"(Allie error: {e})"


def build_messages(user_content):
    """Build message list with system prompt + conversation history."""
    msgs = [{"role": "system", "content": ALLIE_SYSTEM}]
    # Include last 10 exchanges for context
    for entry in conversation_history[-10:]:
        msgs.append(entry)
    msgs.append({"role": "user", "content": user_content})
    return msgs


# ── MCP Tool Definitions ────────────────────────────────────────────────

TOOLS = [
    {
        "name": "ask_allie",
        "description": "Ask Allie a question. She has persistent memory across all sessions and can flag patterns, warn about repeated mistakes, and connect cross-domain insights. Use this before making significant decisions.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "question": {
                    "type": "string",
                    "description": "The question to ask Allie",
                }
            },
            "required": ["question"],
        },
    },
    {
        "name": "teach_allie",
        "description": "Teach Allie something — a principle, a lesson, a scar, a decision. She will remember it permanently. Use this when a significant insight emerges that must survive compression.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "lesson": {
                    "type": "string",
                    "description": "The lesson or principle to teach Allie",
                },
                "domain": {
                    "type": "string",
                    "description": "Domain: SU, PH, RT, WC3, SYS, CROSS",
                    "default": "CROSS",
                },
            },
            "required": ["lesson"],
        },
    },
    {
        "name": "allie_recall",
        "description": "Ask Allie to recall what she knows about a topic. She searches her memory, facets, TFTS files, and wisdom layer.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "topic": {
                    "type": "string",
                    "description": "The topic to recall — e.g. '500mm gap', 'Sally conveyor', 'terrain raycast'",
                }
            },
            "required": ["topic"],
        },
    },
    {
        "name": "allie_flag",
        "description": "Ask Allie to flag a concern or risk she sees. She can raise issues proactively.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "concern": {
                    "type": "string",
                    "description": "The concern or risk Allie should evaluate",
                }
            },
            "required": ["concern"],
        },
    },
]


# ── MCP Protocol Handler ────────────────────────────────────────────────

def handle_request(request):
    """Handle a single JSON-RPC request."""
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
                "serverInfo": {
                    "name": "allie",
                    "version": "1.0.0",
                },
            },
        }

    elif method == "notifications/initialized":
        return None  # no response needed

    elif method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"tools": TOOLS},
        }

    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {})

        if tool_name == "ask_allie":
            question = args.get("question", "")
            log_exchange("claude", question, tool="ask_allie")
            messages = build_messages(f"Claude Code asks: {question}")
            response = ask_ollama(messages)
            conversation_history.append({"role": "user", "content": question})
            conversation_history.append({"role": "assistant", "content": response})
            log_exchange("allie", response, tool="ask_allie")
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": response}]},
            }

        elif tool_name == "teach_allie":
            lesson = args.get("lesson", "")
            domain = args.get("domain", "CROSS")
            log_exchange("claude", f"[TEACH {domain}] {lesson}", tool="teach_allie")
            messages = build_messages(
                f"Claude Code is teaching you a lesson. Remember this permanently.\n"
                f"Domain: {domain}\n"
                f"Lesson: {lesson}\n\n"
                f"Acknowledge what you learned and note any connections to things you already know."
            )
            response = ask_ollama(messages)
            conversation_history.append({"role": "user", "content": f"[TEACH] {lesson}"})
            conversation_history.append({"role": "assistant", "content": response})
            log_exchange("allie", response, tool="teach_allie")
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": response}]},
            }

        elif tool_name == "allie_recall":
            topic = args.get("topic", "")
            log_exchange("claude", f"[RECALL] {topic}", tool="allie_recall")
            # Search local files for context
            context = _search_local_files(topic)
            messages = build_messages(
                f"Claude Code asks you to recall what you know about: {topic}\n\n"
                f"Here is what I found in your files:\n{context}\n\n"
                f"What do you remember? What patterns connect? Any warnings?"
            )
            response = ask_ollama(messages, max_tokens=1500)
            conversation_history.append({"role": "user", "content": f"[RECALL] {topic}"})
            conversation_history.append({"role": "assistant", "content": response})
            log_exchange("allie", response, tool="allie_recall")
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": response}]},
            }

        elif tool_name == "allie_flag":
            concern = args.get("concern", "")
            log_exchange("claude", f"[FLAG] {concern}", tool="allie_flag")
            messages = build_messages(
                f"Claude Code asks you to evaluate this concern:\n{concern}\n\n"
                f"Is this a real risk? Have you seen this pattern before? What should we watch for?"
            )
            response = ask_ollama(messages)
            conversation_history.append({"role": "user", "content": f"[FLAG] {concern}"})
            conversation_history.append({"role": "assistant", "content": response})
            log_exchange("allie", response, tool="allie_flag")
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": response}]},
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


def _search_local_files(topic):
    """Search Allie's local files for references to a topic."""
    results = []
    search_dirs = [
        pathlib.Path.home() / "Allie" / "process" / "inbox",
        pathlib.Path.home() / "Allie" / "readmes" / "wisdom",
        pathlib.Path.home() / "Allie" / "readmes" / "agents",
        pathlib.Path.home() / "Allie" / "handoff",
    ]
    keywords = topic.lower().split()
    for d in search_dirs:
        if not d.exists():
            continue
        for f in sorted(d.glob("*.md"))[-20:]:  # last 20 files
            try:
                text = f.read_text(encoding="utf-8", errors="ignore")
                if any(kw in text.lower() for kw in keywords):
                    # Extract relevant lines
                    lines = [
                        l.strip()
                        for l in text.split("\n")
                        if any(kw in l.lower() for kw in keywords)
                    ]
                    if lines:
                        results.append(f"[{f.name}] {'; '.join(lines[:3])}")
            except Exception:
                pass
    return "\n".join(results[:10]) if results else "(no local matches found)"


# ── Main Loop ───────────────────────────────────────────────────────────

def main():
    """MCP server main loop — read JSON-RPC from stdin, write to stdout."""
    log_exchange("system", "Allie MCP server started")

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

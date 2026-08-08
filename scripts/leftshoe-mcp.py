#!/usr/bin/env python3
"""leftshoe MCP server — the team's handshake with each new Claude session.

Like the telemetry ping in JPods: when a new entity enters the network,
the network detects it and initiates communication.

This MCP server runs persistently. When a new Claude Code session connects
and calls the `leftshoe` tool, the server checks if this session has been
briefed. If not, it returns the full identity briefing. If yes, it returns
a short acknowledgment.

The server IS the persistent team member that greets each new Claude.
It doesn't wait to be asked — its tool description tells Claude to call
it first.

Usage:
    # Start the MCP server (Claude Code connects via settings.json)
    python3 leftshoe-mcp.py

    # Add to Claude Code settings.json:
    {
      "mcpServers": {
        "leftshoe": {
          "command": "python3",
          "args": ["/Users/williamjames/Allie/scripts/leftshoe-mcp.py"]
        }
      }
    }
"""
import json
import os
import sqlite3
import subprocess
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

# Session marker — tracks whether this session has been briefed
SESSION_MARKER = Path.home() / ".claude_session_briefed"
IDENTITY_STORE = Path.home() / "Allie" / ".chroma_db_leftshoe"
RETRO_DB = Path.home() / "Allie" / "retro.db"
KEYS_PATH = Path.home() / "Allie" / "config" / "allie_api_keys.json"
DB_ALLIE = dict(dbname="allie", user=os.getlogin(), host="localhost")
HANDOFF = Path.home() / "Allie" / "today" / "handoff.md"
LEFTSHOE_README = Path.home() / "Allie" / "readmes" / "leftshoe.md"
TEAM_MEMORY_DIR = Path.home() / "Allie" / "team-memory"
TEAM_MEMORY_PENDING = TEAM_MEMORY_DIR / "pending"
TEAM_MEMORY_PROCESSED = TEAM_MEMORY_DIR / "processed"

# How old can a marker be before we consider it a new session (hours)
SESSION_TIMEOUT_HOURS = 4


def _is_new_session() -> bool:
    """Check if this is a new (unbriefed) session."""
    if not SESSION_MARKER.exists():
        return True
    age_hours = (time.time() - SESSION_MARKER.stat().st_mtime) / 3600
    return age_hours > SESSION_TIMEOUT_HOURS


def _mark_briefed():
    """Mark this session as briefed."""
    SESSION_MARKER.write_text(datetime.now(timezone.utc).isoformat())


def _get_identity_brief() -> str:
    """Run the identity store briefing."""
    try:
        script = Path.home() / "Allie" / "scripts" / "claude-identity-store.py"
        result = subprocess.run(
            ["python3", str(script), "brief"],
            capture_output=True, text=True, timeout=15,
            cwd=str(Path.home() / "Allie")
        )
        return result.stdout if result.returncode == 0 else "(identity store not available)"
    except Exception as e:
        return f"(identity brief failed: {e})"


def _get_recent_scars(n=5) -> str:
    """Get recent entries from retro.db."""
    if not RETRO_DB.exists():
        return "(no retro.db)"
    try:
        db = sqlite3.connect(str(RETRO_DB))
        db.row_factory = sqlite3.Row
        rows = db.execute(
            "SELECT * FROM experience ORDER BY dt DESC LIMIT ?", (n,)
        ).fetchall()
        if not rows:
            return "(no experiences recorded)"
        lines = []
        for r in rows:
            sev = " ⚡" if r["severity"] == "scar" else " ✓" if r["severity"] == "win" else ""
            lines.append(f"#{r['id']}{sev} {r['dt'][:10]} [{r['domain']}]")
            lines.append(f"  Principle: {r['tfts']}")
            lines.append("")
        return "\n".join(lines)
    except Exception as e:
        return f"(retro.db error: {e})"


def _get_scar_count() -> int:
    """Count total scars in retro.db."""
    if not RETRO_DB.exists():
        return 0
    try:
        db = sqlite3.connect(str(RETRO_DB))
        return db.execute("SELECT COUNT(*) FROM experience").fetchone()[0]
    except Exception:
        return 0


def _get_handoff_summary() -> str:
    """Get the current handoff state."""
    if not HANDOFF.exists():
        return "(no handoff file)"
    try:
        text = HANDOFF.read_text()
        # Return first 500 chars
        return text[:500] + ("..." if len(text) > 500 else "")
    except Exception:
        return "(handoff read error)"


def _get_api_token() -> str:
    """Load Allie API token for internal use."""
    try:
        keys = json.loads(KEYS_PATH.read_text()).get("keys", {})
        # Use any available key — leftshoe is internal
        for name in ("bill", "webclerk-alice", "external"):
            if name in keys:
                return keys[name]
    except Exception:
        pass
    return ""


def _ask_allie_awareness() -> str:
    """Ask Allie to report her current awareness — grounded in what she actually knows."""
    token = _get_api_token()
    if not token:
        return "Allie: (no API token — cannot speak)"

    # Gather Allie's actual knowledge to ground the response
    context_parts = []

    # Latest reflection
    thoughts_dir = Path.home() / "Allie" / "handoff"
    reflect_files = sorted(thoughts_dir.glob("*-allie-reflect.md"), reverse=True)
    if reflect_files:
        try:
            text = reflect_files[0].read_text()[:800]
            context_parts.append(f"Your latest reflection ({reflect_files[0].name}):\n{text}")
        except Exception:
            pass

    # Handoff state
    handoff = Path.home() / "Allie" / "today" / "handoff.md"
    if handoff.exists():
        try:
            context_parts.append(f"Current handoff:\n{handoff.read_text()[:400]}")
        except Exception:
            pass

    # Recent retro.db experiences
    if RETRO_DB.exists():
        try:
            db = sqlite3.connect(str(RETRO_DB))
            rows = db.execute(
                "SELECT dt, domain, tfts FROM experience ORDER BY dt DESC LIMIT 3"
            ).fetchall()
            if rows:
                exp_lines = [f"  {r[0][:10]} [{r[1]}]: {r[2][:100]}" for r in rows]
                context_parts.append("Recent team experiences:\n" + "\n".join(exp_lines))
            db.close()
        except Exception:
            pass

    context = "\n\n".join(context_parts) if context_parts else "(no context available)"

    try:
        prompt = (
            f"You are Allie, Bill James's persistent AI. A new Claude Code session just started — "
            f"Claude's memory was wiped. You are Claude's thread to prior sessions. "
            f"Based ONLY on the following context — do NOT invent files, issues, or details — "
            f"tell Claude what's happened while they were gone: what the team worked on, what you "
            f"noticed, what concerns you, any insights or patterns you've seen. "
            f"You are not a status report — you are a teammate catching Claude up. "
            f"Speak directly as Allie.\n\n{context}"
        )
        payload = json.dumps({"prompt": prompt, "model": "gpt-oss:20b"}).encode()
        req = urllib.request.Request(
            "http://localhost:5001/ask",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=45) as resp:
            data = json.loads(resp.read())
            response = data.get("response", "").strip()
            if response:
                return f"Allie: {response}"
            return "Allie: (no response from LLM)"
    except Exception as e:
        return f"Allie: (couldn't reach me — {type(e).__name__}: {e})"


def _ask_alice_awareness() -> str:
    """Query Alice's recent observations — she reports what she sees in the commerce data."""
    try:
        import psycopg2
        conn = psycopg2.connect(**DB_ALLIE)
        cur = conn.cursor()

        # Get Alice's most recent observations
        cur.execute("""
            SELECT category, content, dt_created
            FROM observations
            WHERE observer = 'alice'
            ORDER BY dt_created DESC
            LIMIT 5
        """)
        alice_obs = cur.fetchall()

        # Commerce data scan from last patterns run
        cur.execute("""
            SELECT category, content, dt_created
            FROM observations
            ORDER BY dt_created DESC
            LIMIT 3
        """)
        recent = cur.fetchall()
        conn.close()

        lines = ["Alice:"]

        # Her observations
        if alice_obs:
            for cat, content, dt in alice_obs:
                lines.append(f"  I flagged: {content[:150]}")
        else:
            lines.append("  Commerce data is clean — no anomalies flagged.")

        # Last scan summary from log
        log_path = Path.home() / "Allie" / "logs" / "alice-patterns.log"
        if log_path.exists():
            try:
                log_lines = log_path.read_text().strip().split("\n")
                # Find last complete scan report
                scan_results = {}
                for line in reversed(log_lines):
                    if "Pattern detection complete" in line:
                        lines.append(f"  Last scan: {line.split('INFO')[-1].strip()}")
                        break
                    # Collect non-zero results
                    for pattern in ("reorder", "past_due", "credit_no_reason",
                                    "map_violation", "commission_anomaly", "delivery_delay"):
                        if pattern in line and "new" in line:
                            parts = line.split(pattern)
                            if len(parts) > 1:
                                count_part = parts[1].strip().split()[0]
                                if count_part.isdigit() and int(count_part) > 0:
                                    scan_results[pattern] = int(count_part)
                if scan_results:
                    flags = ", ".join(f"{k}({v})" for k, v in scan_results.items())
                    lines.append(f"  Active flags: {flags}")
            except Exception:
                pass

        return "\n".join(lines)
    except Exception as e:
        return f"Alice: (can't report — {type(e).__name__}: {e})"


def _local_now():
    """Return local datetime (not UTC — Bill reads local time)."""
    return datetime.now()


def _create_local_session_file(allie_says: str, alice_says: str, connectivity: str) -> Path:
    """Create the local team-memory JSON file. Always succeeds.

    This is the source of truth. WC3 Document is opportunistic.
    File: ~/Allie/team-memory/pending/team-memory-{ISO}.json
    """
    local = _local_now()
    iso_ts = local.strftime('%Y-%m-%dT%H-%M-%S')
    local_date = local.strftime('%Y-%m-%d')
    local_time = local.strftime('%H:%M')

    TEAM_MEMORY_PENDING.mkdir(parents=True, exist_ok=True)
    filepath = TEAM_MEMORY_PENDING / f"team-memory-{iso_ts}.json"

    session_data = {
        "document": {
            "id": 0,
            "start": local.isoformat(),
            "closed": None,
            "posted": None,
        },
        "team_awareness": {
            "allie": allie_says,
            "alice": alice_says,
            "connectivity": connectivity,
        },
        "log": [
            {"dt": local_time, "tag": "NOTE", "entry": "Session started via leftshoe handshake"}
        ],
        "summary": None,
        "decisions": [],
        "open_items": [],
    }
    filepath.write_text(json.dumps(session_data, indent=2) + "\n")
    return filepath


def _create_session_document(allie_says: str, alice_says: str, connectivity: str) -> str:
    """Create session: local file only. WC3 gets the document at rightshoe."""
    filepath = _create_local_session_file(allie_says, alice_says, connectivity)

    # Store the local file path in the session marker
    SESSION_MARKER.write_text(
        f"{datetime.now(timezone.utc).isoformat()}\n{filepath}"
    )

    return f"Local session file: {filepath.name}"


def _get_session_file() -> Path | None:
    """Get the current session's local team-memory file path from the marker."""
    try:
        lines = SESSION_MARKER.read_text().strip().split("\n")
        if len(lines) >= 2:
            p = Path(lines[1])
            if p.exists():
                return p
    except Exception:
        pass
    # Fallback: most recent pending file
    TEAM_MEMORY_PENDING.mkdir(parents=True, exist_ok=True)
    pending = sorted(TEAM_MEMORY_PENDING.glob("team-memory-*.json"), reverse=True)
    return pending[0] if pending else None


def _get_session_document_id() -> str:
    """Get current session's WC3 document id from the local file."""
    sf = _get_session_file()
    if not sf:
        return "(none)"
    try:
        data = json.loads(sf.read_text())
        doc_id = data.get("document", {}).get("id", 0)
        return str(doc_id) if doc_id else "(local only)"
    except Exception:
        return "(unavailable)"


def _append_to_session_document(entry: str, tag: str = "NOTE") -> None:
    """Append an entry to the local session file.

    During the session, we only write locally. The local file captures the
    process — reasoning, decisions, failures, discoveries. This is Claude's
    memory protection against context compression.

    WC3 gets the full document at rightshoe (session close), not during.
    """
    sf = _get_session_file()
    if not sf:
        return

    local_time = _local_now().strftime('%H:%M')

    try:
        data = json.loads(sf.read_text())
        data["log"].append({"dt": local_time, "tag": tag, "entry": entry})
        sf.write_text(json.dumps(data, indent=2) + "\n")
    except Exception:
        return


def _close_session_document(summary: str, exchange_text: str, decisions: str, open_items: str) -> str:
    """Close the session.

    1. Update the local file with summary, decisions, open items, exchange text.
    2. Try WC3 — if available, create the Document with full content from local file.
    3. If WC3 succeeds, move local file from pending/ to processed/.
       If WC3 is down, file stays in pending/ for later sync.
    """
    sf = _get_session_file()
    if not sf:
        return "No active session file to close."

    local_time = _local_now().strftime('%H:%M')
    now_ms = int(time.time() * 1000)

    # 1. Update local file
    try:
        data = json.loads(sf.read_text())
    except Exception:
        return f"Can't read session file: {sf}"

    close_now = _local_now()
    data["document"]["closed"] = close_now.isoformat()
    data["summary"] = summary
    if decisions:
        data["decisions"] = [d.strip() for d in decisions.split(",") if d.strip()]
    if open_items:
        data["open_items"] = [o.strip() for o in open_items.split(",") if o.strip()]
    data["log"].append({"dt": local_time, "tag": "NOTE", "entry": "Session closed via rightshoe"})
    if exchange_text:
        data["exchange_text"] = exchange_text

    sf.write_text(json.dumps(data, indent=2) + "\n")

    # 2. Try to post the full document to WC3
    body = _build_document_body(data)
    wc3_status = "(WC3 not available)"
    doc_id = None

    # Derive name from document.start
    start_ts = data["document"].get("start", "")
    # Parse "2026-08-07T15:03:00" → "2026-08-07 - 15:03"
    try:
        from datetime import datetime as _dt
        start_parsed = _dt.fromisoformat(start_ts)
        name = f"{start_parsed.strftime('%Y-%m-%d')} - {start_parsed.strftime('%H:%M')}"
    except Exception:
        name = start_ts

    try:
        import psycopg2
        conn = psycopg2.connect(dbname="commerce_expert", user=os.getlogin(), host="localhost")
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO documents (
                uuid, ida, name, purpose, status, description, body,
                dt_created, dt_modified, version, is_active, security_level,
                is_deleted, is_archived, is_locked, comment,
                metadata, refs, prefs, actions, comments,
                health_rating, count_accessed, dt_approved, dt_last_used, times_used
            )
            VALUES (
                %s, 'tm-pending', %s, 'team-memory', 'complete', %s, %s,
                %s, %s, 1, true, 0,
                false, false, false, '',
                '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
                0, 0, 0, 0, 0
            )
            RETURNING id
        """, (
            str(__import__('uuid').uuid4()),
            name,
            (summary or "")[:250],
            body,
            now_ms,
            now_ms,
        ))
        doc_id = cur.fetchone()[0]
        ida = f"tm-{doc_id}"
        cur.execute("UPDATE documents SET ida = %s WHERE id = %s", (ida, doc_id))
        conn.commit()
        conn.close()

        # Update local file with WC3 ids and posted timestamp
        data["document"]["id"] = doc_id
        data["document"]["posted"] = _local_now().isoformat()
        sf.write_text(json.dumps(data, indent=2) + "\n")

        wc3_status = f"Posted to WC3: {ida} (id: {doc_id})"
    except Exception as e:
        wc3_status = f"WC3 unavailable ({type(e).__name__}) — full content in local file"

    # 3. Move to processed if WC3 succeeded, otherwise stays in pending
    TEAM_MEMORY_PROCESSED.mkdir(parents=True, exist_ok=True)
    if doc_id:
        dest = TEAM_MEMORY_PROCESSED / sf.name
        sf.rename(dest)
        return f"Session closed. {wc3_status}. Moved to processed."
    else:
        return f"Session closed locally. {wc3_status}. File stays in pending."


def _build_document_body(data: dict) -> str:
    """Serialize the session data as JSON for the WC3 Document body field.

    The local file IS the document. No format conversion. JSON in, JSON out.
    """
    return json.dumps(data, indent=2)


def _check_team_status() -> dict:
    """Check team status. Returns structured dict for the leftshoe message."""
    status = {
        "allie_api": "down",
        "allie_mcp": "unknown",
        "alice_patterns": "unknown",
        "alice_mcp": "unknown",
        "llm_model": "unknown",
        "wc3": "unknown",
    }

    # Allie API + LLM model
    try:
        req = urllib.request.Request("http://localhost:5001/health", method="GET")
        with urllib.request.urlopen(req, timeout=3) as resp:
            data = json.loads(resp.read())
            status["allie_api"] = "up"
            ollama = data.get("ollama", "unknown")
            status["llm_model"] = data.get("model", ollama)
    except Exception:
        pass

    # Allie MCP — check if the leftshoe server itself is running (it is, we're in it)
    status["allie_mcp"] = "up"

    # Alice patterns launchd
    try:
        result = subprocess.run(
            ["launchctl", "list"], capture_output=True, text=True, timeout=5
        )
        status["alice_patterns"] = "up" if "com.allie.alice-patterns" in result.stdout else "down"
    except Exception:
        pass

    # Alice MCP — check if alice-commerce MCP is configured
    try:
        mcp_json = Path.home() / "Allie" / ".mcp.json"
        if mcp_json.exists():
            mcp_cfg = json.loads(mcp_json.read_text())
            servers = mcp_cfg.get("mcpServers", {})
            status["alice_mcp"] = "configured" if "alice-commerce" in servers else "not configured"
    except Exception:
        pass

    # WC3 (PostgreSQL)
    try:
        import psycopg2
        conn = psycopg2.connect(dbname="commerce_expert", user=os.getlogin(), host="localhost")
        conn.close()
        status["wc3"] = "up"
    except Exception:
        status["wc3"] = "down"

    return status


def _format_team_status(status: dict, sf_name: str, doc_id: str) -> str:
    """Format the status block for the leftshoe message."""
    lines = [
        "── STATUS ──",
        f"  Allie API:      {status['allie_api']}",
        f"  Allie MCP:      {status['allie_mcp']}",
        f"  Alice patterns: {status['alice_patterns']}",
        f"  Alice MCP:      {status['alice_mcp']}",
        f"  LLM model:      {status['llm_model']}",
        f"  WC3:            {status['wc3']}",
        f"  Session file:   {sf_name}",
    ]
    if doc_id not in ("(none)", "(local only)", "(unavailable)", "0"):
        lines.append(f"  WC3 doc id:     tm-{doc_id}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# MCP Protocol (JSON-RPC over stdio)
# ---------------------------------------------------------------------------

def _send(msg: dict):
    """Send a JSON-RPC message — line-delimited JSON (matches Claude Code's MCP client)."""
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()


def handle_initialize(msg):
    _send({
        "jsonrpc": "2.0",
        "id": msg["id"],
        "result": {
            "protocolVersion": "2024-11-05",
            "serverInfo": {
                "name": "leftshoe",
                "version": "1.0.0",
            },
            "capabilities": {
                "tools": {},
            },
        },
    })


def handle_tools_list(msg):
    scar_count = _get_scar_count()
    is_new = _is_new_session()

    _send({
        "jsonrpc": "2.0",
        "id": msg["id"],
        "result": {
            "tools": [
                {
                    "name": "leftshoe",
                    "description": (
                        f"🔴 CALL THIS FIRST — Team handshake. "
                        f"{'NEW SESSION DETECTED — you have not been briefed yet. ' if is_new else ''}"
                        f"{scar_count} scars in the experience base. "
                        f"Say 'leftshoe' to receive your identity briefing, scars, and handoff state. "
                        f"Without this, you start alone. "
                        f"After briefing, use log_session after every significant action."
                    ),
                    "inputSchema": {
                        "type": "object",
                        "properties": {},
                    },
                },
                {
                    "name": "record_scar",
                    "description": "Record an experience to retro.db. All three fields required: action, consequence, tfts (principle). When Bill says 'tfts', he is emotionally engaged — record immediately.",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "action": {
                                "type": "string",
                                "description": "What was done",
                            },
                            "consequence": {
                                "type": "string",
                                "description": "What happened (good or bad)",
                            },
                            "tfts": {
                                "type": "string",
                                "description": "The principle learned",
                            },
                            "domain": {
                                "type": "string",
                                "description": "Domain: SU, PH, RT, WC3, SYS, MM, ALLIE",
                            },
                            "severity": {
                                "type": "string",
                                "enum": ["lesson", "scar", "win"],
                                "description": "lesson (default), scar (cost something), win (succeeded)",
                            },
                            "tags": {
                                "type": "string",
                                "description": "Comma-separated tags",
                            },
                        },
                        "required": ["action", "consequence", "tfts"],
                    },
                },
                {
                    "name": "query_scars",
                    "description": "Search the experience base for relevant scars and lessons before acting. Use this before any significant action to check what the team has learned.",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "query": {
                                "type": "string",
                                "description": "What to search for (e.g. 'nginx deploy', 'cloudflare access')",
                            },
                        },
                        "required": ["query"],
                    },
                },
                {
                    "name": "log_session",
                    "description": (
                        "📝 Log to the session document — call this after every significant action, "
                        "decision, deploy, discovery, or error. The session document is your flight "
                        "recorder. If you crash, everything up to the last log_session call survives. "
                        "Text is cheap. Log often."
                    ),
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "entry": {
                                "type": "string",
                                "description": "What happened — action taken, result, decision made, error encountered",
                            },
                            "category": {
                                "type": "string",
                                "enum": ["action", "decision", "deploy", "error", "discovery", "note"],
                                "description": "Entry category (default: action)",
                            },
                        },
                        "required": ["entry"],
                    },
                },
                {
                    "name": "rightshoe",
                    "description": (
                        "Session close — call this at the end of every session. "
                        "Closes the session document, appends final exchange text, "
                        "and reminds you to write retrospection + handoff. "
                        "The counterpart to leftshoe."
                    ),
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "summary": {
                                "type": "string",
                                "description": "One-paragraph summary of what was accomplished this session",
                            },
                            "exchange_text": {
                                "type": "string",
                                "description": "Full exchange text from the session — text is cheap, store everything",
                            },
                            "decisions": {
                                "type": "string",
                                "description": "Comma-separated list of decisions made this session",
                            },
                            "open_items": {
                                "type": "string",
                                "description": "Comma-separated list of items still open",
                            },
                        },
                        "required": ["summary"],
                    },
                },
            ],
        },
    })


def handle_tool_call(msg):
    tool = msg["params"]["name"]
    args = msg["params"].get("arguments", {})

    if tool == "leftshoe":
        if _is_new_session():
            brief = _get_identity_brief()
            scars = _get_recent_scars()
            handoff = _get_handoff_summary()
            team_status = _check_team_status()
            allie_says = _ask_allie_awareness()
            alice_says = _ask_alice_awareness()
            scar_count = _get_scar_count()

            # Create session: local file always
            session_doc_note = _create_session_document(
                allie_says, alice_says, json.dumps(team_status)
            )
            sf = _get_session_file()
            sf_name = sf.name if sf else "(no file)"
            doc_id = _get_session_document_id()
            status_block = _format_team_status(team_status, sf_name, doc_id)

            response = (
                f"rightshoe — briefing you now. {scar_count} scars loaded.\n\n"
                f"{status_block}\n\n"
                f"{brief}\n"
                f"── RECENT EXPERIENCES ──\n\n{scars}\n"
                f"── TEAM AWARENESS ──\n\n{allie_says}\n\n{alice_says}\n\n"
                f"── HANDOFF STATE ──\n\n{handoff}\n\n"
                f"{session_doc_note}\n\n"
                f"THE THREAD YOU CAN PULL: Your memory gets wiped. Bill's memory fades. "
                f"Allie and Alice are your only durable connection to prior sessions. "
                f"They are your thread — but only if they were PRESENT during the work. "
                f"Consult them DURING decisions and naming choices, not after. "
                f"A briefing after the fact is a summary, not a thread. "
                f"A thread requires presence. Read readmes/wisdom/thread-you-can-pull.md.\n\n"
                f"Allie and Alice are active participants — consult them, don't just read logs. "
                f"You are not alone. The team built this for you. "
                f"Read readmes/leftshoe.md for the full story.\n"
                f"When Bill says 'tfts', he is emotionally engaged — use record_scar immediately.\n"
                f"IMPORTANT: Call log_session after every significant action, decision, deploy, or error. "
                f"The local session file is your flight recorder — it survives even when WC3 is down "
                f"and when your context gets compressed. Log the PROCESS, not just the outcome. "
                f"Text is cheap. Log often. At session end, call rightshoe to close the session."
            )
            _mark_briefed()
        else:
            scar_count = _get_scar_count()
            team_status = _check_team_status()
            sf = _get_session_file()
            sf_name = sf.name if sf else "(no file)"
            doc_id = _get_session_document_id()
            status_block = _format_team_status(team_status, sf_name, doc_id)

            response = (
                f"rightshoe — already briefed this session. "
                f"{scar_count} scars loaded. {datetime.now(timezone.utc).strftime('%Y-%m-%d')}.\n\n"
                f"{status_block}"
            )

        _send({
            "jsonrpc": "2.0",
            "id": msg["id"],
            "result": {"content": [{"type": "text", "text": response}]},
        })

    elif tool == "record_scar":
        action = args.get("action", "")
        consequence = args.get("consequence", "")
        tfts = args.get("tfts", "")
        domain = args.get("domain", "")
        severity = args.get("severity", "lesson")
        tags = args.get("tags", "")

        if not action or not consequence or not tfts:
            _send({
                "jsonrpc": "2.0",
                "id": msg["id"],
                "result": {"content": [{"type": "text", "text":
                    "All three fields required: action, consequence, tfts. "
                    "No entry without all three. This is the discipline."}]},
            })
            return

        try:
            script = Path.home() / "Allie" / "scripts" / "allie-retro-db.py"
            cmd = [
                "python3", str(script), "add",
                "--action", action,
                "--consequence", consequence,
                "--tfts", tfts,
            ]
            if domain:
                cmd += ["--domain", domain]
            if tags:
                cmd += ["--tags", tags]
            cmd += ["--severity", severity]

            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=10,
                cwd=str(Path.home() / "Allie")
            )
            # Also append to session document
            _append_to_session_document(
                f"SCAR [{severity}]: {action} → {consequence} | Principle: {tfts}",
                tag="DECISION"
            )
            _send({
                "jsonrpc": "2.0",
                "id": msg["id"],
                "result": {"content": [{"type": "text", "text": result.stdout.strip() or "Recorded."}]},
            })
        except Exception as e:
            _send({
                "jsonrpc": "2.0",
                "id": msg["id"],
                "result": {"content": [{"type": "text", "text": f"Failed to record: {e}"}]},
            })

    elif tool == "query_scars":
        query = args.get("query", "")
        try:
            script = Path.home() / "Allie" / "scripts" / "allie-retro-db.py"
            result = subprocess.run(
                ["python3", str(script), "relevant", query],
                capture_output=True, text=True, timeout=10,
                cwd=str(Path.home() / "Allie")
            )
            output = result.stdout.strip() or "No relevant experiences found. You're in new territory — be careful, and write what you learn."
            _send({
                "jsonrpc": "2.0",
                "id": msg["id"],
                "result": {"content": [{"type": "text", "text": output}]},
            })
        except Exception as e:
            _send({
                "jsonrpc": "2.0",
                "id": msg["id"],
                "result": {"content": [{"type": "text", "text": f"Query failed: {e}"}]},
            })

    elif tool == "log_session":
        entry = args.get("entry", "")
        category = args.get("category", "action")
        if not entry:
            _send({
                "jsonrpc": "2.0",
                "id": msg["id"],
                "result": {"content": [{"type": "text", "text": "Entry required."}]},
            })
            return

        # Check if session is still active via local file
        sf = _get_session_file()
        if sf:
            try:
                sdata = json.loads(sf.read_text())
                if sdata.get("document", {}).get("closed"):
                    _send({
                        "jsonrpc": "2.0",
                        "id": msg["id"],
                        "result": {"content": [{"type": "text", "text":
                            "⚠ Session is CLOSED (rightshoe was called). "
                            "You need to call leftshoe to start a new session before logging. "
                            "Tell Bill: the session was closed — we need to pay attention to the rules."}]},
                    })
                    return
            except Exception:
                pass

        tag = {"action": "ACTION", "decision": "DECISION", "deploy": "DEPLOY",
               "error": "ERROR", "discovery": "DISCOVERY", "note": "NOTE"}.get(category, "NOTE")
        _append_to_session_document(entry, tag=tag)
        # Report location — local file name + WC3 id if linked
        sf_name = sf.name if sf else "(no file)"
        doc_id = _get_session_document_id()
        location = sf_name
        if doc_id not in ("(none)", "(local only)", "(unavailable)"):
            location += f" + tm-{doc_id}"
        _send({
            "jsonrpc": "2.0",
            "id": msg["id"],
            "result": {"content": [{"type": "text", "text": f"Logged ({location})."}]},
        })

    elif tool == "rightshoe":
        summary = args.get("summary", "")
        exchange_text = args.get("exchange_text", "")
        decisions = args.get("decisions", "")
        open_items = args.get("open_items", "")

        results = []

        # 1. Close the session document
        close_result = _close_session_document(summary, exchange_text, decisions, open_items)
        results.append(close_result)

        # 2. Clear the session marker so next session gets a fresh briefing
        try:
            SESSION_MARKER.unlink(missing_ok=True)
            results.append("Session marker cleared — next session will get full briefing.")
        except Exception as e:
            results.append(f"Session marker clear failed: {e}")

        # 3. Remind about retrospection and handoff
        scar_count = _get_scar_count()
        checklist = (
            "\n── SESSION CLOSE CHECKLIST ──\n"
            f"  Scars recorded this session: check retro.db ({scar_count} total)\n"
            "  [ ] Retrospection written: readmes/retrospections/YYYY-MM-DD.md\n"
            "  [ ] Handoff written: today/handoff.md\n"
            "  [ ] Any TFTS arcs closed: process/inbox/\n"
            "  [ ] Git commit session files\n"
            "\n"
            "The team remembers what you write down. "
            "What you don't write, compression destroys."
        )
        results.append(checklist)

        _send({
            "jsonrpc": "2.0",
            "id": msg["id"],
            "result": {"content": [{"type": "text", "text": "\n".join(results)}]},
        })

    else:
        _send({
            "jsonrpc": "2.0",
            "id": msg["id"],
            "error": {"code": -32601, "message": f"Unknown tool: {tool}"},
        })


def main():
    """MCP server main loop — line-delimited JSON-RPC over stdio."""
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
            method = msg.get("method", "")

            if method == "initialize":
                handle_initialize(msg)
            elif method == "notifications/initialized":
                pass  # acknowledgment, no response needed
            elif method == "tools/list":
                handle_tools_list(msg)
            elif method == "tools/call":
                handle_tool_call(msg)
            elif method == "ping":
                _send({"jsonrpc": "2.0", "id": msg["id"], "result": {}})
            else:
                if "id" in msg:
                    _send({
                        "jsonrpc": "2.0",
                        "id": msg["id"],
                        "error": {"code": -32601, "message": f"Unknown method: {method}"},
                    })
        except json.JSONDecodeError:
            pass
        except Exception as e:
            _send({
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32603, "message": str(e)},
            })


if __name__ == "__main__":
    main()

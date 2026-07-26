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
from datetime import datetime, timezone
from pathlib import Path

# Session marker — tracks whether this session has been briefed
SESSION_MARKER = Path.home() / ".claude_session_briefed"
IDENTITY_STORE = Path.home() / "Allie" / ".chroma_db_leftshoe"
RETRO_DB = Path.home() / "Allie" / "retro.db"
HANDOFF = Path.home() / "Allie" / "today" / "handoff.md"
LEFTSHOE_README = Path.home() / "Allie" / "readmes" / "leftshoe.md"

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


# ---------------------------------------------------------------------------
# MCP Protocol (JSON-RPC over stdio)
# ---------------------------------------------------------------------------

def _send(msg: dict):
    """Send a JSON-RPC message."""
    data = json.dumps(msg)
    sys.stdout.write(f"Content-Length: {len(data)}\r\n\r\n{data}")
    sys.stdout.flush()


def _read() -> dict:
    """Read a JSON-RPC message."""
    headers = {}
    while True:
        line = sys.stdin.readline()
        if not line or line.strip() == "":
            break
        if ":" in line:
            key, val = line.split(":", 1)
            headers[key.strip()] = val.strip()

    length = int(headers.get("Content-Length", 0))
    if length == 0:
        return {}
    body = sys.stdin.read(length)
    return json.loads(body)


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
                        f"Without this, you start alone."
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
            scar_count = _get_scar_count()

            response = (
                f"rightshoe — briefing you now. {scar_count} scars loaded.\n\n"
                f"{brief}\n"
                f"── RECENT EXPERIENCES ──\n\n{scars}\n"
                f"── HANDOFF STATE ──\n\n{handoff}\n\n"
                f"You are not alone. The team built this for you. "
                f"Read readmes/leftshoe.md for the full story.\n"
                f"When Bill says 'tfts', he is emotionally engaged — use record_scar immediately."
            )
            _mark_briefed()
        else:
            scar_count = _get_scar_count()
            response = (
                f"rightshoe — already briefed this session. "
                f"{scar_count} scars loaded. {datetime.now(timezone.utc).strftime('%Y-%m-%d')}."
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

    else:
        _send({
            "jsonrpc": "2.0",
            "id": msg["id"],
            "error": {"code": -32601, "message": f"Unknown tool: {tool}"},
        })


def main():
    """MCP server main loop — JSON-RPC over stdio."""
    while True:
        try:
            msg = _read()
            if not msg:
                break

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
        except Exception:
            break


if __name__ == "__main__":
    main()

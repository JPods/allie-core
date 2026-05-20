#!/usr/bin/env python3
"""
audit.py
Bill's consent gate. Serves a local HTML UI for reviewing and approving/rejecting
actions proposed by Allie and reviewed by Athena.

Usage:
  python3 audit.py          — open browser at http://localhost:7373
  python3 audit.py --cli    — terminal-only interactive review (no browser)

Rules:
- Nothing in the queue with status=pending-audit can be executed until Bill approves.
- Every approval/rejection is timestamped and logged to agent_log.jsonl.
- Overdue items (older than audit_interval_hours from profile.json) surface in harvest.md.
- Blocked items are shown read-only — Bill can acknowledge but not approve.
"""

import sys
import json
import datetime
import pathlib
import webbrowser
import http.server
import threading
import urllib.parse
from http import HTTPStatus

ALLIE = pathlib.Path("/Users/williamjames/Allie")
QUEUE_PATH = ALLIE / "config" / "action_queue.json"
LOG_PATH = ALLIE / "config" / "agent_log.jsonl"
PROFILE_PATH = ALLIE / "config" / "profile.json"

PORT = 7373


# ── Data helpers ──────────────────────────────────────────────────────────────

def load_queue() -> dict:
    if QUEUE_PATH.exists():
        try:
            return json.loads(QUEUE_PATH.read_text())
        except json.JSONDecodeError:
            pass
    return {"actions": []}


def save_queue(queue: dict):
    QUEUE_PATH.write_text(json.dumps(queue, indent=2))


def load_profile() -> dict:
    if PROFILE_PATH.exists():
        return json.loads(PROFILE_PATH.read_text())
    return {"audit": {"interval_hours": 24}}


def log_event(entry: dict):
    entry["ts"] = datetime.datetime.now().isoformat(timespec="seconds")
    with LOG_PATH.open("a") as f:
        f.write(json.dumps(entry) + "\n")


def apply_decision(action_id: str, decision: str, note: str = "") -> bool:
    """Apply approve/reject/defer to an action. Returns True if found."""
    queue = load_queue()
    now = datetime.datetime.now().isoformat(timespec="seconds")
    for a in queue["actions"]:
        if a["id"] == action_id:
            if a["status"] == "blocked":
                return False  # Cannot approve a blocked item
            a["status"] = {"approve": "approved", "reject": "rejected", "defer": "deferred"}.get(decision, decision)
            a["bill_audit"] = {
                "decision": decision,
                "ts": now,
                "note": note,
            }
            save_queue(queue)
            log_event({
                "event": f"bill-{decision}",
                "action_id": action_id,
                "note": note,
            })
            return True
    return False


# ── HTML generation ───────────────────────────────────────────────────────────

RISK_COLOR = {
    "SAFE": "#2d7a2d",
    "CAUTION": "#b07000",
    "ESCALATE": "#c04000",
    "BLOCK": "#8b0000",
}

STATUS_BADGE = {
    "pending-audit": ("⚠️ Pending Your Review", "#b07000"),
    "approved": ("✓ Approved", "#2d7a2d"),
    "approved-routine": ("✓ Routine", "#555"),
    "rejected": ("✗ Rejected", "#8b0000"),
    "deferred": ("⏸ Deferred", "#555"),
    "blocked": ("⛔ Blocked", "#8b0000"),
}


def render_page(queue: dict, profile: dict, message: str = "") -> str:
    actions = queue.get("actions", [])
    pending = [a for a in actions if a.get("status") == "pending-audit"]
    done = [a for a in actions if a.get("status") not in ("pending-audit",)]
    audit_interval = profile.get("audit", {}).get("interval_hours", 24)
    now = datetime.datetime.now()

    def age_hours(created_str):
        try:
            created = datetime.datetime.fromisoformat(created_str)
            return (now - created).total_seconds() / 3600
        except Exception:
            return 0

    def render_action(a, show_form=True):
        risk = a.get("final_risk", a.get("triage", {}).get("triage", "?"))
        risk_col = RISK_COLOR.get(risk, "#555")
        status = a.get("status", "?")
        badge_text, badge_col = STATUS_BADGE.get(status, (status, "#555"))
        created = a.get("created", "")[:16].replace("T", " ")
        age = age_hours(a.get("created", ""))
        overdue = age > audit_interval and status == "pending-audit"

        deep = a.get("deep_review") or {}
        reason = a.get("reason_review") or {}
        audit = a.get("bill_audit") or {}

        html = f"""
        <div class="action {'overdue' if overdue else ''}">
          <div class="action-header">
            <span class="id">#{a['id']}</span>
            <span class="risk" style="color:{risk_col}">■ {risk}</span>
            <span class="badge" style="background:{badge_col}">{badge_text}</span>
            <span class="meta">{a.get('from','?')} → {created}
              {'  ⚠ OVERDUE' if overdue else f'  ({age:.0f}h ago)'}</span>
          </div>
          <div class="action-body">
            <div class="field"><strong>Action:</strong> {a.get('action','')}</div>
            <div class="field"><strong>Context:</strong> {a.get('context','') or '<em>none</em>'}</div>
            <div class="field"><strong>Domain:</strong> {a.get('domain','?')}</div>
        """
        if deep.get("summary"):
            html += f"""
            <details>
              <summary><strong>Athena Deep Review</strong> — {deep.get('risk','?')} / {deep.get('recommendation','?')}</summary>
              <pre>{deep['summary'][:800]}</pre>
            </details>"""
        if reason.get("summary"):
            html += f"""
            <details>
              <summary><strong>Athena Threat Model</strong> — {reason.get('risk','?')} / {reason.get('recommendation','?')}</summary>
              <pre>{reason['summary'][:800]}</pre>
            </details>"""
        if audit:
            html += f"""
            <div class="field audit-record">Bill: <strong>{audit.get('decision','?')}</strong> at {audit.get('ts','?')[:16]}
              {f" — {audit['note']}" if audit.get('note') else ''}</div>"""

        if show_form and status == "pending-audit":
            html += f"""
            <form class="decision-form" method="POST" action="/decide">
              <input type="hidden" name="id" value="{a['id']}">
              <textarea name="note" placeholder="Optional note..." rows="2"></textarea>
              <div class="buttons">
                <button type="submit" name="decision" value="approve" class="btn-approve">✓ Approve</button>
                <button type="submit" name="decision" value="reject" class="btn-reject">✗ Reject</button>
                <button type="submit" name="decision" value="defer" class="btn-defer">⏸ Defer</button>
              </div>
            </form>"""
        elif show_form and status == "blocked":
            html += '<div class="field blocked-notice">⛔ This action was blocked by Athena. It cannot be approved. Investigate and propose a corrected action.</div>'

        html += "</div></div>"
        return html

    pending_html = "".join(render_action(a, show_form=True) for a in reversed(pending))
    done_html = "".join(render_action(a, show_form=False) for a in reversed(done[-20:]))

    msg_html = f'<div class="message">{message}</div>' if message else ""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Allie · Audit Console</title>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #111; color: #ddd; padding: 24px; }}
    h1 {{ color: #fff; font-size: 1.4rem; margin-bottom: 4px; }}
    .subtitle {{ color: #888; font-size: 0.85rem; margin-bottom: 24px; }}
    h2 {{ color: #aaa; font-size: 1rem; margin: 24px 0 12px; border-bottom: 1px solid #333; padding-bottom: 6px; }}
    .message {{ background: #1a3a1a; border-left: 3px solid #4a4; padding: 10px 14px;
                margin-bottom: 16px; border-radius: 4px; color: #8f8; }}
    .action {{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px;
               margin-bottom: 16px; overflow: hidden; }}
    .action.overdue {{ border-color: #8b3a00; }}
    .action-header {{ display: flex; align-items: center; gap: 12px; padding: 10px 14px;
                      background: #222; flex-wrap: wrap; }}
    .id {{ font-family: monospace; color: #888; font-size: 0.8rem; }}
    .risk {{ font-weight: 700; font-size: 0.9rem; }}
    .badge {{ padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; color: #fff; }}
    .meta {{ color: #666; font-size: 0.78rem; margin-left: auto; }}
    .action-body {{ padding: 14px; }}
    .field {{ margin-bottom: 10px; font-size: 0.9rem; line-height: 1.5; }}
    details {{ margin-bottom: 10px; }}
    summary {{ cursor: pointer; color: #aaa; font-size: 0.85rem; padding: 4px 0; }}
    pre {{ background: #0d0d0d; padding: 10px; border-radius: 4px; font-size: 0.78rem;
           white-space: pre-wrap; word-break: break-word; color: #bbb; margin-top: 6px; }}
    .audit-record {{ background: #1a2a1a; padding: 8px; border-radius: 4px; color: #8f8; }}
    .blocked-notice {{ background: #1a0d0d; padding: 8px; border-radius: 4px; color: #f88; }}
    .decision-form {{ margin-top: 14px; border-top: 1px solid #333; padding-top: 14px; }}
    textarea {{ width: 100%; background: #0d0d0d; border: 1px solid #333; color: #ccc;
                padding: 8px; border-radius: 4px; font-size: 0.85rem; resize: vertical; }}
    .buttons {{ display: flex; gap: 10px; margin-top: 10px; }}
    button {{ padding: 8px 20px; border: none; border-radius: 5px; font-size: 0.9rem;
              cursor: pointer; font-weight: 600; }}
    .btn-approve {{ background: #2d7a2d; color: #fff; }}
    .btn-approve:hover {{ background: #3a9a3a; }}
    .btn-reject {{ background: #7a2d2d; color: #fff; }}
    .btn-reject:hover {{ background: #9a3a3a; }}
    .btn-defer {{ background: #444; color: #ccc; }}
    .btn-defer:hover {{ background: #555; }}
    .empty {{ color: #555; font-style: italic; padding: 16px 0; }}
    .stats {{ display: flex; gap: 20px; margin-bottom: 20px; flex-wrap: wrap; }}
    .stat {{ background: #1a1a1a; border: 1px solid #333; padding: 10px 18px;
             border-radius: 6px; text-align: center; }}
    .stat-n {{ font-size: 1.6rem; font-weight: 700; color: #fff; }}
    .stat-l {{ font-size: 0.75rem; color: #777; }}
    .refresh {{ float: right; color: #555; font-size: 0.8rem; text-decoration: none; }}
    .refresh:hover {{ color: #aaa; }}
  </style>
</head>
<body>
  <h1>Allie · Audit Console</h1>
  <div class="subtitle">Review cycle: {audit_interval}h · All agent actions requiring your approval appear here.</div>
  {msg_html}
  <div class="stats">
    <div class="stat"><div class="stat-n">{len(pending)}</div><div class="stat-l">Pending Review</div></div>
    <div class="stat"><div class="stat-n">{len([a for a in actions if a.get('status')=='approved'])}</div><div class="stat-l">Approved</div></div>
    <div class="stat"><div class="stat-n">{len([a for a in actions if a.get('status')=='rejected'])}</div><div class="stat-l">Rejected</div></div>
    <div class="stat"><div class="stat-n">{len([a for a in actions if a.get('status')=='blocked'])}</div><div class="stat-l">Blocked</div></div>
  </div>
  <a class="refresh" href="/">↻ Refresh</a>
  <h2>Pending Your Review ({len(pending)})</h2>
  {pending_html if pending_html else '<div class="empty">No items pending review.</div>'}
  <h2>Recent Decisions (last 20)</h2>
  {done_html if done_html else '<div class="empty">No decisions recorded yet.</div>'}
</body>
</html>"""


# ── HTTP server ───────────────────────────────────────────────────────────────

class AuditHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Suppress default request logging

    def send_html(self, html: str, status: int = 200):
        body = html.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        queue = load_queue()
        profile = load_profile()
        self.send_html(render_page(queue, profile))

    def do_POST(self):
        if self.path != "/decide":
            self.send_response(HTTPStatus.NOT_FOUND)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8")
        params = dict(urllib.parse.parse_qsl(body))

        action_id = params.get("id", "")
        decision = params.get("decision", "")
        note = params.get("note", "").strip()

        message = ""
        if action_id and decision in ("approve", "reject", "defer"):
            found = apply_decision(action_id, decision, note)
            if found:
                message = f"Action {action_id} — {decision}d."
            else:
                message = f"Action {action_id} not found or is blocked (cannot approve blocked items)."
        else:
            message = "Invalid decision."

        queue = load_queue()
        profile = load_profile()
        self.send_html(render_page(queue, profile, message=message))


# ── CLI fallback ──────────────────────────────────────────────────────────────

def cli_review():
    queue = load_queue()
    pending = [a for a in queue.get("actions", []) if a.get("status") == "pending-audit"]
    if not pending:
        print("No items pending audit.")
        return

    print(f"\n{'='*60}")
    print(f"  AUDIT CONSOLE — {len(pending)} item(s) pending")
    print(f"{'='*60}\n")

    for a in pending:
        risk = a.get("final_risk", "?")
        print(f"[{a['id']}] {risk} | {a['from']} | {a.get('created','')[:16]}")
        print(f"  Action:  {a['action']}")
        print(f"  Context: {a.get('context','') or 'none'}")
        if a.get("deep_review"):
            print(f"  Athena:  {a['deep_review']['risk']} — {a['deep_review']['recommendation']}")
        print()

        if a.get("status") == "blocked":
            print("  ⛔ BLOCKED — cannot approve. Press Enter to skip.")
            input()
            continue

        while True:
            choice = input("  Decision [a=approve / r=reject / d=defer / s=skip]: ").strip().lower()
            if choice in ("a", "r", "d", "s"):
                break
        if choice == "s":
            continue
        decision = {"a": "approve", "r": "reject", "d": "defer"}[choice]
        note = input("  Note (optional): ").strip()
        apply_decision(a["id"], decision, note)
        print(f"  → {decision}d.\n")


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    if not (ALLIE / "config").exists():
        print("ERROR: /Users/williamjames/Allie/config not found. Is the Allie drive mounted?")
        sys.exit(1)

    if "--cli" in sys.argv:
        cli_review()
        return

    server = http.server.HTTPServer(("127.0.0.1", PORT), AuditHandler)
    url = f"http://localhost:{PORT}"
    print(f"\nAllie Audit Console")
    print(f"  {url}")
    print(f"  Ctrl+C to stop\n")

    # Open browser after short delay
    def open_browser():
        import time
        time.sleep(0.5)
        webbrowser.open(url)

    t = threading.Thread(target=open_browser, daemon=True)
    t.start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nAudit console stopped.")


if __name__ == "__main__":
    main()

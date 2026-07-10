#!/usr/bin/env python3
"""
allie_wc_client.py — WebClerk3 API client for Allie and Alice scripts

Wraps /wcapi/save/ and /wcapi/list/ for the record types Allie and Alice
create: Action (Kanban sprint cards), Project (weekly sprint containers),
and Setting (document pointers, corpus links, notes).

Usage (from other scripts):
  from allie_wc_client import WCClient
  wc = WCClient(agent="allie")
  wc.create_action("Review MeshMobility topology", project_id=25, kanban_column="InProcess")

  wc = WCClient(agent="alice")
  wc.create_document_pointer(title="Reflect 2026-04-27", path="...", summary="...")

All writes return the created record's id, or raise WCError on failure.
Reads return raw list data from the API.
"""

import json
import sys
import datetime
import pathlib
import urllib.request
import urllib.error

# Import token helper from same scripts dir
_SCRIPTS = pathlib.Path(__file__).parent
sys.path.insert(0, str(_SCRIPTS))
from allie_wc_token import get_token

WC_BASE = "http://localhost:8000"


class WCError(Exception):
    pass


class WCClient:
    """Thin wcapi client. agent = 'allie' | 'alice' | 'athena'."""

    def __init__(self, agent: str = "allie"):
        self.agent = agent
        self._token: str | None = None

    def _auth(self) -> str:
        if not self._token:
            self._token = get_token(self.agent)
        return self._token

    def _post(self, endpoint: str, payload: dict) -> dict:
        data = json.dumps(payload).encode()
        req = urllib.request.Request(
            f"{WC_BASE}{endpoint}",
            data=data,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self._auth()}",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            body = e.read().decode(errors="replace")
            raise WCError(f"HTTP {e.code} from {endpoint}: {body[:300]}")
        except Exception as e:
            raise WCError(str(e))

    def _get(self, endpoint: str, params: dict | None = None) -> dict:
        url = f"{WC_BASE}{endpoint}"
        if params:
            from urllib.parse import urlencode
            url += "?" + urlencode(params)
        req = urllib.request.Request(
            url,
            headers={"Authorization": f"Bearer {self._auth()}"},
            method="GET",
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            body = e.read().decode(errors="replace")
            raise WCError(f"HTTP {e.code} from {endpoint}: {body[:300]}")
        except Exception as e:
            raise WCError(str(e))

    def _save(self, model_name: str, fields: dict, record_id: int | None = None) -> int:
        """POST to /wcapi/save/. Returns the record id."""
        payload = {"model_name": model_name, **fields}
        if record_id:
            payload["id"] = record_id
        result = self._post("/wcapi/save/", payload)
        status = result.get("status")
        if status not in ("success", "created", "updated"):
            raise WCError(f"Save failed ({model_name}): {result}")
        record_id = result.get("data", {}).get("id") or result.get("id")
        if not record_id:
            raise WCError(f"Save succeeded but no id returned: {result}")
        return int(record_id)

    # ── Actions (Kanban sprint cards) ──────────────────────────────────────────

    def create_action(
        self,
        title: str,
        description: str = "",
        project_id: int = 0,
        project_name: str = "",
        kanban_column: str = "Backlog",
        assigned_to: list | None = None,
        deadline_days: int | None = None,
        priority: int = 1,
        status: str = "",
    ) -> int:
        """Create an Action (Kanban card). Returns record id."""
        now_ms = int(datetime.datetime.now().timestamp() * 1000)
        fields: dict = {
            "action_en": title,
            "description_en": description,
            "project_id": project_id,
            "kanban_column": kanban_column,
            "priority": priority,
        }
        if project_name:
            fields["project_name"] = project_name
        if assigned_to:
            fields["assigned_to"] = assigned_to
        if status:
            fields["status"] = status
        if deadline_days is not None:
            fields["dt_deadline"] = now_ms + deadline_days * 86_400_000
        return self._save("action", fields)

    def update_action(self, record_id: int, **fields) -> int:
        """Update an existing Action. Pass only fields to change."""
        return self._save("action", fields, record_id=record_id)

    def list_actions(self, project_id: int | None = None,
                     kanban_column: str | None = None,
                     limit: int = 50) -> list:
        params: dict = {"model_name": "action", "limit": limit}
        if project_id:
            params["project_id"] = project_id
        if kanban_column:
            params["kanban_column"] = kanban_column
        result = self._get("/wcapi/get/", params)
        return result.get("data", result) if isinstance(result, dict) else result

    # ── Projects (weekly sprint containers) ───────────────────────────────────

    def create_project(
        self,
        name: str,
        description: str = "",
        week_start: datetime.date | None = None,
    ) -> int:
        """Create a Project (weekly sprint container). Returns record id."""
        fields: dict = {"name_en": name, "description_en": description}
        if week_start:
            # dt_kanban — the sprint week start, as millisecond timestamp
            fields["dt_kanban"] = int(
                datetime.datetime.combine(week_start, datetime.time()).timestamp() * 1000
            )
        return self._save("project", fields)

    def list_projects(self, limit: int = 20) -> list:
        result = self._get("/wcapi/get/", {"model_name": "project", "limit": limit})
        return result.get("data", result) if isinstance(result, dict) else result

    # ── Document model — file/log pointers ────────────────────────────────────

    def create_document_pointer(
        self,
        title: str,
        path: str,
        summary: str = "",
        description: str = "",
        model_name: str = "",
        project_id: int | None = None,
        tags: list | None = None,
        extra: dict | None = None,
    ) -> int:
        """
        Create a Document record pointing to a file path with a summary.
        Uses the docs.Document model: name, body, description, path (JSON),
        data (JSON for agent/tags/project_id metadata).

        model_name: canonical WC3 model this document relates to (e.g. 'action',
        'project') — leave blank for standalone file pointers like reflect.md.
        """
        data: dict = {
            "agent":      self.agent,
            "dt_created": datetime.datetime.now().isoformat(),
        }
        if project_id:
            data["project_id"] = project_id
        if tags:
            data["tags"] = tags
        if extra:
            data.update(extra)

        fields: dict = {
            "name":        title,
            "body":        summary,
            "description": description or summary[:255],
            "path":        {"local": path},   # path is JSONField on Document
            "status":      "active",
            "data":        data,
        }
        if model_name:
            fields["model_name"] = model_name
        return self._save("document", fields)

    # ── AI notes (alice_pending / allie coordination) ──────────────────────────

    def create_ai_note(
        self,
        category: str,
        role: str,
        body: str,
        details: dict | None = None,
        for_agent: str | None = None,
    ) -> dict:
        """
        POST to /wcapi/ai/note/ — creates an AI coordination note.
        category: 'log' | 'pending' | 'config_suggestion' | 'keyword_gap'
        role: 'system' | 'action_required' | 'config_suggestion'
        for_agent: 'allie' | 'alice' | 'athena' (sets details.for)
        """
        payload: dict = {
            "category": category,
            "role": role,
            "body": body,
            "details": details or {},
        }
        if for_agent:
            payload["details"]["for"] = for_agent
        return self._post("/wcapi/ai/note/", payload)

    def list_ai_notes(self, category: str = "pending", days: int = 7) -> list:
        result = self._get("/wcapi/ai/report/", {"category": category, "days": days})
        return result.get("data", result) if isinstance(result, dict) else result


# ── CLI ────────────────────────────────────────────────────────────────────────

def main():
    import argparse
    parser = argparse.ArgumentParser(description="WC3 API client — quick record creation")
    parser.add_argument("--agent", default="allie", choices=["allie", "alice", "athena"])
    sub = parser.add_subparsers(dest="cmd")

    p = sub.add_parser("action", help="Create an Action record")
    p.add_argument("title")
    p.add_argument("--description", default="")
    p.add_argument("--project-id", type=int, default=0)
    p.add_argument("--project-name", default="")
    p.add_argument("--column", default="Backlog",
                   choices=["Backlog", "Planning", "InProcess", "Review", "Complete"])
    p.add_argument("--deadline-days", type=int, default=None)
    p.add_argument("--priority", type=int, default=1)

    p = sub.add_parser("project", help="Create a Project (sprint container)")
    p.add_argument("name")
    p.add_argument("--description", default="")
    p.add_argument("--week-start", default=None, help="YYYY-MM-DD")

    p = sub.add_parser("doc", help="Create a document pointer (Setting record)")
    p.add_argument("title")
    p.add_argument("path")
    p.add_argument("--summary", default="")
    p.add_argument("--purpose", default="allie_document")
    p.add_argument("--project-id", type=int, default=None)

    p = sub.add_parser("note", help="Create an AI coordination note")
    p.add_argument("body")
    p.add_argument("--category", default="log")
    p.add_argument("--role", default="system")
    p.add_argument("--for", dest="for_agent", default=None)

    args = parser.parse_args()
    if not args.cmd:
        parser.print_help()
        return

    wc = WCClient(agent=args.agent)

    try:
        if args.cmd == "action":
            week = datetime.date.today() - datetime.timedelta(days=datetime.date.today().weekday())
            rid = wc.create_action(
                title=args.title,
                description=args.description,
                project_id=args.project_id,
                project_name=args.project_name,
                kanban_column=args.column,
                deadline_days=args.deadline_days,
                priority=args.priority,
            )
            print(f"Action created: id={rid}")

        elif args.cmd == "project":
            week_start = (datetime.date.fromisoformat(args.week_start)
                          if args.week_start else
                          datetime.date.today() - datetime.timedelta(days=datetime.date.today().weekday()))
            rid = wc.create_project(args.name, args.description, week_start)
            print(f"Project created: id={rid}")

        elif args.cmd == "doc":
            rid = wc.create_document_pointer(
                title=args.title,
                path=args.path,
                summary=args.summary,
                purpose=args.purpose,
                project_id=args.project_id,
            )
            print(f"Document pointer created: id={rid}")

        elif args.cmd == "note":
            result = wc.create_ai_note(
                category=args.category,
                role=args.role,
                body=args.body,
                for_agent=args.for_agent,
            )
            print(f"Note created: {result}")

    except WCError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

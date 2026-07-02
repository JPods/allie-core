#!/usr/bin/env python3
"""
Commerce Expert MCP Server — read-only access to the commerce_expert database.

Gives Claude Code direct database query tools instead of shelling to psql.
READ-ONLY: no INSERT/UPDATE/DELETE allowed.

Tools:
  - wc_query: run SELECT queries against commerce_expert
  - wc_get_record: get a single record by model+id
  - wc_search: search records by model + keyword
  - wc_schema: get table schema (columns, types)
  - wc_count: count records with optional filter
"""
import json
import os
import re
import logging

import psycopg2
import psycopg2.extras

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

logger = logging.getLogger(__name__)

DB_NAME = "commerce_expert"
DB_USER = os.environ.get("PGUSER", os.getlogin())
DB_HOST = os.environ.get("WC_DB_HOST", "localhost")
DB_PORT = os.environ.get("WC_DB_PORT", "5432")

# Model name → table name mapping (common ones)
MODEL_TABLE_MAP = {
    "order": "orders", "invoice": "invoices", "proposal": "proposals",
    "purchase": "purchases", "payment": "payments", "receipt": "receipt",
    "work_order": "work_orders", "item": "products_item",
    "customer": "orgs_orgbase", "vendor": "orgs_orgbase",
    "manufacturer": "orgs_orgbase", "rep": "orgs_orgbase",
    "employee": "orgs_orgbase", "contact": "contacts",
    "action": "actions", "setting": "settings", "document": "documents",
    "report": "reports", "gl_account": "gl_accounts", "gl_journal": "gl_journals",
    "ledger": "ledger", "order_line": "order_lines", "invoice_line": "invoice_lines",
    "proposal_line": "proposal_lines", "purchase_line": "purchase_lines",
    "alice_observation": "alice_observations", "alice_preset": "alice_presets",
}

WRITE_PATTERN = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|TRUNCATE|GRANT|REVOKE)\b",
    re.IGNORECASE,
)


def _connect():
    return psycopg2.connect(
        dbname=DB_NAME, user=DB_USER, host=DB_HOST, port=DB_PORT
    )


def _resolve_table(model_name: str) -> str:
    """Resolve model name to table name."""
    if model_name in MODEL_TABLE_MAP:
        return MODEL_TABLE_MAP[model_name]
    # Try common patterns
    for suffix in ["s", ""]:
        candidate = model_name.replace(".", "_") + suffix
        return candidate
    return model_name


def _safe_query(sql: str) -> list[dict]:
    """Execute a read-only query, return rows as dicts."""
    if WRITE_PATTERN.search(sql):
        return [{"error": "Write operations not allowed. Use wcapi for modifications."}]
    conn = _connect()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql)
            rows = cur.fetchall()
            # Convert to serializable dicts
            result = []
            for row in rows:
                d = {}
                for k, v in dict(row).items():
                    if isinstance(v, (int, float, str, bool, type(None))):
                        d[k] = v
                    else:
                        d[k] = str(v)
                result.append(d)
            return result
    except Exception as e:
        return [{"error": str(e)}]
    finally:
        conn.close()


# ── MCP Server ──────────────────────────────────────────────────────────────

server = Server("commerce-db")


@server.list_tools()
async def list_tools():
    return [
        Tool(
            name="wc_query",
            description="Run a read-only SQL query against the commerce_expert database. SELECT only — no writes.",
            inputSchema={
                "type": "object",
                "properties": {
                    "sql": {"type": "string", "description": "SQL SELECT query"},
                    "limit": {"type": "integer", "description": "Max rows (default 50)", "default": 50},
                },
                "required": ["sql"],
            },
        ),
        Tool(
            name="wc_get_record",
            description="Get a single record by model name and ID.",
            inputSchema={
                "type": "object",
                "properties": {
                    "model": {"type": "string", "description": "Model name (order, invoice, item, customer, etc.)"},
                    "id": {"type": "integer", "description": "Record ID"},
                },
                "required": ["model", "id"],
            },
        ),
        Tool(
            name="wc_search",
            description="Search records by model and keyword. Searches ida, name, display_name, email, description fields.",
            inputSchema={
                "type": "object",
                "properties": {
                    "model": {"type": "string", "description": "Model name"},
                    "keyword": {"type": "string", "description": "Search term"},
                    "limit": {"type": "integer", "description": "Max results (default 20)", "default": 20},
                },
                "required": ["model", "keyword"],
            },
        ),
        Tool(
            name="wc_schema",
            description="Get the schema (columns and types) for a table.",
            inputSchema={
                "type": "object",
                "properties": {
                    "model": {"type": "string", "description": "Model name or table name"},
                },
                "required": ["model"],
            },
        ),
        Tool(
            name="wc_count",
            description="Count records in a model, optionally filtered.",
            inputSchema={
                "type": "object",
                "properties": {
                    "model": {"type": "string", "description": "Model name"},
                    "where": {"type": "string", "description": "Optional WHERE clause (e.g., \"status = 'active'\")"},
                },
                "required": ["model"],
            },
        ),
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict):
    if name == "wc_query":
        sql = arguments["sql"].strip()
        limit = arguments.get("limit", 50)
        if not sql.upper().startswith("SELECT"):
            return [TextContent(type="text", text=json.dumps({"error": "Only SELECT queries allowed"}))]
        if "LIMIT" not in sql.upper():
            sql = f"{sql.rstrip(';')} LIMIT {limit}"
        rows = _safe_query(sql)
        return [TextContent(type="text", text=json.dumps(rows, indent=2, default=str))]

    elif name == "wc_get_record":
        table = _resolve_table(arguments["model"])
        record_id = arguments["id"]
        rows = _safe_query(f"SELECT * FROM {table} WHERE id = {int(record_id)}")
        return [TextContent(type="text", text=json.dumps(rows[0] if rows else {"error": "not found"}, indent=2, default=str))]

    elif name == "wc_search":
        table = _resolve_table(arguments["model"])
        keyword = arguments["keyword"].replace("'", "''")
        limit = arguments.get("limit", 20)
        # Try common searchable fields
        search_fields = []
        try:
            conn = _connect()
            with conn.cursor() as cur:
                cur.execute(f"SELECT column_name FROM information_schema.columns WHERE table_name = '{table}' AND data_type IN ('character varying', 'text')")
                text_cols = [r[0] for r in cur.fetchall()]
            conn.close()
            search_fields = [c for c in text_cols if c in ('ida', 'name', 'display_name', 'email', 'description', 'account_number', 'sku')]
            if not search_fields:
                search_fields = text_cols[:3]
        except Exception:
            search_fields = ['ida']

        conditions = " OR ".join(f"{f} ILIKE '%{keyword}%'" for f in search_fields)
        rows = _safe_query(f"SELECT * FROM {table} WHERE {conditions} LIMIT {int(limit)}")
        return [TextContent(type="text", text=json.dumps(rows, indent=2, default=str))]

    elif name == "wc_schema":
        table = _resolve_table(arguments["model"])
        rows = _safe_query(f"""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_name = '{table}'
            ORDER BY ordinal_position
        """)
        return [TextContent(type="text", text=json.dumps(rows, indent=2))]

    elif name == "wc_count":
        table = _resolve_table(arguments["model"])
        where = arguments.get("where", "")
        sql = f"SELECT COUNT(*) as count FROM {table}"
        if where:
            sql += f" WHERE {where}"
        rows = _safe_query(sql)
        return [TextContent(type="text", text=json.dumps(rows[0] if rows else {"count": 0}))]

    return [TextContent(type="text", text=json.dumps({"error": f"Unknown tool: {name}"}))]


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())

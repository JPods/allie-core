#!/usr/bin/env python3
"""
allie_db_mcp.py — MCP server for the allie PostgreSQL database.

Provides Claude Code with direct database access through MCP tools
instead of shelling out to psql.

Tools:
  allie_db_query       — Read-only SQL (SELECT only)
  allie_db_remember    — Insert into claude_memory
  allie_db_recall      — Search claude_memory
  allie_db_agent_inbox — Check agent messages
  allie_db_send_message — Send agent message
  allie_db_log_observation — Insert into observations

Transport: stdio
Database: allie on localhost, user williamjames
"""

import asyncio
import json
import time
import re
import psycopg2
import psycopg2.extras

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

DB_CONFIG = {
    "dbname": "allie",
    "user": "williamjames",
    "host": "localhost",
}

server = Server("allie-db")


def get_conn():
    """Get a new database connection."""
    return psycopg2.connect(**DB_CONFIG)


def epoch_now():
    """Current time as integer epoch seconds."""
    return int(time.time())


def rows_to_dicts(cursor):
    """Convert cursor results to list of dicts."""
    if cursor.description is None:
        return []
    cols = [d[0] for d in cursor.description]
    return [dict(zip(cols, row)) for row in cursor.fetchall()]


def sanitize_sql(sql: str) -> str:
    """Reject non-SELECT statements. Returns cleaned SQL or raises."""
    stripped = sql.strip().rstrip(";").strip()
    # Check first keyword
    first_word = re.split(r'\s+', stripped, maxsplit=1)[0].upper()
    allowed = {"SELECT", "WITH", "EXPLAIN"}
    if first_word not in allowed:
        raise ValueError(
            f"Only SELECT/WITH/EXPLAIN queries allowed. Got: {first_word}"
        )
    # Reject dangerous keywords anywhere in the statement
    dangerous = re.compile(
        r'\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|TRUNCATE|GRANT|REVOKE)\b',
        re.IGNORECASE,
    )
    if dangerous.search(stripped):
        raise ValueError("Query contains disallowed write/DDL keywords.")
    return stripped


@server.list_tools()
async def list_tools():
    return [
        Tool(
            name="allie_db_query",
            description=(
                "Run a read-only SQL query against the allie database. "
                "Only SELECT/WITH/EXPLAIN allowed. Returns rows as JSON. "
                "Tables: claude_memory, agent_messages, observations, tfts, "
                "sessions, agent_facets, alice_log, noelle_log, nora_log, "
                "natalie_log, sally_log, vector_index."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "sql": {
                        "type": "string",
                        "description": "SQL SELECT query to execute",
                    }
                },
                "required": ["sql"],
            },
        ),
        Tool(
            name="allie_db_remember",
            description=(
                "Store a memory in claude_memory. Use for lessons, facts, "
                "cross-session context that should persist."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "category": {
                        "type": "string",
                        "description": "Category: lesson, fact, decision, pattern, reference",
                    },
                    "domain": {
                        "type": "string",
                        "description": "Domain: SU, PH, RT, WC3, SYS, CROSS, ALLIE",
                        "default": "CROSS",
                    },
                    "title": {
                        "type": "string",
                        "description": "Short title for the memory",
                    },
                    "content": {
                        "type": "string",
                        "description": "Full content of the memory",
                    },
                },
                "required": ["category", "title", "content"],
            },
        ),
        Tool(
            name="allie_db_recall",
            description=(
                "Search claude_memory by text or category. "
                "Returns matching memories ordered by most recent."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Text to search for in title and content",
                    },
                    "category": {
                        "type": "string",
                        "description": "Filter by category",
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Max results (default 10)",
                        "default": 10,
                    },
                },
            },
        ),
        Tool(
            name="allie_db_agent_inbox",
            description=(
                "Check agent messages. Returns messages for the specified agent."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "agent": {
                        "type": "string",
                        "description": "Agent name to check inbox for (default: claude)",
                        "default": "claude",
                    },
                    "unread_only": {
                        "type": "boolean",
                        "description": "Only show unread messages (default: true)",
                        "default": True,
                    },
                },
            },
        ),
        Tool(
            name="allie_db_send_message",
            description=(
                "Send a message to another agent via the agent message bus."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "from_agent": {
                        "type": "string",
                        "description": "Sender agent name",
                    },
                    "to_agent": {
                        "type": "string",
                        "description": "Recipient agent name",
                    },
                    "subject": {
                        "type": "string",
                        "description": "Message subject",
                    },
                    "body": {
                        "type": "string",
                        "description": "Message body",
                        "default": "",
                    },
                    "priority": {
                        "type": "integer",
                        "description": "Priority (0=normal, 1=high, 2=urgent)",
                        "default": 0,
                    },
                    "category": {
                        "type": "string",
                        "description": "Optional category tag",
                    },
                },
                "required": ["from_agent", "to_agent", "subject"],
            },
        ),
        Tool(
            name="allie_db_log_observation",
            description=(
                "Log an observation to the observations table. "
                "Used for patterns, anomalies, things worth watching."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "observer": {
                        "type": "string",
                        "description": "Who observed this (claude, allie, noelle, etc.)",
                    },
                    "content": {
                        "type": "string",
                        "description": "The observation content",
                    },
                    "category": {
                        "type": "string",
                        "description": "Category tag (default: observation)",
                        "default": "observation",
                    },
                    "domain": {
                        "type": "string",
                        "description": "Domain: SU, PH, RT, WC3, SYS, CROSS",
                        "default": "CROSS",
                    },
                },
                "required": ["observer", "content"],
            },
        ),
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict):
    try:
        if name == "allie_db_query":
            sql = sanitize_sql(arguments["sql"])
            conn = get_conn()
            try:
                cur = conn.cursor()
                cur.execute(sql)
                rows = rows_to_dicts(cur)
                return [TextContent(
                    type="text",
                    text=json.dumps(rows, default=str, indent=2),
                )]
            finally:
                conn.close()

        elif name == "allie_db_remember":
            category = arguments["category"]
            domain = arguments.get("domain", "CROSS")
            title = arguments["title"]
            content = arguments["content"]
            conn = get_conn()
            try:
                cur = conn.cursor()
                cur.execute(
                    """INSERT INTO claude_memory
                       (dt_created, category, domain, title, content, still_valid)
                       VALUES (%s, %s, %s, %s, %s, true)
                       RETURNING id""",
                    (epoch_now(), category, domain, title, content),
                )
                row_id = cur.fetchone()[0]
                conn.commit()
                return [TextContent(
                    type="text",
                    text=json.dumps({"status": "ok", "id": row_id}),
                )]
            finally:
                conn.close()

        elif name == "allie_db_recall":
            query = arguments.get("query")
            category = arguments.get("category")
            limit = arguments.get("limit", 10)
            conn = get_conn()
            try:
                cur = conn.cursor()
                conditions = ["still_valid = true"]
                params = []
                if query:
                    conditions.append(
                        "(title ILIKE %s OR content ILIKE %s)"
                    )
                    like_pat = f"%{query}%"
                    params.extend([like_pat, like_pat])
                if category:
                    conditions.append("category = %s")
                    params.append(category)
                where = " AND ".join(conditions)
                params.append(limit)
                cur.execute(
                    f"""SELECT id, dt_created, category, domain, title,
                               LEFT(content, 300) AS content_preview
                        FROM claude_memory
                        WHERE {where}
                        ORDER BY dt_created DESC
                        LIMIT %s""",
                    params,
                )
                rows = rows_to_dicts(cur)
                return [TextContent(
                    type="text",
                    text=json.dumps(rows, default=str, indent=2),
                )]
            finally:
                conn.close()

        elif name == "allie_db_agent_inbox":
            agent = arguments.get("agent", "claude")
            unread_only = arguments.get("unread_only", True)
            conn = get_conn()
            try:
                cur = conn.cursor()
                conditions = ["to_agent IN (%s, 'all')"]
                params = [agent]
                if unread_only:
                    conditions.append("read = false")
                where = " AND ".join(conditions)
                cur.execute(
                    f"""SELECT id, dt_created, from_agent, to_agent,
                               subject, LEFT(body, 200) AS body_preview,
                               priority, category, read
                        FROM agent_messages
                        WHERE {where}
                        ORDER BY priority DESC, dt_created DESC
                        LIMIT 25""",
                    params,
                )
                rows = rows_to_dicts(cur)
                return [TextContent(
                    type="text",
                    text=json.dumps(rows, default=str, indent=2),
                )]
            finally:
                conn.close()

        elif name == "allie_db_send_message":
            conn = get_conn()
            try:
                cur = conn.cursor()
                cur.execute(
                    """INSERT INTO agent_messages
                       (dt_created, from_agent, to_agent, subject, body,
                        priority, category, read, acknowledged)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, false, false)
                       RETURNING id""",
                    (
                        epoch_now(),
                        arguments["from_agent"],
                        arguments["to_agent"],
                        arguments["subject"],
                        arguments.get("body", ""),
                        arguments.get("priority", 0),
                        arguments.get("category"),
                    ),
                )
                row_id = cur.fetchone()[0]
                conn.commit()
                return [TextContent(
                    type="text",
                    text=json.dumps({"status": "sent", "id": row_id}),
                )]
            finally:
                conn.close()

        elif name == "allie_db_log_observation":
            conn = get_conn()
            try:
                cur = conn.cursor()
                cur.execute(
                    """INSERT INTO observations
                       (dt_created, observer, domain, category, content,
                        resolved)
                       VALUES (%s, %s, %s, %s, %s, false)
                       RETURNING id""",
                    (
                        epoch_now(),
                        arguments["observer"],
                        arguments.get("domain", "CROSS"),
                        arguments.get("category", "observation"),
                        arguments["content"],
                    ),
                )
                row_id = cur.fetchone()[0]
                conn.commit()
                return [TextContent(
                    type="text",
                    text=json.dumps({"status": "logged", "id": row_id}),
                )]
            finally:
                conn.close()

        else:
            return [TextContent(type="text", text=f"Unknown tool: {name}")]

    except Exception as e:
        return [TextContent(
            type="text",
            text=json.dumps({"error": str(e)}),
        )]


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())

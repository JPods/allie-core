#!/usr/bin/env python3
"""
agent_bus.py — Inter-agent message bus for the Allie agent team.

Importable library + CLI. All messages stored in PostgreSQL (allie database).

Usage as library:
    from agent_bus import send, inbox, read_message, reply, broadcast

Usage as CLI:
    python3 agent_bus.py send --from claude --to alice --subject "Build done"
    python3 agent_bus.py inbox alice
    python3 agent_bus.py read 42
    python3 agent_bus.py ack 42
    python3 agent_bus.py reply 42 --from alice --body "Got it"
    python3 agent_bus.py broadcast --from noelle --subject "Validation complete"
    python3 agent_bus.py thread 42
    python3 agent_bus.py count alice
    python3 agent_bus.py cleanup --days 30
"""

import argparse
import json
import os
import sys
import time

import psycopg2
import psycopg2.extras


# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

def _connect():
    """Return a psycopg2 connection to the allie database."""
    return psycopg2.connect(
        dbname="allie",
        user=os.getlogin(),
        host="localhost",
    )


def _now_ms():
    """Current UTC time as milliseconds since epoch."""
    return int(time.time() * 1000)


# ---------------------------------------------------------------------------
# Core API
# ---------------------------------------------------------------------------

def send(from_agent, to_agent, subject, body="", priority=0,
         category=None, context=None, response_to=None):
    """Send a message. Returns the new message id."""
    conn = _connect()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO agent_messages
                   (dt_created, from_agent, to_agent, subject, body,
                    priority, category, context, response_to)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                   RETURNING id""",
                (_now_ms(), from_agent, to_agent, subject, body,
                 priority, category,
                 json.dumps(context) if context else "{}",
                 response_to),
            )
            msg_id = cur.fetchone()[0]
            conn.commit()
            return msg_id
    finally:
        conn.close()


def inbox(agent_name, unread_only=True, limit=20):
    """Get messages for an agent. Returns list of dicts."""
    conn = _connect()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            where = "WHERE (to_agent = %s OR to_agent = 'all')"
            params = [agent_name]
            if unread_only:
                where += " AND NOT read"
            where += " ORDER BY dt_created DESC LIMIT %s"
            params.append(limit)
            cur.execute(
                f"""SELECT id, dt_created, from_agent, to_agent, subject,
                           body, priority, category, context
                    FROM agent_messages {where}""",
                params,
            )
            return [dict(row) for row in cur.fetchall()]
    finally:
        conn.close()


def read_message(message_id):
    """Mark a message as read and return the full message."""
    conn = _connect()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                """UPDATE agent_messages
                   SET read = true, dt_read = %s
                   WHERE id = %s
                   RETURNING *""",
                (_now_ms(), message_id),
            )
            row = cur.fetchone()
            conn.commit()
            return dict(row) if row else None
    finally:
        conn.close()


def acknowledge(message_id):
    """Mark a message as acknowledged."""
    conn = _connect()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE agent_messages
                   SET acknowledged = true, dt_acknowledged = %s
                   WHERE id = %s""",
                (_now_ms(), message_id),
            )
            conn.commit()
    finally:
        conn.close()


def reply(message_id, from_agent, body, context=None):
    """Reply to a message. Returns the new reply's message id."""
    conn = _connect()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Get the original message to inherit to_agent / subject
            cur.execute(
                "SELECT from_agent, subject FROM agent_messages WHERE id = %s",
                (message_id,),
            )
            original = cur.fetchone()
            if not original:
                raise ValueError(f"Message {message_id} not found")
            to_agent = original["from_agent"]
            subject = f"Re: {original['subject']}"
        # Send via the normal path (reuses connection logic)
        return send(
            from_agent=from_agent,
            to_agent=to_agent,
            subject=subject,
            body=body,
            context=context,
            response_to=message_id,
        )
    finally:
        conn.close()


def broadcast(from_agent, subject, body="", priority=0,
              category=None, context=None):
    """Send a message to all agents."""
    return send(
        from_agent=from_agent,
        to_agent="all",
        subject=subject,
        body=body,
        priority=priority,
        category=category,
        context=context,
    )


def get_thread(message_id):
    """Get a message and all replies, ordered by creation time."""
    conn = _connect()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Find the root message (walk up response_to chain)
            root_id = message_id
            for _ in range(50):  # safety limit
                cur.execute(
                    "SELECT response_to FROM agent_messages WHERE id = %s",
                    (root_id,),
                )
                row = cur.fetchone()
                if not row or row["response_to"] is None:
                    break
                root_id = row["response_to"]

            # Get root + all descendants via recursive CTE
            cur.execute(
                """WITH RECURSIVE thread AS (
                       SELECT * FROM agent_messages WHERE id = %s
                       UNION ALL
                       SELECT m.* FROM agent_messages m
                       JOIN thread t ON m.response_to = t.id
                   )
                   SELECT * FROM thread ORDER BY dt_created""",
                (root_id,),
            )
            return [dict(row) for row in cur.fetchall()]
    finally:
        conn.close()


def unread_count(agent_name):
    """Quick count of unread messages for an agent."""
    conn = _connect()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT count(*) FROM agent_messages
                   WHERE (to_agent = %s OR to_agent = 'all') AND NOT read""",
                (agent_name,),
            )
            return cur.fetchone()[0]
    finally:
        conn.close()


def cleanup(days=30):
    """Delete old read+acknowledged messages. Returns count deleted."""
    cutoff_ms = _now_ms() - (days * 86400 * 1000)
    conn = _connect()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """DELETE FROM agent_messages
                   WHERE read = true AND acknowledged = true
                     AND dt_created < %s""",
                (cutoff_ms,),
            )
            count = cur.rowcount
            conn.commit()
            return count
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _fmt_dt(ms):
    """Format millisecond timestamp for display."""
    if not ms:
        return "—"
    import datetime
    return datetime.datetime.fromtimestamp(
        ms / 1000, tz=datetime.timezone.utc
    ).strftime("%Y-%m-%d %H:%M:%S UTC")


def _print_message(msg, full=False):
    """Print a message summary or full view."""
    pri_label = {0: "", 1: " [IMPORTANT]", 2: " [URGENT]"}
    cat = f" ({msg.get('category')})" if msg.get("category") else ""
    pri = pri_label.get(msg.get("priority", 0), "")
    print(f"  #{msg['id']}  {_fmt_dt(msg['dt_created'])}")
    print(f"  From: {msg['from_agent']}  To: {msg['to_agent']}{pri}{cat}")
    print(f"  Subject: {msg['subject']}")
    if full and msg.get("body"):
        print(f"  Body: {msg['body']}")
    if full and msg.get("context") and msg["context"] != {}:
        print(f"  Context: {json.dumps(msg['context'], indent=2)}")
    if full:
        read_status = "Yes" if msg.get("read") else "No"
        ack_status = "Yes" if msg.get("acknowledged") else "No"
        print(f"  Read: {read_status}  Acknowledged: {ack_status}")
        if msg.get("response_to"):
            print(f"  In reply to: #{msg['response_to']}")
    print()


def main():
    parser = argparse.ArgumentParser(
        description="Agent message bus CLI",
        prog="agent-msg",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # send
    p_send = sub.add_parser("send", help="Send a message")
    p_send.add_argument("--from", dest="from_agent", required=True)
    p_send.add_argument("--to", dest="to_agent", required=True)
    p_send.add_argument("--subject", "-s", required=True)
    p_send.add_argument("--body", "-b", default="")
    p_send.add_argument("--priority", "-p", type=int, default=0)
    p_send.add_argument("--category", "-c", default=None)
    p_send.add_argument("--context", default=None, help="JSON string")
    p_send.add_argument("--response-to", type=int, default=None)

    # inbox
    p_inbox = sub.add_parser("inbox", help="Check inbox")
    p_inbox.add_argument("agent", help="Agent name")
    p_inbox.add_argument("--all", dest="show_all", action="store_true",
                         help="Show read messages too")
    p_inbox.add_argument("--limit", type=int, default=20)

    # read
    p_read = sub.add_parser("read", help="Read a message (marks as read)")
    p_read.add_argument("message_id", type=int)

    # ack
    p_ack = sub.add_parser("ack", help="Acknowledge a message")
    p_ack.add_argument("message_id", type=int)

    # reply
    p_reply = sub.add_parser("reply", help="Reply to a message")
    p_reply.add_argument("message_id", type=int)
    p_reply.add_argument("--from", dest="from_agent", required=True)
    p_reply.add_argument("--body", "-b", required=True)
    p_reply.add_argument("--context", default=None, help="JSON string")

    # broadcast
    p_bc = sub.add_parser("broadcast", help="Broadcast to all agents")
    p_bc.add_argument("--from", dest="from_agent", required=True)
    p_bc.add_argument("--subject", "-s", required=True)
    p_bc.add_argument("--body", "-b", default="")
    p_bc.add_argument("--priority", "-p", type=int, default=0)
    p_bc.add_argument("--category", "-c", default=None)
    p_bc.add_argument("--context", default=None, help="JSON string")

    # thread
    p_thread = sub.add_parser("thread", help="View message thread")
    p_thread.add_argument("message_id", type=int)

    # count
    p_count = sub.add_parser("count", help="Unread message count")
    p_count.add_argument("agent", help="Agent name")

    # cleanup
    p_cleanup = sub.add_parser("cleanup", help="Archive old messages")
    p_cleanup.add_argument("--days", type=int, default=30)

    args = parser.parse_args()

    if args.command == "send":
        ctx = json.loads(args.context) if args.context else None
        msg_id = send(
            args.from_agent, args.to_agent, args.subject, args.body,
            args.priority, args.category, ctx, args.response_to,
        )
        print(f"Sent message #{msg_id}")

    elif args.command == "inbox":
        messages = inbox(args.agent, unread_only=not args.show_all,
                         limit=args.limit)
        if not messages:
            print(f"No {'unread ' if not args.show_all else ''}messages for {args.agent}")
        else:
            print(f"Inbox for {args.agent} ({len(messages)} messages):\n")
            for msg in messages:
                _print_message(msg)

    elif args.command == "read":
        msg = read_message(args.message_id)
        if msg:
            _print_message(msg, full=True)
        else:
            print(f"Message #{args.message_id} not found")

    elif args.command == "ack":
        acknowledge(args.message_id)
        print(f"Acknowledged message #{args.message_id}")

    elif args.command == "reply":
        ctx = json.loads(args.context) if args.context else None
        msg_id = reply(args.message_id, args.from_agent, args.body, ctx)
        print(f"Sent reply #{msg_id}")

    elif args.command == "broadcast":
        ctx = json.loads(args.context) if args.context else None
        msg_id = broadcast(
            args.from_agent, args.subject, args.body,
            args.priority, args.category, ctx,
        )
        print(f"Broadcast message #{msg_id}")

    elif args.command == "thread":
        messages = get_thread(args.message_id)
        if not messages:
            print(f"No thread found for message #{args.message_id}")
        else:
            print(f"Thread ({len(messages)} messages):\n")
            for msg in messages:
                _print_message(msg, full=True)

    elif args.command == "count":
        n = unread_count(args.agent)
        print(f"{args.agent}: {n} unread message(s)")

    elif args.command == "cleanup":
        n = cleanup(args.days)
        print(f"Cleaned up {n} message(s) older than {args.days} days")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Retrospection Database — structured experience base for the team.

Every entry requires: action, consequence, tfts (principle learned).
No entry without all three. This is the discipline.

Usage:
    # Record an experience (all three fields required)
    python3 allie-retro-db.py add \
        --action "Changed CF Access policy to Allow Everyone" \
        --consequence "Site still blocked — Allow forces login, only Bypass/Delete removes the wall" \
        --tfts "CF Access Allow ≠ public. Delete the application or use Bypass. App-level auth is the right place." \
        --domain SYS --tags "cloudflare,access,nginx"

    # Query before acting — "what do we know about X?"
    python3 allie-retro-db.py query "nginx 403"
    python3 allie-retro-db.py query "cloudflare access"
    python3 allie-retro-db.py query --domain SU "build pipeline"

    # Session start — get the 10 most recent lessons
    python3 allie-retro-db.py recent

    # Session start — get lessons relevant to today's work
    python3 allie-retro-db.py relevant "printing reports pdfme"

    # Stats
    python3 allie-retro-db.py stats

    # Export for Allie's nightly synthesis
    python3 allie-retro-db.py export --since 7d

    # Grade a past lesson — did we follow it?
    python3 allie-retro-db.py grade <id> --score A --note "Followed correctly"

DB: ~/Allie/retro.db (SQLite)
"""
import argparse
import json
import os
import sqlite3
import sys
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path

DB_PATH = Path.home() / "Allie" / "retro.db"

# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------

SCHEMA = """
CREATE TABLE IF NOT EXISTS experience (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    dt          TEXT NOT NULL,               -- ISO-8601 UTC

    -- Always required: intent and tfts book-end every entry
    intent      TEXT NOT NULL DEFAULT '',    -- what you meant to do and why
    action      TEXT NOT NULL,               -- what was done (legacy, maps to intent)
    consequence TEXT NOT NULL,               -- what happened (good or bad)
    tfts        TEXT NOT NULL,               -- the principle learned

    -- Honest accounting — enriches when available
    points_for      TEXT DEFAULT '',         -- arguments for this approach
    points_against  TEXT DEFAULT '',         -- arguments against
    harms           TEXT DEFAULT '',         -- what went wrong
    benefits        TEXT DEFAULT '',         -- what went right
    risk            TEXT DEFAULT '',         -- what could still go wrong
    help_procedure  TEXT DEFAULT '',         -- how to get help if stuck
    alternatives    TEXT DEFAULT '',         -- what else was on the table
    who_affected    TEXT DEFAULT '',         -- people, agents, systems impacted
    confidence      INTEGER DEFAULT 0,      -- how sure (1-10), 0 = not stated
    applies_to      TEXT DEFAULT '',         -- domains, agents, situations
    expires_when    TEXT DEFAULT '',         -- when this might no longer be true
    known_unknowns  TEXT DEFAULT '',         -- what we know we don't know
    unknown_unknowns TEXT DEFAULT '',        -- guesses at what we might not be seeing

    -- Classification
    domain      TEXT DEFAULT '',             -- SU, PH, RT, WC3, SYS, MM, ALLIE
    tags        TEXT DEFAULT '',             -- comma-separated searchable tags
    agent       TEXT DEFAULT 'claude',       -- who recorded it: claude, allie, alice, bill
    session     TEXT DEFAULT '',             -- session date or ID
    severity    TEXT DEFAULT 'lesson',       -- lesson, scar, win

    -- Retrospection grade — filled in later
    grade       TEXT DEFAULT '',             -- A-F
    grade_note  TEXT DEFAULT '',             -- why that grade
    grade_dt    TEXT DEFAULT '',             -- when graded
    related_ids TEXT DEFAULT ''              -- comma-separated IDs of related entries
);

CREATE VIRTUAL TABLE IF NOT EXISTS experience_fts USING fts5(
    intent, action, consequence, tfts, tags,
    points_for, points_against, harms, benefits,
    known_unknowns, unknown_unknowns,
    content='experience',
    content_rowid='id'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER IF NOT EXISTS experience_ai AFTER INSERT ON experience BEGIN
    INSERT INTO experience_fts(rowid, action, consequence, tfts, tags)
    VALUES (new.id, new.action, new.consequence, new.tfts, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS experience_ad AFTER DELETE ON experience BEGIN
    INSERT INTO experience_fts(experience_fts, rowid, action, consequence, tfts, tags)
    VALUES ('delete', old.id, old.action, old.consequence, old.tfts, old.tags);
END;

CREATE TRIGGER IF NOT EXISTS experience_au AFTER UPDATE ON experience BEGIN
    INSERT INTO experience_fts(experience_fts, rowid, action, consequence, tfts, tags)
    VALUES ('delete', old.id, old.action, old.consequence, old.tfts, old.tags);
    INSERT INTO experience_fts(rowid, action, consequence, tfts, tags)
    VALUES (new.id, new.action, new.consequence, new.tfts, new.tags);
END;
"""


def get_db():
    db = sqlite3.connect(str(DB_PATH))
    db.row_factory = sqlite3.Row
    db.executescript(SCHEMA)
    return db


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_add(args):
    """Add an experience. All three fields required — no exceptions."""
    if not args.action or not args.consequence or not args.tfts:
        print("ERROR: All three fields required: --action, --consequence, --tfts")
        print("No entry without all three. This is the discipline.")
        return 1

    db = get_db()
    dt = datetime.now(timezone.utc).isoformat()
    db.execute(
        """INSERT INTO experience (dt, action, consequence, tfts, domain, tags, agent, session, severity)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (dt, args.action, args.consequence, args.tfts,
         args.domain or '', args.tags or '', args.agent or 'claude',
         args.session or datetime.now(timezone.utc).strftime('%Y-%m-%d'),
         args.severity or 'lesson')
    )
    db.commit()
    rid = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    print(f"#{rid} recorded: {args.tfts[:80]}")
    return 0


def cmd_query(args):
    """Full-text search across all experience fields."""
    q = ' '.join(args.terms)
    if not q:
        print("Usage: allie-retro-db.py query <search terms>")
        return 1

    db = get_db()
    where = ""
    params = [q]
    if args.domain:
        where = " AND e.domain = ?"
        params.append(args.domain)

    rows = db.execute(f"""
        SELECT e.*, rank
        FROM experience_fts f
        JOIN experience e ON e.id = f.rowid
        WHERE experience_fts MATCH ?{where}
        ORDER BY rank
        LIMIT ?
    """, params + [args.limit or 10]).fetchall()

    if not rows:
        print(f"No experiences match: {q}")
        return 0

    _print_rows(rows)
    return 0


def cmd_recent(args):
    """Show the N most recent experiences."""
    db = get_db()
    n = args.limit or 10
    rows = db.execute(
        "SELECT * FROM experience ORDER BY dt DESC LIMIT ?", (n,)
    ).fetchall()
    if not rows:
        print("No experiences recorded yet.")
        return 0
    _print_rows(rows)
    return 0


def cmd_relevant(args):
    """Find experiences relevant to a topic — for session start briefing."""
    q = ' '.join(args.terms)
    if not q:
        # Fall back to recent
        return cmd_recent(args)

    db = get_db()
    # FTS query with OR between terms for broader matching
    terms = q.split()
    fts_query = ' OR '.join(terms)

    rows = db.execute("""
        SELECT e.*, rank
        FROM experience_fts f
        JOIN experience e ON e.id = f.rowid
        WHERE experience_fts MATCH ?
        ORDER BY rank
        LIMIT ?
    """, (fts_query, args.limit or 10)).fetchall()

    if not rows:
        print(f"No experiences relevant to: {q}")
        print("Starting fresh — be careful, and write what you learn.")
        return 0

    print(f"── Relevant experiences for: {q} ──\n")
    _print_rows(rows)
    return 0


def cmd_grade(args):
    """Grade a past experience — did we follow the lesson?"""
    if not args.id or not args.score:
        print("Usage: allie-retro-db.py grade <id> --score A --note 'explanation'")
        return 1

    db = get_db()
    row = db.execute("SELECT * FROM experience WHERE id = ?", (args.id,)).fetchone()
    if not row:
        print(f"Experience #{args.id} not found.")
        return 1

    dt = datetime.now(timezone.utc).isoformat()
    db.execute(
        "UPDATE experience SET grade = ?, grade_note = ?, grade_dt = ? WHERE id = ?",
        (args.score.upper(), args.note or '', dt, args.id)
    )
    db.commit()
    print(f"#{args.id} graded {args.score.upper()}: {args.note or '(no note)'}")
    return 0


def cmd_stats(args):
    """Show statistics about the experience base."""
    db = get_db()

    total = db.execute("SELECT COUNT(*) FROM experience").fetchone()[0]
    by_domain = db.execute(
        "SELECT domain, COUNT(*) as n FROM experience GROUP BY domain ORDER BY n DESC"
    ).fetchall()
    by_severity = db.execute(
        "SELECT severity, COUNT(*) as n FROM experience GROUP BY severity ORDER BY n DESC"
    ).fetchall()
    graded = db.execute("SELECT COUNT(*) FROM experience WHERE grade != ''").fetchone()[0]
    ungraded = total - graded

    # Grade distribution
    grades = db.execute(
        "SELECT grade, COUNT(*) as n FROM experience WHERE grade != '' GROUP BY grade ORDER BY grade"
    ).fetchall()

    # Scars
    scars = db.execute(
        "SELECT COUNT(*) FROM experience WHERE severity = 'scar'"
    ).fetchone()[0]

    print(f"Experience Base: {total} entries")
    print(f"  Graded: {graded}  |  Ungraded: {ungraded}")
    print(f"  Scars: {scars}")
    print()
    if by_domain:
        print("By domain:")
        for r in by_domain:
            print(f"  {r['domain'] or '(none)':<8} {r['n']}")
    if by_severity:
        print("By severity:")
        for r in by_severity:
            print(f"  {r['severity']:<8} {r['n']}")
    if grades:
        print("Grade distribution:")
        for r in grades:
            print(f"  {r['grade']:<2} {r['n']}")
    return 0


def cmd_export(args):
    """Export experiences as JSON — for Allie's nightly synthesis."""
    db = get_db()

    since = None
    if args.since:
        val = args.since.rstrip('d')
        days = int(val)
        since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()

    if since:
        rows = db.execute(
            "SELECT * FROM experience WHERE dt >= ? ORDER BY dt DESC", (since,)
        ).fetchall()
    else:
        rows = db.execute("SELECT * FROM experience ORDER BY dt DESC").fetchall()

    data = [dict(r) for r in rows]
    print(json.dumps(data, indent=2))
    return 0


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

def _print_rows(rows):
    for r in rows:
        grade = f" [{r['grade']}]" if r['grade'] else ""
        sev = f" ⚡" if r['severity'] == 'scar' else " ✓" if r['severity'] == 'win' else ""
        domain = f" [{r['domain']}]" if r['domain'] else ""
        print(f"#{r['id']}{domain}{sev}{grade}  {r['dt'][:10]}")
        print(f"  Action:      {r['action']}")
        print(f"  Consequence: {r['consequence']}")
        print(f"  Principle:   {r['tfts']}")
        if r['grade_note']:
            print(f"  Grade note:  {r['grade_note']}")
        if r['tags']:
            print(f"  Tags:        {r['tags']}")
        print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Retrospection Database — structured experience base")
    sub = parser.add_subparsers(dest="cmd")

    # add
    p = sub.add_parser("add", help="Record an experience (all three fields required)")
    p.add_argument("--action", required=True, help="What was done")
    p.add_argument("--consequence", required=True, help="What happened")
    p.add_argument("--tfts", required=True, help="The principle learned")
    p.add_argument("--domain", help="Domain: SU, PH, RT, WC3, SYS, MM, ALLIE")
    p.add_argument("--tags", help="Comma-separated tags")
    p.add_argument("--agent", default="claude", help="Who recorded: claude, allie, alice, bill")
    p.add_argument("--session", help="Session date or ID")
    p.add_argument("--severity", default="lesson", choices=["lesson", "scar", "win"])

    # query
    p = sub.add_parser("query", help="Search experiences")
    p.add_argument("terms", nargs="*", help="Search terms")
    p.add_argument("--domain", help="Filter by domain")
    p.add_argument("--limit", type=int, default=10)

    # recent
    p = sub.add_parser("recent", help="Show recent experiences")
    p.add_argument("--limit", type=int, default=10)

    # relevant
    p = sub.add_parser("relevant", help="Find experiences relevant to a topic")
    p.add_argument("terms", nargs="*", help="Topic keywords")
    p.add_argument("--limit", type=int, default=10)

    # grade
    p = sub.add_parser("grade", help="Grade a past experience")
    p.add_argument("id", type=int, help="Experience ID")
    p.add_argument("--score", required=True, help="Grade: A-F")
    p.add_argument("--note", help="Why this grade")

    # stats
    sub.add_parser("stats", help="Show statistics")

    # export
    p = sub.add_parser("export", help="Export as JSON")
    p.add_argument("--since", help="Export since N days ago (e.g. 7d)")

    args = parser.parse_args()
    if not args.cmd:
        parser.print_help()
        return 1

    cmds = {
        "add": cmd_add, "query": cmd_query, "recent": cmd_recent,
        "relevant": cmd_relevant, "grade": cmd_grade, "stats": cmd_stats,
        "export": cmd_export,
    }
    return cmds[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())

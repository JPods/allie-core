#!/usr/bin/env python3
"""
allie-scrum.py — Agent-to-Alice scrum action queue.

Any agent (Noelle, Natalie, Nora, Sally, Claude Code, Allie) can flag an action
item for Alice to add to the week's scrum. When Alice is unavailable, Allie
accumulates the queue. Alice drains it when she comes online.

Scrum items live in process/scrum/queue.json (pending) and process/scrum/YYYY-WNN.json
(weekly archive once accepted into the sprint).

Usage:
  # Flag an action (from any agent or script)
  python3 allie-scrum.py flag \\
    --agent Noelle --domain SU \\
    --title "Declare seg→gw_cp_in successors in lines.json" \\
    --why "OS-008 Step 7 snap-candidates is a workaround; explicit successor closes the gap permanently" \\
    --priority medium

  # Show pending queue
  python3 allie-scrum.py queue

  # Alice accepts items into this week's sprint (run by Alice or Bill)
  python3 allie-scrum.py accept ITEM-ID

  # Alice defers an item to next week
  python3 allie-scrum.py defer ITEM-ID --note "reason"

  # Mark item done
  python3 allie-scrum.py done ITEM-ID

  # Show this week's sprint
  python3 allie-scrum.py sprint
"""

import argparse
import datetime
import json
import pathlib
import sys
import uuid

ALLIE     = pathlib.Path.home() / 'Allie'
SCRUM_DIR = ALLIE / 'process' / 'scrum'
QUEUE_FILE = SCRUM_DIR / 'queue.json'

PRIORITIES = ('critical', 'high', 'medium', 'low')


# ── ISO week key ───────────────────────────────────────────────────────────

def week_key(dt=None):
    """Return 'YYYY-WNN' for the given date (default: today)."""
    d = dt or datetime.datetime.now(datetime.timezone.utc).date()
    iso = d.isocalendar()
    return f'{iso[0]}-W{iso[1]:02d}'

def sprint_file(wk=None):
    return SCRUM_DIR / f'{wk or week_key()}.json'


# ── Queue helpers ──────────────────────────────────────────────────────────

def load_queue():
    if not QUEUE_FILE.exists():
        return []
    try:
        return json.loads(QUEUE_FILE.read_text(encoding='utf-8'))
    except Exception:
        return []

def save_queue(items):
    SCRUM_DIR.mkdir(parents=True, exist_ok=True)
    QUEUE_FILE.write_text(json.dumps(items, indent=2), encoding='utf-8')

def load_sprint(wk=None):
    fp = sprint_file(wk)
    if not fp.exists():
        return []
    try:
        return json.loads(fp.read_text(encoding='utf-8'))
    except Exception:
        return []

def save_sprint(items, wk=None):
    SCRUM_DIR.mkdir(parents=True, exist_ok=True)
    sprint_file(wk).write_text(json.dumps(items, indent=2), encoding='utf-8')


# ── Commands ───────────────────────────────────────────────────────────────

def cmd_flag(args):
    """Any agent flags a scrum action item."""
    ts  = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    iid = f'SCRUM-{datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S")}'
    item = {
        'id':        iid,
        'flagged_at': ts,
        'agent':     args.agent,
        'domain':    args.domain or 'SU',
        'title':     args.title,
        'why':       args.why or '',
        'priority':  args.priority or 'medium',
        'os_ref':    args.os_ref or '',   # OS-NNN if related to a design decision
        'status':    'pending',           # pending | accepted | deferred | done
        'week':      None,                # set when accepted into sprint
        'notes':     ''
    }
    queue = load_queue()
    queue.append(item)
    save_queue(queue)

    # Also write to Allie process inbox so nightly reflect sees it
    inbox = ALLIE / 'process' / 'inbox'
    if inbox.exists():
        ts_file = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S')
        tf_path = inbox / f'{ts_file}-tf.md'
        tf_path.write_text(
            f'# TF — {ts}\n\n'
            f'summary: Scrum action flagged by {args.agent}: {args.title}\n'
            f'code:    process/scrum/queue.json\n',
            encoding='utf-8')

    print(f'Flagged: {iid}')
    print(f'  [{args.priority}] {args.title}')
    print(f'  Why: {args.why}')
    print(f'Queue depth: {len(queue)} item(s)')


def cmd_queue(args):
    """Show pending queue."""
    queue = load_queue()
    pending = [i for i in queue if i['status'] == 'pending']
    if not pending:
        print('Queue empty.')
        return
    print(f'Pending scrum actions ({len(pending)}):')
    pri_order = {p: i for i, p in enumerate(PRIORITIES)}
    for item in sorted(pending, key=lambda x: pri_order.get(x.get('priority','medium'), 9)):
        ref = f'  [OS: {item["os_ref"]}]' if item.get('os_ref') else ''
        print(f'  {item["id"]}  [{item["priority"]}]  [{item["agent"]}/{item["domain"]}]{ref}')
        print(f'    {item["title"]}')
        if item.get('why'):
            print(f'    Why: {item["why"]}')


def cmd_accept(args):
    """Alice accepts item into this week's sprint."""
    queue  = load_queue()
    wk     = week_key()
    sprint = load_sprint(wk)
    now    = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    moved  = 0
    for item in queue:
        if item['id'] == args.item_id:
            item['status'] = 'accepted'
            item['week']   = wk
            item['accepted_at'] = now
            sprint.append(item)
            moved += 1
    queue = [i for i in queue if i['id'] != args.item_id or i['status'] == 'pending']
    # Remove accepted from queue
    queue = [i for i in queue if not (i['id'] == args.item_id and i['status'] == 'accepted')]
    save_queue(queue)
    save_sprint(sprint, wk)
    if moved:
        print(f'Accepted {args.item_id} into sprint {wk}')
    else:
        print(f'Item {args.item_id} not found in queue', file=sys.stderr)


def cmd_defer(args):
    """Defer item to next week."""
    queue = load_queue()
    now   = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    for item in queue:
        if item['id'] == args.item_id:
            item['status'] = 'deferred'
            item['deferred_at'] = now
            item['notes'] = args.note or ''
    save_queue(queue)
    print(f'Deferred {args.item_id}')


def cmd_done(args):
    """Mark item done in current sprint."""
    wk     = week_key()
    sprint = load_sprint(wk)
    now    = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    for item in sprint:
        if item['id'] == args.item_id:
            item['status']  = 'done'
            item['done_at'] = now
    save_sprint(sprint, wk)
    print(f'Done: {args.item_id}')


def cmd_sprint(args):
    """Show this week's sprint."""
    wk     = args.week or week_key()
    sprint = load_sprint(wk)
    if not sprint:
        print(f'Sprint {wk}: empty.')
        return
    done    = [i for i in sprint if i['status'] == 'done']
    active  = [i for i in sprint if i['status'] == 'accepted']
    print(f'Sprint {wk}: {len(active)} active, {len(done)} done')
    for item in active:
        print(f'  {item["id"]}  [{item["priority"]}]  {item["title"]}')
    if done:
        print(f'Done:')
        for item in done:
            print(f'  ✅ {item["id"]}  {item["title"]}')


# ── Entry point ────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description='Agent-to-Alice scrum action queue')
    sub = p.add_subparsers(dest='cmd')

    fl = sub.add_parser('flag', help='Flag an action item')
    fl.add_argument('--agent',    required=True)
    fl.add_argument('--domain',   default='SU')
    fl.add_argument('--title',    required=True)
    fl.add_argument('--why',      default='')
    fl.add_argument('--priority', choices=PRIORITIES, default='medium')
    fl.add_argument('--os-ref',   dest='os_ref', default='', help='Related OS decision ID')

    sub.add_parser('queue', help='Show pending queue')

    ac = sub.add_parser('accept', help='Alice accepts item into sprint')
    ac.add_argument('item_id')

    df = sub.add_parser('defer', help='Defer item to next week')
    df.add_argument('item_id')
    df.add_argument('--note', default='')

    dn = sub.add_parser('done', help='Mark item done')
    dn.add_argument('item_id')

    sp = sub.add_parser('sprint', help='Show sprint')
    sp.add_argument('--week', default=None)

    args = p.parse_args()
    if not args.cmd:
        p.print_help(); return

    {'flag': cmd_flag, 'queue': cmd_queue, 'accept': cmd_accept,
     'defer': cmd_defer, 'done': cmd_done, 'sprint': cmd_sprint}[args.cmd](args)


if __name__ == '__main__':
    main()

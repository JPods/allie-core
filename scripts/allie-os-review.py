#!/usr/bin/env python3
"""
allie-os-review.py — Daily review of agent OS List decisions and Red Flags.

The OS List is a retrospective design record — one entry per autonomous fix
built into the code. Entries are not written at runtime; they are written once
when the fix is designed and removed when the underlying judgment is made explicit.

Red Flags ARE runtime events — written by agents when they stop and refuse to proceed.

Sources:
  process/os-list/decisions.json      — static design decisions (OS entries)
  process/os-list/YYYY-MM-DD.jsonl    — runtime Red Flag events

Usage:
  python3 allie-os-review.py                     # all active decisions + recent red flags
  python3 allie-os-review.py --days 7            # red flags from last 7 days
  python3 allie-os-review.py --review OS-001     # mark a decision reviewed today
  python3 allie-os-review.py --promote OS-007    # mark decision promoted to explicit code
  python3 allie-os-review.py --resolve TS        # resolve a Red Flag by timestamp ID
  python3 allie-os-review.py --resolution TEXT   # (use with --resolve)
  python3 allie-os-review.py --summary           # counts only
"""

import argparse
import datetime
import json
import pathlib
import sys

OS_DIR       = pathlib.Path.home() / 'Allie' / 'process' / 'os-list'
DECISIONS_FILE = OS_DIR / 'decisions.json'
RISK_ORDER   = {'high': 0, 'medium': 1, 'low': 2}


# ── Decision file (static OS entries) ──────────────────────────────────────

def load_decisions():
    if not DECISIONS_FILE.exists():
        return []
    try:
        return json.loads(DECISIONS_FILE.read_text(encoding='utf-8'))
    except Exception as e:
        print(f'[warn] could not read decisions.json: {e}', file=sys.stderr)
        return []

def save_decisions(decisions):
    DECISIONS_FILE.write_text(
        json.dumps(decisions, indent=2), encoding='utf-8')


# ── Runtime Red Flag events (daily JSONL) ──────────────────────────────────

def load_red_flags(days=7):
    if not OS_DIR.exists():
        return []
    cutoff = (datetime.datetime.now(datetime.timezone.utc) -
              datetime.timedelta(days=days)).strftime('%Y-%m-%d')
    files  = sorted(OS_DIR.glob('*.jsonl'))
    files  = [f for f in files if f.stem >= cutoff]
    flags  = []
    for fp in files:
        for line in fp.read_text(encoding='utf-8').splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
                if e.get('type') == 'red_flag':
                    e['_file'] = str(fp)
                    flags.append(e)
            except Exception:
                pass
    return flags


# ── Display ────────────────────────────────────────────────────────────────

def print_decision(d):
    status = d.get('status', 'active')
    rl     = d.get('risk_level', 'low')
    icon   = {'high': '🔴', 'medium': '🟡', 'low': '🟢'}.get(rl, '⚪')
    reviewed = d.get('last_reviewed') or 'never'
    print(f'\n{icon} {d["id"]}  [{d["agent"]}/{d["domain"]}]  risk={rl}  reviewed={reviewed}  status={status}')
    print(f'   Action: {d["action"]}')
    print(f'   Risk:   {d["risk"]}')
    print(f'   Why:    {d["why"]}')
    print(f'   Code:   {d["code_location"]}')
    if d.get('promotion_path'):
        print(f'   Path:   {d["promotion_path"]}')


def print_red_flag(e):
    ts   = e.get('ts', '')[:19].replace('T', ' ')
    ts_id = e.get('ts', '').replace('-','').replace(':','').replace('T','T')[:15]
    resolved = e.get('resolved_at')
    print(f'\n🚩 RED FLAG [{e.get("agent","?")}]  {ts}  id={ts_id}')
    print(f'   Condition: {e.get("condition","")}')
    print(f'   Demand:    {e.get("demand","")}')
    print(f'   Blocked:   {e.get("blocked","")}')
    if resolved:
        print(f'   ✅ Resolved {resolved[:19]}: {e.get("resolution","")}')
    else:
        print(f'   ⏳ UNRESOLVED — run: allie-os-review.py --resolve {ts_id} --resolution "..."')
    if e.get('context'):
        print(f'   Context:   {json.dumps(e["context"])}')


# ── Commands ───────────────────────────────────────────────────────────────

def cmd_review(args):
    decisions = [d for d in load_decisions() if d.get('status') == 'active']
    red_flags = load_red_flags(days=args.days)
    open_flags = [f for f in red_flags if not f.get('resolved_at')]

    never_reviewed = [d for d in decisions if not d.get('last_reviewed')]
    stale_days     = 30
    today          = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
    stale = [d for d in decisions
             if d.get('last_reviewed') and
             (datetime.datetime.fromisoformat(d['last_reviewed']).date() <
              (datetime.datetime.now(datetime.timezone.utc) -
               datetime.timedelta(days=stale_days)).date())]

    if open_flags:
        print(f'\n{"="*60}')
        print(f'RED FLAGS — {len(open_flags)} unresolved (last {args.days} days)')
        print('='*60)
        for e in open_flags:
            print_red_flag(e)

    if never_reviewed or stale:
        print(f'\n{"="*60}')
        needs = never_reviewed + stale
        print(f'OS DECISIONS — {len(needs)} need review ({len(never_reviewed)} never, {len(stale)} stale >{stale_days}d)')
        print('='*60)
        for d in sorted(needs, key=lambda x: RISK_ORDER.get(x.get('risk_level','low'), 9)):
            print_decision(d)
    elif decisions:
        print(f'\n✅ All {len(decisions)} active OS decisions reviewed within {stale_days} days')
        most_recent = max((d.get('last_reviewed') or '') for d in decisions) if decisions else ''

    if not open_flags and not never_reviewed and not stale:
        print('\n✅ Nothing to review.')
        return

    print(f'\n{"-"*60}')
    print(f'Commands:')
    print(f'  Mark reviewed:  allie-os-review.py --review OS-NNN')
    print(f'  Promote to code: allie-os-review.py --promote OS-NNN')
    print(f'  Resolve red flag: allie-os-review.py --resolve TS --resolution "text"')


def cmd_summary(args):
    decisions = load_decisions()
    active  = [d for d in decisions if d.get('status') == 'active']
    promoted = [d for d in decisions if d.get('status') == 'promoted']
    flags   = load_red_flags(days=7)
    open_f  = [f for f in flags if not f.get('resolved_at')]
    print(f'OS List summary')
    print(f'  Active decisions:   {len(active)} ({sum(1 for d in active if d.get("risk_level")=="high")} high, {sum(1 for d in active if d.get("risk_level")=="medium")} medium)')
    print(f'  Promoted to code:   {len(promoted)}')
    print(f'  Red Flags (7 days): {len(open_f)} unresolved / {len(flags)} total')
    for d in active:
        reviewed = d.get('last_reviewed') or 'never'
        print(f'  {d["id"]} [{d["agent"]}] {d["action"][:60]}  reviewed={reviewed}')


def cmd_mark_reviewed(args):
    decisions = load_decisions()
    today = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
    updated = 0
    for d in decisions:
        if d['id'] == args.review:
            d['last_reviewed'] = today
            updated += 1
    if updated:
        save_decisions(decisions)
        print(f'Marked {args.review} reviewed on {today}')
    else:
        print(f'Decision {args.review} not found', file=sys.stderr)


def cmd_promote(args):
    decisions = load_decisions()
    today = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d')
    updated = 0
    for d in decisions:
        if d['id'] == args.promote:
            d['status']       = 'promoted'
            d['last_reviewed'] = today
            d['promotion_note'] = args.note or ''
            updated += 1
    if updated:
        save_decisions(decisions)
        print(f'Promoted {args.promote} — judgment is now explicit in code. Remove the OS entry after confirming.')
    else:
        print(f'Decision {args.promote} not found', file=sys.stderr)


def cmd_resolve_flag(args):
    now_utc = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    files   = sorted(OS_DIR.glob('*.jsonl'))
    updated = 0
    for fp in files:
        lines = fp.read_text(encoding='utf-8').splitlines()
        new_lines = []
        changed = False
        for line in lines:
            line = line.strip()
            if not line:
                new_lines.append(line)
                continue
            try:
                e = json.loads(line)
                ts_id = e.get('ts','').replace('-','').replace(':','').replace('T','T')[:15]
                if ts_id == args.resolve and e.get('type') == 'red_flag':
                    e['resolved_at'] = now_utc
                    e['resolution']  = args.resolution or ''
                    new_lines.append(json.dumps(e))
                    changed = True
                    updated += 1
                    continue
            except Exception:
                pass
            new_lines.append(line)
        if changed:
            fp.write_text('\n'.join(new_lines) + '\n', encoding='utf-8')
    print(f'Resolved {updated} Red Flag(s) — id={args.resolve}')


# ── Entry point ────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description='OS List daily review')
    p.add_argument('--days',       type=int, default=7, help='Days back for Red Flag search')
    p.add_argument('--summary',    action='store_true')
    p.add_argument('--review',     metavar='ID',   help='Mark decision reviewed (e.g. OS-001)')
    p.add_argument('--promote',    metavar='ID',   help='Mark decision promoted to explicit code')
    p.add_argument('--note',       metavar='TEXT', default='')
    p.add_argument('--resolve',    metavar='TS',   help='Resolve a Red Flag by timestamp ID')
    p.add_argument('--resolution', metavar='TEXT', default='')
    args = p.parse_args()

    if args.summary:
        cmd_summary(args); return
    if args.review:
        cmd_mark_reviewed(args); return
    if args.promote:
        cmd_promote(args); return
    if args.resolve:
        cmd_resolve_flag(args); return
    cmd_review(args)


if __name__ == '__main__':
    main()

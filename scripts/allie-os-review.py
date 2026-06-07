#!/usr/bin/env python3
"""
allie-os-review.py — Daily review of agent OS List and Red Flag entries.

Usage:
  python3 allie-os-review.py                    # today's unjustified/unresolved
  python3 allie-os-review.py --days 7           # last 7 days
  python3 allie-os-review.py --all              # all unjustified, all time
  python3 allie-os-review.py --justify TS --by bill
  python3 allie-os-review.py --code-fix TS --note "reason"
  python3 allie-os-review.py --resolve TS --resolution "what was done"
  python3 allie-os-review.py --summary           # counts only
"""

import argparse
import datetime
import json
import pathlib
import sys

OS_DIR = pathlib.Path.home() / 'Allie' / 'process' / 'os-list'
RISK_ORDER = {'high': 0, 'medium': 1, 'low': 2}


def load_entries(days=None):
    if not OS_DIR.exists():
        return []
    files = sorted(OS_DIR.glob('*.jsonl'), reverse=True)
    if days is not None:
        cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)
        cutoff_str = cutoff.strftime('%Y-%m-%d')
        files = [f for f in files if f.stem >= cutoff_str]
    entries = []
    for fp in files:
        try:
            for line in fp.read_text(encoding='utf-8').splitlines():
                line = line.strip()
                if not line:
                    continue
                entry = json.loads(line)
                entry['_file'] = str(fp)
                entries.append(entry)
        except Exception as e:
            print(f'[warn] could not read {fp}: {e}', file=sys.stderr)
    return entries


def ts_key(entry):
    return entry.get('ts', '')


def is_unresolved(entry):
    t = entry.get('type', 'os')
    if t == 'red_flag':
        return entry.get('resolved_at') is None
    return entry.get('justified_at') is None


def print_entry(entry, verbose=True):
    t    = entry.get('type', 'os')
    ts   = entry.get('ts', '')[:19].replace('T', ' ')
    agent = entry.get('agent', '?')
    domain = entry.get('domain', '?')
    model = entry.get('model', '')
    ts_id = entry.get('ts', '').replace('-', '').replace(':', '').replace('T', 'T')[:15]

    if t == 'red_flag':
        print(f'\n🚩 RED FLAG [{agent}/{domain}] {ts}  model={model}  id={ts_id}')
        print(f'   Condition: {entry.get("condition", "")}')
        print(f'   Demand:    {entry.get("demand", "")}')
        print(f'   Blocked:   {entry.get("blocked", "")}')
        if entry.get('resolved_at'):
            print(f'   ✅ Resolved {entry["resolved_at"][:19]}: {entry.get("resolution", "")}')
        else:
            print(f'   ⏳ UNRESOLVED — run: allie-os-review.py --resolve {ts_id} --resolution "..."')
        if verbose and entry.get('context'):
            print(f'   Context:   {json.dumps(entry["context"])}')
    else:
        rl = entry.get('risk_level', 'low')
        icon = {'high': '🔴', 'medium': '🟡', 'low': '🟢'}.get(rl, '⚪')
        print(f'\n{icon} OS [{agent}/{domain}] {ts}  risk={rl}  model={model}  id={ts_id}')
        print(f'   Action: {entry.get("action", "")}')
        print(f'   Risk:   {entry.get("risk", "")}')
        print(f'   Why:    {entry.get("why", "")}')
        if entry.get('justified_at'):
            print(f'   ✅ Justified {entry["justified_at"][:19]} by {entry.get("justified_by", "?")}')
        else:
            print(f'   ⏳ UNJUSTIFIED — run: allie-os-review.py --justify {ts_id} --by bill')
        if verbose and entry.get('context'):
            print(f'   Context: {json.dumps(entry["context"])}')


def update_entry(ts_prefix, update_fn):
    """Find all entries matching ts_prefix across all files and update them."""
    files = sorted(OS_DIR.glob('*.jsonl'))
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
                entry = json.loads(line)
                ts_id = entry.get('ts', '').replace('-', '').replace(':', '').replace('T', 'T')[:15]
                if ts_id == ts_prefix or entry.get('ts', '').startswith(ts_prefix[:8]):
                    if ts_id == ts_prefix:
                        update_fn(entry)
                        new_lines.append(json.dumps(entry))
                        changed = True
                        updated += 1
                        continue
            except Exception:
                pass
            new_lines.append(line)
        if changed:
            fp.write_text('\n'.join(new_lines) + '\n', encoding='utf-8')
    return updated


def cmd_review(args):
    days = args.days if not args.all else None
    entries = load_entries(days=days)
    if args.all:
        entries = load_entries()

    red_flags = [e for e in entries if e.get('type') == 'red_flag' and is_unresolved(e)]
    os_pending = [e for e in entries if e.get('type', 'os') == 'os' and is_unresolved(e)]
    os_pending.sort(key=lambda e: (RISK_ORDER.get(e.get('risk_level', 'low'), 9), e.get('ts', '')))

    if not red_flags and not os_pending:
        scope = f'last {days} day(s)' if days else 'all time'
        print(f'✅ No unjustified OS entries or unresolved Red Flags ({scope})')
        return

    if red_flags:
        print(f'\n{"="*60}')
        print(f'RED FLAGS — {len(red_flags)} unresolved')
        print('="*60')
        for e in red_flags:
            print_entry(e)

    if os_pending:
        print(f'\n{"="*60}')
        print(f'OS LIST — {len(os_pending)} unjustified')
        print('="*60')
        for e in os_pending:
            print_entry(e)

    print(f'\n{"-"*60}')
    print(f'Total: {len(red_flags)} red flag(s), {len(os_pending)} OS entr(ies) pending review')


def cmd_summary(args):
    entries = load_entries(days=7)
    rf_open = sum(1 for e in entries if e.get('type') == 'red_flag' and not e.get('resolved_at'))
    rf_total = sum(1 for e in entries if e.get('type') == 'red_flag')
    os_open = sum(1 for e in entries if e.get('type', 'os') == 'os' and not e.get('justified_at'))
    os_total = sum(1 for e in entries if e.get('type', 'os') == 'os')
    by_agent = {}
    for e in entries:
        a = e.get('agent', '?')
        by_agent.setdefault(a, {'os': 0, 'rf': 0})
        if e.get('type') == 'red_flag':
            by_agent[a]['rf'] += 1
        else:
            by_agent[a]['os'] += 1
    print(f'OS List summary — last 7 days')
    print(f'  Red Flags:  {rf_open} unresolved / {rf_total} total')
    print(f'  OS entries: {os_open} unjustified / {os_total} total')
    for agent, counts in sorted(by_agent.items()):
        print(f'  {agent}: {counts["os"]} OS, {counts["rf"]} red flags')


def main():
    parser = argparse.ArgumentParser(description='OS List daily review')
    parser.add_argument('--days', type=int, default=1, help='Days to look back (default 1)')
    parser.add_argument('--all', action='store_true', help='All time')
    parser.add_argument('--summary', action='store_true')
    parser.add_argument('--justify', metavar='TS', help='Justify OS entry by timestamp ID')
    parser.add_argument('--by', metavar='WHO', default='bill')
    parser.add_argument('--code-fix', metavar='TS', dest='code_fix')
    parser.add_argument('--note', metavar='NOTE', default='')
    parser.add_argument('--resolve', metavar='TS')
    parser.add_argument('--resolution', metavar='TEXT', default='')
    args = parser.parse_args()

    now_utc = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    if args.justify:
        def do_justify(e):
            e['justified_at'] = now_utc
            e['justified_by'] = args.by
        n = update_entry(args.justify, do_justify)
        print(f'Justified {n} entry(s) — id={args.justify}, by={args.by}')
        return

    if args.code_fix:
        def do_code_fix(e):
            e['justified_at'] = now_utc
            e['justified_by'] = 'code_fix'
            e['code_fix_note'] = args.note
        n = update_entry(args.code_fix, do_code_fix)
        print(f'Marked {n} entry(s) for code fix — id={args.code_fix}, note={args.note!r}')
        return

    if args.resolve:
        def do_resolve(e):
            e['resolved_at'] = now_utc
            e['resolution'] = args.resolution
        n = update_entry(args.resolve, do_resolve)
        print(f'Resolved {n} Red Flag entry(s) — id={args.resolve}')
        return

    if args.summary:
        cmd_summary(args)
        return

    cmd_review(args)


if __name__ == '__main__':
    main()

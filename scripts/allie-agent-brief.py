#!/usr/bin/env python3
"""
allie-agent-brief.py — Synthesize agent observation JSONL files into teaching briefs.

Reads:  ~/Allie/process/agent-observations/{agent}/{formation}.jsonl
Writes: ~/Allie/process/teaching/{formation}_brief.json

Each brief captures what the three agents (Noelle, Natalie, Sally) have
collectively learned about a formation — flag frequencies, recurring demands,
threshold statistics, and design notes distilled from validation history.
Physical processors load these briefs at startup to know what each station
formation requires of them.

Usage:
    python3 allie-agent-brief.py                  # synthesize all formations
    python3 allie-agent-brief.py --formation JPods_station_thru_dip
    python3 allie-agent-brief.py --list           # list formations with observations
"""

import argparse
import json
import pathlib
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone


OBS_ROOT    = pathlib.Path.home() / 'Allie' / 'process' / 'agent-observations'
TEACH_ROOT  = pathlib.Path.home() / 'Allie' / 'process' / 'teaching'
AGENTS      = ['noelle', 'natalie', 'sally']


# ── Helpers ────────────────────────────────────────────────────────────────────

def read_jsonl(path: pathlib.Path) -> list[dict]:
    records = []
    try:
        for line in path.read_text(encoding='utf-8').splitlines():
            line = line.strip()
            if line:
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    except FileNotFoundError:
        pass
    return records


def all_formations() -> set[str]:
    """Return every formation_id that has at least one observation file."""
    formations = set()
    if not OBS_ROOT.exists():
        return formations
    for agent_dir in OBS_ROOT.iterdir():
        if agent_dir.is_dir():
            for f in agent_dir.glob('*.jsonl'):
                formations.add(f.stem)
    return formations


def formation_observations(formation: str) -> dict[str, list[dict]]:
    """Return {agent_name: [records]} for a given formation."""
    result = {}
    for agent in AGENTS:
        path = OBS_ROOT / agent / f'{formation}.jsonl'
        records = read_jsonl(path)
        if records:
            result[agent] = records
    return result


# ── Brief synthesis ────────────────────────────────────────────────────────────

def synthesize(formation: str, obs_by_agent: dict[str, list[dict]]) -> dict:
    """Build the teaching brief for one formation from all agent observations."""

    agents_out = {}

    for agent, records in obs_by_agent.items():
        total       = len(records)
        approved    = sum(1 for r in records if r.get('verdict') == 'approved')
        disapproved = total - approved

        # Count flag frequencies
        flag_counter  = Counter()
        demand_counter = Counter()
        passed_counter = Counter()

        for r in records:
            for f in r.get('flags', []):
                # Strip dynamic parts (numbers) to normalize the flag text
                key = _normalize_text(f)
                flag_counter[key] += 1
            for d in r.get('demands', []):
                demand_counter[_normalize_text(d)] += 1
            for p in r.get('passed', []):
                passed_counter[_normalize_text(p)] += 1

        # Most recent record timestamp
        timestamps = [r['ts'] for r in records if r.get('ts')]
        last_seen  = max(timestamps) if timestamps else None

        # Extract numeric thresholds from context fields
        thresholds = _extract_thresholds(records)

        # Build recurring flags list (seen in ≥ 2 validations or > 50% of all runs)
        recurring_flags = [
            {'flag': flag, 'count': cnt, 'pct': round(cnt / total * 100)}
            for flag, cnt in flag_counter.most_common(20)
            if cnt >= 2 or (total > 1 and cnt / total > 0.5)
        ]

        # Build demands ranked by frequency (always demand, even if only once)
        top_demands = [
            {'demand': dem, 'count': cnt}
            for dem, cnt in demand_counter.most_common(10)
        ]

        # Build reliable passed checks (seen in ≥ 2 runs)
        reliable_passed = [
            {'check': chk, 'count': cnt}
            for chk, cnt in passed_counter.most_common(10)
            if cnt >= 2
        ]

        agents_out[agent] = {
            'total_validations': total,
            'approved':          approved,
            'disapproved':       disapproved,
            'approval_rate_pct': round(approved / total * 100) if total else 0,
            'last_seen':         last_seen,
            'recurring_flags':   recurring_flags,
            'top_demands':       top_demands,
            'reliable_passed':   reliable_passed,
            'thresholds':        thresholds,
        }

    # Combined design notes — distilled from all agents' demands
    all_demands = []
    for agent, data in agents_out.items():
        for d in data.get('top_demands', []):
            all_demands.append(d['demand'])
    unique_demands = list(dict.fromkeys(all_demands))  # preserve order, deduplicate

    # Health summary across agents
    total_runs = sum(d['total_validations'] for d in agents_out.values())
    total_flags = sum(
        sum(f['count'] for f in d['recurring_flags'])
        for d in agents_out.values()
    )
    all_approved = all(
        d['approval_rate_pct'] == 100
        for d in agents_out.values()
        if d['total_validations'] > 0
    )

    return {
        'schema':       'jpods-agent-brief-v1',
        'formation':    formation,
        'generated_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'health': {
            'all_agents_approved': all_approved,
            'total_validations':   total_runs,
            'total_flags_seen':    total_flags,
        },
        'agents': agents_out,
        'design_notes': unique_demands,
    }


def _normalize_text(text: str) -> str:
    """Strip leading track tag (before ':') and trim whitespace."""
    if ':' in text:
        # Remove the specific track tag (varies per run) — keep the message
        parts = text.split(':', 1)
        if parts[0].startswith('gw_') or parts[0].startswith('CP'):
            text = parts[1].strip()
    return text.strip()


def _extract_thresholds(records: list[dict]) -> dict:
    """Pull numeric threshold values from context dicts."""
    thresholds = {}
    for r in records:
        ctx = r.get('context') or {}
        if isinstance(ctx, dict):
            for k, v in ctx.items():
                if isinstance(v, (int, float)):
                    if k not in thresholds:
                        thresholds[k] = v
    return thresholds


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Synthesize agent observations into teaching briefs')
    parser.add_argument('--formation', help='Formation ID to process (default: all)')
    parser.add_argument('--list',      action='store_true', help='List formations with observations')
    args = parser.parse_args()

    if not OBS_ROOT.exists():
        print(f'[allie-agent-brief] No observations directory at {OBS_ROOT}')
        print('  Observations are written when Extract Template runs in SketchUp.')
        sys.exit(0)

    formations = all_formations()

    if args.list:
        if not formations:
            print('[allie-agent-brief] No observations found.')
        else:
            print(f'[allie-agent-brief] {len(formations)} formation(s) with observations:')
            for f in sorted(formations):
                obs = formation_observations(f)
                total = sum(len(v) for v in obs.values())
                agents_present = ', '.join(obs.keys())
                print(f'  {f}  ({total} records, agents: {agents_present})')
        return

    if args.formation:
        targets = [args.formation]
        if args.formation not in formations:
            print(f'[allie-agent-brief] No observations for formation: {args.formation}')
            sys.exit(1)
    else:
        targets = sorted(formations)

    if not targets:
        print('[allie-agent-brief] No formations to process.')
        return

    TEACH_ROOT.mkdir(parents=True, exist_ok=True)

    for formation in targets:
        obs = formation_observations(formation)
        if not obs:
            continue

        brief = synthesize(formation, obs)

        out_path = TEACH_ROOT / f'{formation}_brief.json'
        out_path.write_text(json.dumps(brief, indent=2), encoding='utf-8')

        total_val = brief['health']['total_validations']
        total_flags = brief['health']['total_flags_seen']
        approved = '✅' if brief['health']['all_agents_approved'] else '⚠️'
        print(f'{approved} {formation}: {total_val} validation(s), {total_flags} flag(s) — {out_path.name}')

    print(f'[allie-agent-brief] Teaching briefs written to {TEACH_ROOT}')


if __name__ == '__main__':
    main()

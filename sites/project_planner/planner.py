#!/usr/bin/env python3
"""
Project Planner — Drop a CSV/XLS project plan, get a bundle.json + SVG.

Zero dependencies beyond openpyxl (for xlsx). One file. Python 3.10+.

Usage:
    python3 planner.py ~/project-plan.csv
    python3 planner.py ~/project-plan.xlsx
    python3 planner.py ~/folder-of-csvs/
    python3 planner.py ~/project-plan.csv --port 8878

Opens a browser. Map columns, review actions, edit, export.
Output: project folder with bundle.json, plan.svg, and original file.

Supports: MS Project CSV export, Smartsheet, Asana, Trello, generic CSV/XLSX.
"""
from __future__ import annotations

import argparse
import csv
import html as html_mod
import io
import json
import os
import re
import sys
import uuid
import webbrowser
from datetime import datetime, date, timezone
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, urlparse

# ─── Global state ────────────────────────────────────────────────────

ACTIONS: list[dict] = []
PROJECT: dict = {}
COLUMNS: list[str] = []
RAW_ROWS: list[list[str]] = []
COLUMN_MAP: dict[str, str] = {}
DATA_FILE: Path = Path()
SOURCE_FILE: str = ''
OUTPUT_DIR: Path = Path()

# ─── Column detection ────────────────────────────────────────────────

# Map common column names to our fields
FIELD_HINTS = {
    'action': ['task name', 'task', 'name', 'title', 'action', 'activity',
               'work item', 'item', 'summary', 'subject', 'description',
               'card name', 'issue'],
    'card_number': ['id', 'task id', 'wbs', '#', 'number', 'card number',
                    'card #', 'card no', 'issue id', 'key', 'ref'],
    'description': ['description', 'details', 'notes', 'body', 'acceptance criteria',
                    'definition of done', 'comment', 'remarks'],
    'section': ['section', 'category', 'group', 'phase', 'stream', 'workstream',
                'work stream', 'project', 'sub-project', 'subproject', 'epic',
                'parent', 'folder', 'list', 'board'],
    'priority': ['priority', 'importance', 'urgency', 'p', 'pri'],
    'status': ['status', 'state', 'kanban', 'column', 'stage'],
    'assigned_to': ['assigned to', 'assignee', 'owner', 'responsible',
                    'resource', 'who', 'person'],
    'depends_on': ['depends on', 'predecessors', 'predecessor', 'dependencies',
                   'blocked by', 'after', 'depends'],
    'difficulty': ['difficulty', 'effort', 'points', 'story points',
                   'estimate', 'size', 'weight', 'complexity'],
    'dt_start': ['start', 'start date', 'begin', 'begin date', 'planned start'],
    'dt_deadline': ['end', 'end date', 'due', 'due date', 'deadline',
                    'finish', 'finish date', 'planned finish'],
    'duration': ['duration', 'days', 'hours', 'work', 'effort hours'],
    'percent_complete': ['% complete', 'percent complete', 'progress',
                        'completion', '% done', 'complete'],
    'sequence': ['sequence', 'order', 'sort', 'rank', 'position', 'row'],
}


def auto_map_columns(headers: list[str]) -> dict[str, str]:
    """Auto-detect which CSV columns map to which action fields."""
    mapping = {}
    h_lower = [h.strip().lower() for h in headers]
    for field, hints in FIELD_HINTS.items():
        for hint in hints:
            for i, col in enumerate(h_lower):
                if col == hint and field not in mapping:
                    mapping[field] = headers[i]
                    break
            if field in mapping:
                break
    return mapping


# ─── File parsing ────────────────────────────────────────────────────

def _parse_date(s: str) -> str | None:
    """Try to parse a date string, return ISO format or None."""
    s = s.strip().strip('"')
    if not s:
        return None
    for fmt in ('%m/%d/%Y', '%Y-%m-%d', '%m/%d/%y', '%d/%m/%Y',
                '%Y/%m/%d', '%b %d, %Y', '%d-%b-%Y', '%d %b %Y'):
        try:
            d = datetime.strptime(s, fmt)
            if d.year < 100:
                d = d.replace(year=d.year + 2000)
            return d.strftime('%Y-%m-%d')
        except ValueError:
            pass
    return None


def _parse_number(s: str) -> int | None:
    """Try to parse a number from a string."""
    s = s.strip().strip('"').replace(',', '').replace('%', '')
    try:
        return int(float(s))
    except (ValueError, TypeError):
        return None


def load_csv(filepath: Path) -> tuple[list[str], list[list[str]]]:
    """Load CSV, return headers and rows."""
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        headers = next(reader, [])
        rows = [r for r in reader if any(cell.strip() for cell in r)]
    return headers, rows


def load_xlsx(filepath: Path) -> tuple[list[str], list[list[str]]]:
    """Load XLSX, return headers and rows."""
    try:
        import openpyxl
    except ImportError:
        print("openpyxl required for XLSX. Install: pip install openpyxl")
        sys.exit(1)
    wb = openpyxl.load_workbook(filepath, read_only=True, data_only=True)
    ws = wb.active
    rows_iter = ws.iter_rows(values_only=True)
    headers = [str(c) if c else '' for c in next(rows_iter, [])]
    rows = []
    for row in rows_iter:
        cells = [str(c) if c is not None else '' for c in row]
        if any(cell.strip() for cell in cells):
            rows.append(cells)
    wb.close()
    return headers, rows


def load_file(filepath: Path) -> tuple[list[str], list[list[str]]]:
    """Load CSV or XLSX."""
    ext = filepath.suffix.lower()
    if ext in ('.xlsx', '.xls'):
        return load_xlsx(filepath)
    return load_csv(filepath)


# ─── Row → Action conversion ────────────────────────────────────────

def _get_mapped(row: list[str], headers: list[str], field: str) -> str:
    """Get value from row using column mapping."""
    col_name = COLUMN_MAP.get(field)
    if not col_name:
        return ''
    try:
        idx = headers.index(col_name)
        return row[idx].strip() if idx < len(row) else ''
    except (ValueError, IndexError):
        return ''


def _map_priority(val: str) -> int:
    """Map priority string to 1-4 integer."""
    v = val.lower().strip()
    if v in ('1', 'critical', 'highest', 'urgent', 'p1'):
        return 1
    if v in ('2', 'high', 'p2'):
        return 2
    if v in ('3', 'medium', 'normal', 'p3', 'med'):
        return 3
    if v in ('4', 'low', 'p4', '5', 'lowest', 'p5'):
        return 4
    n = _parse_number(val)
    if n is not None:
        return max(1, min(4, n))
    return 2  # default


def _map_difficulty(val: str) -> int:
    """Map difficulty/points to Fibonacci scale."""
    n = _parse_number(val)
    if n is None:
        return 4
    # Map to closest Fibonacci: 1, 4, 8, 13, 21
    fibs = [1, 4, 8, 13, 21]
    return min(fibs, key=lambda f: abs(f - n))


def _map_status(val: str) -> str:
    """Map status string to kanban column."""
    v = val.lower().strip()
    if v in ('done', 'complete', 'completed', 'closed', 'resolved'):
        return 'Complete'
    if v in ('in progress', 'active', 'doing', 'working', 'started', 'wip'):
        return 'InProcess'
    if v in ('review', 'in review', 'testing', 'qa'):
        return 'Review'
    if v in ('planned', 'planning', 'ready', 'to do', 'todo', 'next'):
        return 'Planning'
    return 'Backlog'


def rows_to_actions(headers: list[str], rows: list[list[str]]) -> list[dict]:
    """Convert mapped rows to action records."""
    actions = []
    for i, row in enumerate(rows):
        name = _get_mapped(row, headers, 'action')
        if not name:
            continue  # skip empty rows

        action = {
            'sequence': i + 1,
            'card_number': _get_mapped(row, headers, 'card_number') or str(i + 1),
            'action': {'en': name},
            'description': {'en': _get_mapped(row, headers, 'description') or ''},
            'metadata': {},
            'kanban_column': 'Backlog',
            'priority': 2,
            'difficulty': 4,
            'status': 'not_started',
            'percent_complete': 0,
            'document': {
                'name': name,
                'status': 'draft',
                'confidential': 'internal',
                'description': ''
            }
        }

        # Section
        section = _get_mapped(row, headers, 'section')
        if section:
            action['metadata']['section'] = section
            action['metadata']['section_label'] = section

        # Priority
        pri = _get_mapped(row, headers, 'priority')
        if pri:
            action['priority'] = _map_priority(pri)

        # Difficulty
        diff = _get_mapped(row, headers, 'difficulty')
        if diff:
            action['difficulty'] = _map_difficulty(diff)

        # Status
        status = _get_mapped(row, headers, 'status')
        if status:
            action['kanban_column'] = _map_status(status)

        # Assigned to
        assigned = _get_mapped(row, headers, 'assigned_to')
        if assigned:
            action['assigned_to'] = [{'name': assigned}]

        # Dependencies
        deps = _get_mapped(row, headers, 'depends_on')
        if deps:
            action['depends_on'] = [d.strip() for d in deps.split(',') if d.strip()]

        # Dates
        start = _get_mapped(row, headers, 'dt_start')
        if start:
            parsed = _parse_date(start)
            if parsed:
                action['dt_start'] = parsed

        deadline = _get_mapped(row, headers, 'dt_deadline')
        if deadline:
            parsed = _parse_date(deadline)
            if parsed:
                action['dt_deadline'] = parsed

        # Duration
        dur = _get_mapped(row, headers, 'duration')
        if dur:
            n = _parse_number(dur)
            if n:
                action['duration'] = n

        # Percent complete
        pct = _get_mapped(row, headers, 'percent_complete')
        if pct:
            n = _parse_number(pct)
            if n is not None:
                action['percent_complete'] = max(0, min(100, n))

        # Sequence override
        seq = _get_mapped(row, headers, 'sequence')
        if seq:
            n = _parse_number(seq)
            if n:
                action['sequence'] = n

        actions.append(action)

    return actions


# ─── Bundle generation ───────────────────────────────────────────────

def generate_bundle(project_name: str, actions: list[dict]) -> dict:
    """Generate a WC3-compatible bundle.json."""
    # Group by section
    sections = {}
    for a in actions:
        sec = a.get('metadata', {}).get('section', 'General')
        if sec not in sections:
            sections[sec] = []
        sections[sec].append(a)

    bundle = {
        'bundle': {
            'name': project_name,
            'version': '1.0',
            'description': f'Project plan: {project_name}. {len(actions)} actions across {len(sections)} section(s). Generated by Project Planner.',
            'created': datetime.now(timezone.utc).strftime('%Y-%m-%d'),
            'source': SOURCE_FILE
        },
        'project': {
            'name': project_name,
            'status': 'active',
            'attention': 'normal',
            'priority': 1,
            'category': 'project',
            'intent': f'{project_name} — {len(actions)} actions',
            'tasks': {
                'items': [],
                'completed': sum(1 for a in actions if a.get('kanban_column') == 'Complete'),
                'total': len(actions),
                'weight_total': 0,
                'weight_completed': 0
            }
        },
        'actions': actions,
        'import_instructions': {
            'step_1': "Create the Project record from the 'project' object",
            'step_2': "For each entry in 'actions', create an Action record linked to the Project",
            'step_3': "For each action, create the Document record from the embedded 'document' object",
            'step_4': "Link each Document to its Action via refs or LinkageEntry",
            'notes': [
                'Actions are ordered by sequence number',
                f'{len(sections)} section(s) detected: {", ".join(sections.keys())}',
                'depends_on references use card_number or sequence values',
                'Edit bundle.json to refine before importing into WC3'
            ]
        }
    }

    # If multiple sections, create sub-projects
    if len(sections) > 1:
        sub_projects = []
        for sec_name, sec_actions in sections.items():
            sub_projects.append({
                'name': sec_name,
                'status': 'active',
                'priority': 1,
                'category': sec_name.lower().replace(' ', '_'),
                'intent': f'{sec_name} — {len(sec_actions)} actions',
                'actions': sec_actions
            })
        bundle['sub_projects'] = sub_projects
        # Keep flat actions list too for simple import
        bundle['import_instructions']['notes'].append(
            'sub_projects array available for hierarchical import (id_parent)'
        )

    return bundle


# ─── SVG generation ──────────────────────────────────────────────────

def _svg_escape(s: str) -> str:
    return html_mod.escape(s, quote=True)


def generate_svg(project_name: str, actions: list[dict]) -> str:
    """Generate an SVG visualization of the project plan."""
    card_w, card_h = 175, 58
    gap_x, gap_y = 20, 18
    cols_per_row = 5
    margin = 25
    header_h = 60

    # Group by section
    sections = {}
    for a in actions:
        sec = a.get('metadata', {}).get('section', 'General')
        if sec not in sections:
            sections[sec] = []
        sections[sec].append(a)

    # Calculate total height
    total_rows = 0
    section_info = []
    for sec_name, sec_actions in sections.items():
        rows_needed = (len(sec_actions) + cols_per_row - 1) // cols_per_row
        sec_h = 30 + rows_needed * (card_h + gap_y) + 15
        section_info.append((sec_name, sec_actions, rows_needed, sec_h))
        total_rows += rows_needed

    width = margin * 2 + cols_per_row * (card_w + gap_x) - gap_x
    height = header_h + sum(s[3] for s in section_info) + margin * 2 + 10

    lines = []
    lines.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
                 f'font-family="Arial, Helvetica, sans-serif">')
    lines.append('<defs>')
    lines.append('  <marker id="arr" viewBox="0 0 10 10" refX="10" refY="5" '
                 'markerWidth="5" markerHeight="5" orient="auto-start-reverse">')
    lines.append('    <path d="M 0 0 L 10 5 L 0 10 z" fill="#666"/>')
    lines.append('  </marker>')
    lines.append('</defs>')

    # Background
    lines.append(f'<rect width="{width}" height="{height}" fill="#ECEFF1"/>')

    # Title
    lines.append(f'<text x="{width // 2}" y="22" text-anchor="middle" '
                 f'font-size="15" font-weight="bold" fill="#333">'
                 f'{_svg_escape(project_name)}</text>')
    lines.append(f'<text x="{width // 2}" y="38" text-anchor="middle" '
                 f'font-size="10" fill="#666">'
                 f'{len(actions)} actions \u2022 {len(sections)} section(s)</text>')

    y_offset = header_h

    for sec_name, sec_actions, rows_needed, sec_h in section_info:
        # Section background
        lines.append(f'<rect x="{margin - 5}" y="{y_offset}" '
                     f'width="{width - margin * 2 + 10}" height="{sec_h}" '
                     f'fill="#f5f5f5" stroke="#ddd" rx="6" ry="6"/>')
        lines.append(f'<text x="{margin + 5}" y="{y_offset + 18}" '
                     f'font-size="11" font-weight="bold" fill="#333">'
                     f'{_svg_escape(sec_name)} ({len(sec_actions)})</text>')

        for idx, action in enumerate(sec_actions):
            col = idx % cols_per_row
            row = idx // cols_per_row
            x = margin + col * (card_w + gap_x)
            y = y_offset + 28 + row * (card_h + gap_y)

            # Card color
            is_critical = action.get('metadata', {}).get('critical_path', False)
            needs_review = action.get('metadata', {}).get('needs_review', False)
            if is_critical:
                fill = '#FFCDD2'
            elif needs_review:
                fill = '#FFE0B2'
            elif action.get('kanban_column') == 'Complete':
                fill = '#C8E6C9'
            else:
                fill = '#FFF9C4'

            lines.append(f'<rect x="{x}" y="{y}" width="{card_w}" height="{card_h}" '
                         f'fill="{fill}" stroke="#999" rx="4" ry="4"/>')

            # Card number (top-right)
            card_num = action.get('card_number', '')
            lines.append(f'<text x="{x + card_w - 5}" y="{y + 12}" '
                         f'text-anchor="end" font-size="7" fill="#888">'
                         f'{_svg_escape(card_num)}</text>')

            # Title (truncate if too long)
            title = action.get('action', {}).get('en', '')
            if len(title) > 24:
                title = title[:22] + '...'
            lines.append(f'<text x="{x + 6}" y="{y + 25}" '
                         f'font-size="9" font-weight="bold" fill="#333">'
                         f'{_svg_escape(title)}</text>')

            # Priority + kanban
            pri = action.get('priority', '')
            kanban = action.get('kanban_column', '')
            sub_text = f'P{pri}' if pri else ''
            if kanban:
                sub_text += f' \u2022 {kanban}' if sub_text else kanban
            lines.append(f'<text x="{x + 6}" y="{y + 38}" '
                         f'font-size="7" fill="#666">'
                         f'{_svg_escape(sub_text)}</text>')

            # Section label if assigned_to
            assigned = action.get('assigned_to', [])
            if assigned:
                owner = assigned[0].get('name', '')
                if owner:
                    lines.append(f'<text x="{x + 6}" y="{y + 50}" '
                                 f'font-size="7" fill="#1565C0">'
                                 f'\u2192 {_svg_escape(owner)}</text>')

            # Dependency arrow (simple: within same section, previous card)
            deps = action.get('depends_on', [])
            if deps and idx > 0:
                # Draw arrow from left neighbor
                prev_col = (idx - 1) % cols_per_row
                prev_row = (idx - 1) // cols_per_row
                if prev_row == row:
                    # Same row: horizontal arrow
                    x1 = margin + prev_col * (card_w + gap_x) + card_w
                    y1 = y_offset + 28 + prev_row * (card_h + gap_y) + card_h // 2
                    x2 = x
                    y2 = y + card_h // 2
                    lines.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
                                 f'stroke="#999" stroke-width="1" marker-end="url(#arr)"/>')

        y_offset += sec_h

    # Legend
    leg_y = height - 25
    lines.append(f'<rect x="{margin}" y="{leg_y}" width="18" height="12" fill="#FFF9C4" stroke="#999" rx="2"/>')
    lines.append(f'<text x="{margin + 22}" y="{leg_y + 10}" font-size="8" fill="#333">Normal</text>')
    lines.append(f'<rect x="{margin + 80}" y="{leg_y}" width="18" height="12" fill="#FFCDD2" stroke="#999" rx="2"/>')
    lines.append(f'<text x="{margin + 102}" y="{leg_y + 10}" font-size="8" fill="#333">Critical</text>')
    lines.append(f'<rect x="{margin + 165}" y="{leg_y}" width="18" height="12" fill="#FFE0B2" stroke="#999" rx="2"/>')
    lines.append(f'<text x="{margin + 187}" y="{leg_y + 10}" font-size="8" fill="#333">Needs Review</text>')
    lines.append(f'<rect x="{margin + 280}" y="{leg_y}" width="18" height="12" fill="#C8E6C9" stroke="#999" rx="2"/>')
    lines.append(f'<text x="{margin + 302}" y="{leg_y + 10}" font-size="8" fill="#333">Complete</text>')
    lines.append(f'<text x="{width - margin}" y="{leg_y + 10}" text-anchor="end" '
                 f'font-size="8" fill="#999">Generated by Project Planner</text>')

    lines.append('</svg>')
    return '\n'.join(lines)


# ─── Output ──────────────────────────────────────────────────────────

def save_outputs(project_name: str, actions: list[dict], output_dir: Path):
    """Save bundle.json and plan.svg to output directory."""
    output_dir.mkdir(parents=True, exist_ok=True)

    bundle = generate_bundle(project_name, actions)
    bundle_path = output_dir / 'bundle.json'
    with open(bundle_path, 'w') as f:
        json.dump(bundle, f, indent=2, default=str)
    print(f"  \u2713 {bundle_path}")

    svg = generate_svg(project_name, actions)
    svg_path = output_dir / 'plan.svg'
    with open(svg_path, 'w') as f:
        f.write(svg)
    print(f"  \u2713 {svg_path}")

    return bundle_path, svg_path


# ─── Web UI ──────────────────────────────────────────────────────────

def _html_page() -> str:
    """Generate the web UI HTML."""
    return '''<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<title>Project Planner</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, sans-serif;
       background: #1a1a2e; color: #e0e0e0; }
header { background: #16213e; padding: 16px 24px; border-bottom: 1px solid #333; }
header h1 { font-size: 20px; color: #fff; }
header p { font-size: 12px; color: #888; margin-top: 4px; }
.container { max-width: 1400px; margin: 0 auto; padding: 20px; }
.section { background: #16213e; border-radius: 8px; padding: 16px; margin-bottom: 16px; }
.section h2 { font-size: 14px; color: #8ab4f8; margin-bottom: 12px; }
label { font-size: 12px; color: #aaa; display: block; margin-bottom: 4px; }
select, input[type=text] {
    background: #0f3460; border: 1px solid #444; color: #e0e0e0;
    padding: 6px 10px; border-radius: 4px; font-size: 13px; width: 100%;
}
.map-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 10px; }
.btn { background: #1a73e8; color: white; border: none; padding: 8px 18px;
       border-radius: 4px; cursor: pointer; font-size: 13px; font-weight: 600; }
.btn:hover { background: #1557b0; }
.btn-green { background: #1e8e3e; }
.btn-green:hover { background: #137333; }
.btn-outline { background: transparent; border: 1px solid #555; color: #aaa; }
.btn-outline:hover { border-color: #888; color: #fff; }
.toolbar { display: flex; gap: 10px; align-items: center; margin-bottom: 16px; flex-wrap: wrap; }
table { width: 100%; border-collapse: collapse; font-size: 12px; }
th { background: #0f3460; padding: 8px 10px; text-align: left; position: sticky; top: 0; }
td { padding: 6px 10px; border-bottom: 1px solid #2a2a4a; }
tr:hover { background: #1a2744; }
.card-num { color: #888; font-size: 11px; }
.pri-1 { color: #ff6b6b; font-weight: bold; }
.pri-2 { color: #ffa94d; }
.pri-3 { color: #69db7c; }
.pri-4 { color: #888; }
.status-tag { padding: 2px 8px; border-radius: 10px; font-size: 10px; font-weight: 600; }
.status-Backlog { background: #333; color: #aaa; }
.status-Planning { background: #1a3a5c; color: #8ab4f8; }
.status-InProcess { background: #1a4a2e; color: #69db7c; }
.status-Review { background: #4a3a1a; color: #ffa94d; }
.status-Complete { background: #1e3a1e; color: #69db7c; }
.stats { display: flex; gap: 24px; margin-bottom: 16px; }
.stat { text-align: center; }
.stat-num { font-size: 28px; font-weight: bold; color: #8ab4f8; }
.stat-label { font-size: 11px; color: #888; }
.upload-zone { border: 2px dashed #444; border-radius: 8px; padding: 40px;
               text-align: center; cursor: pointer; transition: border-color 0.2s; }
.upload-zone:hover { border-color: #8ab4f8; }
.upload-zone.dragover { border-color: #1a73e8; background: #1a2744; }
.hidden { display: none; }
#project-name { max-width: 400px; }
.edit-cell { cursor: pointer; }
.edit-cell:hover { background: #2a3a5a; }
</style>
</head><body>

<header>
  <h1>Project Planner</h1>
  <p>Drop a CSV/XLSX project plan &rarr; map columns &rarr; review &rarr; export bundle.json + SVG</p>
</header>

<div class="container">

  <!-- UPLOAD -->
  <div id="upload-section" class="section">
    <h2>1. Load Project Plan</h2>
    <div id="upload-zone" class="upload-zone">
      <p style="font-size: 16px; margin-bottom: 8px;">Drop CSV or XLSX here</p>
      <p style="font-size: 12px; color: #888;">or click to browse</p>
      <input type="file" id="file-input" accept=".csv,.xlsx,.xls" class="hidden">
    </div>
    <div id="server-file" style="margin-top: 12px;"></div>
  </div>

  <!-- COLUMN MAPPING -->
  <div id="mapping-section" class="section hidden">
    <h2>2. Map Columns</h2>
    <p style="font-size: 12px; color: #888; margin-bottom: 12px;">
      We auto-detected some columns. Adjust if needed. Only "Action/Task Name" is required.</p>
    <div id="map-grid" class="map-grid"></div>
    <div style="margin-top: 16px;">
      <button class="btn" onclick="applyMapping()">Apply Mapping &amp; Preview</button>
    </div>
  </div>

  <!-- PREVIEW -->
  <div id="preview-section" class="section hidden">
    <h2>3. Review Actions</h2>
    <div class="toolbar">
      <label>Project Name:</label>
      <input type="text" id="project-name" value="My Project Plan">
      <button class="btn btn-green" onclick="exportBundle()">Export bundle.json</button>
      <button class="btn" onclick="exportSvg()">Export SVG</button>
      <button class="btn btn-outline" onclick="exportCsv()">Export Clean CSV</button>
    </div>
    <div class="stats" id="stats"></div>
    <div style="max-height: 600px; overflow-y: auto;">
      <table id="actions-table">
        <thead><tr>
          <th>#</th><th>Card #</th><th>Action</th><th>Section</th>
          <th>Priority</th><th>Status</th><th>Assigned</th>
          <th>Depends</th><th>Start</th><th>Deadline</th>
        </tr></thead>
        <tbody id="actions-body"></tbody>
      </table>
    </div>
  </div>
</div>

<script>
let headers = [];
let rawRows = [];
let columnMap = {};
let actions = [];

// ─── Upload handling ───
const uploadZone = document.getElementById('upload-zone');
const fileInput = document.getElementById('file-input');

uploadZone.addEventListener('click', () => fileInput.click());
uploadZone.addEventListener('dragover', e => { e.preventDefault(); uploadZone.classList.add('dragover'); });
uploadZone.addEventListener('dragleave', () => uploadZone.classList.remove('dragover'));
uploadZone.addEventListener('drop', e => {
    e.preventDefault();
    uploadZone.classList.remove('dragover');
    if (e.dataTransfer.files.length) handleFile(e.dataTransfer.files[0]);
});
fileInput.addEventListener('change', e => { if (e.target.files.length) handleFile(e.target.files[0]); });

function handleFile(file) {
    const formData = new FormData();
    formData.append('file', file);
    fetch('/upload', { method: 'POST', body: formData })
        .then(r => r.json())
        .then(data => {
            headers = data.headers;
            rawRows = data.rows;
            columnMap = data.auto_map;
            uploadZone.innerHTML = '<p style="color:#69db7c;">\\u2713 ' + file.name +
                ' (' + rawRows.length + ' rows, ' + headers.length + ' columns)</p>';
            showMapping();
        })
        .catch(err => alert('Error loading file: ' + err));
}

// Check if server pre-loaded a file
fetch('/state').then(r => r.json()).then(data => {
    if (data.headers && data.headers.length) {
        headers = data.headers;
        rawRows = data.rows;
        columnMap = data.auto_map;
        actions = data.actions || [];
        document.getElementById('server-file').innerHTML =
            '<p style="color:#8ab4f8;">Pre-loaded: ' + data.source_file +
            ' (' + rawRows.length + ' rows)</p>';
        showMapping();
        if (actions.length) {
            document.getElementById('project-name').value = data.project_name || 'My Project Plan';
            showPreview();
        }
    }
});

// ─── Column mapping ───
const FIELDS = [
    ['action', 'Action / Task Name *'],
    ['card_number', 'Card / ID #'],
    ['description', 'Description'],
    ['section', 'Section / Category'],
    ['priority', 'Priority'],
    ['status', 'Status'],
    ['assigned_to', 'Assigned To'],
    ['depends_on', 'Depends On'],
    ['difficulty', 'Difficulty / Points'],
    ['dt_start', 'Start Date'],
    ['dt_deadline', 'Deadline / Due'],
    ['duration', 'Duration'],
    ['percent_complete', '% Complete'],
    ['sequence', 'Sequence / Order']
];

function showMapping() {
    const grid = document.getElementById('map-grid');
    grid.innerHTML = '';
    FIELDS.forEach(([field, label]) => {
        const div = document.createElement('div');
        div.innerHTML = '<label>' + label + '</label>';
        const sel = document.createElement('select');
        sel.id = 'map-' + field;
        sel.innerHTML = '<option value="">(unmapped)</option>';
        headers.forEach(h => {
            const opt = document.createElement('option');
            opt.value = h; opt.textContent = h;
            if (columnMap[field] === h) opt.selected = true;
            sel.appendChild(opt);
        });
        div.appendChild(sel);
        grid.appendChild(div);
    });
    document.getElementById('mapping-section').classList.remove('hidden');
}

function applyMapping() {
    columnMap = {};
    FIELDS.forEach(([field]) => {
        const sel = document.getElementById('map-' + field);
        if (sel && sel.value) columnMap[field] = sel.value;
    });
    fetch('/apply', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ column_map: columnMap, project_name: document.getElementById('project-name').value })
    }).then(r => r.json()).then(data => {
        actions = data.actions;
        showPreview();
    });
}

// ─── Preview ───
function showPreview() {
    document.getElementById('preview-section').classList.remove('hidden');

    // Stats
    const total = actions.length;
    const sections = new Set(actions.map(a => (a.metadata||{}).section || 'General')).size;
    const hasDeps = actions.filter(a => a.depends_on && a.depends_on.length).length;
    const complete = actions.filter(a => a.kanban_column === 'Complete').length;
    document.getElementById('stats').innerHTML =
        '<div class="stat"><div class="stat-num">' + total + '</div><div class="stat-label">Actions</div></div>' +
        '<div class="stat"><div class="stat-num">' + sections + '</div><div class="stat-label">Sections</div></div>' +
        '<div class="stat"><div class="stat-num">' + hasDeps + '</div><div class="stat-label">With Deps</div></div>' +
        '<div class="stat"><div class="stat-num">' + complete + '</div><div class="stat-label">Complete</div></div>';

    // Table
    const tbody = document.getElementById('actions-body');
    tbody.innerHTML = '';
    actions.forEach(a => {
        const tr = document.createElement('tr');
        const pri = a.priority || 2;
        const kanban = a.kanban_column || 'Backlog';
        const assigned = (a.assigned_to || []).map(x => x.name).join(', ');
        const deps = (a.depends_on || []).join(', ');
        tr.innerHTML =
            '<td>' + a.sequence + '</td>' +
            '<td class="card-num">' + (a.card_number || '') + '</td>' +
            '<td>' + (a.action.en || '') + '</td>' +
            '<td>' + ((a.metadata||{}).section || '') + '</td>' +
            '<td class="pri-' + pri + '">P' + pri + '</td>' +
            '<td><span class="status-tag status-' + kanban + '">' + kanban + '</span></td>' +
            '<td>' + assigned + '</td>' +
            '<td class="card-num">' + deps + '</td>' +
            '<td class="card-num">' + (a.dt_start || '') + '</td>' +
            '<td class="card-num">' + (a.dt_deadline || '') + '</td>';
        tbody.appendChild(tr);
    });
}

// ─── Export ───
function exportBundle() {
    const name = document.getElementById('project-name').value || 'My Project Plan';
    fetch('/export/bundle?name=' + encodeURIComponent(name))
        .then(r => r.blob()).then(b => downloadBlob(b, 'bundle.json'));
}
function exportSvg() {
    const name = document.getElementById('project-name').value || 'My Project Plan';
    fetch('/export/svg?name=' + encodeURIComponent(name))
        .then(r => r.blob()).then(b => downloadBlob(b, 'plan.svg'));
}
function exportCsv() {
    fetch('/export/csv').then(r => r.blob()).then(b => downloadBlob(b, 'project-plan.csv'));
}
function downloadBlob(blob, filename) {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
}
</script>
</body></html>'''


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # suppress default logging

    def _respond(self, code, content_type, body):
        self.send_response(code)
        self.send_header('Content-Type', content_type)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        if isinstance(body, str):
            body = body.encode('utf-8')
        self.wfile.write(body)

    def do_GET(self):
        global ACTIONS, COLUMNS, RAW_ROWS, COLUMN_MAP
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)

        if path == '/':
            self._respond(200, 'text/html', _html_page())

        elif path == '/state':
            state = {
                'headers': COLUMNS,
                'rows': RAW_ROWS[:5],  # preview only
                'auto_map': COLUMN_MAP,
                'actions': ACTIONS,
                'source_file': SOURCE_FILE,
                'project_name': PROJECT.get('name', Path(SOURCE_FILE).stem if SOURCE_FILE else 'My Project Plan')
            }
            self._respond(200, 'application/json', json.dumps(state, default=str))

        elif path == '/export/bundle':
            name = qs.get('name', ['My Project Plan'])[0]
            bundle = generate_bundle(name, ACTIONS)
            self._respond(200, 'application/json',
                         json.dumps(bundle, indent=2, default=str))

        elif path == '/export/svg':
            name = qs.get('name', ['My Project Plan'])[0]
            svg = generate_svg(name, ACTIONS)
            self._respond(200, 'image/svg+xml', svg)

        elif path == '/export/csv':
            output = io.StringIO()
            writer = csv.writer(output)
            writer.writerow(['sequence', 'card_number', 'action', 'description',
                           'section', 'priority', 'kanban_column', 'assigned_to',
                           'depends_on', 'dt_start', 'dt_deadline', 'difficulty',
                           'percent_complete'])
            for a in ACTIONS:
                writer.writerow([
                    a.get('sequence', ''),
                    a.get('card_number', ''),
                    a.get('action', {}).get('en', ''),
                    a.get('description', {}).get('en', ''),
                    a.get('metadata', {}).get('section', ''),
                    a.get('priority', ''),
                    a.get('kanban_column', ''),
                    ','.join(x.get('name', '') for x in a.get('assigned_to', [])),
                    ','.join(str(d) for d in a.get('depends_on', [])),
                    a.get('dt_start', ''),
                    a.get('dt_deadline', ''),
                    a.get('difficulty', ''),
                    a.get('percent_complete', '')
                ])
            self._respond(200, 'text/csv', output.getvalue())

        else:
            self._respond(404, 'text/plain', 'Not found')

    def do_POST(self):
        global ACTIONS, COLUMNS, RAW_ROWS, COLUMN_MAP
        parsed = urlparse(self.path)
        path = parsed.path
        content_length = int(self.headers.get('Content-Length', 0))

        if path == '/upload':
            # Parse multipart form data (simple implementation)
            body = self.rfile.read(content_length)
            # Extract boundary
            content_type = self.headers.get('Content-Type', '')
            boundary = content_type.split('boundary=')[-1].encode()
            parts = body.split(b'--' + boundary)
            for part in parts:
                if b'filename=' in part:
                    # Extract filename
                    header_end = part.find(b'\r\n\r\n')
                    if header_end < 0:
                        continue
                    file_data = part[header_end + 4:]
                    if file_data.endswith(b'\r\n'):
                        file_data = file_data[:-2]

                    header_text = part[:header_end].decode('utf-8', errors='replace')
                    fn_match = re.search(r'filename="([^"]+)"', header_text)
                    filename = fn_match.group(1) if fn_match else 'upload.csv'

                    # Save to temp
                    tmp_path = Path('/tmp') / filename
                    with open(tmp_path, 'wb') as f:
                        f.write(file_data)

                    COLUMNS, RAW_ROWS = load_file(tmp_path)
                    COLUMN_MAP = auto_map_columns(COLUMNS)

                    self._respond(200, 'application/json', json.dumps({
                        'headers': COLUMNS,
                        'rows': RAW_ROWS[:5],
                        'auto_map': COLUMN_MAP,
                        'row_count': len(RAW_ROWS)
                    }))
                    return

            self._respond(400, 'application/json', '{"error": "No file found"}')

        elif path == '/apply':
            body = self.rfile.read(content_length)
            data = json.loads(body)
            COLUMN_MAP.update(data.get('column_map', {}))
            project_name = data.get('project_name', 'My Project Plan')
            PROJECT['name'] = project_name
            ACTIONS = rows_to_actions(COLUMNS, RAW_ROWS)

            # Save working state
            save_state()

            self._respond(200, 'application/json', json.dumps({
                'actions': ACTIONS,
                'count': len(ACTIONS)
            }, default=str))

        else:
            self._respond(404, 'text/plain', 'Not found')


def save_state():
    """Save current state to _working.json."""
    state = {
        'columns': COLUMNS,
        'column_map': COLUMN_MAP,
        'actions': ACTIONS,
        'project': PROJECT,
        'source_file': SOURCE_FILE
    }
    state_path = OUTPUT_DIR / '_working.json'
    with open(state_path, 'w') as f:
        json.dump(state, f, indent=2, default=str)


# ─── CLI ─────────────────────────────────────────────────────────────

def main():
    global COLUMNS, RAW_ROWS, COLUMN_MAP, ACTIONS, PROJECT, SOURCE_FILE, OUTPUT_DIR

    parser = argparse.ArgumentParser(description='Project Planner — CSV/XLSX to bundle.json + SVG')
    parser.add_argument('input', nargs='?', help='CSV/XLSX file or folder')
    parser.add_argument('--port', type=int, default=8878, help='Web UI port (default: 8878)')
    parser.add_argument('--name', default=None, help='Project name')
    parser.add_argument('--output', default=None, help='Output directory')
    parser.add_argument('--no-browser', action='store_true', help='Don\'t open browser')
    parser.add_argument('--batch', action='store_true', help='Batch mode: auto-map, generate, exit')
    args = parser.parse_args()

    if args.input:
        input_path = Path(args.input).expanduser().resolve()
        if input_path.is_dir():
            # Find first CSV/XLSX in folder
            files = list(input_path.glob('*.csv')) + list(input_path.glob('*.xlsx'))
            if not files:
                print(f"No CSV/XLSX files found in {input_path}")
                sys.exit(1)
            input_path = files[0]
            print(f"Found: {input_path.name}")

        if not input_path.exists():
            print(f"File not found: {input_path}")
            sys.exit(1)

        SOURCE_FILE = str(input_path)
        project_name = args.name or input_path.stem.replace('-', ' ').replace('_', ' ').title()
        PROJECT['name'] = project_name
        OUTPUT_DIR = Path(args.output) if args.output else input_path.parent / f'{input_path.stem}_project'

        print(f"Loading: {input_path.name}")
        COLUMNS, RAW_ROWS = load_file(input_path)
        print(f"  {len(RAW_ROWS)} rows, {len(COLUMNS)} columns")

        COLUMN_MAP = auto_map_columns(COLUMNS)
        print(f"  Auto-mapped: {', '.join(f'{k}={v}' for k, v in COLUMN_MAP.items())}")

        if args.batch:
            ACTIONS = rows_to_actions(COLUMNS, RAW_ROWS)
            print(f"  {len(ACTIONS)} actions created")
            print(f"\nGenerating output in {OUTPUT_DIR}/")
            save_outputs(project_name, ACTIONS, OUTPUT_DIR)

            # Copy source file
            import shutil
            dest = OUTPUT_DIR / input_path.name
            if not dest.exists():
                shutil.copy2(input_path, dest)
                print(f"  \u2713 {dest}")

            save_state()
            print(f"  \u2713 {OUTPUT_DIR / '_working.json'}")
            print(f"\nDone. Edit bundle.json, then import into WC3.")
            return

        ACTIONS = rows_to_actions(COLUMNS, RAW_ROWS)
    else:
        OUTPUT_DIR = Path.cwd() / 'project_output'

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"\nStarting web UI on http://localhost:{args.port}")
    server = HTTPServer(('localhost', args.port), Handler)
    if not args.no_browser:
        webbrowser.open(f'http://localhost:{args.port}')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == '__main__':
    main()

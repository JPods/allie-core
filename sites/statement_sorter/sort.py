#!/usr/bin/env python3
"""
Statement Sorter — Drop your bank statements, sort business from personal.

Zero dependencies. One file. Python 3.10+.

Usage:
    python3 sort.py ~/Taxes/2025/
    python3 sort.py ~/Taxes/2025/ --port 8899

Opens a browser. Classify each line as business or personal.
Export business or personal as CSV or JSON.

Supports: Wells Fargo, USAA, Wise, GoDaddy, and any CSV with date+amount+description.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import io
import json
import os
import sys
import uuid
import webbrowser
from datetime import datetime, date, timezone
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, urlparse

# ─── Global state ────────────────────────────────────────────────────

LINES: list[dict] = []
DATA_FILE: Path = Path()
SOURCE_FOLDER: str = ''

# ─── Bank detection ─────────────────────────────────────────────────

def _is_date(s):
    try: _parse_date(s); return True
    except: return False

def _is_number(s):
    try: float(s.strip().strip('"').replace(',','').replace('$','')); return True
    except: return False

SIGS = [
    (lambda h,r: 'month' in h and 'post date' in h, 'wellsfargo_cc', 'Wells Fargo CC'),
    (lambda h,r: 'original description' in h or ('description' in h and 'status' in h and 'category' in h), 'usaa', 'USAA'),
    (lambda h,r: 'direction' in h and 'source fee amount' in h, 'wise', 'Wise'),
    (lambda h,r: 'receipt number' in h and 'order total' in h, 'registrar', 'Domain Registrar'),
    (lambda h,r: len(r)>=4 and _is_date(r[0]) and _is_number(r[1]) and r[2].strip()=='*', 'wf_legacy', 'Wells Fargo'),
    (lambda h,r: 'date' in h and 'amount' in h, 'generic', 'Generic'),
]

def detect(headers, first_row):
    h = [c.strip().lower() for c in headers]
    for fn, key, name in SIGS:
        try:
            if fn(h, first_row): return key, name
        except: pass
    return 'unknown', 'Unknown'

# ─── Parsers ─────────────────────────────────────────────────────────

def _parse_date(s):
    s = s.strip().strip('"')
    for fmt in ('%m/%d/%Y','%Y-%m-%d','%m/%d/%y'):
        try:
            d = datetime.strptime(s, fmt)
            if d.year < 100: d = d.replace(year=d.year+2000)
            return d.date()
        except: pass
    raise ValueError(s)

def _parse_amt(s):
    s = s.strip().strip('"').replace('$','').replace(',','')
    if s.startswith('(') and s.endswith(')'): s = '-'+s[1:-1]
    return float(s)

def _line(dt, desc, amt, src, raw, bank_cat=''):
    return {
        'uuid': str(uuid.uuid4()), 'date': str(dt), 'description': desc,
        'amount': amt, 'source': src, 'raw': raw,
        'classification': 'unknown', 'category': '', 'bank_category': bank_cat,
    }

def parse_usaa(rows, src):
    out = []
    for r in rows:
        if len(r)<5: continue
        try: dt=_parse_date(r[0]); amt=_parse_amt(r[4])
        except: continue
        out.append(_line(dt, r[1].strip().strip('"'), amt, src, ','.join(r),
                         r[3].strip().strip('"') if len(r)>3 else ''))
    return out

def parse_wf_cc(rows, src):
    out = []
    for r in rows:
        if len(r)<4: continue
        try:
            parts = r[0].strip().split(); year = int(parts[1]) if len(parts)==2 else datetime.now().year
            m,d = r[1].strip().split('/'); dt = date(year, int(m), int(d))
            amt = _parse_amt(r[3])
        except: continue
        out.append(_line(dt, r[2].strip(), amt, src, ','.join(r),
                         r[4].strip() if len(r)>4 else ''))
    return out

def parse_wf_legacy(rows, src):
    out = []
    for r in rows:
        if len(r)<5: continue
        try: dt=_parse_date(r[0]); amt=_parse_amt(r[1])
        except: continue
        out.append(_line(dt, r[4].strip().strip('"'), amt, src, ','.join(r)))
    return out

def parse_wise(rows, src):
    out = []
    for r in rows:
        if len(r)<11: continue
        try: dt=datetime.strptime(r[3].strip().strip('"'),'%Y-%m-%d %H:%M:%S').date(); amt=_parse_amt(r[10])
        except: continue
        if r[2].strip().strip('"').upper()=='OUT': amt=-abs(amt)
        target = r[12].strip().strip('"') if len(r)>12 else ''
        out.append(_line(dt, f"Wise → {target}" if target else "Wise transfer", amt, src, ','.join(r)))
    return out

def parse_registrar(rows, src):
    out = []
    for r in rows:
        if len(r)<10: continue
        try:
            dt = datetime.fromisoformat(r[2].strip().strip('"').replace('Z','+00:00')).date()
            amt = -abs(_parse_amt(r[9]))
        except: continue
        product = r[3].strip().strip('"'); name = r[4].strip().strip('"')
        out.append(_line(dt, f"{product}: {name[:60]}" if name else product, amt, src,
                         ','.join(c[:40] for c in r)))
    return out

def parse_generic(rows, headers, src):
    h = [c.strip().lower() for c in headers]
    di = next((i for i,c in enumerate(h) if c in ('date','post_date','post date','transaction_date','transaction date')),0)
    ai = next((i for i,c in enumerate(h) if c=='amount'),1)
    dsi = next((i for i,c in enumerate(h) if c in ('description','memo','payee','name')),2)
    ci = next((i for i,c in enumerate(h) if c in ('category','type')),None)
    out = []
    for r in rows:
        if len(r)<=max(di,ai,dsi): continue
        try: dt=_parse_date(r[di]); amt=_parse_amt(r[ai])
        except: continue
        bc = r[ci].strip() if ci and ci<len(r) else ''
        out.append(_line(dt, r[dsi].strip().strip('"'), amt, src, ','.join(r), bc))
    return out

# ─── Harvest ─────────────────────────────────────────────────────────

def harvest_file(fp, src_override=''):
    with open(fp, 'r', encoding='utf-8-sig') as f:
        rows = list(csv.reader(f))
    if not rows: return [], ''
    key, name = detect(rows[0], rows[1] if len(rows)>1 else [])
    src = src_override or key
    if key=='wf_legacy': return parse_wf_legacy(rows, src), name
    if key=='wellsfargo_cc': return parse_wf_cc(rows[1:], src), name
    if key=='usaa': return parse_usaa(rows[1:], src), name
    if key=='wise': return parse_wise(rows[1:], src), name
    if key=='registrar': return parse_registrar(rows[1:], src), name
    return parse_generic(rows[1:], rows[0], src), name

def harvest_folder(folder):
    p = Path(folder)
    all_lines = []; banks = {}
    for f in sorted(p.rglob('*.csv')):
        lines, name = harvest_file(str(f))
        if lines:
            all_lines.extend(lines)
            banks[name] = banks.get(name,0)+len(lines)
            print(f"  {f.name}: {len(lines)} lines ({name})")
        else:
            print(f"  {f.name}: no lines parsed")
    return all_lines, banks

def dedup(lines):
    seen = set(); out = []
    for l in lines:
        h = hashlib.md5(l.get('raw','').encode()).hexdigest()[:16]
        if h not in seen: seen.add(h); out.append(l)
    return out

# ─── JSON I/O ────────────────────────────────────────────────────────

def save_data():
    DATA_FILE.write_text(json.dumps(LINES, indent=2))

def load_data():
    global LINES
    if DATA_FILE.exists():
        LINES = json.loads(DATA_FILE.read_text())

# ─── Web UI ──────────────────────────────────────────────────────────

CATEGORIES = [
    'Office Supplies','Travel','Utilities','Rent','Insurance',
    'Professional Services','Shipping','Equipment','Materials',
    'Payroll','Taxes','Advertising','Repairs & Maintenance',
    'Hosting','Software','Domains','Subscriptions','Meals',
    'Vehicle','Phone','Bank Fees','Miscellaneous',
]

def build_html():
    total = len(LINES)
    biz = sum(1 for l in LINES if l['classification']=='business')
    per = sum(1 for l in LINES if l['classification']=='personal')
    unk = total - biz - per
    biz_total = sum(l['amount'] for l in LINES if l['classification']=='business')
    per_total = sum(l['amount'] for l in LINES if l['classification']=='personal')

    cat_options = ''.join(f'<option value="{c}">{c}</option>' for c in CATEGORIES)

    rows_html = ''
    for i, l in enumerate(LINES):
        cls = l['classification']
        bg = '#1a2a1a' if cls=='business' else '#2a1a1a' if cls=='personal' else '#1a1a2a'
        amt = l['amount']
        amt_color = '#4ade80' if amt > 0 else '#f87171' if amt < 0 else '#888'
        esc_desc = html.escape(l['description'])
        esc_cat = html.escape(l.get('category',''))
        esc_bcat = html.escape(l.get('bank_category',''))
        rows_html += f'''<tr data-idx="{i}" style="background:{bg}" class="row">
<td class="cbox"><input type="checkbox" data-idx="{i}"></td>
<td class="dt">{l['date']}</td>
<td class="desc" title="{esc_desc}">{esc_desc[:55]}</td>
<td class="amt" style="color:{amt_color}">{amt:,.2f}</td>
<td class="src">{l['source']}</td>
<td class="cls">
<select data-idx="{i}" data-field="classification" onchange="save(this)">
<option value="unknown" {'selected' if cls=='unknown' else ''}>unknown</option>
<option value="business" {'selected' if cls=='business' else ''}>business</option>
<option value="personal" {'selected' if cls=='personal' else ''}>personal</option>
</select></td>
<td class="cat">
<select data-idx="{i}" data-field="category" onchange="save(this)">
<option value="">--</option>
{cat_options}
</select>
<input type="text" data-idx="{i}" data-field="category" value="{esc_cat}" placeholder="or type..."
 onchange="save(this)" style="width:80px;margin-left:2px">
</td>
<td class="bcat">{esc_bcat}</td>
</tr>'''

    return f'''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Statement Sorter</title>
<style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ background:#0d1117; color:#c9d1d9; font-family:-apple-system,system-ui,sans-serif; font-size:13px; }}
.top {{ position:sticky; top:0; z-index:10; background:#161b22; border-bottom:1px solid #30363d; padding:8px 16px; }}
.top h1 {{ font-size:18px; color:#fff; margin-bottom:6px; }}
.stats {{ display:flex; gap:16px; font-size:12px; color:#8b949e; }}
.stats span {{ padding:2px 8px; border-radius:4px; }}
.s-biz {{ background:#1a3a1a; color:#4ade80; }}
.s-per {{ background:#3a1a1a; color:#f87171; }}
.s-unk {{ background:#1a1a3a; color:#8b949e; }}
.bar {{ display:flex; gap:6px; margin-top:6px; flex-wrap:wrap; }}
.bar button, .bar select {{ padding:4px 10px; border:1px solid #30363d; background:#21262d; color:#c9d1d9;
  border-radius:4px; cursor:pointer; font-size:11px; }}
.bar button:hover {{ background:#30363d; }}
.bar .grn {{ background:#1a6b35; border-color:#2ea043; color:#fff; }}
.bar .red {{ background:#6b1a1a; border-color:#da3633; color:#fff; }}
.bar .blu {{ background:#1a3a6b; border-color:#388bfd; color:#fff; }}
table {{ width:100%; border-collapse:collapse; }}
th {{ position:sticky; top:72px; background:#161b22; padding:4px 6px; text-align:left; font-size:11px;
  color:#8b949e; border-bottom:1px solid #30363d; z-index:5; }}
td {{ padding:3px 6px; border-bottom:1px solid #21262d; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:300px; }}
.row:hover {{ background:#1c2432 !important; }}
.cbox {{ width:24px; text-align:center; }}
.dt {{ width:85px; color:#8b949e; }}
.amt {{ width:90px; text-align:right; font-family:monospace; }}
.src {{ width:100px; color:#8b949e; font-size:11px; }}
.cls select {{ background:#21262d; color:#c9d1d9; border:1px solid #30363d; border-radius:3px; padding:1px 4px; font-size:11px; }}
.cat select, .cat input {{ background:#21262d; color:#c9d1d9; border:1px solid #30363d; border-radius:3px; padding:1px 4px; font-size:11px; }}
.bcat {{ color:#6e7681; font-size:11px; max-width:120px; }}
input[type=checkbox] {{ cursor:pointer; }}
#selbar {{ display:none; position:fixed; bottom:0; left:0; right:0; background:#1a3a1a; border-top:2px solid #2ea043;
  padding:8px 16px; z-index:20; }}
</style></head><body>
<div class="top">
<h1>Statement Sorter <span style="font-size:12px;color:#8b949e;font-weight:normal">— {SOURCE_FOLDER}</span></h1>
<div class="stats">
<span>{total} total</span>
<span class="s-biz">{biz} business (${abs(biz_total):,.2f})</span>
<span class="s-per">{per} personal (${abs(per_total):,.2f})</span>
<span class="s-unk">{unk} unknown</span>
</div>
<div class="bar">
<button class="grn" onclick="bulkSet('classification','business')">Selected → Business</button>
<button class="red" onclick="bulkSet('classification','personal')">Selected → Personal</button>
<button onclick="bulkSet('classification','unknown')">Selected → Unknown</button>
<span style="color:#30363d">|</span>
<select onchange="if(this.value)bulkSet('category',this.value);this.selectedIndex=0">
<option value="">Set Category...</option>
{''.join(f'<option value="{c}">{c}</option>' for c in CATEGORIES)}
</select>
<span style="color:#30363d">|</span>
<select id="filter-cls" onchange="filterRows()">
<option value="">Show All</option>
<option value="unknown">unknown only</option>
<option value="business">business only</option>
<option value="personal">personal only</option>
</select>
<span style="flex:1"></span>
<button class="blu" onclick="exportData('business','csv')">Export Business CSV</button>
<button class="blu" onclick="exportData('business','json')">Export Business JSON</button>
<button onclick="exportData('personal','csv')">Export Personal CSV</button>
<button onclick="exportData('personal','json')">Export Personal JSON</button>
<button onclick="selectAll()">Select All Visible</button>
<button onclick="deselectAll()">Deselect All</button>
</div>
<div class="bar" style="border-top:1px solid #30363d;padding-top:6px">
<button onclick="doUnload()">Unload (Clear)</button>
<div id="drop-zone" onclick="document.getElementById('file-input').click()"
  style="flex:1;padding:8px 16px;background:#21262d;border:2px dashed #30363d;border-radius:6px;text-align:center;cursor:pointer;color:#8b949e;font-size:12px;transition:all 0.2s"
  onmouseover="this.style.borderColor='#ea580c';this.style.color='#ea580c'"
  onmouseout="this.style.borderColor='#30363d';this.style.color='#8b949e'">
  Drop files or folders here — or click to browse
</div>
<input type="file" id="file-input" accept=".json,.csv" multiple style="display:none" onchange="handleFileLoad(this)">
</div>
</div>
<table>
<thead><tr>
<th><input type="checkbox" onchange="toggleAll(this.checked)"></th>
<th>date</th><th>description</th><th>amount</th><th>source</th>
<th>classification</th><th>category</th><th>bank_category</th>
</tr></thead>
<tbody>{rows_html}</tbody>
</table>
<script>
function save(el) {{
  const idx = el.dataset.idx;
  const field = el.dataset.field;
  const value = el.value;
  fetch('/save', {{
    method:'POST',
    headers:{{'Content-Type':'application/json'}},
    body:JSON.stringify({{idx:parseInt(idx), field, value}})
  }}).then(()=>location.reload());
}}
function bulkSet(field, value) {{
  const checked = [...document.querySelectorAll('input[type=checkbox][data-idx]:checked')];
  if(!checked.length) {{ alert('Select rows first'); return; }}
  const indices = checked.map(c=>parseInt(c.dataset.idx));
  fetch('/bulk', {{
    method:'POST',
    headers:{{'Content-Type':'application/json'}},
    body:JSON.stringify({{indices, field, value}})
  }}).then(()=>location.reload());
}}
function exportData(cls, fmt) {{
  window.open('/export?classification='+cls+'&format='+fmt);
}}
function filterRows() {{
  const v = document.getElementById('filter-cls').value;
  document.querySelectorAll('tr.row').forEach(r => {{
    if(!v) {{ r.style.display=''; return; }}
    const sel = r.querySelector('select[data-field=classification]');
    r.style.display = sel && sel.value===v ? '' : 'none';
  }});
}}
function selectAll() {{
  document.querySelectorAll('tr.row').forEach(r => {{
    if(r.style.display!=='none') {{
      const cb = r.querySelector('input[type=checkbox]');
      if(cb) cb.checked = true;
    }}
  }});
}}
function deselectAll() {{
  document.querySelectorAll('input[type=checkbox]').forEach(c=>c.checked=false);
}}
function toggleAll(checked) {{
  document.querySelectorAll('tr.row').forEach(r => {{
    if(r.style.display!=='none') {{
      const cb = r.querySelector('input[type=checkbox]');
      if(cb) cb.checked = checked;
    }}
  }});
}}
function doUnload() {{
  if(!confirm('Clear all lines and start fresh?')) return;
  fetch('/unload', {{method:'POST',headers:{{'Content-Type':'application/json'}},body:'{{}}'}}).then(()=>location.reload());
}}
function doLoad() {{
  document.getElementById('file-input').click();
}}
async function loadFile(file) {{
  return new Promise((resolve, reject) => {{
    const reader = new FileReader();
    reader.onload = async function(e) {{
      try {{
        const res = await fetch('/load', {{
          method:'POST',
          headers:{{'Content-Type':'application/json'}},
          body:JSON.stringify({{filename: file.name, content: e.target.result}})
        }});
        const d = await res.json();
        resolve(d.message || 'OK');
      }} catch(err) {{ reject(err); }}
    }};
    reader.readAsText(file);
  }});
}}
async function handleFileLoad(input) {{
  const files = Array.from(input.files);
  if(!files.length) return;
  const msgs = [];
  for(const f of files) {{
    try {{ msgs.push(await loadFile(f)); }}
    catch(e) {{ msgs.push(f.name + ': failed'); }}
  }}
  alert(msgs.join('\\n'));
  input.value = '';
  location.reload();
}}
// Drag and drop — works on entire page, highlights drop zone
document.addEventListener('DOMContentLoaded', () => {{
  const dz = document.getElementById('drop-zone');
  document.body.addEventListener('dragover', (e) => {{
    e.preventDefault();
    dz.style.borderColor = '#ea580c';
    dz.style.background = 'rgba(234,88,12,0.15)';
    dz.textContent = 'Drop here!';
  }});
  document.body.addEventListener('dragleave', (e) => {{
    if(e.relatedTarget === null) {{
      dz.style.borderColor = '#30363d';
      dz.style.background = '#21262d';
      dz.textContent = 'Drop files or folders here — or click to browse';
    }}
  }});
  document.body.addEventListener('drop', async (e) => {{
    e.preventDefault();
    dz.style.borderColor = '#30363d';
    dz.style.background = '#21262d';
    dz.textContent = 'Loading...';
    // Collect files — folders send their contents as individual files
    const items = e.dataTransfer.items ? Array.from(e.dataTransfer.items) : [];
    let files = [];
    // Try webkitGetAsEntry for folder support
    const entries = items.map(i => i.webkitGetAsEntry && i.webkitGetAsEntry()).filter(Boolean);
    if(entries.length && entries.some(e => e.isDirectory)) {{
      // Recursively collect files from directories
      async function readEntry(entry) {{
        if(entry.isFile) {{
          return new Promise(r => entry.file(f => r(f)));
        }} else if(entry.isDirectory) {{
          const reader = entry.createReader();
          const dirEntries = await new Promise(r => reader.readEntries(e => r(e)));
          const results = [];
          for(const de of dirEntries) {{
            const f = await readEntry(de);
            if(Array.isArray(f)) results.push(...f);
            else if(f) results.push(f);
          }}
          return results;
        }}
      }}
      for(const entry of entries) {{
        const result = await readEntry(entry);
        if(Array.isArray(result)) files.push(...result);
        else if(result) files.push(result);
      }}
    }} else {{
      files = Array.from(e.dataTransfer.files);
    }}
    files = files.filter(f => f.name.endsWith('.csv') || f.name.endsWith('.json'));
    if(!files.length) {{
      dz.textContent = 'No .csv or .json files found';
      setTimeout(() => {{ dz.textContent = 'Drop files or folders here — or click to browse'; }}, 2000);
      return;
    }}
    const msgs = [];
    for(const f of files) {{
      try {{ msgs.push(await loadFile(f)); }}
      catch(err) {{ msgs.push(f.name + ': failed'); }}
    }}
    alert(msgs.join('\\n'));
    location.reload();
  }});
}});
</script></body></html>'''


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == '/':
            html_content = build_html()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(html_content.encode())
        elif parsed.path == '/export':
            params = parse_qs(parsed.query)
            cls = params.get('classification', [''])[0]
            fmt = params.get('format', ['csv'])[0]
            filtered = [l for l in LINES if l['classification'] == cls]
            if fmt == 'json':
                content = json.dumps(filtered, indent=2)
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Disposition', f'attachment; filename="{cls}_statements.json"')
                self.end_headers()
                self.wfile.write(content.encode())
            else:
                output = io.StringIO()
                writer = csv.writer(output)
                writer.writerow(['date', 'description', 'amount', 'source', 'category', 'bank_category'])
                for l in filtered:
                    writer.writerow([l['date'], l['description'], l['amount'], l['source'],
                                    l.get('category', ''), l.get('bank_category', '')])
                content = output.getvalue()
                self.send_response(200)
                self.send_header('Content-Type', 'text/csv')
                self.send_header('Content-Disposition', f'attachment; filename="{cls}_statements.csv"')
                self.end_headers()
                self.wfile.write(content.encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(length)) if length else {}

        if self.path == '/save':
            idx = body.get('idx', 0)
            field = body.get('field', '')
            value = body.get('value', '')
            if 0 <= idx < len(LINES) and field in ('classification', 'category'):
                LINES[idx][field] = value
                save_data()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"ok":true}')

        elif self.path == '/bulk':
            indices = body.get('indices', [])
            field = body.get('field', '')
            value = body.get('value', '')
            if field in ('classification', 'category'):
                for idx in indices:
                    if 0 <= idx < len(LINES):
                        LINES[idx][field] = value
                save_data()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"ok":true}')

        elif self.path == '/unload':
            LINES.clear()
            save_data()
            self._json_response({'message': 'Cleared all lines'})

        elif self.path == '/load':
            filename = body.get('filename', '')
            content = body.get('content', '')
            if filename.endswith('.json'):
                try:
                    new_lines = json.loads(content)
                    if not isinstance(new_lines, list):
                        self._json_response({'error': 'JSON must be an array'}, 400)
                        return
                    existing_hashes = {hashlib.md5(l.get('raw','').encode()).hexdigest()[:16] for l in LINES}
                    added = 0
                    for l in new_lines:
                        if not isinstance(l, dict): continue
                        if 'uuid' not in l: l['uuid'] = str(uuid.uuid4())
                        h = hashlib.md5(l.get('raw','').encode()).hexdigest()[:16]
                        if h not in existing_hashes:
                            LINES.append(l)
                            existing_hashes.add(h)
                            added += 1
                    save_data()
                    self._json_response({'message': f'Loaded {added} lines from {filename} ({len(new_lines)-added} duplicates). Total: {len(LINES)}'})
                except json.JSONDecodeError as e:
                    self._json_response({'error': f'Invalid JSON: {e}'}, 400)
            elif filename.endswith('.csv'):
                # Parse CSV content as a generic bank statement
                reader = csv.reader(io.StringIO(content))
                rows = list(reader)
                if not rows:
                    self._json_response({'error': 'Empty CSV'}, 400)
                    return
                key, name = detect(rows[0], rows[1] if len(rows)>1 else [])
                src = key
                if key == 'wf_legacy': new_lines = parse_wf_legacy(rows, src)
                elif key == 'wellsfargo_cc': new_lines = parse_wf_cc(rows[1:], src)
                elif key == 'usaa': new_lines = parse_usaa(rows[1:], src)
                elif key == 'wise': new_lines = parse_wise(rows[1:], src)
                elif key == 'registrar': new_lines = parse_registrar(rows[1:], src)
                else: new_lines = parse_generic(rows[1:], rows[0], src)
                existing_hashes = {hashlib.md5(l.get('raw','').encode()).hexdigest()[:16] for l in LINES}
                added = 0
                for l in new_lines:
                    h = hashlib.md5(l.get('raw','').encode()).hexdigest()[:16]
                    if h not in existing_hashes:
                        LINES.append(l)
                        existing_hashes.add(h)
                        added += 1
                save_data()
                self._json_response({'message': f'Loaded {added} lines from {filename} ({name}). Total: {len(LINES)}'})
            else:
                self._json_response({'error': 'Unsupported file type. Use .json or .csv'}, 400)

        else:
            self.send_response(404)
            self.end_headers()

    def _json_response(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def log_message(self, format, *args):
        pass  # quiet


def main():
    global LINES, DATA_FILE, SOURCE_FOLDER

    parser = argparse.ArgumentParser(description='Statement Sorter — classify bank statements')
    parser.add_argument('path', help='CSV file, folder of CSVs, or existing .json working file')
    parser.add_argument('--port', type=int, default=8877, help='Server port (default 8877)')
    parser.add_argument('--no-browser', action='store_true', help="Don't auto-open browser")
    args = parser.parse_args()

    p = Path(args.path)
    SOURCE_FOLDER = str(p)

    # If pointing at an existing JSON file, load it directly
    if p.is_file() and p.suffix == '.json':
        DATA_FILE = p
        load_data()
        print(f"Loaded {len(LINES)} lines from {p}")
    else:
        # Harvest CSVs
        if p.is_dir():
            print(f"Harvesting folder: {p}")
            lines, banks = harvest_folder(str(p))
        elif p.is_file():
            lines, name = harvest_file(str(p))
            banks = {name: len(lines)}
        else:
            print(f"Error: {args.path} not found")
            sys.exit(1)

        lines = dedup(lines)
        print(f"\n{len(lines)} unique lines from {len(banks)} accounts")
        for b, c in sorted(banks.items()):
            print(f"  {b}: {c}")

        # Save working file
        DATA_FILE = p / '_working.json' if p.is_dir() else p.with_suffix('.json')
        # Merge with existing if present
        if DATA_FILE.exists():
            existing = json.loads(DATA_FILE.read_text())
            existing_hashes = {hashlib.md5(l.get('raw', '').encode()).hexdigest()[:16] for l in existing}
            new = [l for l in lines if hashlib.md5(l.get('raw', '').encode()).hexdigest()[:16] not in existing_hashes]
            LINES = existing + new
            print(f"Merged: {len(new)} new + {len(existing)} existing = {len(LINES)} total")
        else:
            LINES = lines
        save_data()

    biz = sum(1 for l in LINES if l['classification'] == 'business')
    per = sum(1 for l in LINES if l['classification'] == 'personal')
    unk = len(LINES) - biz - per
    print(f"\n{len(LINES)} lines: {biz} business, {per} personal, {unk} unknown")
    print(f"Working file: {DATA_FILE}")

    server = HTTPServer(('127.0.0.1', args.port), Handler)
    url = f'http://127.0.0.1:{args.port}'
    print(f"\nOpen: {url}")

    if not args.no_browser:
        webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\nSaved. {DATA_FILE}")


if __name__ == '__main__':
    main()

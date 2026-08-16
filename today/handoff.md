# Handoff — 2026-08-16

## Where We Left Off

Built the Form Parade — a complete print form review tool at `/form-parade`. All 14 commerce forms rendering with sample data, company logo, feedback system, and print preview. Also fixed the rightshoe timeout hang (code deployed but MCP server needs restart to take effect).

## What Was Built

### Form Parade (`/form-parade`)

**React page** (`React2025/src/pages/tools/FormParade.tsx`):
- Left panel: 14 reports grouped by business flow (Selling, Getting Paid, Buying, Catalog & Contacts)
- Top toolbar: report name, Keep/Modify/Don't Need feedback buttons, notes field, Print Preview, New Tab
- Right panel: iframe preview rendering form HTML with sample data
- Route at `/form-parade`, registered in Routes.ts + protectedRoutesConfig.tsx

**Django backend:**
- `GET /wcapi/parade-manifest/` — returns grouped report list with sample data status
- `GET /wcapi/parade-preview/?report_id=N` — renders form as standalone HTML with sample data
- `POST /wcapi/parade-feedback/` — saves Keep/Modify/Don't Need + notes to Report record
- Added `data_table` renderer (with group_by, subtotals, grand totals) and `detail_fields` renderer
- Company logo pulled from `Company Profile` Setting → `config.logos.primary`
- Date formatting fix: epoch→YYYY-MM-DD in address_blocks sections
- Filesystem fallback for sample data (Report.config.sample_data → sample_data/*.json)

**New sample data files** (`apps/core/sample_data/`):
- `requisition.json` — maintenance department supplies, 8 lines, $2,847.60
- `workorder.json` — HVAC compressor replacement, labor + materials, $4,925.00
- `aging.json` — AR aging, 10 customers across 3 reps

**Infrastructure:**
- `/media` proxy added to `React2025/vite.config.ts` for dev
- Media serving added to `webClerk3/webclerk3_api/urls.py` (Django dev mode)
- Table header color: JPods blue `#3355FF`

### Rightshoe Timeout Fix (`scripts/leftshoe-mcp.py`)
- 30s thread wrapper around entire rightshoe handler
- psycopg2 `connect_timeout=10`, `statement_timeout=15000`
- Returns graceful timeout message if WC3 post hangs
- **NOT YET ACTIVE** — leftshoe MCP server runs the old code until Claude Code restarts

**Readme:** `webClerk3/readmes/topics/print/form-parade.md`
**Video:** https://vimeo.com/1218709661

## Open Problems

1. **Rightshoe timeout fix not active** — needs leftshoe MCP server restart (next Claude Code session will pick it up)
2. **Thank You Letter** — shows raw JSON dump (no `config.form` layout defined on the Report record)
3. **Print Preview cross-origin** — iframe `contentWindow.print()` works in dev (same origin via proxy), needs testing in production
4. **Aging report fallback** — model is "customer" but sample file is `aging.json`; special-case code in preview view

## Do This First Next Session

1. Verify rightshoe timeout fix works (should be automatic — new MCP server process loads the updated code)
2. If continuing form work: add form layout for Thank You Letter report
3. Bill's choice on what to work on next

## Files Changed

### WC3
```
apps/core/views/parade_preview_view.py
apps/core/services/parade_of_reports.py
apps/core/urls.py
apps/core/sample_data/requisition.json (new)
apps/core/sample_data/workorder.json (new)
apps/core/sample_data/aging.json (new)
apps/core/sample_data/_index.json
webclerk3_api/urls.py
static/images/logo/webclerk.png (new — copy of React logo)
readmes/topics/print/form-parade.md (new)
```

### React2025
```
src/pages/tools/FormParade.tsx (new)
src/routes/Routes.ts
src/routes/protectedRoutesConfig.tsx
vite.config.ts
```

### Allie
```
scripts/leftshoe-mcp.py (rightshoe timeout fix)
```

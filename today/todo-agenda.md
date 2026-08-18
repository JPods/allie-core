# TODO: Agenda — PostgreSQL VIEW in DataBrowser

**Created:** 2026-08-18
**Status:** In progress — backend works, frontend wiring needs testing/fixing
**Priority:** High — this is the primary daily workflow view

## What It Is

A daily agenda combining pending touches (📞) and open actions (🏃) in one DataBrowser view. Users see "what do I need to do next" without caring which model the item comes from.

## Architecture

**PostgreSQL VIEW** — not a Django model. The VIEW does the aggregation, DataBrowser queries it directly.

### Backend (DONE)

1. **VIEW created** via migration `apps/communications/migrations/0016_create_agenda_view.py`:
   ```sql
   CREATE VIEW agenda AS
     SELECT ... FROM touches WHERE dt_next > 0
     UNION ALL
     SELECT ... FROM actions WHERE dt_deadline > 0 AND status IN ('open','in_progress')
   ```
   - Common columns: id, source_model, source_id, icon, title, status, purpose, dt_due, dt_created, impact, direction, contact_id, org_id, org_model, logged_by, detail_text, is_active
   - `source_model` = 'touch' or 'action', `source_id` = original record ID
   - id = touch.id*2 or action.id*2+1 (no collisions)
   - 340 rows confirmed working: `SELECT count(*) FROM agenda` → 340

2. **Endpoint** `apps/core/views/view_query.py` → `GET /wcapi/view/?view=agenda`:
   - Registered in `apps/core/urls.py` as `wcapi-view-query`
   - Reads VIEW registry from Setting `wc-views` (ida=wc-views, #839)
   - Raw SQL with pagination (limit/offset), sort (sort/dir), keyword search, field filters (__gt, __lt, __gte, __lte, __in, eq)
   - Returns: `{ data: { results, count, total, limit, offset, view, columns, config } }`
   - Response wrapped in WC3 envelope: `{ status: "success", data: { ... } }`

3. **VIEW Registry** Setting `wc-views` (#839):
   ```json
   { "config": { "views": { "agenda": { "label": "Agenda", "columns": [...], "default_sort": "dt_due", "source_model_field": "source_model", "source_id_field": "source_id", "read_only": true } } } }
   ```

### Frontend (IN PROGRESS — needs fixing)

1. **useDataBrowser.ts** modified:
   - On model list load, fetches `wc-views` Setting and adds VIEW names to `modelNames`
   - VIEW configs cached in `window.__WC_VIEW_CONFIGS`
   - `fetchRecords`: when `isView` is true, fetches from `/wcapi/view/` instead of `getRecords`
   - Fields come from VIEW config columns, not `getModelDetail`

2. **Known Issues:**
   - Auth timing: `/wcapi/view/` endpoint requires auth. The `fetch()` call in useDataBrowser may fire before auth bootstrap completes (same issue as SelectListBrowser)
   - Solution: use `apiClient` instead of raw `fetch`, or wait for auth token
   - The VIEW fetch uses raw `window.fetch` — should use `apiClient` with auth headers
   - Date range picker not yet mapped to `dt_due__gte`/`dt_due__lte`
   - Detail pane click-through not yet implemented (need to read `source_model` + `source_id` from clicked row and open that model's detail)

3. **AgendaView.tsx** prototype at `/agenda` — standalone page that works but should be replaced by DataBrowser at `/databrowser?model=agenda`

### What to Fix

**Priority 1: Auth issue on VIEW fetch**
In `useDataBrowser.ts`, the VIEW path uses:
```typescript
const res = await fetch(`/wcapi/view/?${qs}`, { credentials: 'include' });
```
This may fail if auth token isn't in cookies. Replace with `apiClient.get()`:
```typescript
const res = await apiClient.get('/wcapi/view/', { params });
const payload = res.data?.data || res.data;
```
Note: `apiClient` has interceptors that may rewrite the URL. Test carefully.

**Priority 2: Detail pane click-through**
When user clicks a row in the agenda list:
- Read `row.source_model` ('touch' or 'action')
- Read `row.source_id` (original record ID)
- Load that model's detail component in the right pane
- Currently DataBrowser assumes the detail model = list model

**Priority 3: Date range**
DataBrowser sends `extraFilters` with date range. For VIEWs, map:
- `dt_created__gte` → `dt_due__gte`
- `dt_created__lte` → `dt_due__lte`
Or let the VIEW config specify which date field to use.

**Priority 4: Column widths**
VIEW config has column definitions with widths. These should feed into the DataBrowser's column sizing.

## Files

| File | What | Status |
|------|------|--------|
| `apps/communications/migrations/0016_create_agenda_view.py` | SQL VIEW | DONE |
| `apps/core/views/view_query.py` | ViewQueryView endpoint | DONE |
| `apps/core/urls.py` | Route `/wcapi/view/` | DONE |
| `readmes/topics/architecture/database-views.md` | Architecture readme | DONE |
| `React2025/src/hooks/useDataBrowser.ts` | VIEW detection + fetch | NEEDS FIX (auth) |
| `React2025/src/pages/admin/AgendaView.tsx` | Standalone prototype | WORKS (replace with DataBrowser) |
| `React2025/src/pages/admin/TouchBadge.tsx` | Badge reads dt_next | DONE |
| `React2025/src/pages/admin/TouchForm.tsx` | Unified touch entry | DONE |

## Testing

```bash
# Verify VIEW exists and has data
cd /Users/williamjames/Documents/CommerceExpert/webClerk3
source venv/bin/activate
python3 -c "
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'webclerk3_api.settings')
django.setup()
from django.db import connection
with connection.cursor() as c:
    c.execute('SELECT count(*) FROM agenda')
    print('Agenda rows:', c.fetchone()[0])
    c.execute('SELECT source_model, count(*) FROM agenda GROUP BY source_model')
    print('By source:', c.fetchall())
"

# Test endpoint (needs auth — use browser or curl with token)
# GET /wcapi/view/?view=agenda&limit=5&sort=dt_due&dir=asc
```

## Related Actions

| IDA | What | Status |
|-----|------|--------|
| TOUCH-ACTION-COMBINED-LIST #31210 | Daily agenda concept | In progress |
| TOUCH-CONSOLE-CARDS #31207 | dd-cards for action+touch counts | Backlog |
| ADMIN-CONSOLE-BUILD #31208 | Admin console page | Backlog |

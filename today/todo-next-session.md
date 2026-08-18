# TODO — Next Session Pickup

**Written:** 2026-08-18 end of marathon session (3 days)
**Context:** Touch model, SelectList architecture, PostgreSQL VIEWs in DataBrowser

## Priority 1 — Test and Fix

### Agenda VIEW click-through
- Code pushed but NOT tested: clicking a row in agenda VIEW should open source record (touch/action) in detail pane read-only
- File: `React2025/src/hooks/useDataBrowser.ts` (lines ~830-860) and `DataBrowser.tsx` (lines ~918-940)
- Uses `source_model` + `source_id` from VIEW row to fetch real record
- May need R25 restart to test

### SelectListBrowser auth timing
- `/selectlists` page header renders but data never loads
- Root cause: auth bootstrap not complete when useEffect fires
- The endpoint works (231 rows via console fetch)
- File: `React2025/src/pages/tools/SelectListBrowser.tsx`
- Fix: ensure auth token is available before fetching, or use apiClient properly

### Touch dt_next on first save
- `_compute_dt_next` runs after `super().save()` because CoreModel sets dt_created during save
- Uses secondary UPDATE query — works but not clean
- File: `apps/communications/models/touch.py` save() method

## Priority 2 — Build

### AdminConsole.tsx (#31208)
- Setting `admin-console` (#838) seeded with 29 functions, 7 categories
- Route exists at `/administration` (currently DDCardDashboard)
- Need: AdminConsole component reading from Setting, left pane = functions by category, right = opens route
- Review WC2 admin functions for completeness

### Action App detail view
- No `APP_DETAIL_COMPONENTS` entry for action model
- Needed for proper detail rendering in DataBrowser App mode
- Pattern: follow OrgDetail.json.tsx (header columns + tabs)

### Console dd-cards (#31207)
- Actions: Open / Due Today / Due Tomorrow / Due This Week
- Touches: Due Today / Due This Week / Overdue / Logged This Week

## Priority 3 — Future

### Touch reports (#31202, #31203, #31204)
- Sales efficiency: touches per $, channel conversion
- Customer health: silent customers, hot-but-cold, cold-but-gold
- Rep management: volume, response time, outbound/inbound ratio

### Touch templates (#31201)
- Pre-fill for repeat call patterns

### Touch → Action spawn (#31199)
- Button to create action from a touch

## Architecture Decisions (reference for new session)

1. **config.selectlists.\<field\>** = canonical path for all select lists
2. **refs.parents** = canonical lineage (from/to/contact/org/action)
3. **comments.process** = parent context text (no parent_id fields)
4. **PostgreSQL VIEWs** = first-class DataBrowser citizens, no Django model
5. **wc-views Setting** (#839) = VIEW registry
6. **ViewQueryView** at `/wcapi/view/` = raw SQL endpoint
7. **Save/Cancel at TOP** of all dialogs, actions top-to-bottom
8. **Badge IS the interface** — everything else on-demand
9. **Touch.plan** = integer N days, dt_next auto-computed
10. **Touch→Action→Transaction** = outward probe → inward commitment → evidence

## Key Files

```
WC3:
  apps/communications/models/touch.py
  apps/communications/migrations/0012-0016
  apps/core/views/view_query.py
  apps/core/views/selectlist_view.py
  readmes/topics/architecture/database-views.md
  readmes/topics/architecture/selectlist-architecture.md
  readmes/68-touch-model.md

React:
  src/pages/admin/TouchForm.tsx
  src/pages/admin/TouchBadge.tsx
  src/pages/admin/TouchBar.tsx
  src/pages/admin/AgendaView.tsx
  src/pages/tools/SelectListBrowser.tsx
  src/hooks/useDataBrowser.ts
  src/pages/admin/DataBrowser.tsx
  src/layout/AppSidebar.tsx
```

# Handoff — 2026-08-13

## What Happened

System crashed mid-session. PostgreSQL had a stale PID file (PID 994 was Clock widget, not Postgres). Recovered database, but machine remained unstable — load avg 10+, zombie vite build processes, Django hanging on migration autodetector. Mac restart recommended before next session.

## What Was Accomplished

### 1. Crash Recovery & Team Memory Cleanup
- Fixed PostgreSQL: removed stale PID, restarted, crash recovery ran automatically
- **Archived 9 empty crash-orphan session documents** (IDs 1382-1390) in WC3 — all were leftshoe handshakes with no content, spanning 08-10 through 08-13
- **Recovered tm-955** interrupted session content → created WC3 document **tm-1391** (Andi device manager, Celery fixes, scar #38, 8 commits from 08-07)

### 2. App View Font Scaling (React2025)
**File:** `src/pages/admin/DataBrowser.tsx`
- Line ~1460: Added `--db-font-size` CSS variable on `.db-root`
- Line ~1878: Added `zoom: baseFontSize / 20` on `.db-detail-pane` when in App mode
- This scales the entire App detail view proportionally when the Font selector changes
- Font:10 = 50%, Font:12 = 60%, Font:14 = 70%, Font:18 = 90%
- **Status: Code saved, needs testing after build**

### 3. Gantt Independent Zoom (React2025)
Separated Gantt scaling from the Font selector. Three files changed:

**`src/apps/utils/gantt/UnifiedGanttPage.tsx`** — Complete rewrite:
- Own +/− zoom control at top of page (not scaled by zoom)
- Default scale: 50% (persisted in localStorage as `wc3_gantt_scale`)
- Range: 30% to 150%, step 10%
- Passes `chartZoom` prop to UnifiedGantt
- Container fills `calc(100vh-2rem)`

**`src/apps/utils/gantt/UnifiedGantt.tsx`**:
- Added `chartZoom` prop to `UnifiedGanttProps` interface
- Destructured in component with default `chartZoom = 1`
- Applied as CSS `zoom` on `DualScrollbar` (chart+list area only — toolbar excluded)

**`src/components/common/DualScrollbar.tsx`**:
- Added `style` prop to interface and component
- Passes `style` to outer wrapper div

**Status: Code saved, hot reload available on dev server, production build NOT completed**

### 4. What Bill Wants for Gantt (from screenshots)
- **Toolbar at ~80%** — natural size, NOT scaled by zoom
- **Chart+list at 40%** — small, dense, shows full timeline
- **Fill the whole window** — no empty white space at bottom
- Current code does all three via the `chartZoom` prop approach

## What Needs to Happen Next Session

### Immediate (before any new work)
1. **Restart Mac** — machine is unstable post-crash
2. **After restart:** `cd ~/Documents/CommerceExpert/webClerk3 && ./runserver.sh`
3. **Production build:** `cd ~/Documents/CommerceExpert/React2025 && npm run build`
4. **Deploy:** `cp -r dist/* ~/Documents/CommerceExpert/webClerk3/media/static/`
5. **Test Gantt zoom** — hard refresh, try +/− buttons, verify toolbar stays normal size
6. **Test App view font** — switch Font:10/12/14/18 on an Order in App view

### If Django still hangs after restart
Try: `venv/bin/python manage.py runserver --skip-checks --noreload`
The migration autodetector was hanging — `--skip-checks` bypasses it.

### Reports (deferred)
Bill wanted to work on reports (touch and feel of printed reports). Didn't get to it. The print system has 12+ document types in `React2025/src/apps/transactions/components/print/`. Start by asking Bill what specifically needs to change.

## Files Changed (not committed)

### React2025 (4 files)
- `src/pages/admin/DataBrowser.tsx` — font zoom on detail pane
- `src/apps/utils/gantt/UnifiedGanttPage.tsx` — independent Gantt zoom
- `src/apps/utils/gantt/UnifiedGantt.tsx` — chartZoom prop
- `src/components/common/DualScrollbar.tsx` — style prop

### WC3 Database
- Documents 1382-1390: `is_archived = true`
- Document 1391: created (recovered tm-955 content)

## Key Decisions
- **Zoom not transform** for Gantt — CSS `zoom` on DualScrollbar, not `transform: scale()`, because zoom adjusts layout flow
- **Separate controls** — Font selector for list/detail, independent +/− for Gantt
- **Gantt default 50%** — Bill wants it small and dense by default
- **baseFontSize / 20** for App view — maps Font:10 to 50% zoom

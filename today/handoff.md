# Handoff — 2026-08-13

## Where We Left Off

Major infrastructure + architecture session. WC3 wouldn't start — root cause was 99% disk full (13GB free on 926GB) causing macOS I/O saturation from Apple services (fileproviderd, knowledgeconstructiond, mds_stores) all fighting over the filesystem at boot. Freed ~145GB by moving media/archives to Andi 5TB (`/mnt/allie-5tb/bill_large_bk/`, 95GB verified) and deleting Docker.raw (60GB, Docker not even installed). Built `DbColumns` as the single base list component — all lists inherit from this. Created consolidated `CommPanel` (one table replacing four separate EMAIL/PHONE/ADDRESS/DOMAIN sections). Seeded Rule of 4 demo cast (qq_1 through qq_5) and item hierarchy (qq_100/200/300 with BOM). Created full order→PO transaction flow with BOM Level 2 explosion. Fixed `Pending.changes` bug in `line_item_service.py`.

## Do This First Next Session

1. **Create 4 is_staff qq_ contacts with 4 actions each** — actions linked to qq_SO-001 and qq_PO-001 via refs.links. Staff need data in their dashboards. Bill requested this before session ended.
2. **Build dash-card component** — clicking an action row in dashboard shows linked transaction data in a card, clickable to open transaction in new window. Not yet built.
3. **Convert remaining panels to DbColumns/--db-* theme** — MetadataPanel, FinancialsPanel, ProjectGanttPanel, ProjectKanbanPanel still use Tailwind `dark:` classes and hard-coded colors. Must use `--db-*` CSS variables exclusively.
4. **Fix ThemeContext.tsx** — currently hard-coded to light-only (`toggleTheme` is a no-op). Must support actual dark/light toggle synced with `data-theme` attributes.
5. **Mount Andi SMB share** — `smb://andi@192.168.1.114/allie-5tb` for persistent access to archived files. Bill agreed to Option A (SMB mount + symlinks). Not yet mounted — needs password entry in Finder.

## Open Problems

- **Documents FK leaking** — DocumentsPanel shows all documents on every contact because docs connect via `refs.links.contacts` (JSON array) and the panel may not be filtering. Seeded 4 docs per qq_ contact to test visually.
- **iCloud + Google Drive fight** — both watch overlapping files via `fileproviderd`, causing I/O storms at boot. Recommended domain separation (iCloud = working files, Google Drive = JPods history, Andi = cold archive). Not yet implemented.
- **Allie API down** — `allie-api.py` not running. MCP works. API needs manual start.
- **jpods.library_2026-07-29.zip** — transferred to Andi (11G verified), deleted locally. If needed, rsync back from `andi:/mnt/allie-5tb/bill_large_bk/`.
- **PanelTable is now a thin re-export** of DbColumns. Existing imports work but should migrate to `DbColumns` directly over time.

## What Was Decided (and Why)

- **DbColumns is the single base list component** — all lists (DataBrowser grid, panels, comm lists) inherit from this. DbList extends by adding toolbar. Reason: three different styling systems (--db-* variables, Tailwind dark:, hard-coded hex) were causing theme inconsistency. One component, one CSS system.
- **Consolidated CommPanel** — one flat table (TYPE | VALUE | NAME) instead of four separate sections. Reason: Bill wanted uniform db.list treatment. Address rows can be taller for multi-line. Card-style rendering left as future option via `renderRow` prop.
- **Rule of 4 for demo/training data** — exactly 4 child records per parent per type. Two parents minimum. Reason: 1-2 records can pass by accident; 4 is verifiable at a glance without counting; more than 4 requires counting.
- **qq_ ida prefix for demo cast** — easy to find, filter, and remember for trainees. qq_1xx = primary items, qq_2xx = BOM sub-assemblies, qq_3xx = BOM components.
- **Documents linked via refs.links, not FK** — Bill confirmed this is the right pattern. Bidirectional: doc.refs.links.contacts and contact.refs.links.document.
- **Andi 5TB is cold archive, not a mirror** — files moved there are deleted locally. SMB mount provides access when needed.

## Files Changed This Session

- `React2025/src/apps/common/components/panels/DbColumns.tsx` — NEW: single base list component with section headers, column config, theme-aware CSS
- `React2025/src/apps/common/components/panels/PanelTable.tsx` — now re-exports DbColumns for backward compatibility
- `React2025/src/apps/common/components/panels/index.ts` — added DbColumns exports
- `React2025/src/apps/communications/components/CommPanel.tsx` — rewritten: consolidated table replacing four-section layout
- `React2025/src/apps/communications/components/CommList.tsx` — updated to use --db-* CSS variables (may be superseded by CommPanel rewrite)
- `React2025/src/apps/communications/components/CommCard.tsx` — updated to use --db-* CSS variables (may be superseded by CommPanel rewrite)
- `React2025/src/pages/admin/DataBrowser.css` — added common list CSS classes (db-section-header, db-list-header, db-list-row, db-list-empty)
- `webClerk3/apps/transactions/services/line_item_service.py` — fixed bug: `Pending.data` → `Pending.changes` (3 instances); restored `trace_pending_created(data=...)` call
- `webClerk3/tools/seed_demo_cast.py` — NEW: idempotent seed script for Rule of 4 demo cast (qq_1–qq_5, companies, comms, docs)

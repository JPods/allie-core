# Handoff — 2026-08-24 (Session 3: Project Planning + Gantt + CSS)

## Where We Left Off

Major session — project planning ecosystem built from scratch, Gantt features added to WC3, CSS theme unified, Project Scanner deployed to webclerk.com/project_planner/.

## What Was Done

### Project Planning Ecosystem
- **Due Diligence bundle.json** — 23 actions, 6 sections, template #1 for capital raises
- **ISO 9001 bundle.json** — 25 actions, Gordy nuclear-grade quality manual discipline, 4-phase implementation
- **JPods Build bundle.json** — 104 actions, 13 sub-projects transcribed from 2009 diagram image, dependency chains, critical path
- **Project plan library** — 18 templates listed at project-plan-library.md, 3 done, 15 planned
- **13 individual SVGs** for JPods Build sub-projects + 1 combined overview
- All bundles at ~/Allie/knowledge/projects/

### Project Scanner Tool
- **planner.py** — Statement Sorter pattern, CSV/XLSX → bundle.json + SVG + clean CSV, port 8878
- **index.html** — pure browser version, SheetJS for XLSX, no server upload, localStorage state
- **Deployed** to webclerk.com/project_planner/ — nginx location block on Andi, /var/www/webclerk-static/project_planner/
- Nginx gotcha: sites-enabled was a copy not a symlink — had to copy after editing sites-available

### WC3 Gantt + Dependencies + Critical Path
- **ProjectActionGantt.tsx** — new component, action bars on timeline, SVG dependency arrows, forward/backward pass critical path calculation, slack display, critical-only filter
- **ActionsPanel.tsx** — added "depends" column (←dep badges) and "path" column (CP badge + slack days)
- **panelRegistry.tsx** — gantt panel renders ProjectActionGantt for projects, ProjectGanttPanel for contacts
- **DEFAULT_TABS** — project gets Actions/Gantt/Documents/Notes tabs automatically

### CSS Theme Unification
- **theme.css** — NEW single source of truth for all --db-* variables at :root scope (light + dark), including standardized buttons
- Removed duplicate --db-* from DataBrowser.css, CommerceDashboard.css, JsonViewer.css
- --wc-* aliased to --db-* for backward compat (48 refs still to migrate)
- DataGrid.css — explicit background on .dg-row fixes transparent row bleed-through

### Backend Fixes
- **aggregation.py** — NameError: 6 bare model name @receivers replaced with dynamic ALL_MODELS loop
- **line_views.py** — import from models.projects → models.project (typo)

### Documentation
- **project-management-comparison.md** — WC3 vs MS Project/Smartsheet/Asana/Trello, transaction models, commerce chain

## What Needs Doing Next

### Deploy
- [ ] Rsync React dist to Andi + restart Gunicorn
- [ ] Run seed_detail_layouts --model project on Andi
- [ ] Verify Gantt tab appears on MOA project

### CSS Migration TODO
- [ ] Migrate 48 --wc-* references to --db-* (5 files), then remove aliases

### Bill's Feedback (Not Yet Applied)
- Tab labels should come from Setting .config.select_lists, not hardcoded
- Unified CSS audit needed across all db.list, db.panel, db.card components

### Project Scanner Enhancements
- Mind map import (FreeMind, XMind, OPML)
- PDF parsing
- Direct WC3 import via wcapi

## Files Changed
- See session log for complete list (14 WC3 files changed, 17 Allie files created)

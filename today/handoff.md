# Handoff — 2026-07-30

## Where We Left Off
Massive session: Gantt chart overhaul (9 enhancements + toolbar consolidation + project settings + sprint lines + side panel detail), sync app built and tested (Mac ↔ Andi encrypted bundle exchange working), `config` moved from ConfigMixin to CoreModel, field size discipline established, Kanban fixed (`assigned_to` type crash + URL param loading). All pushed to git. Last commit `bb516fce` on React2025 `bill_dev`, `eab66e6` on webClerk3 `bill_dev`.

## Do This First Next Session
1. **Push React2025 + WC3 changes to Andi** — sync code is on Andi but React/Gantt changes are not. Run `allie-andi-sync.sh` or rsync the React build.
2. **Fix Gantt bar drag behavior** — Bill reported "odd dragging longer behavior." Investigate SVAR pointer event interaction with custom taskTemplate. The `pointerEvents: none` on outer div may need refinement.
3. **Test Gantt double-click → ActionDetail side panel** — verify it loads the record, displays correctly, and closing returns to Gantt.
4. **Set up Celery Beat on Andi** — the `process_pending` task exists but Beat isn't configured. Add to `CELERY_BEAT_SCHEDULE` in settings.
5. **Tighten ActionDetail.tsx further** — Arabic/Bengali fields show for all users. Should collapse or hide unless the project uses those languages.

## Open Problems
- Gantt bar drag resize has quirky behavior — may be pointer event conflict with custom template
- SVG export needs testing with the new rich bars
- `assigned_to` field on Action is inconsistent (string vs array vs integer) — needs backend normalization
- Hostinger VPS at `85.31.234.194` has dead references in code (old server, not in Bill's account)
- 180+ Pending records with `purpose=None` accumulating — need cleanup or a handler
- `useDataBrowser.ts` had duplicate keys (fixed) — may indicate deeper copy-paste issues

## What Was Decided (and Why)
- **`config` moved to CoreModel, not just BaseModel** — Pending needs config but stays on CoreModel for performance. Every model gets config through inheritance. ConfigMixin is now dead code.
- **Gantt is a view, not data entry** — removed PageBreadcrumb toolbar (add/delete buttons). Record creation belongs in Kanban sprints.
- **Pending is the universal work queue** — Celery dispatches by `purpose` string. `dt_processed=0` means not done. No expiry — only admin closes pending records.
- **Sync: one Connection, one key, bidirectional** — Mac ↔ Andi share a single Connection record. Either side can send/receive through it.
- **Sync: rsync now, Bundle at launch** — Mac→Andi via rsync (Bill controls timing). Andi→Mac will switch to WC3 Bundle model at go-live to dogfood the product.
- **Sync test protocol** — standard `test=true, echo="handshake"` message. Alice coaches users through it on new connections.
- **Field size principle** — no large data inline. Above 64KB → Document record. Alice enforces at write boundary, learns to preempt for known-large content types.
- **Print must match screen richness** — all output modes (print, SVG, JSON) carry the full visual encoding (priority/status stripes, badges, slippage).
- **Project-level Gantt settings** — stored in `project.metadata.kanban`. Admin can pin a default view. Sprint boundary day is per-project.
- **Shift-click = power user action** — Shift-click project in Gantt opens Kanban in new window. Shift-click gear opens admin toolbox.

## Files Changed This Session

### React2025 (bill_dev)
- `src/apps/utils/gantt/UnifiedGantt.tsx` — Rich print bars, milestones, baseline slippage, CP highlight, assignee filter, project settings, sprint lines, admin toolbox, side panel detail, toolbar consolidation, JSON export, SVG rewrite
- `src/apps/utils/gantt/GanttTaskTemplate.tsx` — Black text, milestone diamonds, slippage badges, dimming for CP/assignee, double-click → detail panel, pointer events split for SVAR drag
- `src/apps/utils/gantt/GanttProjectSelector.tsx` — Top-level/sub-project toggle, Shift-click → Kanban, persist showAllLevels
- `src/apps/utils/gantt/UnifiedGanttPage.tsx` — Removed list toolbar, simple breadcrumb nav
- `src/apps/utils/kanban/KanbanBoardPage.tsx` — URL param project selection, isLoadingProjects in effect deps, contacts fetch guard
- `src/apps/utils/kanban/kanbanDataMapper.ts` — Fixed assigned_to crash (string vs array)
- `src/apps/core/models/action/pages/ActionDetail.tsx` — Fetch by ID prop/URL param, removed duplicate ScalarCard, actionId prop
- `src/hooks/useDataBrowser.ts` — Removed duplicate keys

### webClerk3 (bill_dev)
- `common/models.py` — config moved to CoreModel, MAX_CONFIG_SIZE, check_size for config
- `apps/core/models/pending.py` — Added sequence, attempts, changes fields; removed local config
- `apps/sync/models/bundle.py` — Removed local config, added dt_processed
- `apps/sync/models/connection.py` — Removed local config
- `apps/sync/views/bundle_sync.py` — NEW: receive endpoint with idempotency, encryption, sequence
- `apps/sync/services/bundle_send.py` — NEW: send handler with Fernet encryption, retry logging
- `apps/sync/services/bundle_crypto.py` — NEW: Fernet encryption, large payload → file + key
- `apps/sync/services/pending_processor.py` — NEW: purpose-dispatched processor, batch limit 50
- `apps/sync/tasks.py` — NEW: Celery task for hourly pending processing
- `apps/sync/urls.py` — Reconnected Connection views + receive endpoint
- `apps/sync/management/commands/sync_setup.py` — NEW: connect, test, process, status commands
- `apps/ai_assistant/models_alice.py` — Removed local config declaration
- `webclerk3_api/urls.py` — Added sync URLs
- `webclerk3_api/settings.py` — ALLOWED_HOSTS wildcard for dev
- `readmes/topics/sync/sync-test-protocol.md` — NEW: sync test protocol for Alice coaching
- `readmes/topics/ai/alice-field-size-discipline.md` — NEW: field size discipline doc

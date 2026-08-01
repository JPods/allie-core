# Handoff — 2026-07-31

## Where We Left Off
Massive 2-day session. Built: Gantt overhaul (20+ enhancements), sync app (Mac↔Andi encrypted), webclerk.com live on Cloudflare, widget library (10 widgets, screen+print), DynamicDetail (data-driven forms with arrange mode), Settings hierarchy (user→role→org→system), Report-as-form (layout JSON in database), sprint burndown (calc + chart), session guard (live rule enforcement), file storage protocol, reload cost principle, agent action protocol, ContactCard popup, ActionFloatingWindow, Fibonacci difficulty scale.

Last thing done: planned the Big 5 transaction form conversion strategy. The approach is bottom-up: convert individual cards to db.list/DynamicDetail first, then assemble.

## Do This First Next Session
1. **Convert LinesCard to db.list** — `src/apps/transactions/components/LinesCard.tsx` (901 lines). This is the hardest card — inline editing, add/delete, drag reorder, calculated fields (qty × price). If db.list handles this, everything else follows. Test with Order first.
2. **Convert SummaryCard to DynamicDetail** — `src/apps/transactions/components/SummaryCard.tsx` (782 lines). Header fields driven by widget registry + layout JSON. Test with Order.
3. **Test each conversion** against the existing OrderDetail to verify logic is preserved.
4. **Deploy React build to Andi** — run `npm run build` on Andi + fix permissions after. The landing page and React app are working but need the latest code.
5. **Start session guard at leftshoe** — `python3 ~/Allie/scripts/allie-session-guard.py &` is now part of the briefing script.

## Open Problems
- Gantt bar drag behavior quirky — SVAR pointer event conflict with custom template
- Sprint boundary lines visible on Week scale but disappear at Month/Quarter — highlightTime unit issue
- Gantt sticky headers CSS may not work with SVAR's internal scroll container
- ActionDetailCompact data loading — getRecord response structure needs consistent unwrapping
- 90 `.ts` files containing JSX need renaming to `.tsx` (session guard found them)
- 25 model components in wrong locations (session guard found them)
- webclerk.com password for bill.james@jpods.com is `cGnyH3ilRpSpq8ir22Q1CA` — needs password change UI (action created, due 4 weeks)
- Old VPS references (85.31.234.194) still in settings.py — clean up

## What Was Decided (and Why)

### Architecture
- **config on CoreModel** — every model gets it. Pending stays lite. ConfigMixin is dead code.
- **Settings hierarchy: user→role→org→system** — resolver walks the chain, first match wins. Replaces flat name+purpose lookup.
- **Forms stored as Report records** — output_type="screen", category="form". Same model for print and screen. No separate form model.
- **Widget library at src/components/widgets/** — not model-specific, not common UI. Field-level rendering. Screen + print modes from one component.
- **DynamicDetail + arrange mode** — layout JSON in Report record. Users drag to rearrange. ⚙ toggles arrange mode.
- **File storage: /media/<org_id>/<model>/<record_id>/<filename>** — path IS metadata. Tenant isolation by directory.
- **Image schema: tn(64), sm(128), md(256), lg(512), original** — Pydantic schemas at common/schemas/images.py.

### Gantt/Kanban
- **Gantt is a view, not data entry** — removed toolbar. You gain retrospection from Gantt. You plan and work in sprints.
- **Shift-click project → opens Kanban** in new window. Two screens, one dataset.
- **Double-click bar → floating detail window** — draggable, resizable, doesn't cover workspace.
- **Project-level settings** in project.metadata.kanban — admin can pin default view + sprint boundaries.
- **Sprint lines from task deadlines** — not fixed weekday. Variable-length sprints supported.
- **Fibonacci difficulty: 1, 4, 8, 13, 21** — Easy, Average, Hard, Complex, Expert. Burndown weights by difficulty.

### Sync
- **One Connection, one key, bidirectional** — Mac↔Andi share a single Connection record.
- **Pending is the universal work queue** — purpose dispatches to handler. dt_processed=0 = not done. No expiry.
- **Encryption: Fernet AES-128-CBC** — payload encrypted with connection key. Large files → encrypted document + path/key.
- **Idempotency: pending.uuid** sent with every bundle. Receiver deduplicates.
- **rsync now, Bundle at launch** — Mac→Andi via rsync. Andi→Mac switches to WC3 Bundle model at go-live.

### Team Protocols
- **Reload cost** — "Is it in our heads? If yes, suffer now. If speculative, add to an action." Rebuilding context is extremely expensive.
- **Agent action protocol** — every agent creates action records for observations. No waiting to be asked.
- **Session guard** — file watcher enforces model path structure, JSX extensions, config declarations. Part of leftshoe.
- **Alice TSX archive** — when a .tsx is replaced, archive the old version. Alice studies the delta.
- **Field size discipline** — no large data inline. Above 64KB → Document record. Alice enforces at write boundary.

### Big 5 Conversion Strategy (next session)
- **Bottom-up, not top-down** — convert cards first, assemble forms second.
- **LinesCard → db.list first** — hardest card, most reuse. If this works, everything works.
- **SummaryCard → DynamicDetail second** — header fields via widget registry.
- **Each card one by one** — shipping, payments, actions, QA, comments.
- **Big 5 are layout JSON** once cards are converted — Order/Invoice/PO/Proposal are configurations, not code.
- **Collapsible sections** — replaces WC2 numbered pages. User's collapsed state saved per-user via Settings.

## Files Changed This Session

### webClerk3 (bill_dev)
- `common/models.py` — config on CoreModel, MAX_CONFIG_SIZE, check_size
- `apps/core/models/setting.py` — scope, org_id, contact_id for hierarchy
- `apps/core/models/action.py` — Fibonacci difficulty default=4
- `apps/core/models/pending.py` — sequence, attempts, changes
- `apps/core/models/report.py` — screen/form output types
- `apps/core/choices.py` — scope choices, organized purposes, Fibonacci difficulty
- `apps/core/services/burndown.py` — NEW: sprint burndown calculation
- `apps/core/services/setting_resolver.py` — NEW: scope hierarchy resolver
- `apps/core/services/file_storage.py` — NEW: image resize, document save, orphan detection
- `apps/core/views/burndown_view.py` — NEW: /wcapi/burndown/<id>/
- `apps/core/views/setting_resolve_view.py` — NEW: /wcapi/setting/resolve/
- `apps/sync/` — complete sync app: send, receive, crypto, pending processor, tasks, urls
- `common/schemas/images.py` — NEW: ImageSet, ContactImages, OrgImages, ItemImages
- `readmes/settings.md` — complete rewrite with hierarchy docs
- `readmes/topics/agile/reload-cost.md` — NEW
- `readmes/topics/agile/agent-action-protocol.md` — NEW
- `readmes/topics/ai/alice-file-storage.md` — NEW
- `readmes/topics/ai/alice-field-size-discipline.md` — NEW
- `readmes/topics/ai/alice-tsx-archive.md` — NEW
- `readmes/topics/architecture/file-storage-protocol.md` — NEW
- `readmes/topics/sync/sync-test-protocol.md` — NEW

### React2025 (bill_dev)
- `src/components/widgets/` — NEW: 10 widgets + types + registry
- `src/components/common/DynamicDetail.tsx` — NEW: data-driven form renderer
- `src/apps/core/models/action/pages/ActionDetailCompact.tsx` — NEW
- `src/apps/core/models/action/pages/ActionFloatingWindow.tsx` — NEW
- `src/apps/core/models/action/pages/SprintBurndown.tsx` — NEW
- `src/apps/core/models/contact/pages/ContactCard.tsx` — NEW
- `src/apps/utils/gantt/UnifiedGantt.tsx` — massive changes (sprint lines, admin toolbox, compact toolbar, project settings, side panel, etc.)
- `src/apps/utils/gantt/GanttTaskTemplate.tsx` — milestones, slippage, dimming, double-click
- `src/apps/utils/gantt/GanttProjectSelector.tsx` — top-level toggle, Shift-click Kanban
- `src/apps/utils/gantt/UnifiedGanttPage.tsx` — removed toolbar, simple breadcrumb
- `src/apps/utils/kanban/KanbanBoardPage.tsx` — URL param loading, contacts fetch fix
- `src/apps/utils/kanban/kanbanDataMapper.ts` — assigned_to type fix
- `src/App.tsx` — small screen warning instead of block
- `src/routes/Router.tsx` — basename from VITE_BASE_PATH
- `src/components/fields/index.ts → index.tsx` — JSX extension fix
- `vite.config.ts` — VITE_BASE_PATH support

### Allie
- `scripts/allie-session-guard.py` — NEW: live file watcher, rule enforcement
- `scripts/claude-identity-store.py` — guard starts at leftshoe briefing
- `readmes/leftshoe.md` — guard is part of leftshoe
- `readmes/wisdom/reload-cost.md` — NEW
- `today/handoff.md` — this file

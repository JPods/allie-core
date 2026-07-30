# Handoff — 2026-07-29

## Where We Left Off
Machine load hit 131 (Finder, Time Machine, iconservicesagent stuck in loops after 5 days uptime). Bill is rebooting. Vite build was running but crawling under load. All code changes are saved — the Gantt enhancements (font scaling, text overflow, meeting-friendly clicks, project hierarchy cascade), AliceInsight model, login redirect fix, and DevTools reload loop fix are all in source. Migrations applied: `ai_assistant.0006_add_alice_insight`, `core.0021` (action.task→action.action rename), `transactions.0013_project_timeline_hierarchy` (fake-applied). Open-source example files written at `React2025/src/apps/utils/gantt/open-source-example/`.

## Do This First Next Session
1. **Run `vite build`** in React2025 — the last build was interrupted by machine load. All Gantt, login, and DevTools fixes need a clean build to deploy.
2. **Test login** — `bill.james@jpods.com` / `leftshoe` should now redirect to `/dashboard` after sign-in (`SignInForm.tsx` got `navigate(PageRoutes.dashboard)`).
3. **Test Gantt parent cascade** — click MOA in project selector, verify all 10 weekly sprints auto-select. Requires `id_parent` in API response (confirmed working via curl).
4. **Test Gantt interactions** — A+/A- should scale text inside bars (not just row height). Single click = 5s blue outline. Double click = open detail. "Show full text" checkbox.
5. **Disable Chrome extensions** — AI Chat for Search, Mailtrack, Quillbot, Google Meet Tweak (policy violation). These were burning 40%+ CPU. Also killed 5KPlayer (remove from Login Items).

## Open Problems
- DevTools Local/Remote badge — the switch mechanism calls `switch-dataset.sh` which may not work correctly; the reload loop is fixed but actual switching to Andi untested
- AuditLog user_agent NOT NULL — shell operations trigger audit signals without user_agent (non-fatal noise)
- dt_kanban on Project is DateTimeField — should be BigIntegerField (epoch ms); Action #31055
- Celery worker (PID 92290) was at 71% CPU for 5 hours — may restart in a stuck loop after reboot; investigate
- Build taking long — 68 minutes under load; should be ~18s on clean machine; verify after reboot
- `save_wcui_prefs` manage action not yet implemented on backend — wcuiPrefs.ts calls it but it may 404

## What Was Decided (and Why)
- **AliceInsight extends BaseModel not CoreModel** — Bill said "CoreModel and BaseModel" — needs full MCP envelope (metadata, config, refs, pending, status) for sync via Connection+Bundle between installations and WC_HQ
- **Agent field is open CharField, no choices constraint** — Bill: "Users may add other agents besides Alice and Athena." Agents self-register by writing insight records.
- **AliceInsight is per-agent per-contact per-subject, not one-per-user** — Bill: "It should have a record per user, per model, per transaction flow, per sync." Unique together on (agent, contact, subject_type, subject_key).
- **Single click = emphasis, double click = open detail** — Bill: "when users are talking with their hands and click a tag to emphasize it, they do not open the detail.tsx"
- **No font size limits** — Bill: "Users have reasons to change font size." No caps on A+/A- increments.
- **CSS custom properties cross SVAR component boundary** — Key technique: `--gantt-text-overflow` and font size set on container div, read inside SVAR's rendered DOM via `var()` and `inherit`. No fork needed.
- **Open-source the Gantt enhancements** — Bill wants trading partners to use these. Standalone example files created. ERP bridge pattern documented (install WC3 as display layer, sync from ERP).

## Files Changed This Session
- `React2025/src/apps/utils/gantt/GanttTaskTemplate.tsx` — Layered task bar; relative font sizes (em/inherit); click emphasis; hover tooltip; CSS variable overflow
- `React2025/src/apps/utils/gantt/UnifiedGantt.tsx` — A+/A- controls; text overflow checkbox; color mode priority colors fixed; frozen rows; double-click only for detail; ganttFontScale persisted to wcuiPrefs
- `React2025/src/apps/utils/gantt/GanttProjectSelector.tsx` — id_parent field; cascade selection; ▸/└ visual hierarchy
- `React2025/src/apps/utils/gantt/useGanttData.ts` — parseProjectOption extracts id_parent from API
- `React2025/src/apps/utils/gantt/open-source-example/` — 4 standalone files for open-source distribution
- `React2025/src/apps/utils/gantt/README-GANTT-ENHANCEMENTS.md` — Documents all enhancements
- `React2025/src/components/auth/SignInForm.tsx` — Added navigate(dashboard) after login success
- `React2025/src/components/DevTools.tsx` — Removed waitForServerAndReload (caused page reload loop)
- `webClerk3/apps/ai_assistant/models_alice.py` — AliceInsight model (BaseModel, multi-agent, multi-subject)
- `webClerk3/apps/ai_assistant/models.py` — Import AliceInsight
- `webClerk3/apps/transactions/models/project.py` — Added dt_start, dt_end, id_parent (FK self), percent_complete

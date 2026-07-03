# Handoff — 2026-07-03

## Where We Stopped
Layout save persistence — the architecture is built (Pending record → Celery → Setting) but POSTs to /wcapi/save/ were getting 403 due to auth token not being captured after login. Chrome DevTools MCP just installed to diagnose directly.

## CRITICAL: Auth Token Issue
- Login works (curl proves it returns valid JWT)
- But `getAccessToken()` returns `undefined` in the browser
- User was using wrong password (`pass1111` instead of `1111pass` for 3@3.com)
- Even after correct login, token may not persist in memory across page navigations
- This blocks ALL POST requests — not just layout saves
- **Next step:** Use Chrome DevTools MCP to inspect network requests directly

## DB-BUG-01 Root Cause — FOUND AND FIXED
`save_view.py` line 324: `resolve('setting')` returns model CLASS not ModelMeta. Old code called `meta.import_model()` → AttributeError → caught silently → `has_data_field` stayed False → data dict merged into payload → layout data went to `prefs.userdefined` instead of `data`. Fix: check `hasattr(resolved, 'import_model')` before calling.

## Layout Save Architecture (Built, Needs Auth Fix)

### Flow
1. React `persistSetting()` creates a NEW `Pending` record via `/wcapi/save/`
2. Pending: `model_name='setting'`, `purpose='layout_change'`, `data.view={list, detail, views}`
3. Celery Beat (every 10s) runs `apply_pending_layouts_task()`
4. Task reads unprocessed Pending records, applies `data.view` to Setting, marks processed
5. UI updates immediately (optimistic) — user sees changes before celery applies

### Why Pending
- No lock conflicts (always creates NEW record)
- Audit trail (every change is a record)
- FIFO serialization (no race conditions)
- Same pattern as PendingInventoryAdjustment and PendingPaymentApplication

## What Was Built Today

### DataBrowser — wc2 listboxK Port
1. FieldSpec enhanced — minWidth, maxWidth, wrap, phone/masked formats, smart defaults (getDefaultFieldSpec)
2. Right-click column header context menu — Delete/Add Column, Save Layout, Save As New, view switching
3. Cell formatting — currency, percent, date, phone, number via FieldSpec.format
4. Multilingual object display — extracts user's language from JSON objects
5. Seed with FieldSpec objects — 65 models re-seeded
6. Resize handles permanently visible
7. Shift-click "Layouts #NNN" opens raw Setting JSON for inspection
8. Setting model now visible in DataBrowser (was explicitly excluded)

### Console Capture for Alice
- consoleCapture.start() at app boot in main.tsx
- Auto-flushes errors/warnings to alice_observation every 60s
- Documented in Alice and Allie readmes

### Infrastructure
- chromadb + psycopg2 installed in ~/Allie/venv
- Chrome DevTools MCP installed for Claude Code
- Action #336: LIST-UX-01 — end-user list behaviors, deadline 2026-07-17

### Cleanup
- 41 orphan settings (parent_model=None) deleted
- 9 sync_bundle duplicates removed
- 4 settings with prefs.userdefined pollution cleaned
- Setting exclusion from model_name/list endpoint removed

## Key Decisions
- Auto-save is a user preference, not forced (Bill: "perhaps auto save should be a choice")
- Protected views: alice_guess, alphabetical cannot be overwritten
- A view does not need both list and detail
- action.action (multilingual title) vs action.actions (BaseModel next-step metadata) — NOT duplicates, keep both
- Pending record decoupling pattern for any contested writes

## Files Changed
- `React2025/src/hooks/useDataBrowser.ts` — FieldSpec, persistSetting via Pending, smart defaults
- `React2025/src/components/common/DataGrid.tsx` — context menu, formatting, resize handles, fieldSpecs
- `React2025/src/components/common/FieldOrderDialog.tsx` — normalize FieldSpec to strings on load
- `React2025/src/pages/admin/AdminWorkbench.tsx` — wiring, fieldSpecsMap, shift-click inspect
- `React2025/src/utils/consoleCapture.ts` — auto-flush, getReport
- `React2025/src/main.tsx` — consoleCapture.start()
- `webClerk3/apps/core/views/save_view.py` — resolve() fix, diagnostic logging
- `webClerk3/apps/core/views/wcapi.py` — removed setting exclusion from model list
- `webClerk3/apps/core/views/manage_view.py` — save_layout_pending action
- `webClerk3/apps/core/management/commands/seed_alice_layouts.py` — FieldSpec generation
- `webClerk3/apps/ai_assistant/tasks.py` — apply_pending_layouts_task
- `webClerk3/apps/ai_assistant/services/layout_pending.py` — layout pending service
- `webClerk3/webclerk3_api/settings.py` — celery beat schedule
- `webClerk3/readmes/topics/architecture/layout-save-flow.md` — full documentation
- `webClerk3/readmes/topics/ai/setup-guide-Alice.md` — console capture docs
- `~/Allie/readmes/agents/allie.md` — console capture interface
- `~/Allie/readmes/agents/alice.md` — console capture interface

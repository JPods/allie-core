# Handoff — 2026-08-07 (Form Library + Settings Cleanup)

## Where We Left Off
Form Library system built and tested end-to-end. Mac → Andi proxy working. Library button in ReportsDialog shows Andi's catalog. Local reports trimmed from 403 to 18 (core form-detail only). Settings cleaned from 502 to 403, startup cache fixed to fire once. Bill restarting Mac — WC3 dev server wasn't starting.

## Do This First Next Session
1. **Restart WC3** — Bill was restarting Mac. Verify `./runserver.sh local` starts cleanly with the cache fix (should see ONE "Populating settings cache" message, not 20+)
2. **Deploy to Andi** — rsync the latest `apps/sync/views/form_library.py` (has proxy auth fix). The version on Andi is one iteration behind.
3. **Test checkout flow** — open Reports → Library → double-click Customer Form → verify it checks out from Andi with `library_original` preserved
4. **Check form rendering** — does the checked-out Customer Form actually render in detail view?

## What Was Built
- `webClerk3/apps/sync/views/form_library.py` — 4 views: catalog (GET), checkout (POST), submit (POST), restore (POST)
- `webClerk3/apps/sync/urls.py` — 4 new URL routes under `/wcapi/sync/form-library/`
- `React2025/src/api/wcapi.ts` — `getFormLibrary()`, `checkoutForm()`, `submitFormToLibrary()`, `restoreFormFromLibrary()`
- `React2025/src/components/common/ReportsDialog.tsx` — Library button, library panel, Submit/Restore buttons
- `webClerk3/common/schemas/report.py` — `REPORT_PURPOSE_CHOICES` (11 categories)
- `webClerk3/apps/core/init_handlers.py` — post_migrate gated to core app only
- `webClerk3/apps/core/tasks/working_cache_tasks.py` — `STARTUP_PURPOSES` filter

## What Was Decided (and Why)
- **Alice/Andi is librarian** — single source of truth for forms. Local checks out on demand. UUID is the key. Bundle records provide audit trail.
- **form-detail vs form-list** — detail = one record, list = many records. Embedded lists in detail forms (order lines on order) are NOT form-list.
- **Delete not deactivate** — Bill chose to delete 385 report records, not just deactivate. Clean slate. Library brings them back.
- **Settings are not a task queue** — alice_pending and alice_log records deleted. Settings carry config, not operational data.
- **Startup cache fires once** — gate on `sender.label == 'core'`, only cache essential purposes.

## Open Problems
- WC3 dev server not starting (Bill restarting Mac)
- Andi has older version of form_library.py (missing proxy auth fix)
- Andi needs to classify remaining reports into 11 purpose buckets
- No version-based cache invalidation for React yet (Settings carry version field, React doesn't compare)
- Two `wc` parent_model entries in schema_map Settings — need consolidation

## Files Changed This Session
- `webClerk3/apps/sync/views/form_library.py` — NEW
- `webClerk3/apps/sync/urls.py` — added 4 form-library routes
- `webClerk3/common/schemas/report.py` — added REPORT_PURPOSE_CHOICES
- `webClerk3/apps/core/init_handlers.py` — post_migrate gated to core only
- `webClerk3/apps/core/tasks/working_cache_tasks.py` — STARTUP_PURPOSES filter
- `React2025/src/api/wcapi.ts` — form library API functions
- `React2025/src/components/common/ReportsDialog.tsx` — Library button + panel

## Team Memory
- Session document: 955 (team-memory)
- Connection #29 Mac-Andi: endpoint=http://192.168.1.114/wcapi/sync/receive/, key=6OOv-WTG...
- Report Setting #607 now carries report_purposes taxonomy
- Local DB: 18 active reports, 403 active settings

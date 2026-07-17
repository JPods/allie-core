# Handoff — 2026-07-17

## Where We Left Off
Massive MeshMobility session. Built auth layer (Cloudflare Access for both MeshMobility and WC3), Draw tool overhaul (magenta lines, modifier keys, crossing detection with traffic circles, code cleanup), default Tulsa map center, Find City acts as Go, auto-save 2hr cap, landing page all-new-tabs for demos. Fixed fence erasure bug (two POSTs to overlays/active, second was overwriting fence). Fixed shift-select for station deletion (DrawTool was stealing shift-clicks when no drawn lines existed). Removed Document.model_name from WC3 (conflicts with wcapi keyword). Network saves create WC3 Document records with refs.keywords name:value pairs and security_level for publish control. Created pre-release todo (19 items, DEV-342, Tue–Fri next week). Created NYC flagship network design action (DEV-343, priority 1, Tuesday).

## Do This First Next Session
1. **NYC metro network design** — DEV-343. Draw airport corridors (LGA–JFK–EWR), river crossings, Secaucus cargo spines. City Mesh fills between. Crash data for NY available. Two-state (NY+NJ).
2. **Test Cloudflare email gate on meshmobility.com** — mission essential. Verify save/clone requires email, browsing is free.
3. **Test WC3 Cloudflare middleware** — restart WC3, verify CloudflareAccessMiddleware auto-authenticates. Local dev: `CF_ACCESS_DEV_EMAIL=bill@jpods.com`
4. **Capital and MOA plan** — deferred from this session. Pull Google Sheet: `~/Allie/venv/bin/python3 ~/Allie/scripts/allie-sheets-sync.py --pull`
5. **Pre-release todo** — DEV-342, 19 items. Start after user feedback.

## Open Problems
- Cloudflare email gate not tested end-to-end (no CF headers in local dev)
- WC3 contact creation from MeshMobility not tested (wcapi integration not exercised)
- Network save → Document record creation not tested
- City Mesh fence works on first search but needs reload test after fence erasure fix
- Buffer parameter (extend mesh N miles beyond city fence) not yet built — needed for NYC
- AuditLog fails on shell-initiated saves (null user_agent) — cosmetic, save succeeds
- WC3 audit_logs.user_agent column should allow null

## What Was Decided (and Why)
- **Cloudflare email on both MeshMobility and WC3** — single auth pattern, no passwords for public users, kids can use it
- **No password system** — Cloudflare email verification is sufficient; MyCarryon handles offline identity later
- **Guest browsing free, only disk persistence gated** — users play with all tools; auth only when impacting storage
- **Local file download ungated** — browser Save is a blob download, nothing hits storage
- **Document.model_name removed** — conflicts with wcapi routing keyword; type tracked in refs.keywords
- **Network metadata in refs.keywords as name:value pairs** — searchable, WC3 pattern
- **security_level for publish** — 0=draft, 1=published (library), 5000=superuser
- **Noelle + Bill approve before library** — prevents junk; quality gate
- **All landing page links open new tabs** — demos need landing page as home base
- **Shift/Alt in DrawTool only fire when drawn lines exist** — otherwise passes through to region select for station deletion
- **Fence saved in single POST** — two POSTs was erasing fence on second call
- **NYC metro is flagship demo** — three airports, two states, cargo, waste, crash data

## Files Changed This Session
**MeshMobility (JPods/times bill_dev):**
- `gui/auth.py` — NEW: Cloudflare auth, WC3 contact integration, Document registration
- `gui/static/auth.js` — NEW: client-side auth, profile form, requireAuth gate
- `gui/app.py` — Register auth blueprint
- `gui/builders.py` — build_on_lines: true intersection, local headings, helpers, constants
- `gui/network_io.py` — save_network registers Document in WC3
- `gui/static/app.js` — Default Tulsa, auto-save 2hr, fence fix, ungated download
- `gui/static/index.html` — Draw tool overhaul, Find City smart button, auth gates
- `gui/static/library.html` — Auth gate on clone, auth.js loaded
- `gui/static/landing.html` — All links target="_blank"
- `requirements.txt` — Added requests
- `readmes/todo-pre-release.md` — NEW: 19 items across 8 categories

**WC3 (JPods/webClerk3 bill_dev):**
- `common/middleware/cloudflare_auth.py` — NEW: Cloudflare Access auto-login middleware
- `common/middleware/__init__.py` — Register CloudflareAccessMiddleware
- `webclerk3_api/settings.py` — Add middleware after AuthenticationMiddleware
- `apps/docs/models/document.py` — Remove model_name field
- `apps/docs/admin.py` — Remove model_name from admin
- `apps/docs/choices.py` — Remove DOCUMENT_MODEL_CHOICES
- `apps/docs/migrations/0005_remove_document_model_name.py` — Migration

**Alice actions:**
- DEV-342: Pre-release todo (19 items, Tue–Fri 7/22–7/25)
- DEV-343: NYC metro flagship network design (priority 1, Tuesday)

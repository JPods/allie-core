# Handoff — 2026-07-17

## Where We Left Off
Major MeshMobility session: auth layer, Draw tool polish, crossing detection, code cleanup, and WC3 Document integration. Cloudflare Access gates server-side saves; guest browsing is free. Draw tool now uses magenta lines, true segment intersection for traffic circle placement, and modifier keys work properly in Draw mode. WC3 Document.model_name field removed (conflicts with wcapi keyword). Network saves will create Document records in WC3 with refs.keywords name:value pairs and security_level for publish control. Vector store pushes for GEEKOM IT15 completed (Claude, Noelle, Alice).

## Do This First Next Session
1. **Test crossing detection end-to-end** — restart MeshMobility, draw two crossing lines, Build on Lines, verify traffic circle at intersection with station→circle→station connections
2. **Test auth flow with Cloudflare** — verify email verification gates save/clone but not browsing on meshmobility.com
3. **Capital and MOA plan** — Bill's priority. Pull Google Sheet: `~/Allie/venv/bin/python3 ~/Allie/scripts/allie-sheets-sync.py --pull`
4. **Library testing** — load/clone from 5TB library, verify auth gate on clone
5. **WC3 restart** — migration applied (removed Document.model_name). Restart WC3 to confirm no breakage

## Open Problems
- Auth profile form not tested with live Cloudflare headers — only tested guest path
- WC3 wcapi contact creation/lookup not tested from MeshMobility (WC3 was running but integration not exercised)
- Network save → Document record creation not tested (depends on WC3 wcapi being reachable)
- MyCarryon offline identity deferred — Cloudflare email-only for now
- MeshMobility has other unspecified bugs Bill mentioned but didn't specify
- Google Drive MCP auth doesn't work from CLI — workaround: allie-sheets-sync.py
- GEEKOM IT15 expected ~2026-07-20

## What Was Decided (and Why)
- **Cloudflare email verification, no passwords** — passwords are liability; email-only is modern pattern; MyCarryon handles offline identity later
- **Guest browsing free, only server persistence gated** — users should play with all tools; auth only when impacting our storage
- **Local file download ungated** — browser Save downloads .jpd blob, nothing hits our storage
- **Document.model_name removed from WC3** — conflicts with wcapi routing keyword; document type now in refs.keywords as "type:network"
- **Network metadata in refs.keywords as name:value pairs** — searchable, structured, follows WC3 pattern
- **security_level for publish control** — 0=draft (unpublished), 1=published (library), 5000=superuser; refs.published boolean for quick checks
- **Noelle + Bill approve networks before library** — prevents junk; Noelle reviews quality, Bill approves
- **wc_mobility database deferred to IT15** — use existing WC3 commerce_expert for testing
- **True segment intersection replaces vertex proximity** — old code missed crossings between vertices
- **Interposed circle detection improved** — checks distance to both stations, not just midpoint
- **Auto-save recovery cap 2 hours** — multi-user scenario; stale saves shouldn't prompt other users

## Files Changed This Session
- `mesh_mobility/gui/auth.py` — NEW: Cloudflare auth, WC3 contact integration, Document registration, my_networks endpoint
- `mesh_mobility/gui/static/auth.js` — NEW: client-side auth check, profile form modal, requireAuth gate
- `mesh_mobility/gui/app.py` — Register auth blueprint
- `mesh_mobility/gui/builders.py` — build_on_lines: true intersection, local headings, extracted helpers, named constants, removed debug prints
- `mesh_mobility/gui/network_io.py` — save_network registers Document in WC3
- `mesh_mobility/gui/static/app.js` — Default Tulsa, auto-save 2hr cap, dismiss clears auto-save, ungated local download
- `mesh_mobility/gui/static/index.html` — Draw tool: magenta, modifiers, hide/show, dedup, Find City smart button, auth gate on save/build
- `mesh_mobility/gui/static/library.html` — Auth gate on clone, auth.js loaded
- `mesh_mobility/requirements.txt` — Added requests dependency
- `webClerk3/apps/docs/models/document.py` — Removed model_name field
- `webClerk3/apps/docs/admin.py` — Removed model_name from admin
- `webClerk3/apps/docs/choices.py` — Removed DOCUMENT_MODEL_CHOICES
- `webClerk3/apps/docs/migrations/0005_remove_document_model_name.py` — Migration

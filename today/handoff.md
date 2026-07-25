# Handoff — 2026-07-24

## Where We Left Off
DataBrowser App mode working — list on left, full modelDetail.tsx on right. Contact dedup review workflow built: risk records show match candidates with Merge/View/Delete buttons. Bill is actively reviewing 205 `mac_contacts_risk` records. The "Apply to N..." bulk action dropdown is live. Multi-card stacked detail view (showing multiple match candidates side by side) is the next build.

## Do This First Next Session
1. **Build multi-card detail view in DataBrowser right panel** — when reviewing risk/dedup records, show a scrollable list of detail cards on the right instead of one at a time. Each card has Merge and Delete. Bill wants to clear 424 records in an hour.
2. **Fix the 219 failed risk imports** — duplicate `ida` constraint blocked them. Regenerate with unique ida values and retry.
3. **Test auth flow on meshmobility.com** — session persistence after refresh still untested (Action #398). Users lose session on page refresh.
4. **Harvest NV crash data** — available at dot.nv.gov, just not collected. Lowest-effort win on missing states.
5. **Delete test layout names** — Bill3, ShellTest, FinalTest, ConfigShell still in DataBrowser layout dropdown. Del button works but needs to be more visible.

## Open Problems
- wcapi GET 500 on Andi — Contact serialization bug from DB restore
- 799 contacts failed to import (duplicate email constraint) — data in `/tmp/mac_contacts_merged.json`
- AuditLog `user_agent` NOT NULL constraint fails on shell operations — non-fatal but noisy
- `action` column on `actions` table is a JSONField (i18n format `{en: "..."}`) — easy to forget

## What Was Decided (and Why)
- **`config` JSONField added to BaseModel** — every model gets an application data container separate from `metadata` (system behavior). Metadata has auto-scaffolding; config is clean user data. Gordy's quality form data lives here.
- **Quality records are Action records** — no separate model. `metadata.quality_type` discriminates NCR/CAR/deviation/DCR/request. WC2 lesson: controlling actions by model fields sucked.
- **`project_metadata` is for the parent project** — never use it for action-level data. Bill corrected this explicitly.
- **Sprint projects named `{Project}_{600+week}`** — JPods_630, WebClerk_631, etc. Year digit + ISO week. Wednesday 3PM boundaries (accommodates religious observances, 2+3 workday split).
- **DataBrowser App mode renders modelDetail.tsx inline** — right panel shows full detail component, not a new tab. List stays at ~45% width. Double-click opens new tab for comparison.
- **Plain click toggles selection, never clears** — users were losing carefully built selections on accidental clicks. Clear via Shift+Show All only.
- **Import pipeline: parse what you can, preserve what you can't** — `config.original_mac` holds raw data. `refs.import=risk` flags uncertain records. `refs.contact` holds scored match candidates. Alice teaches this to every user.
- **Request framework is core WC3** — every installation ships it. Not a JPods feature. RI DOT NextRequest pattern. Alice tracks submissions, times responses, aggregates demand signal. n² pressure.
- **Traffic circles use cardinal (N/E/S/W) or diagonal (45°) only** — no custom headings. Pick whichever fits the crossing lines better. Users drag to refine.

## Files Changed This Session

### MeshMobility
- `gui/static/app.js` — Save Local uses /api/network/download (JPD round-trip fix), CamelCase filenames via `_jpdFilename()`, silent archive to Noelle
- `gui/static/overlays.js` — Crash contact dialog with phone/URL/request portal, `_showCrashContact()` function
- `gui/overlays.py` — Loads crash-data-status.json, returns contact info on 404, `ARCHIVE_LOCAL_SAVES` admin flag
- `gui/builders.py` — Station dedup (300m exclusion), cardinal/diagonal traffic circles, `_align_score()`
- `gui/network_io.py` — `archive_local_save` endpoint, `ARCHIVE_LOCAL_SAVES` flag
- `overlays/crash-data-status.json` — 5 missing + 5 weak states with contacts, RI updated to "requested"
- `overlays/crashes_all_*.geojson` — 46 states synced (was 18)

### React2025 (WC3 Frontend)
- `src/pages/admin/AdminWorkbench.tsx` — App mode detail in right panel (lazy-loaded components), Apply-to-Selection dropdown, sprint project loader, match candidates panel
- `src/pages/admin/AdminWorkbench.css` — `.db-detail-pane--app` (55% width, no max)
- `src/components/common/DataGrid.tsx` — Plain click toggles without clearing selection
- `src/components/common/FieldOrderDialog.tsx` — Delete button more visible (red, "Delete" not "Del")
- `src/routes/Router.tsx` — Added PurchasePrint route
- `src/apps/transactions/print/PurchasePrint.tsx` — New: purchase order print page
- `src/apps/support/models/quality/` — New: types, schemas, API, QualityDetail, QualityDashboard (Action-based)

### WC3 Backend
- `common/models.py` — `ConfigMixin` added to BaseModel (config JSONField on every model)
- `apps/*/migrations/` — 6 migration files adding config field across all apps

### Allie
- `readmes/capital-pages/inclusive-institutions/index.html` — Landing page draft
- `process/inbox/20260724T162800-tfts.md` — Crash data pain → request framework → inclusive institutions
- `Downloads/JPods Quality Program - 2014/WC3-Quality-Flowchart.dot/.pdf/.png` — Quality system flowchart
- `Downloads/JPods Quality Program - 2014/WC3-Digitization-Map.md` — Every QM section → WC3 mapping

### WC3 Database
- All transactions, line items, ledger, payments deleted (test junk)
- All OrgBase/Customer records deleted (5,445 — rebuild from contacts)
- 8,475 contacts (1,832 enriched from Mac, 2,699 created, 205 risk-flagged)
- 72 sprint Action records created (JPods/WebClerk/General × W30-W53)
- Actions #396-404 created for Alice

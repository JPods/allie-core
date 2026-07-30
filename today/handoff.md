# Handoff — 2026-07-30

## Where We Left Off
Bill wants to shift to WC3 work. Recommend starting a fresh session — this one was dense (two new sites, Gore letter, Data Search Protocol, CrashHarvester fixes, ecosystem reorg). Allie was not consulted this session — ensure ask_allie is available next session.

## What Was Done This Session

### New Sites
- **every-injury.com** (`sites/everyinjury/`) — Brief accountability argument. Blue theme. "every-injury" branding (bad english, memorable). Pushed to `JPods/every-injury.git`.
- **wrongnetwork.com** (`sites/wrongnetwork/`) — Eisenhower's April 6, 1960 warning. Amber theme. Fiscal trap section (5x more road miles than taxes can maintain). Pushed to `JPods/wrongnetwork.git`.
- **Gore letter** (`sites/wrongnetwork/letter-to-gore.html`) — Leads with his 1991 Gore Bill as proven model, contrasts with Interstates built without retrospection. 5X5 = same model for transportation. Mailing address: Climate Reality Project, 555 12th St NW Suite 350, DC 20004.

### MeshMobility / CrashHarvester (on Andi)
- **Data Search Protocol** — When crash data is missing, system actively searches instead of dead-ending. Shows county name, offers "Search for Data" button, polls for results, alerts when found. Code patched on Andi in `overlays.py` and `overlays.js`.
- **County-level completeness** — Reader falls through county files to state-level file when county files don't cover target area. Fixed in `crash_harvester/reader.py`.
- **INCOG Tulsa harvest** — `ok_all` ArcGIS config was wrong (pointed at Phoenix). Harvested from INCOG endpoint (FeatureServer/40): 19,081 records → 3,069 Tulsa cells. Config not yet persisted in arcgis_dot.py.
- **Overlay data excluded from git** — 430MB in `.gitignore`. Synced to Andi via rsync.

### Ecosystem Page
- Added every-injury and Wrong Network.
- Reorganized into 6 categories: Technology, ROI, Paradigm Shift, Fiscal Viability, Accountability Regulations, Managing Radical Adoption.

### Wisdom
- `readmes/wisdom/government-stovepipe.md` — Government stovepiping = sovereign immunity applied to data.
- `readmes/66-data-search-protocol.md` — Full design spec.

## Do This First Next Session
1. **WC3 work** — Bill's priority.
2. **Run `vite build`** — Still pending from prior session (interrupted by machine load).
3. **Ensure Allie is engaged** — ask_allie on every message.

## Open Items (Not Urgent)
- Register every-injury.com and wrongnetwork.com domains → Hostinger
- Gore letter ready to send via Climate Reality Project
- CrashHarvester: fix `ok_all` config, persist INCOG endpoint, user-source-URL backend, Alice request tracking
- MeshMobility on Mac no longer needed — Bill uses meshmobility.com (Andi) going forward

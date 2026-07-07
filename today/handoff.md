# Handoff — 2026-07-06 (Night)

## Do This First
1. **Restart Route-Time server** — new API endpoints for economic overlays won't load until restart
2. Test the three heatmap buttons: isoPopDensity (purple), isoPropertyValue (green), isoJobs (blue)
3. Test city switching — dropdown should swap all 6 overlay types including the new 3

## What Was Done This Session

### React2025 (morning — committed & pushed)
- Major cleanup: 92 qqq_ files, 14 npm deps, 265 lines dead CSS removed
- Sidebar redesign: dark slate, lucide icons, WC3 branding, 3 sections (Work/Forms/Dashboards)
- Dashboard rewritten to Sales & Service (mirrors wc2 Cal_SearchMySales)
- Alice Dashboard: Quiz tab, CycleDetails tab, Page/PDF Designer tabs
- Ported: useColumnContextMenu, useRecords, SlidePanel, QuickCreate, DataBrowserLink
- CORS fix, Accounting/Inventory dashboard routes, manage_view dispatch wiring
- All pushed to git (React2025 + webClerk3)

### Route-Time Economic Overlays (evening — NOT YET COMMITTED)
- `scripts/census_overlays.py` — Census ACS API pulls for 3 cities
- 9 GeoJSON files: {population_density, property_values, jobs} × {sc, ok, mn}
- 3 new API endpoints in api.py
- 3 heatmap renderers in overlays.js (purple=pop, green=property, blue=jobs)
- 3 toggle buttons in index.html
- City switcher updated for new layers
- Generic defaults copied from SC

### Architecture (documented, not coded)
- Signal Loop documented at readmes/50-signal-loop-and-station-economics.md
- Station reports, Noelle draft vs designer comparison, iso-scoring
- MarkMyStation public.html design (read-only civic input)
- Capital meeting format (1hr: pre-model city, CityTool, mall ride, station report)
- JPods cost corrected to $20M/mile (not $7.4M)

### Cloudflare (started, paused)
- webclerk.com DNS moved to Cloudflare (active, propagated)
- cloudflared installed but tunnel login cert not completing — try again next session
- jpods.com not yet moved

## Open Issues
- Post-login redirect not firing in React2025 (manual /dashboard works)
- Cloudflare tunnel auth callback failing — may need firewall check
- Route-Time server needs restart for new overlay endpoints
- Route-Time changes not yet committed to git

## Tomorrow
- Frame capital approaches (1-2 page document)
- Test economic overlays in Route-Time
- 5YearPLBS walkthrough (separate focused session)
- Continue Cloudflare tunnel setup

## Vector Store Updates
IDs 38-43: signal loop, economic overlays design, cost correction, capital meeting format, RT overlay implementation, MarkMyStation design

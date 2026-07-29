# Handoff — 2026-07-29

## What Got Done (July 24-29 session)

### Sites Built & Deployed
1. **JPods3D.com** — SketchUp plugin landing page. Video lightbox. Live on Hostinger.
2. **PersonalizeTransit.com** — 5-tab AI prompt tool (replaced CityTool). 58 cities in Library.
3. **PrimeLawOfNetworks.com** — V ∝ n²/p. DC Metro comparison. S-curve cascade. Regulatory century. Mercantile blind spot.
4. **PhysicalInternet.com** — 3-layer model. Solar on guideways. Patents. Net energy crisis.
5. **CityRoadkills.com** — Litigation-grade advocacy. 4 argument pages + 5 city folders. Live on Hostinger + GitHub JPods/cityroadkills.

### CityRoadkills Architecture
- **index.html** — Stop Child Murder (Dutch example, emotional hook)
- **sovereign-immunity.html** — 60% Reduction (Two Systems table, jury as Fourth Branch, Helsinki vs Tulsa)
- **constitutional.html** — Evidence (21 vetoes, 10 oil quotes, Eisenhower, Congressional Study PB-244854, Morgantown, Wuppertal)
- **bottomup.html** — The Plan (TopDown vs BottomUp, liberty mechanism, 4 steps)
- **City folders:** tx_arlington, ca_paloalto (complete with 5 images), sc_columbia, sc_greenville, ok_tulsa
- **Shared:** style.css, nav.js — one file each, all pages reference both

### Key Reframings
- "Remove sovereign immunity" → "Restore juries"
- "Foolish" → "Childish" (children do childish things, DOTs blame the victim)
- "Juries are retrospection" — Wisdom of the Many judging outcomes, not rules
- "Judgment not compliance. Wisdom not obedience."

### MeshMobility Fixes (deployed to Andi)
- Auth persistence — Redis-backed sessions
- Save folder — IndexedDB directory handles
- User .config — CarryOn seed in WC3 contact metadata
- Superuser-only library save
- CityTool → Personalize Transit scrub + redirect

### Infrastructure
- webclerk.com 403 fixed (recurring /opt/andi/ 700 permission)
- AASHTOWare Safety: 12 state crash data dashboards discovered
- Django passwords changed to "leftshoe" on Mac + Andi (action to upgrade by Aug 3)
- CityRoadkills nginx on Andi:5060

### Outreach
- Adrian Perica (Apple) email sent
- Columbia SC city council email sent (Fred Payne responded in 7 min)

## What's Next
- **Capital page** — still pending
- **desktophosting.com** — landing page, not started
- **Palo Alto page** — needs 5th image explanation from Bill
- **City screenshots** — sc_greenville, ok_tulsa need MeshMobility screenshots
- **/opt/andi/ permission** — find root cause of 700 reversion
- **Adrian Perica** — watch for response
- **Password upgrade** — action due 2026-08-03

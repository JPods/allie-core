# Handoff — 2026-06-24 (end of marathon)

## Status: Travel app working, Sally conveyor solid, Natalie dispatch registry in place

### What Works (accumulated across 2026-06-23 + 06-24)
- Build Profile: smooth guideways, waypoint beam_z, XY=5m Z=60m
- BOM: scans built geometry, 30/70 straight/curved, writes {model}.bom.json
- Capacity per Hour: fleet-limited + station-limited, 2.1 pax/pod, ADA lifts
- Camera Follow: 25/20/5 offset (editable), click pod row
- Travel App: phone UI, stations from network.json, places fresh pod, camera follows
- Station Names: network.json source of truth
- Sally conveyor: 3-step direct transforms, exit hold 3s
- Sally-Natalie: 50% rebalance, inbound tracking, Natalie 5s dispatch interval
- 20s minimum dwell: simulates unload/load at every station
- Route Validation: all pairs tested before animation
- Diverging pod spacing fix (uturn)
- Build-required flag: blocks animation after structure changes
- Console 1 only, Result bar with SU Console + log level
- Speed 12 m/s, personal space 5m travel / 0.5m station
- Crew Health: HTML renders properly
- Toolbar icons: renamed to purpose, custom JPods designs
- Toolbar Travel button opens phone app directly

### Next Session Priorities
1. Natalie dispatch registry → extend to zipper merge timing
2. Pod arrival at entry slot (ps1) not exit slot — conveyor shuffles to exit
3. Travel app: test full trip flow with corrected station ID mapping
4. Station locking: implement lock mechanism from network-change-protocol.md
5. Terrain raycast: proper terrain-group filter (on ouch list)
6. Two-stage Z profile (ouch list)
7. gw_lift_in junction issue — pods stop at fork

### Architecture Rules Established This Session
- Smooth guideways primary — columns absorb terrain
- network.json is source of truth for ALL network-specific data
- Template folders read-only during network operations
- Entity attributes are cache, not source of truth
- Console 1 only
- Sally owns slots, Natalie owns timing, Nora executes
- File authority: lines.json=designer, lines.computed.json=Noelle, network.json=network
- Network ops never modify station instances
- Build-required flag prevents animation on stale network

### Key Commits
- 1cdd3e0 — Custom toolbar icons
- 0eaec53 — Travel station ID fix
- 0685f2a — Travel standalone + 20s dwell
- c4d17be — Natalie 5s dispatch interval
- 5955560 — Sally all-pods-advance
- 646c124 — Sally exit hold 3s
- c716c0a — Sally direct entity transforms
- 195e712 — Route validation, diverging pod fix
- 5085947 — Animation fixes, rebalance, 12 m/s
- 1df1a60 — Smooth guideways, BOM, capacity, camera
- bc8dcdf — Waypoint Z fix

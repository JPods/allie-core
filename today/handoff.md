# Handoff — 2026-06-23 (marathon session)

## Status: Major feature session — Build profile, BOM, Capacity, Travel, Sally-Natalie coordination

### What Works
- **Build Profile**: smooth guideways primary, waypoint beam_z, piecewise grade envelopes, XY=5m Z=60m defaults
- **BOM**: button in Network Display, scans built geometry, writes {model}.bom.json, 30/70 straight/curved split
- **Capacity per Hour**: fleet-limited (3 speeds) + station-limited (PS + ADA lifts), 2.1 pax/pod
- **Camera Follow**: 25m back, 20m right, 5m up (editable), click pod row to follow
- **Travel App**: wired — stations from network.json, booking dispatches pods, camera follow, station rename
- **Station Names**: in network.json (source of truth), not just entity attributes
- **Sally conveyor**: direct entity transforms (3 substeps), no animation maneuvers
- **Sally-Natalie rebalance**: 50% threshold, inbound tracking with ETA, picks station with most room
- **Dispatch cooldown**: 3s per station between departures
- **Route Validation**: tests all station pairs before animation starts
- **Diverging pod spacing**: pods traveling opposite directions skip personal space
- **Build-required flag**: blocks animation after structure changes until Build runs
- **Console cleanup**: Result bar, SU Console button, log level dropdown, no c2 maintenance
- **Speed**: 12 m/s (27 mph) default
- **Crew Health**: HTML renders properly (innerHTML not textContent)
- **Terrain raycast**: bounding-box skip + z=0 interpolation

### Next Session Priorities
1. **Natalie dispatch registry** — per-station outbound queue, manages clearance timing (replaces timer cooldown)
2. **Pod arrival at entry slot** — pods should arrive at lowest empty slot (ps1), conveyor shuffles to exit
3. **Minimum dwell time** — pods need to stay parked before redispatch (prevents ping-pong)
4. **Don't swap origin/dest on redispatch** — causes s001↔s002 ping-pong
5. **Travel app testing** — Make Trip button, trip booking, status polling
6. **Entity name display during animation** — confirmed cosmetic (SketchUp transparent ops), not corruption
7. **Station locking** — implement the lock mechanism from network-change-protocol.md
8. **Two-stage Z profile** — on ouch list for terrain with bridges/overpasses

### Key Commits (su_jpods)
- `6b4ad06` — Station dispatch cooldown
- `c716c0a` — Sally direct entity transforms
- `bfb052d` — Sally lock during advance
- `195e712` — Route validation, diverging pod fix, Sally tick
- `5085947` — Animation fixes, rebalance, personal space, 12 m/s
- `1df1a60` — Smooth guideways, BOM, capacity, camera, console cleanup
- `bc8dcdf` — Waypoint Z fix

### Architecture Rules Established
- Smooth guideways are primary — columns absorb terrain, SU mesh is noise
- network.json is source of truth for all network-specific data
- Template folders are static/read-only during network operations
- Entity attributes are cache only, not source of truth
- Console 1 only — stop maintaining c2
- File authority: lines.json=designer, lines.computed.json=Noelle, network.json=network
- Network operations must never modify station instances or tags

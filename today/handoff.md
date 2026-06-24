# Handoff — 2026-06-24

## Where We Left Off
- 500mm edge hallucination guard in Natalie + Noelle RED FLAG validation in Build
- Crew flag system: any agent flags defects, show/hide in Crew Health, merge within 2m
- Noelle visual defect posts in 3D model, Nora kink detection (>15°)
- Build preserves station_names in network.json
- Travel app wired with fresh pod placement, auto camera follow
- Sally 3-step conveyor, Natalie 5s dispatch, 20s dwell, 3s exit hold
- All architecture rules documented in memory + retrospection

## Do This First Next Session
1. **Restart SU and Build** — test 500mm guard, defect flags, station name preservation
2. **Travel app** — test trip booking with correct station IDs
3. **Crew Health → Flags button** — verify gap + kink defect markers in 3D model
4. **gw_platform_in2 junction** — verify 500mm guard prevents the jam
5. **Template validation chain** — implement timestamp checks (Save > Compute > Test)

## Open Problems
- gw_lift_in junction fork — pods may still stop if chain doesn't match geometry
- Terrain raycast z=0 fallback — interpolation patch covers it, proper fix deferred
- Two-stage Z profile — sharp local + smooth long-distance (ouch list)
- Natalie dispatch registry → extend to zipper merge timing
- Pod arrival at entry slot (ps1) not exit slot — conveyor should shuffle to exit
- Station locking after Build — implement lock mechanism (readme written, code not yet)

## Key Commits (su_jpods)
- e69397a — Crew flags system
- 627c81e — Noelle visual defect flags + Nora kink detection
- f8d9853 — Noelle RED FLAG gap validation
- ba6777c — Build preserves station_names
- 2065193 — 500mm edge hallucination guard
- 0685f2a — Travel standalone + 20s dwell
- c4d17be — Natalie 5s dispatch interval
- c716c0a — Sally direct entity transforms
- 1df1a60 — Smooth guideways, BOM, capacity, camera
- bc8dcdf — Waypoint Z fix

## Architecture Rules
- Smooth guideways primary — columns absorb terrain
- network.json is source of truth for ALL network-specific data
- USE MATH NOT EDGES — Axiom 10 (500mm hallucination is the proof)
- No silent defect tolerance — documented, visible, counted, approved
- Sally owns slots, Natalie owns timing, Nora executes
- Template validation chain: Save → Compute → Test (timestamps must align, all UTC)
- Designer accountability — Noelle rejects, designer fixes
- Build must not destroy user data

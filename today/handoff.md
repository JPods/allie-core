# Handoff — 2026-07-12

## Where We Left Off

Massive architecture session. Built CrashHarvester as a standalone data supply chain app. MeshMobility reads ALL overlay data from the CH library — no government API calls, no legacy fallbacks, no _overlay_path. 566 lines of government code removed from api.py. Drawing tools built for designer-drawn corridor networks.

## What Was Built

1. **CrashHarvester** — standalone app at `00_working_code/CrashHarvester/` with full README
2. **mobility_data/** — library package (reader, schemas, registry, harvesters for FARS, HPMS, state DOT)
3. **309 datasets registered** — crash, fatal, traffic, census across 50 states
4. **Drawing tools** — Cmd+click draws corridors, Option+click adjusts, Shift deletes. Build on Lines places stations along drawn corridors
5. **Crash Mesh algorithm** — auto-extracts corridors from top 10% crash density cells
6. **Line tool** — click two points, stations every mile (airport-to-city)
7. **Threshold slider** — min crashes filter on All Crashes overlay, reveals corridors from noise
8. **Morgantown comparison** — Stockdale paradox + roadkill count per city in overlay panel
9. **Tooltips toggle** — overlays non-interactive by default, toggle for presentations
10. **City switch cleanup** — save prompt, clear overlays, fresh start on Find City

## Tuesday Release Target

Bill wants to release MeshMobility + CrashHarvester Tuesday July 15. Next session must:

1. Move `mobility_data/` into `CrashHarvester/` as one app
2. Run FARS harvester for all 50 states — county-level files
3. Run HPMS harvester for all 50 states
4. Remove fake crash data (crashes:fatal ratio < 3:1 = FARS repackaged)
5. Real all-severity states: AK, CO, DC, DE, IA, ID, IL, MA, OK, OR, PA, TN, UT, VA, WA
6. Rebuild registry.json from disk
7. Test end-to-end: DC, Greenville SC, Tulsa OK

## Key Principles Established

- **More doors > bigger doors** — station density is coverage, not capacity
- **Noelle owns slot count** from data unless user explicitly overrides
- **Crash corridors = guideways, walk circles = stations** — two signals, one network
- **Parallel mesh beats hub-and-spoke** — no single point of failure, V ∝ n²/p
- **Highway POLICIES roadkill people** — not highways
- **Designer draws, algorithm builds** — Build on Lines is the primary workflow
- **Noelle algorithm library** — never lose an algorithm, add new ones
- **Overlays non-interactive by default** — work mode vs presentation mode

## Key Files

| What | Where |
|------|-------|
| CrashHarvester README | `00_working_code/CrashHarvester/README.md` |
| Library | `00_working_code/mobility_data/library/` |
| Reader | `00_working_code/mobility_data/reader.py` |
| Harvesters | `00_working_code/mobility_data/harvest/` |
| MeshMobility API | `00_working_code/mesh_mobility/gui/api.py` |
| Drawn lines | `00_working_code/mesh_mobility/drawn_lines/` |
| DC network iterations | `00_working_code/mesh_mobility_maps/WA_Washington_2026-07-12_v*.jpd` |

## Open Issues

- `mobility_data/` needs to move into `CrashHarvester/` — currently a sibling
- Snap radius on drawing tools may need tuning (currently ~200m)
- Traffic circles not always detected at line crossings if angle is wide
- SC, MN, and most states lack real all-severity crash data — need state DOT harvesting
- Census auto-fetch still in Fetch Data endpoint — should move to CH

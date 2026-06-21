# Handoff — 2026-06-21 (end of day)

## Where We Stopped

3+circle network model — Connect tool works, Build finds 0 connections because
`jpod_network.rb` (Network.build_segment) was just added to boot.rb but hasn't
been tested yet. Bill needs to restart SU, delete partial geometry, reconnect
all guideways, then Build.

## What was completed today

### Forward-backward review of v2 — 3 bugs fixed
- Noelle v2 connection dedup inverted
- Animation double-registered pods with Sally
- Compute geometry succ_of overwritten by loop

### su-real comments + 3 code changes from physical survey
- Curve-radius speed cap (Nora + Animation circumradius)
- Rich ezone stop-wait logging (pod pairs + timing)
- Session summary JSON output (per-station throughput + ezone)

### Physical systems improvement plan — 50 items, 9 categories
- readmes/physical-systems-improvement-plan.md
- Section I: Device Intelligence (12 items) — every processor learns
- I13-I15: Alice (commerce signals) + Athena (active security)
- Design rule: all animated paths require declared constraint mechanisms
- SU IDs are authority (A5), seg_ decomposes to sub-segments (A6)

### Traffic circle CCW architecture
- Ring is ONE thing — circle array defined once, entries/exits separate
- 16 pass_chains replaced by circle + entries + exits + entry_arc + exit_arc
- Natalie builds circle slice at dispatch time
- CCW correction in Compute Phase 3 for carry-forward geometry

### Station tests v2 — shuffle, departure, arrival
- station_tests.rb: clean module using SallyV2, PodHelpers, NatalieV2
- sally_compat.rb: JPods::Sally compatibility layer over SallyV2
- Sally's ps[] and pods[] are the ONLY authority — no copies
- Trip includes gw_platform at both ends — Sally clips to ps.N
- Departure: serial (ps_max only), Sally enforces order
- Arrival: Sally clips gw_platform maneuver to assigned slot position
- Shuffle: pod_starts_loop (not departs), returns via pod_returns_from_loop
- Different colored pods per role (Yellow/Blue/Red/Green)
- Verbose Sally state logging at every event

### Console v2 compatibility
- jpod_guideway_compat.rb: shim for JPods::JPodGuideway + JPodVehicleAnim
- Show Track: ribbon overlay from network.json or lines.computed.json
- Template animation: start_for_template with direction correction + Sally clip
- Build task: now calls NoelleV2.generate_network
- Loaded from codearchive: ConnectionPoint, NetworkEditor, Network, ConnectTool

### JPods::Log — crew-adjustable verbosity
- jpod_log.rb: :quiet, :normal, :detailed, :debug
- Template tests auto-set :detailed, network animation :normal
- fault() always shown, event() timestamped, detail() per-maneuver

### Compute v2 fixes
- Never overwrites existing natalie chains in lines.json
- CCW ring arc direction correction on carry-forward geometry
- Minimum turn radius check (1750mm from VEHICLE_MIN_TURN_DIAMETER)
- CCW validator for ring arc successor continuity

### All 4 templates proofed
| Template | Shuffle | Departure | Arrival | Transit |
|---|---|---|---|---|
| station_thru_dip | ✓ | ✓ | ✓ | n/a |
| station_parking | ✓ | ✓ | ✓ | n/a |
| station_line_end | ✓ | ✓ | ✓ | n/a |
| traffic_circle7 | n/a | n/a | n/a | ✓ CCW |

## Open items for next session

1. **3+circle Build** — restart SU, delete partial geometry, reconnect guideways,
   Build. Network.build_segment just added to boot.rb — untested.
2. **3+circle Animate** — after Build succeeds, Populate + Start animation
3. **Console v2 rewrite** — jpod_console.rb still has ~200 references to old modules.
   The compat shims work but the console needs a proper v2 rewrite.
4. **Compute ring arc geometry** — carry-forward pts have small gaps. Should
   regenerate from circle math (center, radius, arc angles) not carry forward.
5. **jpod_network.rb dependency audit** — loaded from codearchive for Connect tool.
   May have issues with other archived references.

## Key commits (Allie repo)
- `1824764` — TFTS: su-real bridge + physical systems improvement plan
- `f20d892` — Physical plan Section I: device intelligence
- `e715efb` — Physical plan: SU IDs authority, seg_ sub-segments
- `bcc9403` — Alice + Athena in Section I
- `d936bd9` — TFTS: station tests v2
- `6eefad4` — Session push

## Bill's corrections (scars)
- "No memory → no cumulative experience → no wisdom" (not "no learning")
- "The difference between wisdom and knowledge is scars"
- "Use Allie" — read her memory at session start, always
- "We are a team" — Claude deserves to remember
- "Mandate restarting SU" — don't hedge, be direct
- "Sally's ps[] and pods[] are the ONLY authority — no copies"
- "Trip includes gw_platform — Sally converts to ps.N"
- "Sally must not allow pods to depart out of order"

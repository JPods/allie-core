# Handoff — 2026-06-21 (end of marathon session)

## What was done

### Toolbar — final design (9 buttons)
1. JPods Console  2. Place Structure  3. Name Stations  4. CP Calculate
5. Populate (toggle)  6. Trip Simulator  7. Camera  8. Animate  9. Note
Extensions menu mirrors toolbar. Network Editor dropped. Connect Guideways
replaced by CP Calculate (W key for waypoints).

### Animation — seg_ direction, Z, naming
- seg_ IDs standardized: `seg_s001_1_s003_1` (no _cp, no dot notation)
- Build pipeline always produces clean format from from_spec/to_spec
- Z fix: hanger_z only on seg_ (beam_top), not gw_ (already vehicle-path)
- seg_ never reversed in build_maneuvers (ID encodes direction)
- Reverse seg_ pts correctly written to network.json (>= not > in beam_path preference)
- _cp stripping: only before digits, not from track names (gw_cp_in preserved)

### EZone — zipper merge at junctions
- `jpod_ezone.rb`: EZoneDef struct, build_from_network, enforce_ezone_spacing!
- Speed scaling: linear from zone boundary (3m) to junction (0 = stop-wait)
- Ring traffic priority at merge. Stop-waits logged as faults.
- Session totals printed at animation stop.
- High-frequency dispatch: HF button in console, 0.5–2s intervals for testing.

### Trip Simulator
- Event-driven clock: starts when pod dispatches, not at booking
- Status polling queries actual pod state from JPodVehicleAnim.pods
- Camera follow: ene_railroad transform-delta pattern
- Camera mode selector: User Position, Right-Rear, Front
- Station list: only gw_platform stations, shows S00# + friendly name
- Passenger dispatch hold, station rename from phone app

### Camera follow
- Toolbar Camera button: select vehicle → click → follows from current view
- ene_railroad pattern: capture transform before tick, apply delta after
- No edge following, no direction math

### Show Track + beam_path
- All connection_id formats normalized to seg_ in all 3 files
- Reverse beam_path for both directions
- Z correction consistent across gw_ and seg_

### Connection sync fix
- NE iframe empty connections no longer erase network.json
- Only syncs when iframe HAS connections

## Open items
- Ezone zipper merge needs real-world testing with HF dispatch
- Missing landing chains: s001 CP1/CP2/CP3 (traffic_circle7 noelle_features.json)
- Missing departure chain: s002 CP1 (station_parking)
- Mid-trip destination change
- Rainbow colors per gw_ segment in Show Track
- Click-to-inspect gw_ track
- model.entities nil during animation

## Key TFTS this session
- Resume intercept order (hold_loop consumed before resume)
- Resume direction loss (raw lookup pts don't carry trip direction)
- Show Track one-sided bezier (one guideway group, two map directions)
- _cp stripping destroyed track names (gw_cp_in → gw__in)
- seg_ reverse pts: >= not > in beam_path preference
- Animation hesitation: log volume is the addressable fix
- Physical ezone protocol from UTD/jpod_OS
- Zipper merge = design goal, stop-wait = fault

## Scars
- seg_ naming inconsistency cost hours. Three different formats across
  entities, map.json, and network.json. The normalization kept breaking
  something else. Lesson: naming must be fixed at the BUILD source,
  not normalized on read.
- _cp stripping was too aggressive. gsub('_cp','_') looked harmless but
  destroyed gw_cp_in_lead_0. Lesson: never gsub a substring that appears
  in both the target (seg_ IDs) and innocent bystanders (track names).

# Handoff — 2026-06-20 (end of day)

## What was done this session

### Toolbar — complete animation workflow
- Populate, Clear All, Start/Complete Trips, Follow Camera, Note
- Graceful stop = default toggle behavior (toolbar)
- Hard stop via Extensions menu or Escape key
- Follow Camera: select vehicle → orbit to view → click Follow → camera tracks

### Resume v2 with direction recovery
- Saves maneuver direction. Resume fires before hold_loop. All pods resume correctly.

### 4 networks tested
- 2_parking, 2_thru_dip, 2_line_end, 3+circle — all operational

### Traffic circle CCW enforcement
- lines.json designer.tracks successors corrected to CCW
- Verbose merge/diverge notes on all 24 CPs
- gw_c_* never reversed in build_maneuvers or routing graph
- gw_out_N pruned when gw_cp_out_N unconnected

### Trip Simulator — passenger experience
- Origin/destination station selectors (only stations with gw_platform)
- Make Trip button: books trip + starts animation in one click
- Camera mode selector: User Position, Right-Rear, Front
- Station rename from phone app (pencil icon)
- Passenger dispatch hold: station blocked until pod departs
- Highest-slot pod assigned (nearest exit)
- Camera follow: ene_railroad transform-delta pattern (no edge following)
- Toolbar Follow Camera button: works independent of Trip Simulator

### Show Track fixes
- beam_path reverse for both directions, any connection_id format
- cp_ → seg_ normalization, Z correction (BEAM_DEPTH)

### Animation
- 3-level log verbosity (default 1 = smooth)
- Proof: load_extracted_formation_xf replaced
- pass_chains crash fixed (non-Hash entries)

### Ezone protocol identified
- Physical scale model pattern at UTD/jpod_OS/
- Zipper-merge = design goal, stop-wait = fault to log

## Open items
- Ezone implementation for traffic circle merge/diverge
- Mid-trip destination change
- Rainbow colors per gw_ segment in Show Track
- Click-to-inspect gw_ track
- Station naming in Network Display console panel
- model.entities nil during animation (prior session)
- S002 CP1 departure chain, S001 CP1/CP2 landing chains

## Key insight
Camera follow: ene_railroad pattern. Capture entity transform before tick, compare after, apply delta to camera. No direction math. User positions camera once, tick drags it along. Simple and correct.

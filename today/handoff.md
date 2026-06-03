# Handoff — 2026-06-03

## What Was Done This Session

### 1. populate_from_open_template — Hash format crash fixed
- `lines_raw.is_a?(Hash)` branch converts Hash-keyed lines.json to Array before iteration
- Write-back preserves original format (Hash or Array)

### 2. `_validate_connectivity` — redesigned + argument fix
- Argument count fixed (3 args: template_data, formation_id, gw_index)
- Walks DECLARED chains only; landing_chains format detection (Hash vs Array)
- Feedback: ✓/⚠/🚫 per junction; explicit warnings for empty/missing/malformed chains

### 3. Sally — chain feedback
- Empty hold_loop_chain segments get ⚠ warnings
- landing_chains/exit_chains: explicit format detection + warnings in init_sequencer_for_station

### 4. MIN_STATION_ARC_RADIUS_MM = 3500.0
- Added to jpod_constants.rb
- Enforced: _generate_uturn_arc_pts_mm / populate / proof_lines (3 checkpoints)
- Documented: CLAUDE.md Axiom 16, jpods-plugin.md Rule 12

### 5. Exterior arc fix — `_generate_uturn_arc_pts_mm`
- Accepts `station_centroid_mm:` keyword arg
- Centroid computed from all gw_* endpoints after gw_index built (both populate functions)
- CCW vs CW: whichever arc midpoint is FARTHER from centroid = exterior arc
- Fixes gw_uturn_1 wrong half-circle (was always CCW → interior for far-end uturns)

### 6. station_line_end hold_loop_chain.loop corrected (lines.json data fix)
- Root cause: loop ended at gw_cp_in_lead_0; no physical path back to gw_uturn_1 without platform tracks
- 43,000mm gap caused animator to cross via gw_platform, skipping gw_platform_in + gw_platform_parking
- Fix: loop = 8 tracks (added gw_platform_in, gw_platform_parking after gw_cp_in_lead_0)
- to_platform changed to ["gw_platform"] (final slot assignment)
- Rule: station_line_end has no platform bypass — approach tracks ARE the loop connection

## Status

### Done ✓
All items above committed to su_jpods_claude, pushed to JPods/sketchup.git (9050f19)

### Still Open
1. **Direction preservation**: populate writes pts_mm in arbitrary mesh order. proof shows gw_platform, gw_far_main, gw_lift, gw_platform_parking REVERSED (end_delta ≈ full length). Fix: after extracting sp/ep from model, compare against declared startPoint in lines.json; swap if reversed.
2. **Inverse transform in proof_lines**: Z offsets (312.5mm, 62.5mm) are coordinate system artifacts — populate wrote local coords, proof reads world coords. Fix: apply inverse instance transform before comparison.
3. **First maneuver event not logged**: trajectory starts with tick data for hold_loop[7/7] but no preceding maneuver event. Logging gap in animator.

## Next Session Start

1. Reload: `load Sketchup.find_support_file('jpod_path_json.rb', 'Plugins/su_jpods')`
2. Run: `JPods::PathJSON.populate_from_open_template` on station_line_end model
3. Verify console: centroid printed, arc sweep CW for gw_uturn_1, 8-track loop in Sally
4. Animate — verify no jump from gw_cp_in_lead_0; pod traverses gw_platform_in + gw_platform_parking on every loop
5. Next fix: direction preservation for straight tracks (biggest remaining proof SEVERE)

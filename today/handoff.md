# Handoff — 2026-05-20 (Session 2)

## Where We Stopped

Two bugs fixed and confirmed working in the SketchUp plugin. Committed to `su_jpods_claude` branch (commit `14f743f`). Two TFTS files written and committed to `~/Allie`.

## What Is Done (This Session)

### 1. Approach Curve False Violations — Fixed

Noelle was reporting 5 BLOCK violations at ~1.2m radius on inter-station connections at S048, S050, S051. Visual inspection showed radii of 3.5m+.

Root cause: `check_approach_curves` in `noelle.rb` was calling `vehicle_path_for`, which stitches station-internal U-turn geometry (genuine ~3.5m radius curves) onto the inter-station path for animation continuity. The station-internal geometry caused false circumradius readings.

Fix: Changed to `base_vehicle_path_for` — reads only the guideway's own `beam_path` attribute, no stitching.

Result: "Noelle approach curves: all guideways approved (min radius >= 8.0 m)." All 5 violations gone.

Two intermediate attempts failed first (chord filter, skip depth) — documented in TFTS `20260520T232624-tfts.md`.

### 2. Waypoint (via_markers) Dropping — Fixed

The 3 waypoints placed between S048 and S050 were being dropped during Build. Guideways built as a straight pair; columns appeared at waypoint locations separately.

Root cause: `generate_feature_json` was creating TWO separate `cp_` entries — one for each direction of each bidirectional connection. `build_from_config` called `build_segment` twice for the same physical guideway pair. The second call (with `via_markers=[]`) erased and rebuilt what the first call had placed, dropping all waypoints.

Fix: Modified `generate_feature_json` to check if the reverse `cp_` key already exists before creating a new one. Both directional `seg_` entries now nest inside ONE `cp_` entry per physical pair.

Result: feature.json dropped from 6 cp_ entries to 3. Trip S048→S050 grew from 465m to 556m (waypoints being routed). `via_markers: [1,2,3]` confirmed on the S048-S050 pair.

TFTS `20260520T234607-tfts.md` written, then amended to add warning: future single-guideway (one-way) connections require revisiting the merge logic before implementing.

### 3. TFTS Files Committed

Both process/inbox files written and committed immediately per protocol.

## Next Steps (Priority Order)

1. **Next Build** — the "Perfect" build ran against the OLD 6-entry feature.json. The new 3-entry feature.json is now on disk. Run Build again to confirm via_markers=[1,2,3] stamps correctly on both guideways (topology log should show [1,2,3] not [1,2]).
2. **Pipeline test** (carried from Session 1) — Build → generate_map_json v2 → generate_feature_json → TripPlanner v2 → Animate. Expect map.json v2 output, trip.json v2 output.
3. **"Trip" → "Route" terminology** — mentioned at session start, tool call rejected, never implemented. Confirm with Bill before starting.
4. **physical.json (jpods-physical-v1)** — not yet implemented; staging area is `anomalies: []` in nora.json.
5. **Station template F-07** — stubs at 7.5m need structural redesign.

## Files Changed This Session (su_jpods)

- `noelle.rb` — `check_approach_curves`: changed `vehicle_path_for` → `base_vehicle_path_for`
- `noelle.rb` — `generate_feature_json`: ONE cp_ entry per physical pair; both seg_ directions nested inside
- `jpod_constants.rb` — added `APPROACH_SKIP_DEPTH = 2.0.m`

## Commits

`14f743f` on `su_jpods_claude` branch. Not pushed — wait for Bill's verification of next build.

## Key Design Principles (This Session)

| Principle | Where it applies |
|-----------|-----------------|
| `base_vehicle_path_for` for per-guideway spatial analysis; `vehicle_path_for` for animation only | `noelle.rb` approach curve checks |
| ONE cp_ entry per physical guideway pair in feature.json | `generate_feature_json` in `noelle.rb` |
| `build_segment` builds BOTH tracks in one call — duplicate cp_ entries cause double-build and via_markers erasure | `noelle.rb` + `jpod_noelle_bridge.rb` |

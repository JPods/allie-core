# Handoff — 2026-06-03

## What Was Done This Session

### 1. Sally — Intersection-based landing routing

`_final_approach_tracks(hl_loop, landing_chain)` implemented in `jpod_sally.rb`.
Finds the first track shared between the outer hold loop and the landing_chain (O(1)
Set lookup). Returns `hl_loop[0..exit_idx] + landing_chain[(lc_exit_idx+1)..]`.
ONE algorithm for all station templates.

Priority order in `on_maneuver_complete` promote branch:
1. Direct-park (`hl_to_platform == []`) → `:land` with empty tracks
2. Intersection approach (landing_chains defined + intersection found) → `:land` with partial loop + chain tail
3. Declared `to_platform` (non-empty Array) → `:land` with declared tracks
4. Legacy nil → `landing_chains[cp]` directly
5. No path → continue looping

### 2. station_parking/lines.json — landing_chains added

```json
"landing_chains": {
  "in_cp0": {
    "tracks": ["gw_cp_in_lead_0", "gw_platform_in1", "gw_platform_in2"]
  }
}
```

Intersection at `gw_cp_in_lead_0` (index 6 in hl_loop). Final approach = 7 partial
loop + 2 platform approach = 9 tracks total.

### 3. Platform departure fix — `_pts_tail_from_near`

Added to `module RubyNatalie` in `jpod_vehicle_anim.rb`. Projects pod's current position
onto the platform polyline, returns forward tail only (never reverses). Used by
`build_maneuver_from_tracks` when `clip_start: true` — hold_loop departure now
passes this flag. Pod at slot N exits forward directly; never reverses to slot 1.

### 4. Two crash fixes

- `LIFT_RE = /gw_lift/i` inside method → renamed to local `lift_re` (Ruby forbids
  constant assignment in method bodies)
- `_pts_tail_from_near` was in `module JPodVehicleAnim` but called from `module RubyNatalie`
  → moved to RubyNatalie; call site updated from `JPodGuideway._pts_tail_from_near` to plain `_pts_tail_from_near`

### 5. Trip Sequence preview — expanded JSON format

`preview_hold_loop_sequence` output changed from 4-phase labeled text to flat
`{"trip":[...]}` JSON with loops fully expanded (target_loops repetitions).
Warnings become `//` comments. Header shows total distance.

### 6. Trip Sequence task + console panel

- New console task: Models > Stations > "Show Trip" button. No vehicle required.
  Returns `__TRIPSEQ__:` prefix → dispatched by `cmd_execute` to `showTripSequence()`.
- `showTripSequence(text, label)` creates persistent `<div id="trip-sequence-panel">`
  below task controls. Green monospace, ✕ close, 55vh max-height. Clears on nav away.
- `_TRIP_PANEL_TASK_IDS` controls which tasks keep the panel visible.

### 7. All work committed + pushed

6 commits to su_jpods_claude branch, JPods/sketchup.git.

## Status

S002 (JPods_station_parking) hold_loop animation working end-to-end:
- Pod enters loop → traverses outer ring → takes intersection branch → parks at slot N
- Departure: pod clips gw_platform at slot position → exits forward only

## Still Open

1. **Arc undersampling** — gw_uturn_0/gw_uturn_1 in station_parking are 2-pt chord
   (not 56-pt arc). Fix: reopen station_parking template in SketchUp → Workflow > Generate
   Template Data. Sally's `_generate_uturn_arc_pts_mm` will produce the arc; `populate_from_open_template` writes it.

2. **Hold Loop task trip preview** — Hold Loop task run lambda does not yet emit
   `__TRIPSEQ__:` prefix. Add it so the trip panel fires automatically when the task runs,
   not only from the Trip Sequence task.

3. **Vehicle trip detail in panel** — `showTripSequence` ready for vehicle trips.
   When a vehicle is selected and animating, show its actual maneuver sequence in the panel.
   Add vehicle task ID(s) to `_TRIP_PANEL_TASK_IDS` when built.

4. **S007 / S008 geometry drift** — proof shows SEVERE on multiple tracks. Not yet addressed.

## Next Session Start

```
load Sketchup.find_support_file('jpod_sally.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_path_json.rb', 'Plugins/su_jpods')
```

1. Open station_parking template model
2. Workflow > Generate Template Data → verify gw_uturn_0/gw_uturn_1 get 56-pt arcs
3. Close template; reload plugin; open network model
4. Run Trip Sequence task on S002 → verify expanded JSON in trip panel
5. Run Hold Loop on S002 → verify pod exits platform forward, arcs exterior, parks at slot N
6. Add `__TRIPSEQ__:` output to Hold Loop task run lambda

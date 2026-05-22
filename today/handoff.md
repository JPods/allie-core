# Handoff — 2026-05-22

## What was fixed this session

### Vehicle placement on gw_platform (confirmed working)

**Root cause:** `ensure_platform_host_guideway` built its synthetic host guideway from
`platform['start_m']`/`['end_m']` — these are CP stub endpoints (~40000,-4800mm), not
the parking track. Vehicles were placed at CP0 area, not on gw_platform (-1018mm Y).

**Fix:** `ensure_platform_host_guideway` now loads `{sid}.gw_platform` from map.json via
`RubyNatalie.build_line_lookup`. These pts are the authoritative parking track. Vehicle-level
pts are stored as beam_top (add BEAM_DEPTH before storing in beam_path attribute).

Files changed: `jpod_animator.rb`, `jpod_platform.rb` — both copies of `ensure_platform_host_guideway`.

**Track direction fix:** Platform hash `track_index` was 0 (entrance=pts.last = exit/gw_platform_out1
end), placing slot 1 at t≈0.94 right next to gw_platform_out1. Fixed by forcing `track_index=1`
on all synthetic guideways built from map.json gw_platform (entrance=pts[0]=inbound end).
Tier 2 in `spawn_t_for_platform_slot_on_guideway` now reads track_index from the guideway
group (not platform hash) for platform_host guideways.

**Safety net (build_fleet):** If entity is >1m from first maneuver at animation start,
snap it to the slot position on that maneuver. `_point_along_polyline` helper added to
`jpod_vehicle_anim.rb`.

### Result
- S001 vehicle: placed at t≈0.06 on gw_platform (1.5m from inbound end)
- S002 vehicle: unchanged (was already placing correctly)
- Animation: no jump at start; vehicles depart and loop correctly

## Open items

### Platform shuffle — Natalie's next task (Bill requested 2026-05-22)
Vehicles parked on a platform that are NOT involved in an active trip should be shuffled
forward to the highest-numbered open slot. This is the "compact toward exit" rule.
- Natalie detects idle parked vehicles (no trip_id or trip_assigned_at expired)
- Identifies the highest open slot on the platform
- Issues a move order: vehicle travels gw_platform pts from current slot to target slot
- This is a short intra-platform move, not a full trip
- Existing shuffle infrastructure: `run_5v_shuffle_forward` in `jpod_vehicle_runtime.rb`,
  `shuffle_forward_all_platforms` in `jpod_animator.rb`
- Key difference from existing shuffle: triggered by idle detection, not by 5V test

### Vehicle doors
Bill will tag left/right door geometry in the pod component models. Once tagged,
`vehicle_transform_for` should orient the vehicle so doors face the platform loading area.
Door orientation = perpendicular to forward, toward the "inner" side of the curve.
No code change needed yet — waiting for model work.

### gw_lift TODO
Both `ensure_platform_host_guideway` copies have a TODO comment. Lift-equipped stations
need a gw_lift segment type. Affects: beam_path lookup key, slot math, possibly track_index.

### FALLBACK in slot log
Tier 2 (FALLBACK) still used because platform_endpoint_points returns nil for S001.
Tier 2 with track_index=1 gives correct results — low priority to fix to Tier 1.

## Files changed this session
- `jpod_vehicle_anim.rb` — snap in build_fleet, _point_along_polyline helper
- `jpod_animator.rb` — ensure_platform_host_guideway (map.json gw_platform path + track_index=1)
- `jpod_platform.rb` — ensure_platform_host_guideway (same), Tier 2 track_index from guideway

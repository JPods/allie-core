# TFTS — 20260613T164218
problem:   gw_platform maneuver len mismatch — TickLog minor_defects on hold_loop and park maneuvers
fault_ref: (no standalone fault file — emerged from TickLog log analysis after plat_pts orientation fix)
arc:
  - try:      Identified TickLog delta < 0 on hold_loop[11/11], hold_loop[9/9], gw_platform_park_ps7.
              Root cause hypothesis: Natalie trip.json includes gw_platform; pod's seed_pos (bounds.center)
              has wrong Z vs path, causing _project_t_on_polyline to return t_proj > 0 at maneuver start.
              man[:len] = full path length; actual travel = (1-t_proj) × len → expected > actual → delta < 0.
    result:   Confirmed for park maneuver: seed_pos = pod_pos (bounds.center, Z≈4165mm) vs path Z≈5144mm.
    revealed: bounds.center Z differs from path Z by ~1m (vehicle height/2). 3D projection is off.
              For departure: clip_start already handles gw_platform via _pts_tail_from_near.
              For arrival: park maneuver uses seed_pos: pod_pos — wrong Z.

  - try:      Fix park maneuver seed_pos (arrival end):
              Replace seed_pos: pod_pos with seed_pos: pod.current_maneuver&.dig(:pts)&.last || park_pts.first.
              The completed maneuver's last point IS gw_platform entry at the correct path Z.
              This is Nora/Sally replacing Natalie's gw_platform behavior with station-specific behavior.
    result:   succeeded
    revealed: The principle applies to all three clip_start sites:
              (1) _dispatch_hold_loop_for_pod: departure, uses transformation.origin → prefer pod.pose.first
              (2) _dispatch_next_sequential: departure from parked slot → same fix
              (3) originating chain exit: uses bounds.center → prefer pod.pose.first
              All three updated to use pod.pose.first as the path-correct seed position.

principle: |
  Natalie issues trips that include gw_platform by track name. That is correct and expected.
  Nora and Sally must REPLACE gw_platform behavior at both ends of a trip:
    - DEPARTURE: clip_start: true clips gw_platform pts from the pod's actual slot position.
                 Seed position must be pod.pose.first (last rendered path point, correct path Z),
                 not transformation.origin or bounds.center (entity Z may differ from path Z by vehicle height/2).
    - ARRIVAL: park maneuver seed_pos must be the preceding maneuver's path endpoint (pod.current_maneuver[:pts].last),
               which connects exactly to park_pts[0] at the correct path Z. t_proj ≈ 0 → man[:len] = actual travel.
  The rule: pod.pose.first for departures; pod.current_maneuver[:pts].last for arrivals.
  Never use bounds.center or transformation.origin as seed_pos for platform track maneuvers.

domain:    SU

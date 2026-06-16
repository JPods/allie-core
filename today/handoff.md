# Handoff — 2026-06-16

## Step 4 COMPLETE and VALIDATED

Animator reads model.json (5-section v1.0 schema) instead of map.json.
Pods route correctly: 2_thru_dip, NORA_0001 S006→S007 and NORA_0004 S007→S006, 13 segs each.

### Commits this session
- e8535f9 — Animator reads model.json (load_model_json + model_json_to_map_compat)
- f404789 — Two bugs fixed: complete routing_graph + v5 lines.json chain access

### Root causes found and fixed

1. routing_graph incomplete (noelle.rb generate_network_json):
   Pass 1 only gave pass-through successors from map.json track data.
   Missing: gw_near_main_1→gw_platform_in branch; no cp_out_N→seg_* links.
   Fix: Pass 2 reads consecutive pairs from all chains in lines.json natalie section.
        Pass 3 adds cp_out_N→seg_id and seg_id→cp_in_N from canonical connections.

2. v5 lines.json not handled (jpod_animator.rb _load_formation_lines):
   _departure_tracks/_arrival_tracks/_passthrough_tracks read top-level keys
   but v5 moved chains under lj['natalie'].
   Fix: hoist lj['natalie'] to top level on load.

## Open Issues

### Sally advance SKIPPED (FAULT filed 20260616T054917-fault.md)
advance_pod_slot reports "path too short" for ps3→ps4 advance on gw_platform_parking.
Distance is ~2500mm (correct slot spacing) but path clip fails length check.
Effect: platform queue jams after first arrivals; ps2/ps3 pods never dispatch.

### Pods in trip_complete not redispatching
NORA_0001/0004 arrive ps1, compact loop targets=[4] but reserved_by_others=[2,3].
Secondary effect of Sally advance SKIPPED above.

## Next Steps

1. Fix Sally advance_pod_slot "path too short" for gw_platform_parking ps3→ps4
2. Test Build + Animate on station_line_end and traffic_circle models
3. Step 5: remove map.json fallback from jpod_vehicle_anim.rb

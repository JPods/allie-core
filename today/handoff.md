# Handoff — 2026-06-11 (session 3)

## Status
CCW violation + direct-to-final-slot fixes applied and committed (7898850). Ready to re-run platform_shuffle test.

## What was fixed this session

**Root cause:** `_platform_pts_entry_first` used pod_pos as orientation fallback when `gw_platform_parking` is absent from the lookup. JPods_station_parking has no `gw_platform_parking` — it uses `gw_platform_in2` as its final landing track. When a pod advances past the platform midpoint, `d_rev < d_fwd` → pts reversed → advance travels toward entry end → CCW violation.

**Four fixes applied (7898850):**

1. `_platform_pts_entry_first` — replace pod_pos fallback with Sally ps1 slot_position anchor.
   Sally.init_from_model uses raw pts direction (no reversal when gw_platform_parking absent).
   ps1 anchor matches that frame exactly. pod_pos was unreliable past midpoint.

2. `_advance_platform_queues` — direct-to-final-slot compaction.
   Sort pods DESCENDING by slot. Assign targets: rank 0 → cap, rank 1 → cap-1, etc.
   Highest slot advances first (clears track for pods behind). Break after first per tick (1s stagger).
   With cap=9 and 2 pods: tick 1 → highest pod to ps9, tick 2 → remaining to ps8.

3. `advance_pod_slot` — release stale Sally slot when pod not in @@pods.
   Stops "not in active pods" spam; unblocks ps9 for subsequent pods.

4. `compact_platform_idle` — nil guard for model.entities (matches confirm_slots fix from session 2).

## Re-run platform_shuffle test

Reload both files in SketchUp Ruby console:
```
load Sketchup.find_support_file('jpod_vehicle_anim.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_sally.rb', 'Plugins/su_jpods')
```

Then: Workflow → Station Test → JPods_station_parking → platform_shuffle

**Expected behavior:**
- nora_001 (loops=1) departs for hold_loop; Sally fires 1s advancement cycle
- Tick 1: highest-slot pod advances directly to ps9
- Tick 2 (1s later): next pod advances directly to ps8
- Both pods eventually exit via originating chain; remaining count drops to 0
- Test polls `remaining == 0` → PASS

**Watch for:**
- `[Sally] queue advance: NORA_000x psN → ps9` (tick 1)
- `[Sally] queue advance: NORA_000x psM → ps8` (tick 2)
- No CCW violations; no pods passing through each other
- `shuffle_parked ps9/9 — at highest slot, queueing exit`
- `originating chain → gw_cp_out_0` + `erased at ...`

## If test passes: 6-template regression
Re-run platform_shuffle for all 6 templates.
- JPods_station_parking ← current focus
- station_line_end
- station_thru_dip ✓
- traffic_circle7
- JPods_station_parking (network path, step 2)

## Pre-network audit (still pending)
Check JPods_station_parking and traffic_circle7 landing_chains:
- Rule: last track must be gw_platform_parking (or equivalent), NOT gw_platform
- station_thru_dip fixed prior session ✓
- station_line_end confirmed correct ✓
- JPods_station_parking — CHECK lines.json in_cp0/in_cp1
- traffic_circle7 — CHECK lines.json

## Key files
```
su_jpods/jpod_vehicle_anim.rb  — _platform_pts_entry_first, advance_pod_slot, compact_platform_idle
su_jpods/jpod_sally.rb         — _advance_platform_queues
```

# Handoff — 2026-06-21

## Where We Stopped

Forward-backward review of v2 complete. su-real comments added to all 8 v2 modules.
Three code changes from physical system survey. Physical systems improvement plan written
(50 items, 9 categories A-I). Device intelligence architecture (Section I) established.
Bill corrected: "no memory → no cumulative experience → no wisdom."

## What was completed today

### Forward-backward review (Axiom 23) — 2 forward + 1 backward pass
- **Forward pass 1** (prior context): interfaces, naming, error handling
- **Backward pass** (prior context): Sally integration, Natalie capacity, Nora alias, graceful stop
- **Forward pass 2** (this session): found 3 bugs:
  1. Noelle v2 connection dedup inverted — better connection rejected, worse kept
  2. Animation double-registered pods with Sally (init + start loop)
  3. Compute geometry succ_of overwritten by loop — kept last not first

### su-real comments — all 8 v2 modules annotated
Physical system survey covered all 4 codebases:
- JPodsSM_RPi: 10Hz loop, I2C/Romeo, encoder+ToF+HuskyLens, mapSM.json
- JRobots_4WD: differential steering, waypoint graph, AprilTag floor markers
- JRobots_FullScale: CAN bus, 3kW PMSM, door cycle (Willi), stub
- JRobots_SkyRide: VESC, 300W brushless, hang detection, stub

### Three SU code changes from physical survey
1. **Curve-radius speed cap** — Nora propose() uses sqrt(0.3 * g * min_radius) from pts circumradius. Matches physical maxLateralG=0.3. Animation _maneuver_to_hash computes speed_cap_in.
2. **Rich ezone stop-wait logging** — records {yielder, blocker, time, remaining_mm}. Reset prints pod-pair tallies. session_summary method returns structured data.
3. **Session summary JSON** — Animation.stop() writes anim-session-summary.json to process/inbox with per-station throughput + ezone data.

### Physical systems improvement plan — readmes/physical-systems-improvement-plan.md
- 50 items across 9 categories (A-I)
- Section I: Device Intelligence — 12 items for per-device learning
- Key principles:
  - SU-generated IDs are the authority (A5) — same names everywhere
  - seg_ decomposes to many physical sub-segments (A6)
  - All animated paths require declared constraint mechanisms (G1, G3)
  - No memory → no cumulative experience → no wisdom (I1)
  - Every processor learns; Allie harvests, reflects, instructs (I4, I5)
  - Device autonomy levels: earned trust, not configured permission (I9)
  - Station-as-teacher: Sally coaches pods (I10)

### Bill's correction on memory
"No memory = no learning" → "No memory → no cumulative experience → no wisdom."
The difference between wisdom and knowledge is scars. This is why context compaction
is destructive — it throws away the reasoning chain, the failures, the scars.
Use Allie's memory to build experience over time. Saved as memory + updated in plan.

## Open items for next session

1. **Build and run v2** — Load network model, Build (Noelle v2), Populate, Start animation.
   Real faults beat review passes at this point.
2. **Populate v2** — needs populate_fleet and clear_all_pods implementations
3. **Console v2** — jpod_console.rb still references old task system
4. **Trip Simulator v2** — currently loads from codearchive
5. **Handoff.md was stale** (June 7) — Allie's nightly hasn't run since templates were approved.
   Check allie-reflect.py status.
6. **Map-v2 draft** (from Allie's May 20 deliberation) already uses SU IDs (S048.gw_platform)
   — confirms A5 was emerging. Revisit that schema now that Compute v2 produces the data.

## Key commits (Allie repo, today)
- `1824764` — TFTS: su-real bridge + physical systems improvement plan (38 items)
- `f20d892` — Physical plan Section I: device intelligence (12 items)
- `e715efb` — Physical plan: SU IDs authority, seg_ sub-segments

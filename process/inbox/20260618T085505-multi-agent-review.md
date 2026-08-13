# Multi-Agent Log Review — 2_thru_dip Animation
# Generated: 2026-06-18T08:55:05Z
# Based on: 20260612T042239 run logs + June 12 trip reports

---

## Source material

- `20260612T042239-proof-summary.json` — SC_Greenville_Bolden Noelle proof (56 severe, all 4 stations)
- `20260612T042313-trip-report-NORA_0001.json` — NORA_0001 trip s001→s002 (deviated: 9 skipped, 24 defects)
- `20260612T042239-trip-plan-NORA_0001.json` — authorized 25-seg plan
- `20260612T042239-fault.md` — Natalie junction gap fault at startup
- Animation stacking log from Bill's report (vehicle stacking at s006 platform)

---

## Noelle's View — Network Geometry

**What Noelle sees:**

Proof scan shows 56 severe errors across 4 stations, 0 ok. Every track fails.
Root cause: `lines.computed.json` is missing or stale for all 4 stations in
2_thru_dip/SC_Greenville_Bolden. The June 12 run predates the Compute pipeline
fixes (bezier centerline correction, direction normalization, gap auto-correction)
that were completed June 18.

Specific geometry defects in the trip report:

| Track | Issue | Evidence |
|-------|-------|----------|
| s001.gw_far_main | no_geometry | status=authorized_only, skipped |
| s001.gw_cp_out_lead_0 | no_geometry | authorized_only |
| s003.gw_cp_in_lead_0 | no_geometry | authorized_only |
| s003.gw_near_main_1 | no_geometry | authorized_only |
| s004.gw_cp_in_1 | no_geometry | authorized_only |
| s004.gw_cp_in_lead_1 | no_geometry | authorized_only |
| s004.gw_cp_out_0 | no_geometry | authorized_only |
| seg_s004_cp0_s002_cp0 | no_geometry | connection segment absent |
| s002.gw_platform | no_geometry | authorized_only |

Also: junction gaps of 100mm, 116mm, 312mm, 2519mm, 5009mm, 9548mm, 20012mm,
440439mm — all are proximity fallback artifacts from missing/wrong pts_mm.
The 440439mm "gap" at s002.gw_cp_in_0 (440 meters) is Nora jumping from the
last s004 exit point to s002 entrance — no connection segment geometry.

**Noelle's corrections:**

1. Rebuild 2_thru_dip / SC_Greenville_Bolden (re-generates beam geometry, segments)
2. Run Compute on all 4 stations:
   - station_line_end (s001, s002): direction normalization + bezier centerline correction
   - station_thru_dip (s003, s004): direction normalization + bezier centerline correction
3. Verify lines.computed.json for each station shows 0 SEVERE gaps
4. Re-run proof scan — expect all green

---

## Natalie's View — Routing and Dispatch

**What Natalie sees:**

Startup fault: `4 junction gap(s) on route s002→s003` — gaps of 100.1mm, 116.2mm,
312.5mm, 312.5mm. These are NOT real gaps; they are Noelle's no_geometry artifacts
propagating into Natalie's build_maneuvers gap check. Once Noelle's Compute is correct,
these disappear.

Trip NORA_0001 verdict: `deviated`. 9 of 25 authorized segs were no_geometry → skipped.
`build_maneuvers` reversed 4 tracks per trip:
  - gw_platform_out, gw_near_main_1, gw_platform_in, gw_platform_parking
These reversals should be baked into `lines.computed.json` by Noelle's direction
normalization step — Natalie should never need to reverse at trip dispatch time.
That these are still reversed at dispatch means Compute has not been run on
2_thru_dip since the direction normalization fix (commit 21cd72b).

130 proximity fallbacks per trip = lines.computed.json missing declared successors.
After Rebuild+Compute, network.json is regenerated with correct successor declarations
and proximity fallbacks drop to 0.

`dispatch_idle nil:NilClass` error: `undefined method 'each' for nil:NilClass`.
Recurring, caught by rescue. Does not crash animation. Root cause not yet pinpointed
(likely in bfs_route or build_maneuvers when map_data is partially stale). Low priority
— network Rebuild should resolve it if it's driven by stale map data.

**Natalie's corrections:**

1. After Noelle Rebuild+Compute: regenerate network.json (Build → network.json includes
   correct declared successors from lines.computed.json)
2. Expect 0 track reversals at dispatch time after direction normalization runs in Compute
3. Expect 0 proximity fallbacks after correct successor declarations
4. Investigate dispatch_idle nil error — add defensive nil guard to
   `build_maneuvers(seg_ids, ...)` call if `seg_ids` could be nil despite `unless` check

---

## Nora's View — Vehicle Execution

**What Nora sees:**

Trip NORA_0001 completed (completed=true) — Nora reached s002 gw_platform_parking.
But execution was wrong throughout:

| Segment | Expected (s) | Actual (s) | Actual speed (mm/s) | Note |
|---------|-------------|-----------|-------------------|------|
| s001.gw_platform | 0.926 | 0.409 | 18.77 | 2x fast |
| s001.gw_far_main_2 | 2.54 | 0.314 | 67.15 | 8x fast — proximity jump |
| seg_s003_cp1_s004_cp1 | 29.627 | 0.588 | 417.85 | 50x fast — 245m in 0.6s |
| s002.gw_platform_parking | 1.565 | 0.035 | — | near-instant |

The enormous speed ratios are Nora's proximity jumps: when no_geometry skips a track,
the next track's entry point may be far from the last known position, so the "gap
travel" speed is 5–50x authorized. Authorized speed is 8.3 m/s.

4 tracks had `actual_ms: null` — maneuver completed with no measurable time. These
are instantaneous jumps, not travel.

9 tracks skipped entirely. Nora traveled 25 legs on only 16 track segments.

**Nora's corrections:**

Nora's execution is correct given the geometry she received. All deviations are
downstream of Noelle's missing geometry. After Rebuild+Compute:
- Expect 0 no_geometry tracks
- Expect 0 proximity jumps
- Expect actual_s ≈ expected_s (within 20% for normal operation)
- Expect 0 null actual_ms

No Nora code changes needed. Nora's reporting is accurate.

---

## Sally's View — Station Management

**What Sally sees:**

Platform stacking at s006 — vehicles did not shuffle forward, stacked up on arrival.

Root cause identified: `confirm_slots` ghost re-admission loop.

NORA_0004 sequence:
1. Arrives s006, Sally assigns ps2. Sally writes `parked_station_id=s006`, `parking_slot=2`.
2. NORA_0004 departs on next trip. Removed from `@@pods` (active fleet).
3. Entity persists in model with `parked_station_id=s006` (never cleared on departure).
4. `confirm_slots` entity scan finds entity with `e_sid=s006`, `parking_slot=4` (stale).
5. Position snap: bounds_center near ps1. `traveling_ids` does NOT include NORA_0004
   (it's not `state=:traveling` — it's not in `@@pods` at all).
6. Snap corrects to ps1. `confirmed[ps1] = "NORA_0004"` written.
7. `advance_pod_slot: NORA_0004 not in active pods — releasing stale slot`.
   `release_slot` clears in-memory. But next sweep: step 3 repeats.
8. `confirm_slots reconciled: ps1: nil→"NORA_0004"` on every Natalie sweep.
9. ps1 perpetually occupied by a ghost. NORA_0005 and NORA_0006: `no reachable slot`.

**Sally's fix (applied 2026-06-18):**

`confirm_slots` now builds `active_pod_ids` (all pods in @@pods, regardless of state)
in addition to `traveling_ids`. Ghost guard added in entity scan:

```ruby
next if anim_running && !active_pod_ids.include?(nid)
```

When animation is running, any pod entity not in the active fleet is a ghost from a
completed/departed trip. Skip it. The entity's stale `parked_station_id` does not
constitute occupancy.

Pass 2a (platform_vehicles inbound reservations) is still the authority for
in-transit reservations — pods actively traveling to their assigned slot are
protected even after the entity scan skips their ghost.

**Sally's remaining corrections:**

After ghost fix:
1. Verify NORA_0005 and NORA_0006 can claim ps1 when it becomes free
2. Verify `advance_platform_queues` fires and pods shuffle forward
3. Verify no `confirm_slots reconciled` loop after NORA_0004 departs

---

## Work Sequence

The correct order for making 2_thru_dip / SC_Greenville_Bolden fully operational:

1. **Reload su_jpods** — picks up noelle.rb (Compute fixes) and jpod_sally.rb (ghost guard)
2. **Open 2_thru_dip.skp (or SC_Greenville_Bolden)**
3. **Rebuild** — regenerates beam geometry, connection segments, lines.computed.json
   for all 4 stations with direction normalization + bezier centerline correction
4. **Run Noelle proof** — verify 0 severe gaps across all 4 stations
5. **Animate** — expect clean platform flow: vehicles shuffle forward, no stacking
6. **Observe Natalie log** — expect 0 track reversals, 0 proximity fallbacks, 0 dispatch_idle errors
7. Write TFTS for animation stacking arc once step 5 confirms fix

---

## Open questions for Bill

1. Is the model currently named `2_thru_dip.skp` or has it been renamed to SC_Greenville_Bolden?
   The proof summary shows SC_Greenville_Bolden with station_line_end + station_thru_dip.
2. After Rebuild confirms clean, should Natalie's per-trip direction reversal log
   (`[Natalie] reversed <track>`) be treated as a warning (Noelle didn't normalize) or
   silent (Noelle already handled it)? If Compute is correct, this log should never fire.
3. The `dispatch_idle nil:Nilalie error` — want to chase the nil source, or accept the
   rescue and move on once network.json is current?

# Handoff — 2026-06-08

## What was accomplished

### 1. geometry.json — all 4 templates complete and correct

| Template | Tracks | Key corrections |
|----------|--------|----------------|
| JPods_station_parking | 20 | Flattened to single ring_z=5143.9mm (zero Z differences) |
| station_line_end | 14 | gw_cp_in_0 + gw_uturn_0 corrected; upper/lower levels preserved |
| station_thru_dip | 19 | gw_cp_in_0/1 + gw_uturn_0/1 corrected; platform dip preserved |
| traffic_circle7 | 24 | gw_cp_in_0/1/2/3 corrected from neighbor Z; no uturn tracks |

Committed: "95% with z-bumps and station defects" (earlier in session)

### 2. Z-bump root cause identified (both anomalies)

**187.5mm internal gw_ bump (gw_cp_in_lead)** — extracted.json path only:
- Step 6 ran before snap_to_cp_centers, propagating defective gw_cp_in Z into gw_cp_in_lead
- geometry.json path: gw_cp_in pre-corrected at ring_z; Step 6 doesn't run → bump gone
- **Requires plugin reload to verify**

**312mm seg_→gw_ gap** — systematic, all stations:
- beam_path (seg_) stores beam-TOP Z; geometry.json ring_z is beam-CENTER
- Gap ≈ BEAM_DEPTH/2 (~250mm) + offsets
- Deferred: fudge-factor after snap_to_cp_centers (50–1000mm gate)

### 3. Sally backtrack fix — DONE

`reserve_slot` now refuses slot 1 when higher slots are occupied and capacity > 1.
Pod is deferred to gw_platform_parking queue. Prevents the reversal Bill observed at s004.
Committed: "Sally: refuse slot 1 when higher slots occupied — prevent backtrack"

### 4. Retrospection 2026-06-08 written

---

## Open items for next session

### Priority 1: Plugin reload + verify geometry.json path
```
load Sketchup.find_support_file('jpod_path_json.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_sally.rb', 'Plugins/su_jpods')
```
Run s004→s003 animation. Verify:
- No 187.5mm internal gw_ bump
- Sally backtrack fix works (no reversal to slot 1)
- 312mm seg_→gw_ gap is still there (expected — fudge factor not yet applied)

### Priority 2: Z-bump fudge factor
In export(), geometry.json path, after snap_to_cp_centers:
- For each station, find an adjacent seg_ endpoint
- Compute Z delta (expected ~312mm)
- Apply uniform Z shift to all gw_ pts for that station
- Gate: only if 50mm < delta < 1000mm
- Log delta per station

### Priority 3: Sally slot 1 edge case
Future hardening: if pod has looped N times and slot 1 is still the only free slot,
eventually assign it anyway. Currently pods could queue indefinitely if higher slots
never free. Add loop_count tracking or a timeout threshold.

---

## Key files changed this session
- `su_jpods/jpod_sally.rb` — backtrack fix in reserve_slot
- `su_jpods/templates/track_formations/JPods_station_parking/geometry.json` — flattened
- `su_jpods/templates/track_formations/station_line_end/geometry.json` — new
- `su_jpods/templates/track_formations/station_thru_dip/geometry.json` — new
- `su_jpods/templates/track_formations/traffic_circle7/geometry.json` — new
- `readmes/retrospections/2026-06-08.md` — this session

## Z reference cheat sheet (for next session working on fudge factor)
- `seg_` pts Z: beam-TOP centerline (from beam_path)
- `geometry.json` pts_mm Z: beam-CENTER (from extracted.json formation-local)
- Gap at station junction: ~312mm = BEAM_DEPTH/2 + offsets
- `snap_to_cp_centers` snaps gw_ endpoints toward seg_ within 600mm 3D distance

# JPods Deviation Monitor — Nora Position Watchdog

**Last Updated:** 2026-05-25
**Domain:** SketchUp (SU) + Physical (PH)
**Status:** Implemented in SU; Physical implementation pending

---

## What It Is

The deviation monitor watches each Nora vehicle every animation tick. It compares
two positions:

- **Expected position** — interpolated from `man[:pts]` at the pod's current `@t`
  (the path Natalie declared and Nora is executing)
- **Actual position** — the entity's world origin from `pod.entity.transformation.origin`

When the gap exceeds tolerance, the monitor logs the event and writes a FAULT file.
After an animation run, the operator clicks **Report Route Defects** in the Animation
panel to generate a TFTS summary of everything Nora observed.

---

## Tolerances

| Axis | Tolerance | Rationale |
|------|-----------|-----------|
| XY (plan view) | 50 mm | Track alignment; beyond this, pods visually leave the guideway |
| Z (vertical) | 100 mm | Beam flex + terrain grade; Z lags because entity origin lags transform commit |

These are configurable constants in `jpod_vehicle_anim.rb`:

```ruby
DEVIATION_TOL_XY_MM = 50.0
DEVIATION_TOL_Z_MM  = 100.0
```

---

## What Gets Logged

### Per-tick check

Every tick, for each traveling pod:

1. `interpolate_pts(man[:pts], pod.t, man[:len])` → `expected_pt`
2. `pod.entity.transformation.origin` → `actual_pt`
3. Delta XY and Z computed in inches, converted to mm for reporting
4. **mm/tick** tracked: `(delta_t * man_len * 25.4).round(1)` — quantifies segment
   roughness over successive ticks. Sudden jumps in mm/tick signal a discontinuity
   at a junction (bad successor wiring or CP position mismatch in map.json).

### Event record (in `@@deviation_log`)

```ruby
{
  nora_id:     "NORA_0001",
  elapsed_s:   12.34,
  man_id:      "S003.gw_uturn_0",
  t:           0.4821,
  xy_mm:       67.3,
  z_mm:        12.1,
  mm_per_tick: 24.8,
  expected:    { x: 12340.0, y: 56780.0, z: 4600.0 },   # mm
  actual:      { x: 12407.3, y: 56780.0, z: 4600.0 }    # mm
}
```

### FAULT files

Written to `~/Allie/process/inbox/YYYYMMDDTHHMMSS-fault.md`, capped at 20 per run
to prevent inbox flood. Format:

```
# FAULT — 2026-05-25T14:32:11Z

system:      SU
detected_by: Nora
fault:       position deviation 67.3mm XY / 12.1mm Z on S003.gw_uturn_0
context:     nora_id=NORA_0001 t=0.4821 elapsed=12.34s expected=... actual=...
resolved_at:
```

---

## Report Route Defects

The **Report Route Defects** button (Animation panel, console) writes a TFTS file
that groups deviations by segment:

```yaml
# TFTS — 2026-05-25T14:45:00Z

problem:   Nora detected position deviation between interpolated path and entity origin
fault_ref: (see FAULT files in inbox with matching timestamps)
arc:
  - try:      Run animation and observe vehicle positions
    result:   Deviation detected between expected and actual XYZ
    revealed: path.json or map.json pts do not match built geometry or entity origin is offset
segments:
  - seg: S003.gw_uturn_0
    count: 14
    worst_xy_mm: 67.3
    worst_z_mm: 12.1
principle: Single segment deviation — check map.json pts accuracy for S003.gw_uturn_0
domain:    SU
```

After writing, `@@deviation_log` is cleared so the next run starts fresh.

---

## Interpreting Results

| Pattern | Likely cause |
|---------|-------------|
| All segments deviate equally | Vehicle entity origin is offset (check `vehicle_transform_for`) |
| One inter-station segment deviates | `path.json` pts don't match built guideway (re-run Build) |
| One intra-station segment deviates | `map.json` pts for that station template are wrong |
| Deviation spikes at t ≈ 0 or t ≈ 1 | CP position mismatch — stub tip vs. CP center offset |
| mm/tick jumps at segment boundary | Bad successor wiring — pod teleports to start of next segment |
| Z deviation only | `beam_path` Z is beam_top; vehicle Z should be `beam_top - BEAM_DEPTH` (hanger_z) |

---

## SketchUp Implementation

**File:** `jpod_vehicle_anim.rb`

Key methods:

| Method | What it does |
|--------|-------------|
| `check_deviation(pod, elapsed_s)` | Called every tick per traveling pod; computes delta, logs events |
| `_write_deviation_fault(evt)` | Writes a FAULT file to `~/Allie/process/inbox/` |
| `report_route_defects` | Groups `@@deviation_log` by segment, writes TFTS, clears log |

State reset on `start`:
```ruby
@@deviation_log.clear
@@prev_t_by_pod.clear
@@deviation_fault_n = 0
@@elapsed_s = 0.0
```

**Console task:** "Report Route Defects" in the Animation category.

---

## Physical Implementation (Pi — Pending)

The same logic applies to physical pods. The inputs are different but the principle
is identical: **expected position from Natalie's route vs. actual position from sensors**.

### Expected position on Pi

Natalie assigns a trip path. Each segment has a known length (mm). At any moment:

```
expected_mm = segment_start_mm + (speed_mm_per_tick * ticks_elapsed)
expected_xyz = interpolate along segment pts at (expected_mm / segment_len)
```

### Actual position on Pi

Three sensor sources, in order of preference:

1. **AprilTag** — absolute XYZ fix when a tag is in frame; most accurate
2. **ToF (VL53L0X)** — distance to nearest surface; confirms expected distance
   at known waypoints (junction markers, station entrance)
3. **Encoder** — incremental; drifts over time but gives mm/tick directly

### Deviation threshold on Pi

Physical pods move at 0.5–1.5 m/s. At 25 Hz ticks: 20–60 mm/tick expected.

Suggested thresholds (tune after first calibration run):

| Sensor | XY threshold | Z threshold |
|--------|-------------|------------|
| AprilTag (absolute) | 30 mm | 20 mm |
| ToF (waypoint check) | 50 mm | 30 mm |
| Encoder drift (accumulated) | 100 mm per meter traveled | — |

### Pi fault path

Physical Nora writes to `~/jpod_logs/faults/` when Allie's inbox is not mounted,
`~/Allie/process/inbox/` when it is. Same FAULT file format.

```python
def _write_fault(fault_text, context='', detected_by='Nora'):
    # (already in jpod_constants — see CLAUDE.md physical implementation pattern)
```

### Pi TFTS reporting

Two paths:
1. **Automatic** — after each trip completes, if `anomaly_count > 0`, append to
   `{model}.physical.json` (Axiom 9 — physical observations are separate from routing)
2. **Manual** — `allie-whatif.py` or direct TFTS write when a pattern is confirmed

`{model}.physical.json` schema `jpods-physical-v1` is the permanent store for
physical observations. FAULT files are ephemeral (resolved → archived).

---

## Connection to Allie's Learning Loop

```
Nora deviation → FAULT file → ~/Allie/process/inbox/
                                     ↓
                          allie-reflect.py (nightly)
                                     ↓
                    FAULT + no TFTS → unresolved → ouch-list candidate
                    FAULT + TFTS    → Understanding candidate (U-SK-NNN / U-PH-NNN)
                    Recurring pattern → risk escalation
```

TFTS from "Report Route Defects" includes segment IDs. Allie extracts the principle
and drafts a U-SK-NNN entry. Bill activates confirmed entries.

---

## Quick Reference

```
Run animation
  → Nora checks deviation every tick
  → Deviations > 50mm XY / 100mm Z → @@deviation_log + FAULT files (cap 20)

Stop animation
  → Click "Report Route Defects" (Animation panel)
  → TFTS written to ~/Allie/process/inbox/
  → @@deviation_log cleared

Allie reads FAULT + TFTS nightly
  → Drafts Understanding candidates
  → Flags unresolved FAULTs to ouch-list
```

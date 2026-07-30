# Track Formation Tag Discipline
**Last updated:** 2026-05-17
**Enforced by:** `Create > Validate Template Tags` — blocks Export Feature JSON until all templates pass.

---

## Curve Speed Rule

**Requirement — not yet enforced by the animator.** Ezone speed enforcement is a future task.
`radius_m` and `speed_limit_mps` are stored in `line.json`/`feature.json` as design requirements.

Every curved guideway segment has a maximum speed derived from its radius:

```
v_max_mps = sqrt(lateral_g_mps2 × radius_m)
```

Normal passenger comfort range: **0.1g – 0.3g**. Use 0.1g for conservative design.

| Formation | Segment | Radius | v_max at 0.1g | v_max at 0.3g |
|-----------|---------|--------|---------------|---------------|
| End-of-line station | `gw_uturn_0/1` | 3.5 m | 1.85 m/s (4.1 mph) | 3.21 m/s (7.2 mph) |
| Traffic circle ring | `gw_c_N_M` | ≈ 8.3 m | 2.85 m/s (6.4 mph) | 4.94 m/s (11.0 mph) |
| Straight guideway | `gw_far_main`, stubs, etc. | ∞ | cruise speed | cruise speed |

A U-turn at 3.5 m radius requires less than half the speed of a traffic circle ring arc.
Every tight-curve segment must carry `radius_m` and `speed_limit_mps` fields in its JSON spec.

---

## Design Rule — General to Specific

Tag names are written **general → specific**, left to right. Each underscore-separated
token narrows the meaning of the one before it.

```
gw_stub_pair_0_in
│   │         │ └─ direction (in)
│   │         └─── CP index (0)
│   └─────────── type (stub_pair)
└─────────────── class (gw = guideway)

cap_end
│   └── specific placement (end of stub)
└────── class (cap)

gw_c_0_1
│  │  └── to CP (1)
│  └───── from CP (0) via ring arc (c)
└──────── class (gw)
```

This rule makes tags sort naturally by class, groups related segments visually in
Entity Info lists, and prevents ambiguous names like `in_platform` or `platform_in_ramp`.

---

## First Principle — `gw_` prefix

Every guideway segment tag begins with `gw_`. No exceptions.

- `gw_0_in`, `gw_c_1_2`, `gw_stub_pair_0_out`, `gw_far_main` — correct
- `track_far`, `stub_pair`, `platform_in1`, `uturn0` — **wrong** (no `gw_` prefix on routing segments)

Exception: structural tags (`cap_end`, `canopy`) do not require the `gw_` prefix because
they are not traversed by Nora as routing segments.

---

## Complete Guideway Naming Taxonomy

### Connection stubs — `gw_stub_pair`

| Tag | Meaning |
|-----|---------|
| `gw_stub_pair_0_in` | CP 0 inbound stub — connects inter-station guideway to formation entry |
| `gw_stub_pair_0_out` | CP 0 outbound stub — connects formation exit to inter-station guideway |
| `gw_stub_pair_1_in` | CP 1 inbound stub (formations with multiple CPs) |
| `gw_stub_pair_N_in/out` | N is sequential from 0 |

One `cap_end` entity lives at the outer tip of each stub.

---

### Lift zone — `gw_lift`

Animation skips all segments whose tag begins with `gw_lift`.
Physical lift behavior is not modelled in simulation.

| Tag | Meaning |
|-----|---------|
| `gw_lift_in0` | First approach segment entering the lift zone |
| `gw_lift_in1`, `gw_lift_in2`... | Additional sequential approach segments |
| `gw_lift_parking` | Parking/holding area within lift zone |
| `gw_lift` | The lift itself — actual vertical travel segment |

---

### Platform zone — `gw_platform`

| Tag | Meaning |
|-----|---------|
| `gw_platform_in` | Single approach segment leading to platform |
| `gw_platform_in1`, `gw_platform_in2`... | Multiple approach segments — number only when more than one |
| `gw_platform_parking` | Pod holding/parking area adjacent to platform |
| `gw_platform` | The platform itself — loading and unloading zone |

---

### U-turn — `gw_uturn`

The reversing hairpin at an end-of-line station. Every U-turn is exactly two arcs.
The number encodes the **direction of travel**, not the CP number.

| Tag | Direction | Role in hairpin |
|-----|-----------|-----------------|
| `gw_uturn_0` | **far → near** | First arc — pod curves from the far-side guideway toward the near (platform) side |
| `gw_uturn_1` | **near → far** | Second arc — pod curves from the near side back onto the far-side return guideway |

**Direction rule:** `gw_uturn_0` may only be traversed far-to-near. `gw_uturn_1` may only be
traversed near-to-far. A trip sequence that reverses either constraint is invalid.

**Geometry constraint:** Each U-turn arc must subtend well under 90 degrees of arc.
JPods vehicles cannot negotiate tight curves — the actual limit is much less than 90°.
A U-turn that requires a vehicle to turn 90° or more is a design defect, not a routing
problem. Build the geometry with gentle, gradual arcs. The number of arcs needed is
determined by the geometry — place as many `gw_uturn_N` segments as the curve requires.

If a formation has U-turns at multiple CPs, qualify with the CP:
`gw_uturn_0_cp0`, `gw_uturn_1_cp0`, `gw_uturn_0_cp1`, `gw_uturn_1_cp1`.

---

### Near-side thru traffic — `gw_near`

The guideway running on the **station side** of the structure (adjacent to the platform).
Used when a pod passes through without stopping.

| Tag | Meaning |
|-----|---------|
| `gw_near_main` | Main near-side through guideway |
| `gw_near_in` | Single inbound approach section feeding `gw_near_main` |
| `gw_near_in1`, `gw_near_in2`... | Multiple inbound sections — number only when more than one |
| `gw_near_out` | Single outbound departure section leaving `gw_near_main` |
| `gw_near_out1`, `gw_near_out2`... | Multiple outbound sections — number only when more than one |

---

### Far-side thru traffic — `gw_far`

The guideway running on the **opposite side** from the platform.

| Tag | Meaning |
|-----|---------|
| `gw_far_main` | Main far-side through guideway |
| `gw_far_in` | Single inbound approach section feeding `gw_far_main` |
| `gw_far_in1`, `gw_far_in2`... | Multiple inbound sections — number only when more than one |
| `gw_far_out` | Single outbound departure section leaving `gw_far_main` |
| `gw_far_out`, `gw_far_out2`... | Multiple outbound sections — number only when more than one |

---

### Traffic circle ring — `gw_c`

| Tag | Meaning |
|-----|---------|
| `gw_c_N_M` | Ring arc from CP N to adjacent CP M (CCW) |
| `gw_c_N_N` | Bypass arc at CP N — pod skips station without stopping |
| `gw_N_in` | Entry ramp from ring merge point to CP N |
| `gw_N_out` | Exit ramp from CP N to ring diverge point |

---

## The Diagnostic Command

Run this in the SketchUp Ruby Console any time you want to see exactly what the
active model contains:

```ruby
tracks = {}
JPods::StructurePlacer.send(:harvest_track_groups, Sketchup.active_model.entities, Geom::Transformation.new, tracks, 0)
tracks.each { |id, t| puts "  #{t['tag'].ljust(30)} #{t['length_mm'].to_i.to_s.rjust(8)} mm  #{t['identity']}" }
nil
```

**Output columns:**
- `tag` — the SketchUp Tag (layer) assigned to the group. `Layer0` means untagged — fix it.
- `length_mm` — segment length in millimetres. This is Nora's odometer.
- `identity` — the group's instance name. Used to parse length if tag is not yet assigned.

**Run it after every tagging session.** Compare output to the formation's `line.json`.

---

## Required Outcomes

A template passes when all five conditions are met:

### 1. No Layer0 tags
Every `gw_` group must have a named tag. `Layer0` means Noelle cannot see the segment.

```
Layer0    91665 mm  gw_0_out     ← FAIL — fix in Entity Info
gw_0_out  91665 mm  gw_0_out     ← PASS
```

### 2. In/out balance
The count of tags ending in `_in` must equal the count ending in `_out`.
Every entry to a formation must have a matching exit.

```
FAIL: 2 _in tracks vs 1 _out tracks
  missing _out for: platform_in
```

### 3. Naming convention matches `line.json`
Open the formation's `line.json`. Every `"layer"` value in that file must appear as a tag
in the harvest output. Any tag in the model not in `line.json` needs investigation.

### 4. Correct stub count
Each CP must have exactly one `gw_stub_pair_N_in` and one `gw_stub_pair_N_out`.
A 4-CP circle needs 8 stubs total.

### 5. Correct `cap_end` count
One `cap_end` per stub pair tip. Count must equal number of stub pairs.
A stray cap (count > stubs) means an orphaned cap needs to be found and deleted.

---

## The Gate Command

After fixing tags run the full validator. It loads every template, not just the active one:

```ruby
JPods::StructurePlacer.validate_template_tags(Sketchup.active_model)
```

Output is a checklist. All templates must show `PASS` before `Export Feature JSON` is allowed.

**Note:** If the active model IS one of the templates (e.g. you have `traffic_circle7/model.skp`
open), the validator uses it directly — no "insert into itself" error.

---

## Naming Conventions by Formation Type

### Traffic circle — `circle_Ncp`

| Segment type | Tag pattern | Example | Role |
|-------------|-------------|---------|------|
| Ring arc CP N → CP M | `gw_c_N_M` | `gw_c_0_1` | `ring_arc` |
| Bypass arc at CP N | `gw_c_N_N` | `gw_c_1_1` | `bypass_arc` |
| Entry ramp at CP N | `gw_N_in` | `gw_2_in` | `entry_ramp` |
| Exit ramp at CP N | `gw_N_out` | `gw_2_out` | `exit_ramp` |
| Inbound stub at CP N | `gw_stub_pair_N_in` | `gw_stub_pair_0_in` | `stub` |
| Outbound stub at CP N | `gw_stub_pair_N_out` | `gw_stub_pair_0_out` | `stub` |
| Connection end cap | `cap_end` | `cap_end` | `cap` |

**Trip example — CP0 to CP2, bypass CP1:**
`gw_stub_pair_0_in → gw_0_in → gw_c_0_1 → gw_c_1_1 → gw_c_1_2 → gw_2_out → gw_stub_pair_2_out`

### Station end-of-line — `station_1cp`

Pod enters CP0, stops at platform, U-turns, exits CP0.

| Tag | Role | Length (mm) |
|-----|------|------------|
| `gw_stub_pair_0_in` | stub | varies |
| `gw_platform_in1` | routing | 20,358.9 |
| `gw_platform_in2` | routing | 12,986.6 |
| `gw_platform` | routing | 7,682.9 |
| `gw_uturn_0` | routing | 4,873.7 |
| `gw_uturn_1` | routing | 4,872.9 |
| `gw_far_main` | routing | 21,084.4 |
| `gw_far_out` | routing | 19,905.9 |
| `gw_stub_pair_0_out` | stub | varies |
| `gw_parking_in` | parking | 6,265.2 |
| `gw_parking` | parking | 6,124.3 |
| `gw_parking_slope` | slop | 20,810.7 |

**Trip array:**
`gw_stub_pair_0_in → gw_platform_in1 → gw_platform_in2 → gw_platform → gw_uturn_0 → gw_uturn_1 → gw_far_main → gw_far_out → gw_stub_pair_0_out`

### Station through — `station_2cp`

Pod enters CP0, stops at platform, exits CP1. Used by `station_solar`.

| Tag | Role |
|-----|------|
| `gw_stub_pair_0_in` | stub |
| `gw_platform_in1` | routing |
| `gw_platform_in2` | routing |
| `gw_platform` | routing |
| `gw_platform_out` | routing |
| `gw_stub_pair_1_out` | stub |

**Trip array:**
`gw_stub_pair_0_in → gw_platform_in1 → gw_platform_in2 → gw_platform → gw_platform_out → gw_stub_pair_1_out`

### Station through-dip — `station_2cp`

Same as through-station but guideway dips below an obstacle before the platform.

| Tag | Role |
|-----|------|
| `gw_stub_pair_0_in` | stub |
| `gw_dip` | routing |
| `gw_dip_connector` | routing |
| `gw_platform_in1` | routing |
| `gw_platform` | routing |
| `gw_platform_out` | routing |
| `gw_stub_pair_1_out` | stub |

**Trip array:**
`gw_stub_pair_0_in → gw_dip → gw_dip_connector → gw_platform_in1 → gw_platform → gw_platform_out → gw_stub_pair_1_out`

---

## How to Fix a Tag in SketchUp

1. Run the diagnostic command — note the identity of the Layer0 group
2. Click the group in the viewport
3. Open **Window > Entity Info**
4. Set the **Tag** field to the correct name (e.g. `gw_c_0_0`)
5. Press Enter — the tag is applied immediately (no save needed to take effect)
6. Re-run the diagnostic command — confirm the tag appears

---

## How to Add a New Formation

1. Build the geometry in SketchUp. Group each routing segment separately.
2. Name each group instance to match its intended tag (e.g. name = `gw_0_in`)
3. Set the Tag field in Entity Info to match the instance name
4. Run the diagnostic command — confirm all segments appear with correct tags
5. Write `line.json` documenting the naming convention and predicted stop route
6. Run `validate_template_tags` — fix any failures
7. Run `Export Feature JSON` — writes `feature.json` with lengths, roles, and CP map

---

## Length Standard

All lengths stored as `length_mm` (float, 1 decimal).

**Parse priority:**
1. Identity string: `"gw, 12.9866 m (JPod, c_bezier)"` → `12986.6` mm
   Handles both `.` and `,` as decimal separator (European locale models)
2. Recursive edge sum (fallback)
3. `null` — needs manual measurement

Nora uses `length_mm` as her odometer. A wrong or null length on a stop route
segment means Nora stops at the wrong position. Every segment on a stop route
must have a verified `length_mm` before physical testing.

---

## Current Status

| Template | CP count | Stubs | Layer0 | Balance | Ready |
|----------|----------|-------|--------|---------|-------|
| `traffic_circle7` | 4 | 8 ✅ | 0 ✅ | 4/4 ✅ | **✅ PASS** |
| `station_line_end` | 1 | 2 | 0 | imbalance | 🔧 fix |
| `station_solar` | 2 | 4 | 1 | imbalance | 🔧 fix |
| `station_parking` | 1 | 2 | 3 | unknown | 🔧 fix |
| `station_thru_dip` | 2 | 4 | 2 | unknown | 🔧 fix |

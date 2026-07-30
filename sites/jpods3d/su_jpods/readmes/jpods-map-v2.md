# JPods Map v2 Schema

**File:** `{model_name}.map.json`
**Schema identifier:** `jpods-map-v2`
**Written by:** Noelle — on every Build and Validate
**Last updated:** 2026-05-20

---

## Purpose

`{model}.map.json` is the single authoritative physical network document for a JPods
model. It is derived from `followme.json` (the geometric source) and `noelle_features.json`
(the behavioral source). All consumers read this file; none of them re-derive geometry
from the SketchUp model at runtime.

Consumers and what they need:

| Consumer | What it reads | Why |
|---|---|---|
| SketchUp animator (`jpod_vehicle_anim.rb`) | `lines{}` via `build_map_lookup` | Geometry for pod movement — coordinate arrays, not SketchUp entities |
| TripPlanner (`jpod_trip_planner.rb`) | `lines{}`, `stations{}`, `ezones[]` | Builds self-contained `trip.json`; all geometry copied into trip at planning time |
| Nora (Pi vehicle) | Via `trip.json` only — never opens `map.json` | Trip is self-contained; map is too large for Pi to hold open mid-trip |
| Natalie (dispatcher) | `stations{}`, `ezones[].ezone_status` | Platform availability and ezone clearance before dispatching |
| Alice (billing) | `energy_model`, `network_summary` | Billing by energy consumed; capacity planning |
| Route-Time | `nominal_time_s`, `length_mm` | O-D travel time matrix; never recalculates fixed geometry |

---

## Who Writes It

Noelle writes `map.json` on every Build and Validate via `generate_map_json(model)`.
It is also callable standalone:

```ruby
JPods::Noelle.generate_map_json(model)
```

Never written by hand. Never patched in place. Every Build overwrites the previous file.

The call chain from Build:

```
Noelle.generate_feature_json(model)     # validates structure, writes feature.json
  └── Noelle.generate_map_json(model)   # always called after feature.json succeeds
```

---

## File Location

```
{model_dir}/{model_name}.map.json
```

Sits next to the `.skp` file. Example:

```
~/Documents/skp_jpods/CA_Gilroy_Clean/
  CA_Gilroy_Clean.skp
  CA_Gilroy_Clean.followme.json     ← geometric source
  CA_Gilroy_Clean.map.json          ← this file
  CA_Gilroy_Clean.feature.json      ← routing behavioral declarations
  CA_Gilroy_Clean.physical.json     ← Nora's physical observations (separate schema)
```

---

## Coordinate System and Units

- All distances: millimeters (mm)
- All coordinates: mm, right-hand system (x = east, y = north, z = up)
- All timestamps: ISO-8601 UTC with Z suffix (`YYYY-MM-DDTHH:MM:SSZ`)
- Speed: mm/s
- Energy: watt-hours (Wh)
- Grade: percent (dz/len * 100; uphill positive)

---

## Top-Level Structure

```json
{
  "schema":               "jpods-map-v2",
  "mapId":                "CA_Gilroy_Clean",
  "generated_at":         "2026-05-20T18:30:00Z",
  "generated_by":         "Noelle",
  "followme_hash":        "a3f9c2...(SHA-256)",
  "last_physical_survey": null,
  "geolocation":          { ... },
  "stations":             { ... },
  "lines":                { ... },
  "ezones":               [ ... ],
  "dead_end_nodes":       [ ... ],
  "network_summary":      { ... }
}
```

### geolocation{}

Present when the SketchUp model has been geolocated (satellite imagery placed). Derived
from the `model` block of `followme.json`. Absent when followme.json has no lat/lng.

```json
"geolocation": {
  "latitude":          37.0058,
  "longitude":        -121.5683,
  "altitude_m":        91.0,
  "north_angle":        0.0,
  "coordinate_system": "model_mm",
  "note": "x/y/z in map.json are mm in SketchUp model space; use north_angle to rotate to true north"
}
```

| Field | Type | Description |
|---|---|---|
| `latitude` | float | WGS-84 decimal degrees — origin of the SketchUp model |
| `longitude` | float | WGS-84 decimal degrees |
| `altitude_m` | float | Meters above sea level at model origin |
| `north_angle` | float | Degrees clockwise from model +Y axis to true north |
| `coordinate_system` | string | Always `"model_mm"` — all map.json coords are mm in model space |

For web map display, apply the north_angle rotation to convert model-space x/y to
true north/east before projecting against the lat/lng origin.
```

### schema

Always `"jpods-map-v2"`. Consumers check this before parsing. If the value is missing
or different, the consumer must refuse to use the file and request a new Build.

### mapId

The model's base filename without extension. Matches the `.skp` file. Used as a
namespace when multiple maps are loaded simultaneously.

### generated_at

UTC timestamp of the Build or Validate run that produced this file.

### generated_by

Always `"Noelle"`. Records which agent is the authority for this file.

### followme_hash

SHA-256 hex digest of the `followme.json` content at the time of the Build.

**Stale detection:** TripPlanner and the SketchUp animator compute the SHA-256 of the
current `followme.json` before consuming `map.json`. If the hashes do not match, the
map is stale — the model geometry was changed after the last Build. The consumer must
refuse to proceed and prompt the user to run Build again.

Nora cannot check this directly (she reads only `trip.json`), but TripPlanner embeds
the hash check at trip generation time. A stale map cannot produce a valid trip.

### last_physical_survey

`null` until Nora completes a full traversal of every inter-station segment and reports
back. Natalie (dispatcher) can age-gate on this field — refuse to dispatch new trips
on segments that have not been surveyed within a configurable interval.

When Nora completes a full survey, this field becomes a UTC timestamp. Not yet
implemented in the Pi software as of 2026-05-20.

---

## stations{} Block

Keyed by station_id (e.g., `"S048"`). Built by scanning SketchUp model entities for
components with a `structure_id` JPods attribute. Template key is matched against
`noelle_features.json` by case-insensitive prefix match on the component definition name.

```json
"stations": {
  "S048": {
    "station_id":        "S048",
    "template":          "station_thru_dip",
    "platform_capacity": 3,
    "dwell_time_s":      30,
    "cargo_direction":   "bidirectional",
    "cp_count":          2,
    "center_mm":         { "x": 21625.0, "y": -8200.0, "z": 4630.0 }
  }
}
```

| Field | Type | Description |
|---|---|---|
| `station_id` | string | Matches JPods `structure_id` attribute on the SketchUp component |
| `template` | string | Component definition name, or matched `noelle_features.json` key |
| `platform_capacity` | integer | Derived from `gw_platform` line: `floor(length_mm / 6000)`, minimum 1 |
| `dwell_time_s` | integer | Default 30 s. Future: configurable per template |
| `cargo_direction` | string | `bidirectional`, `inbound`, or `outbound` |
| `cp_count` | integer or null | From `noelle_features.json` `cp_count` field; null if template not found |
| `center_mm` | object or null | `{x, y, z}` midpoint of the platform guideway — used for map pins and proximity queries; null if no `gw_platform` line found |

`platform_capacity` represents the number of 6-meter pods that fit simultaneously on
the platform guideway. The 6000 mm divisor is the nominal pod length.

---

## lines{} Block

The unified line dictionary. Replaces the old split `features{}`/`connections{}` blocks
from pre-v2 formats. Keys use dot notation.

**Key conventions:**

| Type | Key format | Example |
|---|---|---|
| Intra-station | `{station_id}.{role}` | `S048.gw_platform` |
| Inter-station | `seg_{from}_{cpN}_{to}_{cpN}` | `seg_S048_cp1_S050_cp0` |

All lines carry the same base fields. Type-specific fields are added on top.

### Base fields (all line types)

```json
"S048.gw_platform": {
  "id":             "S048.gw_platform",
  "type":           "intra_station",
  "direction":      "internal",
  "length_mm":      18450.0,
  "speedMin":       0,
  "speedMax":       80,
  "nominal_time_s": 231,
  "startPoint":     { "x": 12400.0, "y": -8200.0, "z": 4630.0 },
  "endPoint":       { "x": 30850.0, "y": -8200.0, "z": 4630.0 },
  "pts":            [ { "x": 12400.0, "y": -8200.0, "z": 4630.0 },
                      { "x": 30850.0, "y": -8200.0, "z": 4630.0 } ],
  "segments":       [ ... ],
  "markers":        []
}
```

| Field | Type | Description |
|---|---|---|
| `id` | string | Dot-notation key; matches the dict key |
| `type` | string | `intra_station` or `inter_station` |
| `direction` | string | `inbound`, `outbound`, or `internal` |
| `length_mm` | float | Total arc length of the line |
| `speedMin` | integer | mm/s — minimum allowed speed on this line |
| `speedMax` | integer | mm/s — maximum allowed speed on this line |
| `nominal_time_s` | integer | `ceil(length_mm / speedMax)` — worst-case transit time; Route-Time reads this directly |
| `startPoint` | object | `{x, y, z}` in mm — first point of the line (same as `pts[0]`) |
| `endPoint` | object | `{x, y, z}` in mm — last point of the line (same as `pts[-1]`) |
| `pts` | array | Ordered `{x,y,z}` points along the full path — one per track start point plus the final endpoint; used by the animator for smooth interpolation |
| `segments` | array | Ordered subsegment records (see below) |
| `markers` | array | Waypoint markers on inter-station lines (empty for intra-station) |
| `successors` | array | **Inter-station only.** Line IDs that follow this line, derived from ezone topology. Intra-station lines do not carry this field. |
| `predecessors` | array | **Inter-station only.** Line IDs that precede this line, derived from ezone topology. Intra-station lines do not carry this field. |

### pts[] — why it exists

The animator (`build_map_lookup`) needs ordered coordinate arrays for pod interpolation.
Without `pts[]`, the animator fell back to a 2-point straight line from `startPoint`
to `endPoint` — correct for single-track lines, wrong for curved or waypointed connections.

For a connection with N waypoints, `followme.json` stores N+1 Bezier approximation tracks.
`pts[]` contains the N+1 start points plus the final endpoint, giving N+2 total points that
trace the actual path. This is what the animator interpolates along.

**For single-track lines** (no waypoints), `pts` has exactly 2 entries: start and end.
**For waypointed lines**, `pts` has one entry per track start, plus the final endpoint.

### nominal_time_s

Computed by Noelle at Build from fixed geometry. Route-Time reads this directly and
never recalculates it for fixed network geometry. The formula is:

```
nominal_time_s = ceil(length_mm / speedMax)
```

This is a worst-case (slowest) estimate. It bounds the O-D matrix without simulation.
Actual trip time will be faster when the pod accelerates to cruise speed; `nominal_time_s`
is conservative by design and is used for scheduling capacity, not for billing.

### Per-Segment Record (inside segments[])

Each line contains one segment record per Bezier approximation track from `followme.json`.
Connections with waypoints have multiple tracks (and thus multiple segment records). The
array structure also supports future grade-change modelling.

```json
{
  "id":        1,
  "xs":        12400.0,  "ys": -8200.0, "zs": 4630.0,
  "xe":        30850.0,  "ye": -8200.0, "ze": 4630.0,
  "len":       18450.0,
  "lenCum":    18450.0,
  "radius":    0,
  "dx":        1.0,      "dy": 0.0,     "dz": 0.0,
  "grade_pct": 0.0
}
```

| Field | Type | Description |
|---|---|---|
| `id` | integer | 1-based index within the line's segments array |
| `xs/ys/zs` | float | Start coordinates in mm |
| `xe/ye/ze` | float | End coordinates in mm |
| `len` | float | Length of this segment in mm |
| `lenCum` | float | Cumulative length from line start to this segment's end |
| `radius` | float | 0 = straight; non-zero = curve radius in mm (reserved) |
| `dx/dy/dz` | float | Unit direction vector (rounded to 4 decimal places) |
| `grade_pct` | float | Grade percent: `(ze - zs) / len * 100`; uphill positive |

### Marker Record (inside markers[])

Present on inter-station lines only. Markers are waypoints placed by the user with the
Marker Tool to route the guideway around obstacles.

```json
{
  "id":      1,
  "dist_mm": 45200.0,
  "x":       88400.0,
  "y":       -6100.0,
  "z":       4640.0,
  "value":   0,
  "color":   "YELLOW"
}
```

| Field | Type | Description |
|---|---|---|
| `id` | integer | 1-based sequential marker index on this line |
| `dist_mm` | float | Distance from line start to this marker |
| `x/y/z` | float | Marker position in mm |
| `value` | integer | Reserved for future speed-zone or grade annotation |
| `color` | string | Marker color from SketchUp (typically `YELLOW`) |

### Intra-Station Additional Fields

Fields added when `type == "intra_station"`:

| Field | Type | Description |
|---|---|---|
| `station` | string | Parent station ID (`"S048"`) |
| `role` | string | Guideway role within the station template (see Speed Table below) |

For `role == "gw_platform"` only:

| Field | Type | Description |
|---|---|---|
| `dwell_time_s` | integer | Nominal dwell time at this platform — default 30 s |
| `platform_capacity` | integer | Maximum simultaneous pods — derived from `floor(length_mm / 6000)` |
| `cargo_direction` | string | `bidirectional`, `inbound`, or `outbound` |

### Inter-Station Additional Fields

Fields added when `type == "inter_station"`:

| Field | Type | Description |
|---|---|---|
| `from` | object | `{ station: "S048", cp_index: 1 }` |
| `to` | object | `{ station: "S050", cp_index: 0 }` |
| `energy_model` | object | Energy estimate (see below) |

`cp_index` is the stub_pair number, 0-based, matching the `cp{N}` portion of the
inter-station segment ID. `seg_S048_cp1_S050_cp0` has `from.cp_index = 1`,
`to.cp_index = 0`.

### energy_model (inter-station lines)

```json
"energy_model": {
  "estimated_wh":         3.42,
  "grade_penalty_factor": 1.08,
  "method":               "grade_adjusted_flat_rate"
}
```

| Field | Type | Description |
|---|---|---|
| `estimated_wh` | float | Estimated energy for one pod traversal of this line |
| `grade_penalty_factor` | float | Multiplier applied to flat rate for grade; range 1.0–1.5 |
| `method` | string | Always `"grade_adjusted_flat_rate"` in current implementation |

**Formula:**

```
flat_rate      = 27.5 Wh/km  (nominal ~200 kg pod at 50 km/h on level ground)
energy_km      = length_mm / 1_000_000
grade_factor   = 1.0 + min(abs(grade_pct) / 100 * 0.5, 0.5)
estimated_wh   = flat_rate * energy_km * grade_factor
```

Alice uses `estimated_wh` as the billing basis. Calibrate `flat_rate` against physical
telemetry when available — the current value is a design estimate.

---

## Speed Table by Role

Design targets. All values in mm/s. Calibrate against physical system when telemetry
is available. `nominal_time_s` is computed from `speedMax`.

| Role | speedMin | speedMax | Notes |
|---|---|---|---|
| `gw_platform` | 0 | 80 | Dwell; nearly stationary |
| `gw_platform_in` | 50 | 2000 | Deceleration approach to platform |
| `gw_platform_out` | 50 | 2000 | Acceleration from platform |
| `gw_platform_parking` | 20 | 500 | Slow park maneuver |
| `gw_near_main` | 500 | 8000 | Near-side merge/diverge |
| `gw_far_main` | 500 | 8000 | Far-side through |
| `gw_far_out` | 50 | 2000 | Far-side exit |
| `gw_lift` | 50 | 2000 | Vertical lift guideway |
| `gw_lift_in` | 50 | 2000 | Lift approach |
| `gw_lift_parking` | 20 | 500 | Lift parking |
| `gw_uturn_0` | 50 | 1000 | U-turn inbound |
| `gw_uturn_1` | 50 | 1000 | U-turn outbound |
| `gw_stub_pair_0_in` | 50 | 4000 | CP0 inbound stub |
| `gw_stub_pair_0_out` | 50 | 4000 | CP0 outbound stub |
| `gw_stub_pair_1_in` | 50 | 4000 | CP1 inbound stub |
| `gw_stub_pair_1_out` | 50 | 4000 | CP1 outbound stub |
| `_inter_station` | 500 | 13900 | ~50 km/h cruise |
| `_default` | 50 | 2000 | Fallback for unrecognized roles |

---

## ID Convention — v1 vs. v2

| Format | Intra-station key | Source |
|---|---|---|
| v1 (pre-map-v2) | `S048_gw_platform` (underscore) | `followme.json` original convention |
| v2 | `S048.gw_platform` (dot) | `map.json` v2 canonical |

`followme.json` still uses underscores (`S048_gw_platform`) because it predates the v2
dot convention. Noelle converts at map generation time:

```
followme.json key: "S048_gw_platform"   →   map.json key: "S048.gw_platform"
```

`build_map_lookup` in `jpod_vehicle_anim.rb` registers both forms so that trip.json
files generated before the convention change still animate:

```ruby
# Underscore alias registered alongside dot key:
under = line_id.sub('.', '_')
lookup[under] ||= entry unless under == line_id
```

Consumers should write the dot-notation key. The underscore alias is a backward-compat
shim, not a supported primary key.

---

## ezones[] Block

Merge and diverge points where two inter-station lines share an endpoint. Noelle
detects these geometrically: any endpoint where exactly two `seg_*` lines arrive
and one departs is classified as a merge ezone.

```json
"ezones": [
  {
    "id":               1,
    "type":             "merge",
    "ezone_status":     "clear",
    "center_mm":        { "x": 88400.0, "y": -6100.0, "z": 4640.0 },
    "radius_mm":        30000,
    "inPoint1":         { "lineId": "seg_S012_cp1_S048_cp0", "distFrom": 0, "distTo": 48200.0 },
    "inPoint2":         { "lineId": "seg_S044_cp1_S048_cp0", "distFrom": 0, "distTo": 31700.0 },
    "outPoint":         { "lineId": "seg_S048_cp1_S050_cp0", "distFrom": 0, "distTo": 3000 },
    "ezMaxSpeed":       2000,
    "curveRadius":      8000,
    "maxLateralG":      0.3,
    "approach_decel_mm":30000
  }
]
```

| Field | Type | Description |
|---|---|---|
| `id` | integer | Sequential 1-based index within this map |
| `type` | string | `merge` (two lines converge) or `diverge` (one line splits) |
| `ezone_status` | string | Runtime field: `clear`, `occupied`, or `blocked` — Natalie writes this |
| `center_mm` | object | `{x, y, z}` — the shared endpoint coordinate where the merging lines meet; derived from the actual geometry, not computed as an average |
| `radius_mm` | integer | Ezone exclusion radius in mm; default 30000 (30 m); pods within this radius of center_mm respect ezone_status |
| `inPoint1` | object | First incoming line: `lineId`, `distFrom`, `distTo` (mm from line start) |
| `inPoint2` | object | Second incoming line (merge) or null (diverge) |
| `outPoint` | object | Outgoing line: `lineId`, `distFrom`, `distTo` — `distTo` = 3000 mm past junction |
| `ezMaxSpeed` | integer | mm/s — maximum speed within the ezone |
| `curveRadius` | float | mm — minimum curve radius at this junction |
| `maxLateralG` | float | Maximum lateral G at `ezMaxSpeed` through `curveRadius` |
| `approach_decel_mm` | integer | mm before ezone entry where Nora begins deceleration |

`center_mm` is the actual shared endpoint of the merging lines — the real merge point,
not an approximation. Used by the map UI for ezone highlighting and by Natalie for
distance-based approach deceleration triggers.

**ezone_status is the only runtime-mutable field in map.json.** Natalie updates
`ezone_status` in memory before dispatching. The on-disk map.json always has
`"clear"` at generation time. Natalie's in-memory state is the live authority;
never read `ezone_status` from disk for dispatching decisions.

Current implementation detects merge ezones only. Diverge ezone detection (one
arriving, two departing) is not yet implemented.

---

## dead_end_nodes[] Block

Inter-station lines whose endpoint does not match the startPoint of any other
inter-station line. Nora must stop before reaching these endpoints.

```json
"dead_end_nodes": [
  {
    "lineId":   "seg_S050_cp1_S048_cp0",
    "endPoint": { "x": 12400.0, "y": -8200.0, "z": 4630.0 }
  }
]
```

| Field | Type | Description |
|---|---|---|
| `lineId` | string | The inter-station line that terminates here |
| `endPoint` | object | `{x, y, z}` in mm — the terminal point |

A dead-end node is a network design artifact, not necessarily an error. Line-end
stations (`station_line_end` template) produce dead-end nodes by design. Nora's
runtime stops at the terminal gw_platform; the dead-end node is the inter-station
exit that leads into the station's inbound stub.

---

## network_summary{} Block

Aggregate statistics for Alice and Route-Time. Computed by Noelle at Build from
the `lines{}` dict.

```json
"network_summary": {
  "total_lines":               21,
  "intra_station_lines":       17,
  "inter_station_connections":  4,
  "station_count":              4,
  "total_length_mm":        487300,
  "ezone_count":                0,
  "solar_panel_count":          0,
  "bbox": {
    "min": { "x": -12400.0, "y": -8500.0, "z":  4600.0 },
    "max": { "x": 156000.0, "y":  8100.0, "z": 12500.0 }
  }
}
```

| Field | Type | Description |
|---|---|---|
| `total_lines` | integer | Count of all entries in `lines{}` |
| `intra_station_lines` | integer | Lines with `type == "intra_station"` |
| `inter_station_connections` | integer | Lines with `type == "inter_station"` |
| `station_count` | integer | Entries in `stations{}` |
| `total_length_mm` | integer | Sum of all `length_mm` values across all lines |
| `ezone_count` | integer | Length of `ezones[]` |
| `solar_panel_count` | integer | Reserved; always 0 until solar panel geometry is tracked |
| `bbox` | object or null | Axis-aligned bounding box of the full network, computed from all `pts[]` across all lines; null if no pts were generated |

`bbox.min` and `bbox.max` are `{x, y, z}` objects in mm. The map UI uses these to set
the initial viewport. Route-Time uses them for the O-D grid bounds. Null when no
geometry was exported (empty followme.json).

`total_length_mm` includes both intra-station and inter-station lines. For billing
by network-km, use only inter-station lines (`inter_station_connections` lines with
`type == "inter_station"`).

---

## Backward Compatibility

`build_map_lookup` in `jpod_vehicle_anim.rb` reads three formats in priority order:

1. **v2 `lines{}`** — dot-notation keys, unified dict. Read first.
2. **Legacy `segments{}`** — old inter-station dict (pre-v2 format). Checked only if
   the `lines{}` key is absent or empty.
3. **Legacy `features{}`** — old per-station feature dict with nested `lines[]` arrays.
   Checked only if both `lines{}` and `segments{}` are absent.

Models that have not been rebuilt after the v2 format was introduced will still animate.
The legacy paths are read-only shims; no new code should write to them.

After a model is rebuilt (Build or Validate run), the output is always v2. There is
no mechanism to produce a legacy format from current Noelle code.

---

## Stale Map Detection Protocol

1. **TripPlanner** — before generating `trip.json`, TripPlanner computes
   `SHA-256(followme.json)` and compares it to `map.json["followme_hash"]`. If they
   differ, TripPlanner aborts and reports: `"map.json is stale — run Build first"`.

2. **SketchUp animator** — checks for the `lines{}` key. If missing, reports:
   `"map.json has no lines — run Build first"`. Does not check `followme_hash`
   at animation time (the animator is used after Build, not as a validation gate).

3. **Nora (Pi)** — relies on TripPlanner's gate. A trip.json that passes TripPlanner's
   hash check is considered valid. Nora does not independently validate the map.

---

## Relationship to Other JSON Files

```
followme.json          ← Noelle reads this at Build
noelle_features.json   ← Noelle reads this at Build (template behavioral rules)
        │
        ▼
  map.json (this file) ← Noelle writes; all consumers read
        │
        ├── trip.json          ← TripPlanner copies geometry from map.json into trip
        ├── feature.json       ← Written by Noelle separately; behavioral rules per instance
        └── physical.json      ← Written by Nora; physical observations (separate schema)
```

`physical.json` is intentionally separate. If physical observations were merged into
`map.json`, every Build would erase them. See `readmes/jpods-physical-v1.md` (when
written) for the physical observation schema.

---

## Standalone Generation

To regenerate `map.json` without running a full Build (e.g., after a minor change
that does not affect geometry):

```ruby
# SketchUp Ruby Console:
JPods::Noelle.generate_map_json(Sketchup.active_model)
```

This reads the current `followme.json`, recomputes all fields, and overwrites
`map.json`. It does not validate station geometry or run Noelle's direction checks.
Use full Build for validation.

---

## All Timestamps UTC

`generated_at` uses the Z suffix (`2026-05-18T22:08:32Z`). Ruby:

```ruby
Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
```

See `readmes/jpods-utc-standard.md` for the project-wide UTC requirement.

---

## Example Fragment — CA_Gilroy_Clean (2026-05-20)

Abridged; real file has 17 station lines and 4 inter-station connections.

```json
{
  "schema":               "jpods-map-v2",
  "mapId":                "CA_Gilroy_Clean",
  "generated_at":         "2026-05-20T18:30:00Z",
  "generated_by":         "Noelle",
  "followme_hash":        "a3f9c2d1...",
  "last_physical_survey": null,

  "geolocation": {
    "latitude": 37.0058, "longitude": -121.5683,
    "altitude_m": 91.0, "north_angle": 0.0,
    "coordinate_system": "model_mm",
    "note": "x/y/z in map.json are mm in SketchUp model space; use north_angle to rotate to true north"
  },

  "stations": {
    "S012": {
      "station_id": "S012", "template": "station_line_end",
      "platform_capacity": 3, "dwell_time_s": 30,
      "cargo_direction": "bidirectional", "cp_count": 1,
      "center_mm": { "x": 5200.0, "y": -8200.0, "z": 4630.0 }
    },
    "S048": {
      "station_id": "S048", "template": "station_thru_dip",
      "platform_capacity": 3, "dwell_time_s": 30,
      "cargo_direction": "bidirectional", "cp_count": 2,
      "center_mm": { "x": 21625.0, "y": -8200.0, "z": 4630.0 }
    }
  },

  "lines": {
    "S048.gw_platform": {
      "id": "S048.gw_platform", "type": "intra_station",
      "station": "S048", "role": "gw_platform",
      "direction": "internal",
      "length_mm": 18450.0, "speedMin": 0, "speedMax": 80,
      "nominal_time_s": 231,
      "dwell_time_s": 30, "platform_capacity": 3,
      "cargo_direction": "bidirectional",
      "startPoint": { "x": 12400.0, "y": -8200.0, "z": 4630.0 },
      "endPoint":   { "x": 30850.0, "y": -8200.0, "z": 4630.0 },
      "pts": [
        { "x": 12400.0, "y": -8200.0, "z": 4630.0 },
        { "x": 30850.0, "y": -8200.0, "z": 4630.0 }
      ],
      "segments": [{
        "id": 1,
        "xs": 12400.0, "ys": -8200.0, "zs": 4630.0,
        "xe": 30850.0, "ye": -8200.0, "ze": 4630.0,
        "len": 18450.0, "lenCum": 18450.0,
        "radius": 0, "dx": 1.0, "dy": 0.0, "dz": 0.0, "grade_pct": 0.0
      }],
      "markers": []
    },

    "seg_S048_cp1_S050_cp0": {
      "id": "seg_S048_cp1_S050_cp0", "type": "inter_station",
      "from": { "station": "S048", "cp_index": 1 },
      "to":   { "station": "S050", "cp_index": 0 },
      "direction": "outbound",
      "length_mm": 124800.0, "speedMin": 500, "speedMax": 13900,
      "nominal_time_s": 9,
      "startPoint": { "x": 31200.0, "y": -8100.0, "z": 4650.0 },
      "endPoint":   { "x": 156000.0, "y": -7900.0, "z": 4680.0 },
      "pts": [
        { "x": 31200.0, "y": -8100.0, "z": 4650.0 },
        { "x": 156000.0, "y": -7900.0, "z": 4680.0 }
      ],
      "segments": [{
        "id": 1,
        "xs": 31200.0, "ys": -8100.0, "zs": 4650.0,
        "xe": 156000.0, "ye": -7900.0, "ze": 4680.0,
        "len": 124800.0, "lenCum": 124800.0,
        "radius": 0, "dx": 0.9999, "dy": 0.0016, "dz": 0.0002,
        "grade_pct": 0.024
      }],
      "markers": [],
      "successors": [], "predecessors": [],
      "energy_model": {
        "estimated_wh": 3.43, "grade_penalty_factor": 1.0,
        "method": "grade_adjusted_flat_rate"
      }
    }
  },

  "ezones": [],
  "dead_end_nodes": [
    { "lineId": "seg_S050_cp1_S048_cp0",
      "endPoint": { "x": 31200.0, "y": -8100.0, "z": 4650.0 } }
  ],
  "network_summary": {
    "total_lines": 21,
    "intra_station_lines": 17,
    "inter_station_connections": 4,
    "station_count": 4,
    "total_length_mm": 633200,
    "ezone_count": 0,
    "solar_panel_count": 0,
    "bbox": {
      "min": { "x": -12400.0, "y": -8500.0, "z": 4600.0 },
      "max": { "x": 156000.0, "y":  8100.0, "z": 12500.0 }
    }
  }
}
```

---

## What Is Not in This File

| Data | Where it lives | Why separate |
|---|---|---|
| Physical observations (bumps, anomalies) | `{model}.physical.json` | Build would erase them every time |
| Behavioral routing rules | `{model}.feature.json` | Noelle writes separately; keyed by instance not template |
| Template behavioral declarations | `noelle_features.json` | Plugin-level authority; not per-model |
| Trip plans | `{model}.trip.json` | Self-contained for Nora; derived from map.json at planning time |
| Geometric source | `{model}.followme.json` | map.json is derived from this; followme is the authoring format |
| Ezone runtime state | Natalie in-memory | On-disk map.json always shows "clear"; runtime is Natalie's domain |

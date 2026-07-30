# JPods Trip JSON Schema v2 — `jpods-trip-v2`
**Created:** 2026-05-20  
**Status:** Authoritative — update when any field changes  
**Owner:** TripPlanner  
**Related:** `trip-json-schema.md` (v1), `jpods-map-v2.md`, `jpods-utc-standard.md`

---

## Purpose

`jpods-trip-v2` is a self-contained navigation package. TripPlanner writes it once; Nora reads it once at dispatch time and never opens `map.json` mid-trip.

Key design goals:

- **Self-contained.** Every physical fact Nora needs — segment geometry, speeds, ezone data, markers — is embedded at plan time. No mid-trip lookups.
- **Single format for all environments.** The same file drives the SketchUp simulator and the physical Pi dispatch. No environment-specific fields.
- **Alice's billing input.** Passenger count, cargo weight, CarryOn UUID, and energy estimate are first-class fields. Alice reads the trip file directly; no side-channel needed.
- **Stale-safe.** Three checks before Nora executes. If the network was rebuilt since the trip was written, Nora refuses.

---

## Who Writes It

**TripPlanner** — after reading `map.json v2`.

TripPlanner:
1. Reads current `map.json` (schema `jpods-map-v2`)
2. Plans routes for all O-D pairs in the network
3. Embeds all physical data (geometry, speeds, ezones, markers) from `map.json` into each trip segment
4. Writes one `{model_name}.trip.json` containing all planned trips

TripPlanner also feeds the **Route-Time O-D matrix**: one trip per O-D pair, with `estimated_time_s` and `estimated_energy_wh` aggregated by `route_id`.

---

## Who Reads It

| Consumer | What they read | Why |
|----------|---------------|-----|
| **Nora** | `segments[]`, `speedMin`/`speedMax`, `ezone_entries[]`, `segment_action`, `trip_hash` | Navigation — segment sequence, speeds, ezone data, tamper check |
| **Dispatcher / Natalie** | `trip_id`, `expires_at`, `route_id` | Dispatch management — assign to Nora, check expiry, correlate route |
| **Alice** | `passenger_count`, `cargo_kg`, `carryon_uuid`, `station_pair`, `estimated_energy_wh` | Billing — fare calculation, energy cost, CarryOn ledger entry |
| **Route-Time** | `estimated_time_s`, `estimated_energy_wh` aggregated by `route_id` | O-D matrix — travel time and energy cost per station pair |

---

## File Location

```
{model_dir}/
  {model_name}.trip.json          ← all O-D trips for this network
  {model_name}.map.json           ← authoritative network map (map.json v2)
  {model_name}.feature.json       ← routing declarations (Noelle writes on every Build)
  {model_name}.physical.json      ← physical observations (Nora writes; never erased by Build)
```

One trip file per model. All O-D pairs are entries in the `trips[]` array. TripPlanner overwrites the file on every replan.

---

## Top-Level Structure

```json
{
  "schema":           "jpods-trip-v2",
  "model_id":         "CA_Gilroy_Clean",
  "generated_at":     "2026-05-20T14:30:00Z",
  "generated_by":     "TripPlanner",
  "map_version":      "jpods-map-v2",
  "map_generated_at": "2026-05-20T14:25:00Z",
  "trips": [ ... ]
}
```

### Top-Level Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `schema` | string | Always `"jpods-trip-v2"`. Version identifier. |
| `model_id` | string | Model filename without extension. Matches `map.json.model_id`. |
| `generated_at` | string | UTC timestamp when TripPlanner wrote this file. Z suffix required. |
| `generated_by` | string | Always `"TripPlanner"`. |
| `map_version` | string | Always `"jpods-map-v2"`. Declares which map schema was read at plan time. |
| `map_generated_at` | string | Copied from `map.json.generated_at` at plan time. **Stale detection anchor.** If this does not match the current `map.json.generated_at`, the trip file must be replanned — the network topology has changed since these trips were written. |

---

## Stale Trip Detection

Three checks before Nora executes a trip. All three must pass.

| Check | How |
|-------|-----|
| **Map freshness** | `trip.map_generated_at` must equal current `map.json.generated_at`. If they differ, the network was rebuilt. Replan. |
| **Expiry** | If `trip.expires_at` is set: `now (UTC) < expires_at`. If expired, reject and request a new dispatch. |
| **Tamper detection** | `trip.trip_hash` must equal SHA-256 of the pipe-delimited ordered segment ID list. If mismatch, the file was modified after planning. Reject. |

**Never patch a stale trip.** Delete and replan.

---

## trips[] Array

Each entry is one planned O-D route. The array contains all O-D pairs TripPlanner resolved at plan time.

### Trip-Level Fields

```json
{
  "trip_id":             null,
  "route_id":            "S048_to_S050",
  "from":                "S048",
  "to":                  "S050",
  "hops":                1,
  "expires_at":          "2026-05-20T16:30:00Z",
  "trip_hash":           "a3f2b9c1d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1",
  "total_length_mm":     412800,
  "estimated_time_s":    247,
  "estimated_energy_wh": 0.83,
  "passenger_capacity":  6,
  "passenger_count":     null,
  "cargo_kg":            null,
  "carryon_uuid":        null,
  "station_pair":        "S048:S050",
  "segments":            [ ... ]
}
```

### Trip-Level Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `trip_id` | string or null | UUID assigned by Dispatcher at dispatch time. **Null in pre-computed files.** Alice and Nora use this as the billing and telemetry correlation key once a trip is live. |
| `route_id` | string | Canonical label for this O-D pair. Format: `"{from}_to_{to}"`. Stable across dispatches — the same label for every trip from S048 to S050 regardless of when it runs. Route-Time aggregates `estimated_time_s` and `estimated_energy_wh` by `route_id`. |
| `from` | string | Origin station ID. Matches a station ID in `map.json`. |
| `to` | string | Destination station ID. |
| `hops` | integer | Count of inter-station connections. `1` = direct (origin → destination with no intermediate stations). Multi-hop not yet implemented — see Open Items. |
| `expires_at` | string or null | UTC expiry timestamp. TripPlanner sets to `generated_at + TTL`. Nora refuses to execute if `now > expires_at`. **Null = no expiry** — used in the SketchUp simulator only. Physical Pi dispatch always sets a TTL. |
| `trip_hash` | string | SHA-256 of the pipe-delimited ordered segment ID list (e.g. `"S048.gw_platform|seg_S048_cp1_S050_cp0|S050.gw_platform"`). Nora verifies before departure. Tamper detection. |
| `total_length_mm` | integer | Sum of `length_mm` across all segments in this trip. |
| `estimated_time_s` | number | Sum of `nominal_time_s` from `map.json` lines for every segment in the trip. Route-Time reads this for the O-D matrix. |
| `estimated_energy_wh` | number | Sum of `energy_model.estimated_wh` from `map.json` lines. Alice uses this for energy cost billing. Route-Time uses this for O-D energy analysis. |
| `passenger_capacity` | integer | Maximum occupancy for this pod type. Sourced from the station template. Alice enforces booking limit — she will not accept a `passenger_count` above this value. |
| `passenger_count` | integer or null | Number of passengers. **Null until dispatch.** Alice bills by this count after the Dispatcher assigns the trip. |
| `cargo_kg` | number or null | Cargo mass. **Null until dispatch.** Affects energy cost calculation — heavier loads draw more power. Alice applies the cargo surcharge formula. |
| `carryon_uuid` | string or null | MyCarryOn UUID of the requestor. **Null until dispatch.** Alice uses this to link the billing record to the rider's sovereign identity. |
| `station_pair` | string | Fare zone key for Alice. Format: `"{from}:{to}"`. Alice looks up the base fare from the fare zone table using this key. |

---

## segments[] Array

Ordered — first segment is the first physical move from the origin platform. Nora travels in array order. No skipping, no reordering.

Each segment embeds **all physical data from map.json at plan time**. Nora never re-queries map.json during a trip.

### Segment Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Dot-notation line ID. Intra-station: `"S048.gw_platform"`. Inter-station: `"seg_S048_cp1_S050_cp0"`. These IDs are the canonical keys — they match `trip.json` and `physical.json` exactly. |
| `type` | string | `"intra_station"` or `"inter_station"`. |
| `station` | string | *(intra_station only)* The station this segment belongs to. |
| `role` | string | *(intra_station only)* The functional role of this guideway within the station (e.g. `"platform"`, `"uturn"`, `"pass_through"`). |
| `from` | object | *(inter_station only)* `{ "station": "S048", "cp_index": 1 }`. Origin CP. `cp_index` matches the stub_pair numbering in `noelle_features.json`. |
| `to` | object | *(inter_station only)* `{ "station": "S050", "cp_index": 0 }`. Destination CP. |
| `length_mm` | integer | Physical length of this segment in millimeters. |
| `cumulative_mm` | integer | Distance from trip start (origin platform departure) to the **beginning** of this segment. Nora reports position as `cumulative_mm + mm_into_segment`. Enables network-level position reporting and telemetry aggregation. |
| `speedMin` | integer | Minimum speed on this segment (mm/s). Nora must not travel slower than this except during dwell. |
| `speedMax` | integer | Maximum speed on this segment (mm/s). Nora must not exceed this. |
| `startPoint` | object | `{ "x": ..., "y": ..., "z": ... }` in mm. Physical start of this segment. |
| `endPoint` | object | `{ "x": ..., "y": ..., "z": ... }` in mm. Physical end of this segment. |
| `sub_segments` | array | Sub-segments with full geometry. See Sub-Segment Fields below. |
| `markers` | array | AprilTag markers on this segment. See Marker Fields below. |
| `segment_action` | string | What Nora does on this segment. See Segment Action Values below. |
| `dwell_time_s` | number | Seconds the pod waits at this segment. Non-zero only at origin platform (boarding) and destination platform (alighting). Zero for all transit and arrive segments. |
| `ezone_entries` | array | Ezone data for this segment. Nora checks this without opening map.json. See Ezone Entry Fields below. |

### Sub-Segment Fields

Each entry in `sub_segments[]` is one physical arc of the guideway.

| Field | Type | Description |
|-------|------|-------------|
| `xs`, `ys`, `zs` | number | Start point coordinates (mm). |
| `xe`, `ye`, `ze` | number | End point coordinates (mm). |
| `len` | number | Length of this sub-segment (mm). |
| `len_cum` | number | Cumulative length from segment start to end of this sub-segment (mm). |
| `radius` | number or null | Arc radius (mm). Null for straight sub-segments. |
| `dx`, `dy`, `dz` | number | Unit direction vector at sub-segment start. |
| `grade_pct` | number | Grade as a percentage. Positive = uphill, negative = downhill. |

### Marker Fields

Each entry in `markers[]` is one AprilTag marker on this segment.

| Field | Type | Description |
|-------|------|-------------|
| `marker_id` | string | AprilTag marker ID. |
| `dist_mm` | integer | Distance from segment start to marker (mm). |
| `type` | string | Marker function — e.g. `"ezone_entry"`, `"ezone_exit"`, `"speed_limit"`, `"station_approach"`. |

### Segment Action Values

| Value | When | What Nora does |
|-------|------|---------------|
| `depart` | Origin platform segment | Pod departs. Doors close, cargo locked. Pod accelerates onto the mainline. |
| `transit` | All en-route inter-station segments | Normal travel. Nora maintains speed within `speedMin`/`speedMax`. |
| `arrive` | Destination approach segment | Deceleration sequence begins. Nora reduces speed to arrive at platform speed. |
| `dwell` | Terminal segment at destination | Pod enters platform. Doors open. Passengers alight and board. Pod waits `dwell_time_s`. |

### Ezone Entry Fields

Each entry in `ezone_entries[]` is one ezone that applies to this segment.

| Field | Type | Description |
|-------|------|-------------|
| `ezone_id` | string | Unique ezone identifier from map.json. |
| `entry_dist_mm` | integer | Distance from segment start where this ezone begins (mm). |
| `approach_decel_mm` | integer | Distance before `entry_dist_mm` where Nora must begin decelerating to reach `ez_max_speed` by entry (mm). |
| `ez_max_speed` | integer | Maximum speed inside the ezone (mm/s). |

Nora uses `ezone_entries[]` to plan her deceleration curve for each ezone on the segment. She checks this array without opening `map.json`.

---

## Example — Single Trip

```json
{
  "schema":           "jpods-trip-v2",
  "model_id":         "CA_Gilroy_Clean",
  "generated_at":     "2026-05-20T14:30:00Z",
  "generated_by":     "TripPlanner",
  "map_version":      "jpods-map-v2",
  "map_generated_at": "2026-05-20T14:25:00Z",
  "trips": [
    {
      "trip_id":             null,
      "route_id":            "S048_to_S050",
      "from":                "S048",
      "to":                  "S050",
      "hops":                1,
      "expires_at":          "2026-05-20T16:30:00Z",
      "trip_hash":           "a3f2b9c1d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1",
      "total_length_mm":     412800,
      "estimated_time_s":    247,
      "estimated_energy_wh": 0.83,
      "passenger_capacity":  6,
      "passenger_count":     null,
      "cargo_kg":            null,
      "carryon_uuid":        null,
      "station_pair":        "S048:S050",
      "segments": [
        {
          "id":              "S048.gw_platform",
          "type":            "intra_station",
          "station":         "S048",
          "role":            "platform",
          "length_mm":       18500,
          "cumulative_mm":   0,
          "speedMin":        500,
          "speedMax":        2000,
          "startPoint":      { "x": 12400, "y": 8300, "z": 4600 },
          "endPoint":        { "x": 12400, "y": 26800, "z": 4600 },
          "sub_segments":    [ { "xs": 12400, "ys": 8300, "zs": 4600,
                                 "xe": 12400, "ye": 26800, "ze": 4600,
                                 "len": 18500, "len_cum": 18500,
                                 "radius": null,
                                 "dx": 0.0, "dy": 1.0, "dz": 0.0,
                                 "grade_pct": 0.0 } ],
          "markers":         [],
          "segment_action":  "depart",
          "dwell_time_s":    30,
          "ezone_entries":   []
        },
        {
          "id":              "seg_S048_cp1_S050_cp0",
          "type":            "inter_station",
          "from":            { "station": "S048", "cp_index": 1 },
          "to":              { "station": "S050", "cp_index": 0 },
          "length_mm":       376300,
          "cumulative_mm":   18500,
          "speedMin":        2000,
          "speedMax":        15000,
          "startPoint":      { "x": 12400, "y": 26800, "z": 4600 },
          "endPoint":        { "x": 84200, "y": 63100, "z": 4600 },
          "sub_segments":    [ "..." ],
          "markers":         [
            { "marker_id": "AT-0042", "dist_mm": 94000, "type": "ezone_entry" },
            { "marker_id": "AT-0043", "dist_mm": 112000, "type": "ezone_exit" }
          ],
          "segment_action":  "transit",
          "dwell_time_s":    0,
          "ezone_entries":   [
            {
              "ezone_id":          "ez_S048_cp1_crossing",
              "entry_dist_mm":     94000,
              "approach_decel_mm": 8000,
              "ez_max_speed":      3000
            }
          ]
        },
        {
          "id":              "S050.gw_platform",
          "type":            "intra_station",
          "station":         "S050",
          "role":            "platform",
          "length_mm":       18000,
          "cumulative_mm":   394800,
          "speedMin":        500,
          "speedMax":        2000,
          "startPoint":      { "x": 84200, "y": 63100, "z": 4600 },
          "endPoint":        { "x": 84200, "y": 81100, "z": 4600 },
          "sub_segments":    [ "..." ],
          "markers":         [],
          "segment_action":  "dwell",
          "dwell_time_s":    45,
          "ezone_entries":   []
        }
      ]
    }
  ]
}
```

---

## cumulative_mm — Network-Level Position Reporting

`cumulative_mm` is the distance from the trip start (origin platform departure point) to the beginning of each segment. Nora reports her live position as:

```
position = segment.cumulative_mm + mm_into_current_segment
```

This produces a single monotonically-increasing integer for the full trip — from 0 at origin platform departure to `total_length_mm` at destination platform arrival. Telemetry aggregators and Allie's nightly analysis use this to compare positions across Noras on the same route without requiring knowledge of internal segment boundaries.

---

## physical_json_check{} — Pre-Dispatch Anomaly Gate

Before the Dispatcher assigns a trip to Nora, Noelle checks `{model}.physical.json` for anomalies on every segment in the trip.

```json
{
  "physical_json_check": {
    "segments_with_anomalies": [
      {
        "segment_id":  "seg_S048_cp1_S050_cp0",
        "severity":    "minor",
        "description": "bump at 34% — column joint logged by NORA_0001"
      }
    ],
    "checked_at": "2026-05-20T14:31:00Z"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `segments_with_anomalies` | array | One entry per segment that has at least one anomaly in `physical.json`. Empty array = clean. |
| `segments_with_anomalies[].segment_id` | string | The segment ID. |
| `segments_with_anomalies[].severity` | string | Worst severity on this segment: `"minor"`, `"moderate"`, or `"severe"`. |
| `segments_with_anomalies[].description` | string | Summary of the anomaly, including location_t and source Nora. |
| `checked_at` | string | UTC timestamp of the check. Z suffix required. |

**Dispatch gate rule:**

| Severity | Action |
|----------|--------|
| `minor` | Log. Include in check result. Allow dispatch. |
| `moderate` | Warn operator. Require operator acknowledgment before dispatch. |
| `severe` | Block assignment. Flag to operator. Do not dispatch until operator signs off. |

---

## Relationship to map.json

The trip file is a **read-only snapshot** of the physical data in map.json at plan time.

| map.json | trip.json |
|----------|-----------|
| Authoritative network topology | Frozen snapshot at plan time |
| Written by Noelle (Build/Validate) | Written by TripPlanner (after map.json) |
| Changes on every network rebuild | Must be replanned after any map.json change |
| Contains all segments across all routes | Contains only segments for each planned O-D trip |

If map topology changes (any network rebuild by Noelle), all trip files for that model must be replanned. `map_generated_at` in the trip file is the anchor. Any mismatch between `trip.map_generated_at` and current `map.json.generated_at` triggers a replan.

**Trip is not a derivative of followme.json (v1).** It is a derivative of map.json (v2). The two schemas are independent lineages. The v1 trip file (`jpods-trip-v1`) remains in use for SketchUp simulator compatibility; `jpods-trip-v2` is the format for Pi dispatch and Route-Time.

---

## Field Rename History (deliberation 2026-05-20)

These renames were made during the v2 schema deliberation to eliminate ambiguity with other protocols.

| Old name | New name | Reason |
|----------|----------|--------|
| `action` | `segment_action` | `action` collides with the dispatch protocol `"action"` field. `segment_action` is unambiguous at any layer of the stack. |
| `ezones` | `ezone_entries` | `ezones` reads as a reference to the network-wide ezone registry. `ezone_entries` correctly implies per-trip, per-segment ezone data embedded at plan time. |
| `stub` | `cp_index` | `stub` was informal. `cp_index` matches the `stub_pair` numbering in `noelle_features.json` exactly, making cross-reference unambiguous. |

---

## All Timestamps — UTC with Z Suffix

All timestamps in `jpods-trip-v2` are UTC with the Z suffix. No local timestamps. No offsets.

| Field | UTC required |
|-------|-------------|
| `generated_at` | YES |
| `map_generated_at` | YES |
| `expires_at` | YES |
| `physical_json_check.checked_at` | YES |

See `jpods-utc-standard.md` for the full standard.

---

## Open Items (from deliberation 2026-05-20)

| Item | Description | Status |
|------|-------------|--------|
| **Multi-hop trips** | `hops > 1` requires a `hops[]` array describing intermediate station passes and transfer rules. Route-Time will need aggregate time/energy across hops. Not yet implemented. | Deferred |
| **TripPlanner segment validation** | TripPlanner must verify every `segment_id` exists in the current `map.json` before writing the trip file. If a segment is missing from map.json, the trip file is corrupt before Nora ever reads it. | Pending |
| **TTL policy** | What is the correct TTL for `expires_at`? Physical Pi dispatch needs a short TTL (minutes). Pre-computed simulator trips may run with `expires_at: null`. Needs an explicit policy document. | Pending |
| **cargo_kg energy formula** | The energy cost with cargo is not yet formalized. `estimated_energy_wh` currently ignores `cargo_kg`. Alice applies a flat cargo surcharge; the physics-based formula is deferred. | Deferred |

---

## Invariants — Do Not Break

1. **`map_generated_at` must match** `map.json.generated_at` before Nora executes. TripPlanner copies this value at plan time. Never fabricate or carry over from a prior plan.

2. **`trip_hash` must be verified** before departure. SHA-256 of the pipe-delimited ordered segment ID list. If the file was modified after TripPlanner wrote it, the hash will not match.

3. **`expires_at` is null only in the simulator.** Physical Pi dispatch always sets a TTL. A trip file with `expires_at: null` on a Pi is a planning error.

4. **Segments are ordered and complete.** Nora travels the `segments[]` array in order. No segment may be skipped. Every segment from origin platform departure to destination platform arrival must appear.

5. **`cumulative_mm` is computed at plan time, not at dispatch.** TripPlanner sets it. Nora reads it. No recalculation mid-trip.

6. **`trip_id` is null until Dispatcher assigns it.** TripPlanner does not generate `trip_id`. The Dispatcher generates a UUID and writes it into the trip entry at dispatch time. Alice uses this UUID as the billing correlation key.

7. **`physical_json_check` is run by Noelle at dispatch time, not at plan time.** Physical observations accumulate continuously from Nora's trips. A check at plan time would be stale by dispatch. Noelle runs the check fresh before each assignment.

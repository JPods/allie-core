# JPods Feature JSON — Schema jpods-feature-v3

**Schema:** `jpods-feature-v3`  
**Written by:** Noelle — on every Build and Validate  
**Read by:** TripPlanner, Natalie  
**File:** `{model_dir}/{model_name}.feature.json`

---

## Purpose

`feature.json` is a routing declaration. It answers one question: **given a station template and a trip direction, what sequence of guideway segments must a pod traverse?**

It is not a geometry file. It does not carry coordinates, lengths, or speeds — those live in `map.json`. It is not a physical observation file — those live in `physical.json`. It is a pure behavioral declaration: what is allowed, not what was observed.

Noelle writes it. TripPlanner and Natalie read it. No other agent writes it.

---

## What It Is Not

| NOT in feature.json | Where it lives instead |
|---|---|
| Guideway geometry (coordinates, lengths) | `map.json` lines{} |
| Physical observations (bumps, alignment issues) | `physical.json` |
| Ezone geometry or speed limits | `map.json` ezones[] |
| Vehicle state, trip assignment | `vehicles.json`, `trip.json` |
| Billing data | `trip.json` billing fields |

---

## Who Writes It

Noelle — `JPods::Noelle.generate_feature_json(model)` — called on every Build and Validate.  
Also called standalone from the Console: `Generate feature.json`.

The authority for behavioral declarations is `noelle_features.json` (in the plugin folder, keyed by template name). `feature.json` is the resolved, per-model output: Noelle reads `noelle_features.json`, maps each station instance in the model to its template, and writes the per-station sequences.

**Never edit `feature.json` by hand.** Changes to station behavior belong in `noelle_features.json`. Changes to physical layout require a model rebuild followed by a new Build.

---

## File Location

```
{model_dir}/{model_name}.feature.json
```

Example: `~/Documents/skp_jpods/CA_Gilroy_Clean/CA_Gilroy_Clean.feature.json`

---

## Top-Level Structure

```json
{
  "schema":       "jpods-feature-v3",
  "model_id":     "CA_Gilroy_Clean",
  "generated_at": "2026-05-20T18:30:00Z",
  "generated_by": "Noelle",
  "note":         "...",
  "faults":       [],
  "templates":    { ... },
  "connections":  { ... }
}
```

### generated_at
UTC ISO-8601 with Z suffix. TripPlanner compares this against the current file timestamp to detect stale trips. See `jpods-utc-standard.md`.

### faults[]
Array of strings. Non-empty if Noelle detected problems during generation (missing template, unknown guideway role, etc.). TripPlanner and Natalie should refuse to plan trips if faults is non-empty.

---

## templates{} block

Keyed by template name (matches the component definition name in the SketchUp model).

```json
"templates": {
  "station_thru_dip": {
    "instances": ["S048", "S049", "S051"],
    "originating": {
      "out_cp0": ["gw_platform", "gw_platform_out", "gw_uturn_1", "gw_far_main", "gw_stub_pair_0_out"],
      "out_cp1": ["gw_platform", "gw_platform_out", "gw_uturn_0", "gw_near_main", "gw_stub_pair_1_out"]
    },
    "landing": {
      "in_cp0": ["gw_stub_pair_0_in", "gw_near_main", "gw_platform_in", "gw_platform_parking", "gw_platform"],
      "in_cp1": ["gw_stub_pair_1_in", "gw_far_main",  "gw_platform_in", "gw_platform_parking", "gw_platform"]
    },
    "pass_far": {
      "in_cp1": ["gw_stub_pair_1_in", "gw_far_main", "gw_stub_pair_0_out"]
    },
    "pass_near": {
      "in_cp0": ["gw_stub_pair_0_in", "gw_near_main", "gw_stub_pair_1_out"]
    }
  },
  "station_line_end": {
    "instances": ["S050"],
    "originating": {
      "out_cp0": ["gw_platform", "gw_uturn_1", "gw_far_main", "gw_far_out", "gw_stub_pair_0_out"]
    },
    "landing": {
      "in_cp0": ["gw_stub_pair_0_in", "gw_platform_in", "gw_platform_parking", "gw_platform"]
    }
  }
}
```

### instances[]
List of station IDs using this template. TripPlanner resolves the correct sequence for each station by looking up its template, then selecting the sequence matching the cp_index being entered or exited.

### Sequence categories

| Category | Meaning |
|---|---|
| `originating.out_cpN` | Pod departs this station via CP N |
| `landing.in_cpN` | Pod arrives at this station via CP N |
| `pass_far.in_cpN` | Pod passes through, entering via CP N, on the far track |
| `pass_near.in_cpN` | Pod passes through, entering via CP N, on the near track |

Each sequence is an ordered list of guideway role names (`gw_platform`, `gw_stub_pair_0_out`, etc.). TripPlanner prepends the station ID to build the full line ID: `gw_platform` → `S048.gw_platform`.

---

## connections{} block

Keyed by connection ID (`seg_*` or `cp_*`). Maps each inter-station connection to its two directional entries with `length_mm`.

```json
"connections": {
  "seg_S048_cp1_S050_cp0": {
    "length_mm": 474160.6,
    "from": { "station": "S048", "cp_index": 1 },
    "to":   { "station": "S050", "cp_index": 0 }
  },
  "seg_S050_cp0_S048_cp1": {
    "length_mm": 524213.5,
    "from": { "station": "S050", "cp_index": 0 },
    "to":   { "station": "S048", "cp_index": 1 }
  }
}
```

TripPlanner uses this to identify which inter-station segment connects a given origin CP to a destination CP. Length is used by Natalie for headway planning.

---

## How TripPlanner Uses feature.json

For a trip from S048 (departing via CP1) to S050 (arriving via CP0):

1. Look up S048's template → `station_thru_dip`
2. Resolve `originating.out_cp1` → `["gw_platform", "gw_platform_out", "gw_uturn_0", "gw_near_main", "gw_stub_pair_1_out"]`
3. Prepend station ID → `["S048.gw_platform", "S048.gw_platform_out", ...]`
4. Find inter-station segment from S048.cp1 to S050.cp0 → `seg_S048_cp1_S050_cp0`
5. Look up S050's template → `station_line_end`
6. Resolve `landing.in_cp0` → `["gw_stub_pair_0_in", "gw_platform_in", "gw_platform_parking", "gw_platform"]`
7. Prepend station ID → `["S050.gw_stub_pair_0_in", "S050.gw_platform_in", ...]`
8. Concatenate: full segment sequence for the trip
9. For each segment ID, look up geometry in `map.json` lines{}
10. Write self-contained segment records into `trip.json`

---

## noelle_features.json — The Authority

`noelle_features.json` is the behavioral declaration source. It lives in the plugin folder (`su_jpods/noelle_features.json`) and is version-controlled with the plugin. It is keyed by template name.

`feature.json` is the resolved output for a specific model. Noelle generates it by:
1. Scanning model entities for `JPods::structure_id` attributes
2. Mapping each structure to its component definition name (template)
3. Looking up the template in `noelle_features.json`
4. Writing the per-instance resolved sequences

**Adding a new station template:**
1. Add the template entry to `noelle_features.json` (once)
2. Re-run Build on any model that uses the new template
3. `feature.json` regenerates automatically

**Never add template logic to `feature.json` directly** — it will be overwritten on next Build.

---

## Relationship to map.json

| Concern | feature.json | map.json |
|---|---|---|
| What sequence of segments to travel | Yes — role names | No |
| Geometry of each segment | No | Yes — coordinates, lengths |
| Speed limits | No | Yes — speedMin, speedMax |
| Platform capacity | No | Yes — platform_capacity on gw_platform lines |
| Ezone locations | No | Yes — ezones[] |
| Network topology (successors/predecessors) | No | Yes — lines{}.successors/predecessors |

TripPlanner needs both: feature.json for the sequence, map.json for the geometry of each segment.

---

## Faults and Validation

Noelle logs faults when:
- A station instance's component definition does not match any template in `noelle_features.json`
- A station instance has no `structure_id` attribute
- `followme.json` models section is empty (fallback entity scan used)
- A referenced guideway role is not present in the model geometry

If `faults` is non-empty, TripPlanner should log a warning and refuse to generate trips for the affected stations. Natalie should not assign trips to affected stations.

---

## Timestamps

All datetimes UTC. `generated_at` uses Z suffix. See `jpods-utc-standard.md`.

---

## Version History

| Version | Date | Key changes |
|---|---|---|
| v1 | pre-2026 | Initial — template sequences only |
| v2 | 2026-04 | Added connections{} block |
| v3 | 2026-05 | Added generated_at UTC, faults[], fallback entity scan, cp_index rename |

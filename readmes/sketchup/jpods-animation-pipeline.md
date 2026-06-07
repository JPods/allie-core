# JPods Animation Pipeline — JSON Sequence

**Last Updated:** 2026-06-07
**Domain:** SketchUp (SU)
**Status:** Production

---

## Overview

Six JSON artifacts move data from Noelle's Build output to a running animation.
Each layer adds something the previous layer cannot provide.

```
lines.json (formation authority)
    ↓
extracted.json (template geometry)
    ↓  PathJSON.export — Steps 1–6
path.json (corrected, snapped, CCW-directed track pts)
    ↓
map.json (integer IDs, successors graph, gap-fill pts)
    ↓  Animation startup — build_lookup + id_lookup upgrade
lookup / id_lookup (merged runtime tables)
    ↓
trip.json (authorized segment sequence)
    ↓  bfs_route_by_id + build_maneuvers_from_ids
maneuver chain (ordered pts, ready for pod traversal)
```

---

## Step-by-Step

### 1. lines.json — formation authority
**Location:** `su_jpods/formations/{formation_id}.json`
**Written by:** Generate Formation Map (user action on open template) or Build (first time)
**Read by:** PathJSON.export, Noelle validator, Natalie trip planner

Declares CP positions and tangent vectors in LOCAL (definition) coordinates.
Also carries `successors` — the CCW travel graph for each track in the formation.
These successors are the seed for:
- PathJSON Step 6 (endpoint snap)
- `build_topology_from_ids` Pass 1 (adjacency wiring)

**Noelle's snap candidate input (learning loop):**
`{model}.snap-candidates.json` is merged into lines.json successors at Build time.
Animation-detected gaps that were not covered by declared successors end up here.
Noelle reviews and promotes confirmed pairs to lines.json. See §6 below.

---

### 2. extracted.json — template geometry
**Location:** `su_jpods/formations/{formation_id}.extracted.json`
**Written by:** `populate_from_open_template` (user action)
**Read by:** PathJSON.export

Raw track geometry in LOCAL template frame. Contains:
- `pts_mm` — polyline points at ~1000mm spacing (SketchUp visual resolution)
- `sv`, `ev` — outward tangent vectors at start and end (Bezier convention)
- ArcCurve-exact radius (Priority 1 extraction path)

After extraction, Step 4 (direction correction) ensures ring arcs are stored
first→last in CCW traversal order. Re-running Extract Template triggers Step 4
again — direction correction is automatic.

---

### 3. path.json — corrected, snapped, CCW-directed pts
**Location:** `{model_dir}/{model_name}.path.json`
**Schema:** `jpods-path-v2`
**Written by:** `PathJSON.export` — called at animation start
**Read by:** Animation startup, Show Route overlay

`PathJSON.export` runs 6 steps every time animation starts:

| Step | What it does |
|------|-------------|
| 1 | Load extracted.json for each station formation |
| 2 | Scale LOCAL pts_mm → WORLD pts (apply station instance transform) |
| 3 | Topology snap — find minimum-distance endpoint pair for ring circle arcs |
| 4 | Direction correction — reverse any ring arc where pts are stored backward (CCW rule) |
| 5 | Ring junction snap — move gw_in/gw_out endpoints to match adjacent ring arc endpoints |
| 5b | Bezier reconstruction — fit gw_in/gw_out as cubic Bezier using CP and ring tangents |
| 6 | Endpoint snap — for each declared A→B successor pair, move B.first to A.last if gap > 1mm and < 500mm |

Step 6 reads `successors` from lines.json. Any pair not declared there is not snapped.
This is the gap Noelle's learning loop closes (see §6).

**What path.json does NOT contain:** `seg_*` inter-station tracks. Those live in map.json only.

---

### 4. map.json — integer IDs, successors graph, gap-fill pts
**Location:** `{model_dir}/{model_name}.map.json`
**Written by:** Noelle Build + Validate
**Read by:** Animation startup

Two roles:
1. **Registry** — assigns permanent integer `id` to every track. IDs do not change
   across re-builds unless the track itself is deleted. Used to build `id_lookup`
   and the integer adjacency graph `adj`.
2. **Gap-fill** — provides pts for tracks path.json does not cover (primarily
   `seg_*` inter-station guideways and any station tracks not yet extracted).

**Limitation:** map.json pts use template-local geometry, not WORLD-snapped geometry.
For intra-station tracks, first/last endpoints may differ from the adjacent seg's
endpoints by hundreds of millimeters. path.json corrects this via Step 6.

---

### 5. Animation startup — lookup + id_lookup merge
**Called by:** `JPodVehicleAnim.start`

```
map_lookup   ← flatten_map_lines(map.json)         # flat string keys, map.json pts
lookup       ← PathJSON.load(model)                 # path.json pts (snapped, CCW-directed)
lookup       ← map_lookup.merge(lookup)             # path.json wins on conflict
lookup       ← edge_lookup upgrades                 # live model ArcCurve edges win over 2-pt chords

id_result    ← build_lookup(map.json)               # id_lookup[int_id] from map.json pts
id_lookup    ← id_result[:id_lookup]
id_lookup    ← upgraded from lookup (all entries)   # ← always prefer lookup pts over map.json pts
adj          ← build_topology_from_ids(id_lookup)   # CCW adjacency from successors + proximity
```

**Why the id_lookup upgrade matters:**
`build_maneuvers_from_ids` uses `id_lookup[:pts]` for its proximity flip. Without the
upgrade, it would use map.json's unsnapped pts — causing the flip to fire in the wrong
direction and producing a backward jump (snag) at the seg→station boundary.

After the upgrade, `id_lookup[:pts]` matches `lookup[:pts]` for every track where
path.json or edge_lookup provided corrected pts.

---

### 6. trip.json — authorized segment sequence
**Location:** `{model_dir}/trip_reports/YYYYMMDDTHHMMSS-trip-plan-{nora_id}.json`
**Schema:** `jpods-trip-plan-v1`
**Written by:** `_write_trip_plan` at animation dispatch
**Read by:** Natalie re-dispatch loop

Declares the complete authorized route as `lines` → station/track entries with
integer `id` and `seq` fields. The `seq` number is the canonical travel order.

```json
{
  "schema": "jpods-trip-plan-v1",
  "lines": {
    "s002": { "gw_platform": { "plan": { "seq": 1, "id": 46 } }, ... },
    "connections": {
      "seg_s002_cp0_s001_cp2": { "plan": { "seq": 9,  "id": 97 } },
      "seg_s001_cp1_s004_cp0": { "plan": { "seq": 19, "id": 94 } }
    },
    "s001": { "gw_cp_in_2": { "plan": { "seq": 10, "id": 11 } }, ... },
    "s004": { "gw_cp_in_0": { "plan": { "seq": 20, "id": 80 } } }
  }
}
```

---

### 7. bfs_route_by_id + build_maneuvers_from_ids — maneuver chain
**Called by:** `build_fleet` → `NoraPod.initialize_trip`

`bfs_route_by_id` walks `adj` (from map.json successors) to find the integer-ID path
from origin `gw_platform` to destination `gw_platform_parking`.

`build_maneuvers_from_ids` converts integer IDs → maneuver hashes `{ id:, pts:, len: }`.
Applies a proximity flip: if `pts.last` is closer to `prev_end_pt` than `pts.first`,
reverses the pts array. With the id_lookup upgrade (Step 5), the flip receives
correct CCW-directed pts so it orients correctly rather than reversing valid tracks.

---

## Gap Measurement and Noelle's Learning Loop

### Junction gap report

At the end of `build_maneuvers_from_ids` and `build_maneuvers`, every consecutive
maneuver pair `m[i] → m[i+1]` is checked:

```
gap_mm = distance(m[i].pts.last, m[i+1].pts.first) × 25.4
```

Gaps > `JUNCTION_GAP_WARN_MM` (default 5.0mm) are:
1. **Logged to console** — `[Natalie] junction gap: seg_s001_cp1_s004_cp0 → s004.gw_cp_in_0: 85.3mm`
2. **Written to `{model}.snap-candidates.json`** — persisted for Noelle
3. **Reported to user** — FAULT file in `~/Allie/process/inbox/`

### snap-candidates.json
**Location:** `{model_dir}/{model_name}.snap-candidates.json`
**Written by:** `build_maneuvers_from_ids` / `build_maneuvers` (animation startup)
**Read by:** PathJSON.export Step 6, Noelle Build

```json
{
  "schema": "jpods-snap-candidates-v1",
  "generated_at": "2026-06-07T14:11:49Z",
  "candidates": [
    {
      "from_track": "seg_s001_cp1_s004_cp0",
      "to_track":   "s004.gw_cp_in_0",
      "gap_mm":     406.2,
      "observed_at": "2026-06-07T14:11:49Z",
      "run_count":  1
    }
  ]
}
```

`run_count` increments each time the same pair is observed. Noelle promotes
candidates with `run_count >= 2` to lines.json `successors` at next Build.
Once declared in lines.json, PathJSON Step 6 closes the gap automatically.
The candidate is removed from snap-candidates.json after promotion.

### The closed loop

```
Animation detects junction gap
    ↓
snap-candidates.json (accumulated observations)
    ↓ run_count >= 2 → Noelle promotes at next Build
lines.json successors (declared snap pairs)
    ↓ PathJSON.export Step 6
path.json (endpoint-snapped)
    ↓ id_lookup upgrade
id_lookup (correct snapped pts)
    ↓ build_maneuvers_from_ids
zero junction gap
```

---

## Data Authority Hierarchy

For any given track, pts come from the highest-authority source available:

| Priority | Source | What it provides |
|----------|--------|-----------------|
| 1 | Live model ArcCurve edges | Exact arc vertex chain from SketchUp geometry |
| 2 | path.json | Endpoint-snapped, CCW-directed, Bezier-reconstructed pts |
| 3 | map.json | 2-pt chord fallback; unsnapped template-local endpoints |

This hierarchy applies to both `lookup` (string-keyed) and `id_lookup` (integer-keyed).
The id_lookup upgrade at animation startup enforces it for the integer path.

---

## Zero-Tolerance Goal

trip.json declares the route with zero tolerance. The pipeline exists to ensure
the pts that animate that route also have zero gaps between consecutive tracks.

Current state: gaps arise because:
- `seg_*` → `gw_cp_in_*` boundaries are not yet declared as successors in lines.json
- Noelle's snap candidate loop will close these one animation run at a time

Target state: after two animation runs on any new network, all junction gaps are
declared in lines.json, PathJSON Step 6 snaps them, and `build_maneuvers_from_ids`
reports zero gaps.

---

## Files Quick Reference

| File | Location | Written by | Read by |
|------|----------|-----------|---------|
| `lines.json` | `su_jpods/formations/` | Generate Formation Map / Build | PathJSON, Noelle, Natalie |
| `extracted.json` | `su_jpods/formations/` | populate_from_open_template | PathJSON |
| `path.json` | `{model_dir}/` | PathJSON.export (animation start) | Animation startup, Show Route |
| `map.json` | `{model_dir}/` | Noelle Build + Validate | Animation startup, Natalie |
| `snap-candidates.json` | `{model_dir}/` | build_maneuvers* (animation) | PathJSON Step 6, Noelle Build |
| `trip-plan-*.json` | `{model_dir}/trip_reports/` | _write_trip_plan (animation) | Natalie re-dispatch |

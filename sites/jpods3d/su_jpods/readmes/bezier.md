# Bezier Curve Status — su_jpods
**Last Updated:** 2026-06-18
**Purpose:** Document all known bezier/arc geometry defects across track formation templates.
Read this before touching any code in populate_from_open_template, generate_geometry_json,
or any curve synthesis path.

---

## Bezier Code Map (24 items, 12+ files)

| # | Item | File | Lines | Role |
|---|------|------|-------|------|
| 1 | `_bezier_pts_from_tangents_mm` | jpod_path_json.rb | ~2045-2078 | Cubic bezier from endpoints + tangent vectors; returns nil if parallel |
| 2 | `_arc_pts_from_center_mm` | jpod_path_json.rb | ~2098+ | Samples circular arc at ARC_SAMPLE_MM intervals; used by Priority B |
| 3 | `populate_from_open_template` | jpod_path_json.rb | ~3213-3475 | Priority chain: 0 → 0.5 → B; sets pts[] on each track |
| 4 | Priority 0 (uturn synthesis) | jpod_path_json.rb | ~3220-3260 | cp_marker centroid → CENTERLINE_R_G=1750mm arc |
| 5 | Priority 0.5 (jpods_path attr) | jpod_path_json.rb | ~3261-3300 | Reads jpods_path entity attr; sets authored=true |
| 6 | Priority B (centroid arc) | jpod_path_json.rb | ~3410-3450 | Fits center from pts[0..1], sweeps arc — WRONG RADIUS for N_N arcs |
| 7 | `generate_geometry_json` ring synthesis | jpod_path_json.rb | ~2854-2948 | Fits ring center from N_N arcs, synthesizes connector arcs |
| 8 | Ring guard | jpod_path_json.rb | 2903 | `next unless pts && pts.size == 2` — connector arcs must stay 2-pt |
| 9 | authored flag propagation (else-branch) | jpod_path_json.rb | ~2850 | `entry['authored'] = true if ext['authored']` — added 2026-06-18 |
| 10 | `_write_path_attr` lambda | jpod_path_json.rb | ~3021-3048 | Writes pts to jpods_path attr on entity; called by connect tool |
| 11 | `save_geometry` authored guard | jpod_path_json.rb | ~284-337 | Reads authored from lines.computed.json; protects pts across Compute |
| 12 | `jpod_connect_tool.rb` | jpod_connect_tool.rb | — | Writes jpods_path attr at connect time using cp_marker math |
| 13 | `beam_path` attr write | jpod_network.rb | — | Build time: samples bezier pts at BEZIER_TARGET_SEG_M=2m intervals |
| 14 | `ARC_SAMPLE_MM = 1000` | jpod_constants.rb | — | Target spacing for arc/bezier pts in populate_from_open_template |
| 15 | `BEZIER_TARGET_SEG_M = 2` | jpod_constants.rb | — | Target spacing for Build-time bezier sampling |
| 16 | `CENTERLINE_R_G = 1750` | jpod_constants.rb | — | Vehicle path centerline radius for station uturn arcs |
| 17 | `BEAM_WIDTH = 500` | jpod_constants.rb | — | Inside to outside edge; centerline ± 250mm |
| 18 | Show Track bezier rendering | jpod_show_track_tool.rb | — | Reads pts[] from geometry.json / lines.computed.json |
| 19 | Animate bezier following | jpod_animator.rb | — | Reads beam_path attr from guideway group |
| 20 | station_line_end gw_lift_in | templates/.../lines.computed.json | — | Reference correct: 22 pts, authored=true |
| 21 | station_parking diagonals | templates/.../lines.computed.json | — | DEFECTIVE: all 2-pt, no jpods_path attr |
| 22 | traffic_circle7 N_N arcs | templates/.../lines.computed.json | — | DEFECTIVE: interior pts at outside edge (7766mm) |
| 23 | traffic_circle7 connector gw_c_0_1 | templates/.../lines.computed.json | — | DEFECTIVE: wrong start, wrong end |
| 24 | traffic_circle7 gw_in_*/gw_out_* | templates/.../lines.computed.json | — | DEFECTIVE: straight 2-pt lines, no bezier curve following |

---

## Priority Chain (current state — 2026-06-18)

```
Priority 0   — cp_marker uturn arc synthesis (radius=CENTERLINE_R_G)
Priority 0.5 — jpods_path entity attr (set by connect tool; authored=true)
[Priority 1   — ArcCurve extraction       ARCHIVED]
[Priority 1.5 — edge-trace extraction      ARCHIVED]
Priority 2   — bbox 2-pt (straight chord, no bezier)
[Priority A   — ene_railroad tangent bezier ARCHIVED 2026-06-18]
Priority B   — centroid arc synthesis (WRONG RADIUS — see Defect TC-1 below)
```

**Governing axiom:** Source of truth for gw_* bezier pts is cp_marker_* geometry only.
No edge attributes, no ene_railroad controls[]. "No edges, only math."

---

## DEFECT TC-1 — traffic_circle7: N_N arc interior pts on outside edge

**Tracks:** gw_c_0_0, gw_c_1_1, gw_c_2_2, gw_c_3_3 (all four N_N arcs)
**Status:** OPEN

### Circle geometry constants

```
Circle center (cp_marker centroid): [-15881.728, 0.0, 0.0] mm
Centerline radius:  7516mm  (15m circle ≈ 15032mm diameter)
Outside edge:       7766mm  (centerline + 250mm = centerline + BEAM_WIDTH/2)
Inside edge:        7266mm  (centerline − 250mm = centerline − BEAM_WIDTH/2)
BEAM_WIDTH:          500mm
```

### Ring topology (travel direction)

```
gw_c_0_0 → gw_c_3_0 → gw_c_3_3 → gw_c_2_3 → gw_c_2_2 → gw_c_1_2 → gw_c_1_1 → gw_c_0_1 → (gw_c_0_0)
```

natalie.pass_chains.circle: [gw_c_0_0, gw_c_0_1, gw_c_1_1, gw_c_1_2, gw_c_2_2, gw_c_2_3, gw_c_3_3, gw_c_3_0]

### Measured distances from circle center (13 pts per N_N arc)

| Track    | pt[0]    | pt[1..11]  | pt[12]   |
|----------|----------|------------|----------|
| gw_c_0_0 | 7766mm ✗ | 7766mm ✗   | 7516mm ✓ |
| gw_c_1_1 | 7516mm ✓ | 7766mm ✗   | 7516mm ✓ |
| gw_c_2_2 | 7516mm ✓ | 7766mm ✗   | 7516mm ✓ |
| gw_c_3_3 | 7516mm ✓ | 7766mm ✗   | 7516mm ✓ |

Interior pts (pts[1..11]) are on the OUTSIDE EDGE at 7766mm.
Only the connection endpoints happen to be at 7516mm because they were extracted from
the SketchUp entity at rail junctions, which ARE at centerline.

**Error magnitude:** 7766 − 7516 = 250mm outward bow. Vehicle path incorrect for 11 of 13 pts.

### Per-pt distances — gw_c_0_0 (representative)

```
pt[ 0] dist=7766.09mm  [-10048.1,  5126.5, 31.25]  ← OUTSIDE EDGE ✗
pt[ 1] dist=7766.16mm  [ -9475.6,  4390.3, 31.25]  ← OUTSIDE EDGE ✗
pt[ 2] dist=7766.16mm  [ -8995.5,  3590.7, 31.25]  ← OUTSIDE EDGE ✗
  ...
pt[11] dist=7766.16mm  [ -9475.6, -4390.3, 31.25]  ← OUTSIDE EDGE ✗
pt[12] dist=7516.63mm  [-10224.9, -4949.75,31.25]  ← CENTERLINE ✓
```

### Root cause

Priority B (`centroid arc synthesis`) in `populate_from_open_template` uses the raw
2-pt chord endpoints from extracted.json to fit the arc center. Those endpoints are
at centerline (7516mm). But `_arc_pts_from_center_mm` sweeps the arc from the
center at the WRONG radius — it measures from the fitted center to pt[0] to determine
radius, and pt[0] is at the outside edge (7766mm). So the fitted arc has radius 7766mm
instead of 7516mm.

**Fix direction:** Priority B must be given the known centerline radius (7516mm)
explicitly, not derived from the endpoint distances. The circle center and radius
must come from the cp_marker geometry, not from endpoint-to-center distance fitting.

---

## DEFECT TC-2 — traffic_circle7: gw_c_0_0 start pt on outside edge

**Track:** gw_c_0_0 only
**Status:** OPEN
**Downstream of:** Defect TC-1

gw_c_0_0 pt[0] is at 7766mm. All other N_N arc start/end endpoints (the junction pts)
are at 7516mm. This is a direct consequence of Defect TC-1 — Priority B places pt[0]
at the swept radius (7766mm) instead of the junction position.

Practical consequence: gw_c_0_1 connector arc cannot connect correctly because its
expected end (gw_c_0_0 start) is at the wrong position.

---

## DEFECT TC-3 — traffic_circle7: gw_c_0_1 connector arc defective

**Track:** gw_c_0_1
**Status:** OPEN
**Sub-defect 3A:** Independent of TC-1/TC-2
**Sub-defect 3B:** Downstream of TC-2

### Actual endpoints (from lines.computed.json)

```
start: [-10932.0,  5656.85, 31.25]  dist_from_center=12308.9mm  ← WRONG POINT
end:   [-10401.7,  4773.0,  31.25]  dist_from_center=11444.5mm  ← INSIDE EDGE ✗
chord: 1030.7mm (correct connectors have chord=1000.0mm)
```

### Expected endpoints

```
start = gw_c_1_1 END:   [-20831.5, 5656.85, 31.25]  (centerline ✓)
end   = gw_c_0_0 START: [currently at outside edge — TC-2]
```

### Sub-defect 3A — wrong predecessor end used as start

gw_c_0_1 start is at gw_c_1_1 START `[-10932.0, 5656.85]` instead of
gw_c_1_1 END `[-20831.5, 5656.85]`. These are 9899mm apart.
The ring synthesis confused start and end of gw_c_1_1.

This is INDEPENDENT of Defects TC-1/TC-2.

### Sub-defect 3B — end on inside edge

gw_c_0_1 end `[-10401.7, 4773.0]` is at 11444.5mm from circle center —
inside edge territory, not centerline. This is downstream of TC-2: the connector
arc synthesis points toward gw_c_0_0 start, which is at the outside edge (TC-2),
and the swept arc overshoots to the inside edge on the other end.

### Connector arc status summary

| Arc      | start          | end            | Status                        |
|----------|----------------|----------------|-------------------------------|
| gw_c_3_0 | 7516mm ✓ CL    | 7516mm ✓ CL    | CORRECT centerline→centerline |
| gw_c_2_3 | 7516mm ✓ CL    | 7516mm ✓ CL    | CORRECT centerline→centerline |
| gw_c_1_2 | 7516mm ✓ CL    | 7516mm ✓ CL    | CORRECT centerline→centerline |
| gw_c_0_1 | wrong point ✗  | inside edge ✗  | DEFECTIVE — TC-3A + TC-3B    |

CL = vehicle centerline (7516mm from circle center)

---

## DEFECT TC-4 — traffic_circle7: gw_in_* and gw_out_* are straight lines

**Tracks:** gw_in_0, gw_in_1, gw_in_2, gw_in_3, gw_out_0, gw_out_1, gw_out_2, gw_out_3
**Status:** OPEN

All gw_in_* and gw_out_* tracks are stored as 2-pt straight chords. Endpoints are on
the correct vehicle centerlines. But the vehicle path between endpoints follows a
straight line rather than the 1m-sampled bezier curve that follows the actual arc.

**What correct looks like:** gw_lift_in in station_line_end — 22 pts, authored=true,
bezier curves visible in Show Track.

**Root cause:** These tracks have no `jpods_path` entity attribute set by the connect tool.
Priority 0.5 never fires. Priority B cannot synthesize a meaningful arc from 2 straight-
chord endpoints without a known center and radius. Result: 2-pt chord, straight line.

**Fix direction:** Connect tool must write jpods_path attr for gw_in_*/gw_out_* at
template authoring time, OR Priority B must be extended to detect these tracks and
synthesize the correct arc using circle center and centerline radius from cp_marker geometry.

---

## DEFECT SP-1 — station_parking: diagonal bezier tracks are straight lines

**Template:** station_parking
**Tracks:** gw_platform_in1, gw_platform_in2, gw_platform_out1, gw_platform_out2,
            gw_lift_in, gw_lift_parking
**Status:** OPEN

All six diagonal tracks are stored as multi-pt chords from prior extraction but the
pts are on opposite rails at internal junctions — 250mm off centerline on alternating
sides, producing 500mm total endpoint gaps between adjacent tracks. No jpods_path
attribute has been set with correct centerline pts. Result: wrong vehicle path throughout;
continuous path through the diagonal chain is broken.

**Reference:** gw_uturn_0 and gw_uturn_1 have 7 pts via Priority 0 — these are correct.
gw_lift has its own defect — see SP-2 below.

### Junction measurements (from geometry.json, station-local coordinates)

**CP-in end → gw_platform_in1 start — CORRECT**
```
gw_cp_in_lead_0 pt[-1]: [9133.65, 66103.58, 7500.0]
gw_platform_in1 pt[ 0]: [9133.65, 66103.58, 7500.0]
gap: 0.0mm  ✓
```

**gw_platform_in1 end / gw_platform_in2 start / gw_lift_in start — DEFECTIVE**
```
gw_platform_in1 pt[-1]: [7618.55, 56093.28, 7562.5]  ← 245mm INSIDE rail
gw_platform_in2 pt[ 0]: [7148.65, 56264.28, 7562.5]  ← 245mm OUTSIDE rail
gw_lift_in      pt[ 0]: [7148.65, 56264.28, 7562.5]  ← 245mm OUTSIDE rail (same point)
gap (in1_end → in2/lift_in start): 500.05mm  ✗
true CL midpoint: [7383.6, 56178.78, 7562.5]
```

gw_platform_in2 start and gw_lift_in start are at the same point — the three tracks
should converge here but the 500mm rail-to-rail gap means they do not.

**gw_lift_in end / gw_lift_parking start — DEFECTIVE**
```
gw_lift_in      pt[-1]: [4674.95, 48754.58, 7562.5]  ← 250mm INSIDE rail
gw_lift_parking pt[ 0]: [4205.05, 48925.58, 7562.5]  ← 250mm OUTSIDE rail
gap: 500.05mm  ✗
true CL midpoint: [4440.0, 48840.08, 7562.5]
```

gw_lift_in's end is 250mm to the inside rail; gw_lift_parking's start is 250mm to the
outside rail — opposite sides of the guideway, 500mm total separation.

**gw_platform_out1 end / gw_platform_out2 start — DEFECTIVE (mirror of in-side)**
```
gw_platform_out1 pt[-1]: [7148.65, 12379.18, 7562.5]  ← −250mm from CL
gw_platform_out2 pt[ 0]: [7618.55, 12550.18, 7562.5]  ← +250mm from CL
gap: 500.05mm  ✗
```

**gw_platform_out2 end → gw_cp_out_lead_1 start — CORRECT**
```
gw_platform_out2  pt[-1]: [9133.65, 2539.98, 7500.0]
gw_cp_out_lead_1  pt[ 0]: [9133.65, 2539.98, 7500.0]
gap: 0.0mm  ✓
```

### Pattern

Each diagonal track alternates between rails: one end on the inside rail (−250mm from CL),
the other on the outside rail (+250mm from CL). Adjacent tracks are on opposite rails at
their shared junction → 500mm gap between endpoints that should be coincident.

The CP-lead endpoints happen to be at the correct centerline because they are synthesized
from cp_marker geometry (Priority 0). The diagonal tracks between them were extracted from
SketchUp entities that sit on the structural rail edge, not the vehicle centerline.

### Root cause

Extracted pts came from rail-edge geometry, not vehicle centerline. Priority 0.5 never
fired (no jpods_path attr set). No Priority B path exists for non-circular bezier curves.
Each track's endpoints are 250mm off centerline, alternating side at each junction.

### Fix direction

For each diagonal track, compute the correct centerline bezier pts from cp_marker geometry
(endpoints at true CL; tangent from track direction at junction). Write jpods_path attr via
connect tool. Set authored=true. Commit updated lines.computed.json.

---

## DEFECT SP-2 — station_parking: gw_lift shows arc in Show Track; should be straight

**Template:** station_parking
**Track:** gw_lift
**Status:** OPEN

gw_lift is a perfectly straight track in SketchUp (`gw_` naming, not `gw_c_`).
But Show Track renders it as a significant arc because the 8 pts stored in
lines.computed.json (embedded geometry section) bow 678mm off the chord.

### Measured pts (lines.computed.json embedded geometry, station-local coords)

```
pt[0]: [2734.3, 38892.97, 7312.5]   ← 0mm off chord  (endpoint)
pt[1]: [2386.0, 38074.27, 7312.5]   ← 336mm off chord
pt[2]: [2146.0, 37217.57, 7312.5]   ← 563mm off chord
pt[3]: [2018.4, 36337.07, 7312.5]   ← 678mm off chord  (max)
pt[4]: [2005.2, 35447.47, 7312.5]   ← 678mm off chord  (max)
pt[5]: [2106.7, 34563.57, 7312.5]   ← 563mm off chord
pt[6]: [2321.1, 33700.07, 7312.5]   ← 336mm off chord
pt[7]: [2645.0, 32871.47, 7312.5]   ← 0mm off chord  (endpoint)
chord: [2734.3, 38892.97] → [2645.0, 32871.47], length=6022mm, direction mostly −Y
```

The pts form a symmetric bow — 678mm at midpoint, zero at endpoints. Show Track follows
these pts and draws what appears to be a large arc, but the track is straight.

### Root cause

The pts stored in lines.computed.json for gw_lift came from a prior extraction that
captured a curved or off-center edge in the SketchUp model rather than the straight
vehicle centerline. The SketchUp entity itself is straight; the stored pts are not.

### Fix direction

Replace the gw_lift pts in lines.computed.json with a straight 2-pt chord between
the correct centerline endpoint positions at the correct Z height. Set authored=True
to protect them from overwrite by future Compute runs.

---

## DEFECT STD-1 — station_thru_dip: bezier tracks are straight lines

**Template:** station_thru_dip
**Tracks:** all bezier-curve tracks (specific names not yet audited)
**Status:** OPEN — same class as SP-1, not yet measured

Same root cause as Defect SP-1: 2-pt chords, no jpods_path attr, no Priority 0.5 firing.
Needs audit pass identical to what was done for station_parking.

---

## Reference: correct bezier track

**station_line_end / gw_lift_in**
- 22 pts, authored=true
- Visible as smooth curve in Show Track
- Set by connect tool at template authoring time
- Protected by save_geometry authored guard across all Compute runs

This is the target state for all bezier tracks in all templates.

---

## Fix Dependency Graph

```
TC-1 (N_N arc wrong radius)
  └─► TC-2 (gw_c_0_0 start at outside edge)
        └─► TC-3B (gw_c_0_1 end on inside edge)

TC-3A (gw_c_0_1 wrong start) — independent

TC-4 (gw_in/gw_out straight) — independent; same class as SP-1/STD-1

SP-1 (station_parking diagonals: ±250mm rail errors at internal junctions) — independent
SP-2 (station_parking gw_lift: arc shape in Show Track, should be straight) — independent
STD-1 (station_thru_dip diagonals straight) — same class as SP-1
```

Fix TC-1 first. TC-2 and TC-3B resolve automatically once N_N arc endpoints land at
7516mm. TC-3A requires a separate fix to the ring synthesis predecessor-end logic.
SP-1 and TC-4/STD-1 require connect tool authoring runs against the templates.
SP-2 requires SketchUp entity correction for gw_lift before re-extraction.

---

## authored Flag Pipeline (fixed 2026-06-18)

```
connect tool writes jpods_path attr on entity
    ↓
populate_from_open_template: Priority 0.5 reads attr, sets authored=true in tracks[]
    ↓
generate_geometry_json else-branch: entry['authored'] = true if ext['authored']  ← FIX ADDED
    ↓
geometry.json has authored=true
    ↓
save_geometry: reads authored from lines.computed.json, protects pts across Compute
    ↓
lines.computed.json has authored=true, pts preserved
```

Before the fix: authored never reached geometry.json from the else-branch, so save_geometry
never protected the pts, and every Compute run overwrote them with 2-pt chords.

**Note:** gw_uturn_* and gw_cp_in_* branches have their own result[] assignments —
authored is NOT propagated there (correct; those tracks are always recomputed from
cp_marker geometry via Priority 0).

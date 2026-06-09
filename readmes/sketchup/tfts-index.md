# JPods SketchUp Plugin — Troubleshooting Index
**Audience:** Designers and users who have a problem and want to know if it has been solved before.
**Last Updated:** 2026-06-09

Each entry: symptom → what was found → where to read the full arc.
Process files are in `~/Allie/process/inbox/TIMESTAMP-tfts.md`.

---

## How to Use This Index

Find the section that matches your symptom. Read the principle. If you need the full
try-fail-try-succeed arc, open the referenced file.

---

## CP Positions and Tangents

**CPs detected at wrong position (1.75m off, or 111–296mm off)**
The shared hub vertex of the CP component's two rail edges was computed incorrectly.
Correct method: count vertex occurrences across all rail edges; the vertex shared by 2+
edges is the hub. No averaging, no bounding box.
→ `20260524T221423-tfts.md`

**CP tangent direction wrong — connection approach angle off by ~6°**
`xy_tangent(bounding_box_center, hub_pos)` introduces angular error when the formation
bounding box is asymmetric (e.g. parking bays offset the center). Tangent must be derived
from the perpendicular to the rail span at the CP gate — this is exact regardless of
bounding box shape. formation_center is used only to resolve the ±sign.
→ `20260609T132909-tfts.md`

**Traffic-circle CPs assigned in wrong order (CW scrambled)**
Nearest-neighbour matching between independently-computed sets is fragile. Use explicit
`cp_marker_N` components with numeric suffixes; read the index from the marker tag.
No sorting, no proximity matching.
→ `20260605T063323-tfts.md`

**Traffic circle inter-station beams 0.25m lower than non-TC station ends**
When cp_marker components are explicitly placed in templates, the hub vertex Z is the
authoritative CP height. Do not add BEAM_DEPTH to the center Z for traffic circle
stations — the cp component already sits at the correct beam center height.
→ `20260524T221500-tfts.md`

**CP Calculate not detecting CPs from station templates**
`cp_marker_N` is the single universal CP detection mechanism. Every template must have
one `cp_marker_N` component per CP, placed at the gate center. If CPs are missing from
Calculate output, verify the components are tagged `cp_marker_0`, `cp_marker_1`, etc.
→ `20260531T120000-tfts.md`

---

## Track Geometry and Extraction

**Extracted geometry has wrong endpoints — bbox extents used instead of path endpoints**
FollowMe extrusion buries the centerline inside structural faces. The bbox is the
structural footprint, not the routing path. Recover actual endpoints by finding
valence-1 vertices (connected to exactly one edge) and clustering them — centroid of
each cluster is the true endpoint.
→ `20260521T181351-tfts.md`

**geometry.json pts in wrong coordinate frame — large ribbon offset in Show Formation Tracks**
geometry.json pts_mm are in formation-component-local coords (the component instance
definition space). Apply the instance's world transformation before drawing. Never store
world coordinates in geometry.json.
→ `20260609T042430-tfts.md`

**Bezier curve in geometry.json draws as wrong shape or loops 180°**
Two rules must both hold: (1) handle vectors h = chord/3, not h = chord. (2) ev must be
the OUTWARD tangent at the end point (pointing AWAY from the curve back toward p0) —
not the arrival direction. Wrong ev produces a 180° loop.
→ `20260609T050247-tfts.md`

**lines.json — topology declaration is not a scan output; math is authority**
For fixed-geometry station structures (gw_uturn, gw_c_*), lines.json is written from
math, not scanned from the model. Scan only to verify. Once written, lines.json is the
authority. The ene_railroad principle: path is data, not geometry.
→ `20260527T025100-tfts.md`

**Ring arc traversed backward after re-extract**
Topology snap (step 3) identifies which endpoint connects — it does not fix direction.
Direction correction (step 4) must run after snap, using A's LAST pt as reference:
if B's LAST is closer than B's FIRST, B is backward — reverse it. Two-pt arcs mask
this; multi-pt arcs expose it.
→ `20260607T070000-tfts.md`

**gw_in_* tracks appear as 2-pt chords in path.json despite resampling log**
When the first pt is snapped to an adjacent track's endpoint, any intermediate pts
already in the array before the snap are lost. Snap first, then resample.
→ `20260607T120000-tfts.md`

**seg_ coordinates came from geometry scan fallback, not from math**
One source of truth. Do the math. CP center coordinates (from_cp[:center],
to_cp[:center]) connected directly give the seg_ endpoint. No beam scan, no
Z-snap, no approximation. entity.transformation IS the terrain adaptation.
→ `20260607T214448-tfts.md`

---

## Show Formation Tracks / Show Route Ribbon Wrong

**Ribbon traces beam cross-section perimeter instead of vehicle path (zig-zag, 115 pts)**
FollowMe beam solid edges are structural geometry, not path geometry. Never walk
FollowMe solid edges to recover the path. Read pts from geometry.json (preferred) or
the `beam_path` attribute set at Build time. The solid cross-section perimeter is ~42×
longer than the track on short straights.
→ `20260606T234218-tfts.md`, `20260606T231244-tfts.md`

**Ribbon missing over some tracks; wrong track drawn instead**
edge_lookup reads structural beam geometry, not vehicle path geometry. When
edge_lookup produces wrong pts, the ribbon falls back to an adjacent track. Use
geometry.json as the source for all ribbon drawing.
→ `20260606T231244-tfts.md`

**gw_uturn and gw_cp_in/out missing or offset in Show Route**
pts in extracted.json (now geometry.json) must be stored in formation-component-local
space so that the instance world_xf applies correctly. Storing world coordinates in
geometry.json breaks every instance placed at a different location.
→ `20260607T015656-tfts.md`

**Show Formation Tracks: gw_lift_in and platform tracks show wrong Bezier or straight lines**
Two rules for every Bezier: (1) handle length = chord/3. (2) ev points OUTWARD from p3
(reverse of arrival). Both must hold. Check that the Bezier convention matches the
ene_railroad handle convention, not the Hermite velocity convention — they require
opposite signs at the TO endpoint.
→ `20260609T050247-tfts.md`

**Traffic circle arm positions wrong in map.json — animation follows wrong path**
map.json arm positions come from scanned guideway edges (followme.json), NOT from
lines.json coordinates. After updating lines.json, re-run Build to regenerate
followme.json and map.json. lines.json and map.json are not the same thing.
→ `20260530T235900-tfts.md`

---

## Animation — Vehicle Wrong Position or Motion

**Vehicle placed at CP stub (~40km from gw_platform) instead of on the platform**
Platform placement authority lives in two separate layers that can drift: the spawn_t
calculation and the entity placement. Both must use the same path source or vehicles
appear at the stub rather than the platform.
→ `20260522T141918-tfts.md`

**Vehicle animates with 1750mm Y jump at the CP→seg_ boundary**
The CP center is used only to calculate where to place guideways — it is not the
vehicle entry point. The vehicle enters at the stub-end of gw_cp_in/out, not at the
CP center. Using cp[:center] as the animation start point introduces a 1.75m offset.
→ `20260523T235900-tfts.md`

**Vehicle stutters / appears to turn at stub_pair→inter-station junction**
A fix applied to one file (e.g. `jpod_connect_tool.rb`) must be applied to every file
that reads the same data with the same logic. `jpod_network.rb` has its own independent
copy of bezier and offset_path methods. Fix both or only one stays broken.
→ `20260523T231508-tfts.md`

**Animation starts from pts[0] instead of vehicle's placed position**
Animation must start from the vehicle's actual placed position, not from the first
point of the trip. Read the vehicle entity's current position and find the nearest
point on the path to begin interpolation.
→ `20260522T052337-tfts.md`

**Intra-station arc segments animate as straight chords (gw_uturn, gw_c_*)**
SketchUp edge geometry IS the authoritative arc path. The FollowMe tool itself uses
edge chains as its spine. Store the edge chain points as the arc geometry — do not
approximate with a 2-pt chord. Two-pt entries in geometry.json animate as straight lines.
→ `20260605T200000-tfts.md`

**gw_uturn_1 animation is chaotic — Y oscillates ±2000mm, Z oscillates**
The edge_lookup override exists to upgrade chords (2-pt start/end) to real arc pts.
When edge_lookup returns wrong pts for a uturn (e.g. from FollowMe solid geometry),
the animator follows the wrong path. Verify edge_lookup returns pts from the correct
source (geometry.json or arc edge chain), not from the FollowMe solid perimeter.
→ `20260606T213049-tfts.md`

**gw_platform_out — pod zig-zags in 165mm area instead of traveling the 18m ramp**
When geometry.json contains FollowMe solid edge-trace geometry (zig-zag pts) for a
track, animation is chaotic. geometry.json must store path geometry (Bezier pts or
edge chain of the guide path), never FollowMe solid perimeter pts.
→ `20260606T204500-tfts.md`

---

## Station Routing — Pod Goes to Wrong Track

**Pod bypasses platform landing and continues on gw_near_main**
The CCW/naming direction correction must cover ALL station tracks that can be traveled,
not just the first one found. If gw_platform_in1 and gw_platform_in2 share a junction,
both must appear in the landing chain for the correction to apply.
→ `20260607T000000-tfts.md`

**Pod entering CP1 jumps to gw_cp_in_lead_0 instead of gw_cp_in_lead_1**
noelle_features.json and lines.json eps[] are a MATCHED PAIR. Changing one without
updating the other causes routing to silently use the wrong EP decisions.
→ `20260531T170000-tfts.md`

**station_thru_dip: pod entering CP1 exits wrong side**
landing.in_cpN defines the intra-station route for pods arriving at CPN specifically.
One landing entry per CP arrival direction. If both CPs share the same landing entry,
the station cannot distinguish arrival direction and routes both the same way.
→ `20260531T180000-tfts.md`

**Intra-station successor wiring produces empty successors — BFS falls back to wrong exit**
When lines_out intra-station keys use different case than the station loop's sid
variable, the key lookup fails silently. The station ID key comparison must be
case-insensitive, or both sides must normalize to uppercase consistently.
→ `20260606T220000-tfts.md`

**Pod loops back on gw_near_main — wrong direction in routing_chains**
When two segments share a start point and diverge, the one with the "wrong" vector
will have its start and end reversed in the extracted topology. Verify each chain
segment's direction by checking that the end of segment N equals the start of
segment N+1. If not, one segment is stored backward.
→ `20260525T195953-tfts.md`

---

## Build Pipeline

**Build produces wrong approach curves — 1.2m radius reported on visually correct 3.5m arcs**
`vehicle_path_for` stitches through stations and includes neighboring geometry.
`base_vehicle_path_for` returns only the guideway's own points. Any check that measures
a specific guideway's own geometry must use `base_vehicle_path_for`. Using the stitch
path produces false readings for per-guideway spatial analysis.
→ `20260520T232624-tfts.md`

**Waypoints between stations dropped — columns appear separately, no guideway through them**
`generate_feature_json` must produce ONE cp_ entry per physical guideway pair. Both
from→to and to→from entries must reference the same `via_markers` array. If via_markers
are on only one direction, the reverse-direction build ignores them.
→ `20260520T234607-tfts.md`

**Solar tag assignment: hiding "JPods Solar" tag has no effect on solar panels**
Two categories of fix are required when a tag assignment is added to a build pipeline:
(1) add the tag assignment to the build code for new geometry, and (2) retroactively
assign the tag to any existing geometry from previous builds.
→ `20260518T230734-tfts.md`

**show_followme_json_overlay missing — NoMethodError on load_map_json**
When a module is reorganized (methods moved to a new file), all callers referencing the
old location get NoMethodError at runtime. After any module split, grep every caller
and update the module path before shipping.
→ `20260607T043309-tfts.md`

---

## Proof Lines / Validation

**Proof Lines SEVERE on multi-pt FollowMe solid tracks — non-deterministic scan**
For FollowMe solid tracks stored as SketchUp Groups, Proof Lines cannot guarantee
entity identity between the indexer and the scanner. Accept this: classify these
tracks as SCAN status, not SEVERE. Animation reads geometry.json which is correct
regardless of the Proof Lines scan result.
→ `20260606T174000-tfts.md`

**Proof Lines showing SEVERE/WARN on multiple tracks across all templates**
Scanner priority order matters: (1) path attribute → (2) ene_railroad control points →
(3) edge trace → (4) bounding box. Each priority level should only be reached if the
previous failed. SEVERE appears when priority 3 or 4 is reached on tracks that have
correct data at priority 1 or 2.
→ `20260606T174100-tfts.md`

---

## Parking and Platform

**Vehicles stacked at platform entrance instead of parking at assigned slots**
Two trips is simpler than one trip with two phases. When a vehicle has a platform
approach phase and a parking phase, model them as two sequential trip assignments,
not one trip with a conditional mid-trip branch.
→ `20260523T150120-tfts.md`

**Vehicles not compacting to highest available slots — parking cycle stalls**
Three rules: (1) vehicles live in model.entities root, never in gw.entities.
(2) The compact pass and the populate pass must use the same spawn_t formula or
vehicles are placed at different positions for the same slot index.
(3) Any slot with parking_slot > 0 is occupied regardless of vehicle presence.
→ `20260522T221917-tfts.md`, `20260530T233335-tfts.md`, `20260524T000000-tfts.md`

---

## lines.json and Topology Authoring

**Division of authority: who owns lines.json vs. map.json vs. path.json**
- `lines.json` — designer declares: tracks, EPs, chain sequences, approval
- `map.json` / `path.json` — Noelle/Build derives: world coordinates, lengths, widths
- Never put world coordinates in lines.json. Never put topology declarations in map.json.
→ `20260531T160000-tfts.md`

**Component definition names are not stable identifiers**
SketchUp component definition names carry internal model instance counters
("JPods Formation: station_parking#2"). Never use definition.name as a lookup key.
Use a stable JPods attribute (`formation_id`, `structure_id`) stored on the entity.
→ `20260525T200009-tfts.md`

**Template model geometry cannot be extracted via definitions.load() + definition name**
To extract geometry from a template model: load the model via `definitions.load()`,
then index entities by SketchUp layer (tag) name. Do not search by formation name
(anonymous in loaded definitions). Do not search depth-0 model.entities (misses
geolocation wrapper). Each module needing tag lookup must define its own reader.
→ `20260521T170926-tfts.md`

---

## System and Infrastructure

**SketchUp Ruby does not have standard library (WEBrick, etc.)**
SketchUp's Ruby runtime is not standard Ruby. Never assume standard library
availability. UI communication must use HtmlDialog callbacks (`sketchup.method_name`).
→ `20260524T030649-tfts.md`

**Hidden faces z-fight at gate connections — visual raggedness**
Hidden faces still exist in SketchUp geometry and z-fight with coincident faces.
At a gate connection where two guideways meet, one face must be erased, not merely
hidden. Hidden ≠ deleted in SketchUp's geometry kernel.
→ `20260524T180000-tfts.md`

**Terminology confusion — Station / Map / Trip used interchangeably**
Vocabulary is load-bearing. Each term must carry exactly one meaning throughout the
codebase, console output, and documentation. Adding a synonym without retiring the
old term creates ambiguity that propagates into wrong code paths.
→ `20260522T024839-tfts.md`

**Three routing systems producing inconsistent trip formats (Natalie BFS, TripPlanner, show_route BFS)**
When three systems produce the same output, delete two. One source of truth: BFS over
the live model graph is the authority. route.json is never generated again.
→ `20260605T035441-tfts.md`

---

## Ring Junction Geometry (traffic_circle7 and similar)

**Short ring connectors cross the guideway — ribbon visually wrong, length ≠ 1000mm**
Every endpoint touching a ring junction must equal the adjacent ring arc's own FIRST
or LAST pt — not switch-box offset coordinates from extracted.json. Correct connector
length = exactly 1000mm. Any deviation means an endpoint is off the ring centerline.
→ Session 2026-06-09 (`notes.md` in traffic_circle7 template)

**gw_in / gw_out approach tracks draw as straight diagonals**
2-pt straight line in geometry.json. Needs a 13-pt Bezier: sv = CCW ring tangent at
diverge EP, ev = REVERSE of CP track direction, h = chord/3. Ring-side endpoint must
use the same EP coordinate as the adjacent short connector (0mm gap self-check).
→ Session 2026-06-09 (`readmes/sketchup/formation-tracks-recovery.md`)

---

## Cross-Reference by File

| TFTS File | Category | One-Line Problem |
|-----------|----------|-----------------|
| 20260518T230734 | Build | Solar tag: hiding has no effect |
| 20260520T232624 | Build | Wrong approach curve radius reported |
| 20260520T234607 | Build | Waypoints dropped between stations |
| 20260521T170926 | Geometry | Template geometry cannot be extracted by definition name |
| 20260521T181351 | Geometry | Bbox endpoints wrong — valence-1 vertex method needed |
| 20260522T024839 | System | Terminology confusion Station/Map/Trip |
| 20260522T052337 | Animation | Animation starts from pts[0] not vehicle position |
| 20260522T141918 | Animation | Vehicle placed at CP stub not platform |
| 20260522T221917 | Parking | Vehicles not compacting to highest slots |
| 20260523T150120 | Parking | Vehicles stacked at platform entrance |
| 20260523T231508 | Animation | CP stutter — fix applied to one file not both |
| 20260523T235900 | Animation | 1750mm Y jump at CP→seg_ boundary |
| 20260524T000000 | Parking | Parking shuffle skips — slot occupancy rule |
| 20260524T030649 | System | WEBrick not available in SketchUp Ruby |
| 20260524T180000 | Visual | Hidden faces z-fight at gate connections |
| 20260524T221423 | CP | CP hub vertex computed incorrectly |
| 20260524T221500 | CP | Traffic circle beams 0.25m low |
| 20260525T195953 | Routing | gw_platform_in1 wrong direction in routing_chains |
| 20260525T200009 | Topology | Definition names not stable identifiers |
| 20260527T025100 | Topology | lines.json is math, not scan output |
| 20260530T233335 | Parking | Platform slot overlap — compact vs populate |
| 20260530T235900 | Animation | Traffic circle map.json arm positions wrong |
| 20260531T120000 | CP | CP Calculate not detecting CPs |
| 20260531T160000 | Topology | Division of authority lines.json vs map.json |
| 20260531T170000 | Routing | Pod jumps to wrong gw_cp_in_lead |
| 20260531T180000 | Routing | station_thru_dip pod exits wrong side |
| 20260603T033325 | Routing | S004 hold_loop — six defect classes |
| 20260603T203802 | Animation | gw_* lead tracks animate reversed |
| 20260605T035441 | System | Three routing systems producing inconsistent formats |
| 20260605T063323 | CP | Traffic circle CPs in wrong order |
| 20260605T200000 | Animation | Arcs animate as straight chords |
| 20260606T174000 | Proof Lines | FollowMe solid tracks: non-deterministic SEVERE |
| 20260606T174100 | Proof Lines | SEVERE/WARN across all templates — scanner priority |
| 20260606T204500 | Animation | gw_platform_out zig-zags — FollowMe solid pts in geometry |
| 20260606T213049 | Animation | gw_uturn_1 chaotic — wrong edge_lookup source |
| 20260606T220000 | Routing | Intra-station successors empty — case mismatch |
| 20260606T231244 | Show Route | Ribbon traces beam cross-section not path |
| 20260606T234218 | Show Route | Ribbon 115 pts FollowMe perimeter |
| 20260607T000000 | Routing | Pod bypasses platform landing |
| 20260607T015656 | Show Route | gw_uturn missing/offset in Show Route |
| 20260607T043309 | System | show_followme_json_overlay NoMethodError after module split |
| 20260607T070000 | Geometry | Ring arc traversed backward after re-extract |
| 20260607T120000 | Geometry | gw_in_* appear as chords despite resampling |
| 20260607T214448 | Geometry | seg_ coordinates from scan fallback not math |
| 20260609T042430 | Show Route | Large ribbon offset — wrong coordinate frame |
| 20260609T050247 | Show Route | gw_lift_in Bezier wrong shape — ev convention |
| 20260609T132909 | CP | CP tangent 6° angular error — bounding box bias |

# JPods SketchUp Plugin — Design Axioms and Active State
**Context:** This file is loaded when working in `su_jpods/`. For collaboration protocol,
session start/end procedures, and the agent team overview, see the parent `CLAUDE.md`.

---

## Non-Negotiable Design Axioms

These have been paid for with real bugs. They are not preferences.

### 1. Edge-Driven — No Calculated Centerlines as Authoritative References

SketchUp's geometry kernel operates on **edges**. FollowMe walks edges. Every position
reference in specs, sensors, metrics, and code anchors to a hard physical edge:
- Beam clearance = terrain surface edge + CLEARANCE_HEIGHT → **bottom face edge of beam**
- CP position = **stub end edge**, not stub midpoint
- Ezone boundary = **entry/exit edge** of the guideway segment
- PathBuilder receives Z=0 on center_pts; `floor_z = terrain + CLEARANCE_HEIGHT` builds from real surface

**Never:** store `bounding_box.center.z` as a beam height. Never pass Bezier midpoint Z
as a desired elevation. Never define a junction by a computed centerpoint.

**The proof:** Guideway-at-8.4m bug. The Bezier spline inherited CP stub heights (~7.5m)
as `desired_z`. PathBuilder's grade corridor allowed the interior to stay at 7.5m even
though anchor_zs was correctly set to 4.6m. Fix: zero center_pts Z before PathBuilder.
The edge-referenced floor_z dominates.

This axiom transfers to physical sensors (TOF, AprilTag), routing (Natalie), and ezone
definitions (Noelle). See full rule in `readmes/sketchup/jpods-plugin.md` Rule 8.

### 2. `Vector3d * Float` is Illegal in SketchUp Ruby

SketchUp's `Geom::Vector3d` has no `coerce` method. `vec * scalar` always raises
`ArgumentError: Cannot convert argument to Geom::Vector3d`. Always expand:

```ruby
# WRONG — crashes:
vec.normalize * 2.5

# RIGHT — always:
n = vec.normalize
Geom::Vector3d.new(n.x * 2.5, n.y * 2.5, n.z * 2.5)
```

**`jpod_connect_tool.rb` and `jpod_network.rb` each have their own copy of the bezier
and offset_path methods.** Fix both, always. One file staying broken looks like a different bug.

### 3. Color Standard — Never Reversed

- **Red = inbound** (hot end — vehicle or flow arriving)
- **Blue = outbound** (cool end — vehicle or flow departing)

Applies in all tools: SketchUp plugin, Route-Time GUI, any future visualizations.
No monochrome for directional elements. This is physics (hot/cool), not style.

### 4. CLEARANCE_HEIGHT = 4.6m — Active Safety Debt

The single source of truth is `jpod_constants.rb`. Guideways are safe at 4.6m.
**JPods vehicles (pods) are exposed to overheight trucks.** Height-sensing and pod
defensive-stop systems are committed but not yet built (CL-01 to CL-07 in ouch-list).

Do not lower below 4.6m. Do not deploy publicly at 4.6m without CL-02 having a
design, owner, and certification path.

### 5. Draw from Live State, Not Stale Instance Variables

When `@@draft_connections` is updated by a drag, the draw method must read from
`@@draft_connections`, not from instance variables set before the drag started.
`@edit_preview_pts` was the culprit that caused live Bezier to not update during drag.

### 6. Fail Fast, Never Silent Degradation

Three examples of silent degradation that cost weeks:
- Stations missing `platform_guideways` → routing ran but produced nonsense
- `msg.length != 7` → Natalie silently dropped every START ping from Nora
- Bezier at old 7.5m Z → guideways built at wrong height with no error

When a check fails, print and abort. When a definition is missing, demand it loudly.

### 7. Trip Authority Chain

Noelle certifies the map → Natalie plans the route → Nora travels it.
Nora does not re-query Noelle at runtime. Redundant validation is noise, not safety.
Stale trip files (wrong `followme_generated_at`) are purged at export, not patched.

### 8. Noelle Feature JSON — Applies to All Environments

Station behaviors (what segment sequences are physically allowed at each station template)
are declared once in `noelle_features.json` in the plugin folder. This is **not a
SketchUp-only concept** — the same behavioral declarations apply to:

- **SketchUp plugin** — TripPlanner reads `{model}.feature.json` to build trip.json
- **Physical scale model** — Nora follows the same segment sequences; the JPodsSM_RPi
  dispatcher must reference feature behaviors when planning routes for physical pods
- **Route-Time** — station capacity, throughput, and pass-through eligibility are
  derived from the same behavioral declarations

**Noelle generates `{model}.feature.json` on every Build and Validate** — never by
user request, never calculated at trip-planning time. It is a resolved reference:
Noelle writes it, everyone else reads it.

**Why this matters for large networks:** A network with 20 stations has hundreds of
possible O-D pairs. Recalculating routing rules at trip-planning time means recalculating
the same physical facts hundreds of times. Feature JSON declares them once. TripPlanner,
Natalie, and Nora look them up. This is how JPods scales.

File locations:
- Plugin authority: `su_jpods/noelle_features.json` (keyed by component definition name)
- Project reference: `{model}.feature.json` (per-template with instances list, generated by Noelle)
- Adding a new station template: add one entry to `noelle_features.json`, re-run Build

### 9. Physical Observations Are Separate from Routing Declarations

`{model}.feature.json` is a routing declaration — regenerated by Noelle on every Build
and Validate. It must never contain physical observations.

Physical observations (bumps, trees, obstructions, alignment issues, debris, vibration,
speed anomalies) accumulate from Nora's sensors over every trip. They live in:

**`{model}.physical.json`** — schema `jpods-physical-v1`.

**Why separate:** If physical observations were in feature.json, every Build would erase
them. A bump Nora logged three weeks ago at 34% of a segment would vanish the next time
a student resets the network. The physical world does not reset.

**Who writes what:**
- Noelle writes `feature.json` (routing behaviors — what is allowed)
- Nora writes `physical.json` (physical reality — what was observed)
- Noelle reads both before confirming a route is clear

**Observation structure:**
```json
{
  "seg_S048_cp1_S050_cp0": {
    "observations": [
      { "type": "bump", "location_t": 0.34, "severity": "minor",
        "description": "column joint", "logged_at": "...", "logged_by": "NORA_0001" }
    ]
  },
  "S048.gw_uturn_1": {
    "observations": [
      { "type": "alignment_issue", "location_t": 0.5, "severity": "moderate",
        "description": "yaws right at apex", "logged_at": "...", "logged_by": "NORA_0001" }
    ]
  }
}
```

Line IDs in physical.json match trip.json exactly — both inter-station (`seg_*`) and
intra-station (`STATION_ID.gw_*`). trip.json segment list is the canonical key set.

Severity: `minor` (log, report at review) → `moderate` (warn operator) → `severe`
(block route until operator signs off).

**Not yet implemented.** `anomalies: []` in `nora.json` is the staging area. First step:
populate from IMU/encoder spikes; flush to `physical.json` at trip end.

### 10. Explicit Model Datum Beats Derived Reference — 2026-05-18

When an explicit, model-author-placed datum exists, use it. Never prefer a derived
reference over an explicit one.

**The proof:** `scan_stub_pair_tips` derived CP tangent direction from cluster centroids
and then from radial distance from the bounding box center (`formation_center`). Both
failed for S050.CP0 because both references can misclassify for asymmetric or unusual
templates. The fix: validate tangent against `cap_pt` (the `dead_cap_end` entity,
explicitly placed by the model author). If the tangent points away from `cap_pt`,
reverse it. No clustering or bounding box geometry needed.

**The hierarchy:**
1. Explicit tagged entity (cap_pt, stub_pair, platform tag) → use directly
2. Hard physical edge endpoint → use directly
3. Radial distance from formation center → use only when 1 and 2 unavailable
4. Cluster centroid projection → last resort, most fragile

**Applies to all domains:** same principle governs Nora's sensor anchor points
(explicit AprilTag position, not estimated midpoint), Natalie's ezone boundaries
(entry/exit edge, not computed centerline), and physical model waypoints (ToF reads
a hard surface, not a calculated reference plane).

**Process note:** Three fix attempts were needed:
- Fix 1 (`avg_outward_tangent` guard): failed — `inward_ref` was also derived wrong
- Fix 2 (radial distance swap): failed — `formation_center` biased for some templates
- Fix 3 (`cap_pt` validation): correct — explicit datum, no derivation

The gap between Fix 2 and Fix 3 is the lesson: ask "what explicit datum exists?" before
reaching for another derived reference.

### 11. Hermite Terminal Tangent is the Curve Velocity — Reverse for Arriving CP — 2026-05-18

In the Hermite-to-Bezier formulation (`bezier_pts_via` in `jpod_connect_tool.rb`),
the tangent at each endpoint is the **curve velocity** at that point — not a handle
direction.

- **FROM endpoint:** velocity is outward (pod departs). Use `from_cp[:tangent]` as-is.
- **TO endpoint:** velocity is inward (pod arrives). Use `to_cp[:tangent].reverse`.

The ene_railroad handle convention in `bezier_pts` / `tangent_curve_pts` is different:
both handles are placed OUTWARD from their respective CPs. The math is equivalent but
the sign convention is opposite. Never mix the two formulations in the same function.

**The proof:** `bezier_pts_via` used the outward TO tangent directly → curve velocity
at the destination was outward → the guideway appeared to loop backwards at the gate.
`bezier_spline_pts` in `jpod_network.rb` already had `.reverse` correctly. The connect
tool preview was wrong; the build was right. Fixed by adding `.reverse` to the TO
endpoint tangent in `bezier_pts_via`.

**Check whenever touching Bezier/Hermite endpoint code:** is this function using the
Hermite convention (velocity = tangent magnitude × direction) or the handle convention
(control point = anchor + tangent × scale)? The two require opposite signs at the TO end.

### 12. Bezier Preview Density Must Be Adaptive — 2026-05-18

Never use a fixed segment count (`BEZIER_SEGS = 20`) for bezier preview curves.
For a 300m connection: 20 segments = 15m each. The preview looked angular and users
reported it as broken.

**Rule:** Use `PREVIEW_SEG_M = 3.0.m` — one point every 3m, minimum 20 segments.
The build code already used `BEZIER_TARGET_SEG_M = 2.0.m`. The preview needs the same
adaptive logic.

**Implementation:** `n = [[(chord / PREVIEW_SEG_M).ceil, BEZIER_SEGS].max, 512].min`

This applies to both `bezier_pts` (no markers) and `bezier_pts_via` (with markers).
When the caller passes an explicit `n:`, that still overrides — but the default is now
adaptive.

**Also applies to the physical model:** if any path preview is drawn for the tabletop
demo, the same principle holds. Fixed segment counts break at scale.

### 13. Non-Station Components Must Not Enter the CP Pipeline — 2026-05-18

`pair_stubs` and `detect_cps_from_stub_pair_tags` are called on every component in the
model that has `gw_stub_pair` tagged entities. The terrain tile (Geolocation Content)
and any other non-station components may also be scanned if they accidentally carry
these tags or if the scan is broader than intended.

**Guard added:** `pair_stubs` now returns `[]` immediately when `all_pts.empty?`
(line 1266 in `jpod_structure_tool.rb`). Previously this caused `ZeroDivisionError`.

**The broader rule:** Every function that aggregates points and divides by count must
guard against the empty case. In SketchUp Ruby, there is no type system to prevent
a scan from encountering geometry the author never intended. Fail fast with `[]` or
`nil` — never divide blindly.

### 14. All Stored Datetimes Are UTC — 2026-05-20

**Rule:** Every datetime written to a file, database, attribute, or log record is UTC,
ISO-8601 format with Z suffix: `YYYY-MM-DDTHH:MM:SSZ`.

**In Ruby (SketchUp):**
```ruby
Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')   # correct
Time.now.strftime('%Y-%m-%dT%H:%M:%S')         # WRONG — local time, no zone marker
```

**In Python (Allie, Pi agents):**
```python
from datetime import datetime, timezone
datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')   # correct
datetime.now().isoformat()                                    # WRONG — local, no zone
```

**Display is a rendering concern.** Any user-facing timestamp converts UTC to local at
render time. The stored record is always UTC.

**If timezone context matters** (physical location of an event — e.g., Nora observing
an anomaly on a Pi in Gilroy vs. a future Pi in another city), store the UTC offset
alongside the UTC datetime:
```json
{ "observed_at": "2026-05-20T18:30:00Z", "utc_offset_minutes": -420 }
```
Never store local time as the primary record. The offset is metadata, not the anchor.

**Why this matters:**
- `expires_at`, `followme_hash`, stale detection — all comparisons require a single
  reference frame. UTC is that frame.
- Multiple machines (Mac, Pi fleet, Alice server) may be in different time zones or
  have misconfigured local clocks. UTC comparisons are immune to this.
- Allie's nightly reflection and Claude Code sessions operate in the same UTC space
  regardless of where the hardware sits.

**Applies to:** Noelle (map.json, feature.json), Nora (physical.json, nora.json),
Natalie (trip assignments), Alice (billing records), Allie (memory, harvest, reflect),
Claude Code (session files, process/inbox).

**Verified clean 2026-05-20** — 9 non-UTC data-field timestamps fixed across:
`noelle.rb`, `jpod_vehicle_runtime.rb`, `jpod_animator.rb`, `jpod_structure_tool.rb`,
`jpod_followme_exporter.rb`, `jpod_network_editor.rb`, `jpod_oversight.rb`.

### 15. Formation Map — Debug Once, Use Many — 2026-05-24

Each station template has one formation map at `su_jpods/formations/{formation}.json`
(schema `jpods-formation-map-v1`). It stores CP positions and tangents in LOCAL
(definition) coordinates.

**BUILD rule:** always use an existing formation map; never overwrite it.
- Map exists → read CP data from it (pre-verified, no re-detection)
- Map missing → generate from `connection_points` attribute + save for future use

**User debug path:** open template model → Console → Workflow → **Generate Formation Map**
(always overwrites — explicit re-verification action).

**Why this matters:** CP detection runs on live model geometry. If a student accidentally
moves a cp instance, the next BUILD would generate wrong CPs for every network using that
template. The formation map breaks this dependency — CPs are verified once, then locked.
Delete `su_jpods/formations/{formation}.json` to force a fresh generation.

**Applies to all environments:** the same formation map is the authority for SketchUp
(stub synthesis), Natalie (trip planning), and Nora (ezone boundaries). If the formation
map says CP0 is at a given position, all three agree. No per-network recalculation.

### 16. Minimum In-Station Arc — Updated 2026-06-04

**Three concentric radii — beam width = 500 mm (250 mm each side):**
- Inside rail: 1500 mm — ArcCurve in SketchUp; what `MIN_STATION_ARC_RADIUS_MM` enforces
- Centerline:  1750 mm — pod travel path; physical minimum for vehicle dynamics
- Outside rail: 2000 mm — outer envelope

No arc may have inside-rail radius < 1500 mm. `gw_uturn_*` arcs are exactly at this limit
(inside chord = 3.0 m, inside radius = 1.5 m, centerline = 1.75 m, outside = 2.0 m).

**Source of truth:** `jpod_constants.rb` → `MIN_STATION_ARC_RADIUS_MM = 1500.0`

**Enforced at three checkpoints:**
1. `_generate_uturn_arc_pts_mm` — prints violation, refuses to silently compensate
2. `populate_from_open_template` — checks ArcCurve radius and chord/2; prints `🚫 FIX MODEL`
3. `proof_lines` — checks extracted.json segment radius; prints `🚫 ARC RADIUS VIOLATION`

**gw_cp_in_* direction standard — established 2026-06-04:**
Every `gw_cp_in_*` component must contain a 172mm edge on the `vector_in` tag at the
component local origin, pointing in pod travel direction. This is the explicit model datum
(Axiom 10). `populate_from_open_template` and `proof_lines` both warn when it is missing.

**ArcCurve extraction — established 2026-06-04:**
`populate_from_open_template` now checks for SketchUp ArcCurve edges first (Priority 1)
before falling back to bounding-box extraction (Priority 2). ArcCurve gives exact
connected pts, correct radius, and ordered vertex chain — essential for traffic-circle-style
stations where bounding-box extraction gives disconnected endpoints.

**Full rule:** `readmes/sketchup/jpods-plugin.md` Rule 12.

### 17. All JPods Curves Are Cubic Bezier — Established 2026-06-07

**Design axiom:** Every curve in the JPods network — station-interior (`gw_platform_out`,
`gw_c_0_0`, `gw_uturn`) and inter-station (`seg_*`) — is a **cubic Bezier curve**.
No circular arc approximation. No circular-arc-from-tangent fitting. No edge-trace heuristics.

**What this means for path extraction (`populate_from_open_template`):**
- When start point, end point, and outward tangent vectors at both ends are available,
  use `_bezier_pts_from_tangents_mm` to reconstruct the exact curve.
- Tangent convention (Axiom 11 / ene_railroad): `sv` = outward at start (departure direction);
  `ev` = outward at end (arrival direction reversed, i.e., `-ev` is travel direction at end).
  Bezier handles: B1 = sp + sv, B2 = ep + ev.
- If cross-product of tangent directions ≈ 0 (parallel), it is a straight track — return nil
  and use the 2-pt endpoint line.
- Short arcs where straight-line deviation is negligible (user-judged) may use 2-pt line.

**What this means for `show_route_followus_overlay`:**
- The ribbon draws from `anim_lookup`, which comes from path.json.
- Correct Bezier pts in path.json (written by extraction) → correct ribbon. No runtime curve generation needed.

**What to NEVER do:**
- Walk FollowMe beam solid edges to extract path geometry. The solid cross-section perimeter
  is longer than the track on short straight tracks (ratio ≈ 42×) and the edge chain algorithm
  cannot distinguish spine from cross-section reliably.
- Use circular arc approximation (`_arc_pts_from_tangents_mm`) for new track extraction.
  It remains in the codebase as historical fallback; do not promote it.
- Assume a track is straight because it is not named `uturn`. Tracks like `gw_platform_out`
  have Bezier exit curves that matter for vehicle dynamics and followus ribbon accuracy.

**Implementation:** `jpod_path_json.rb` → `_bezier_pts_from_tangents_mm` (Priority A in
`populate_from_open_template`). Replaces `_arc_pts_from_tangents_mm` in Priority A.

**Curve sampling — domain split (established 2026-06-07):**

| Domain | How curves are represented | Why |
|--------|--------------------------|-----|
| **SketchUp (SU)** | Polyline: one pt per ~1000mm of arc length, min 4 pts | Human visual perception — smooth appearance at station scale; chord deviation <10mm at 15m radius |
| **Physical (PH)** | True analog — continuous motor control follows the actual curve | Discrete waypoints produce jerky motion; the vehicle must track the real curve, not a polyline approximation |

The 1000mm spacing rule applies to: `extracted.json` pts_mm, `path.json` pts, followus ribbon,
and any SketchUp visualization. It does NOT apply to Nora's motor control, ezone boundaries,
or any Pi firmware curve-following. Physical curve following is a separate problem (smooth
velocity profile on the arc, not waypoint-to-waypoint stepping).

### 18. Every Coordinate Must Declare Its Frame of Reference — Established 2026-06-07

JPods geometry crosses three distinct frames of reference. Code that silently mixes them
produces bugs that are invisible at the call site and only manifest as wrong behavior
(wrong radius, wrong Z, wrong ribbon position, wrong vehicle path).

**The three frames:**

| Frame | What it measures | Key values |
|-------|-----------------|-----------|
| **Structural** | Inside rail edge — what SketchUp ArcCurves and FollowMe paths are built on | inside radius = 1500mm (`MIN_STATION_ARC_RADIUS_MM`) |
| **Vehicle path** | Pod centerline — where the vehicle actually travels | centerline = inside + 250mm (`BEAM_WIDTH/2`) |
| **Vertical** | Beam center (mid-beam), beam top face, or terrain surface | varies by ±250mm (`BEAM_DEPTH/2`) |

**Conversions (all explicit, all named):**
- Structural inside rail → vehicle centerline: scale radially outward +`BEAM_WIDTH/2` (250mm)
- Beam center → beam top: +`BEAM_DEPTH/2` (250mm)
- Beam center → beam bottom: −`BEAM_DEPTH/2` (250mm)
- Terrain → beam bottom: +`CLEARANCE_HEIGHT` (4600mm)
- Terrain → beam center: +`CLEARANCE_HEIGHT` + `BEAM_DEPTH/2` (4850mm)

**Frame declarations for established data stores:**
- `extracted.json` pts_mm → LOCAL TEMPLATE frame, beam center Z, **vehicle path** (after arc correction)
- `path.json` pts → WORLD frame, beam center Z, **vehicle path**
- `followus ribbon_z` → display only, lifted above beam top; not a vehicle path coordinate
- `CLEARANCE_HEIGHT` → terrain surface → beam bottom edge (structural)

**The rule:** Every function signature, comment, or variable that holds a coordinate must
name its frame. "arc correction" is not enough — write "structural inside rail → vehicle
centerline (+250mm)". When a coordinate crosses a frame boundary, the conversion is
explicit, named, and in one place.

**Why this matters:** Three separate bugs in this session (gw_uturn inside rail, Z-disconnected
ribbon, arc radius check against wrong reference) all had the same root cause: a coordinate
was created in one frame and consumed in another with no conversion and no documentation
of which frame applied. The followus ribbon was lifted "above pts" — but pts were sometimes
beam center, sometimes beam top. The arc correction assumed "extracted pts are in structural
frame" without verifying. Challenge every coordinate: which frame is this in?

### 19. One Source of Truth — Do the Math — Established 2026-06-07

**Rule:** Every network coordinate has exactly one authoritative source. Compute it once from
that source. Do not scan 3D geometry to recover what math already knows. Do not snap or patch
to reconcile two sources that disagree. If they disagree, the model is wrong — fix the model.

**The proof:** `generate_map_json` had a `beam_path_fallback` that scanned built SketchUp groups
to recover seg_ endpoint Z. It was also doing `z = (beam_top_Z - BEAM_DEPTH) × 25.4` — which
is just `cp[:center].z × 25.4`. The datum was the CP center all along. The fallback was hiding
the math inside a geometry scan. A Z-snap was then patching the mismatch between the fallback
result and the station track geometry.

**The fix:** `StructurePlacer.connection_point(entity, index)` applies the station instance's
world transformation to the definition-local CP center and returns the exact world position.
That position IS the seg_ endpoint. No scan, no snap, no fallback.

**What this means for the Build pipeline:**

`cached_connection_point` must apply `entity.transformation` to definition-local CP coords.
Without it, Build produces correct guideways only on flat terrain (Z≈0). When terrain changes
and the station instance moves, `entity.transformation` changes. The Bezier adapts automatically.
**This is what "Build adapts to terrain changes" means** — not a separate recalculation, not
a cache flush, not a rebuild trigger. The transformation IS the terrain adaptation.

**Corollaries:**

1. **No fallbacks for coordinate data.** If a station entity or CP is not found, log and skip.
   Do not approximate from nearby geometry or stored beam attributes.

2. **No snapping to reconcile sources.** A snap means two things disagree. Find the one
   authoritative source and remove the other. Z-snaps, position-snaps, endpoint-snaps — all
   symptoms of multiple sources of truth.

3. **No reading 3D geometry to recover computed values.** If Build computed a Bezier path,
   that result is available during Build. Store it in a structured attribute if needed later.
   Do not re-derive it by walking FollowMe edge geometry.

4. **Reject, not degrade.** If the math cannot run (missing entity, missing CP), reject the
   seg_ from map.json with a log message. A map with a missing seg_ is better than a map
   with a seg_ at the wrong coordinates.

**Applies to all domains:** Route-Time (network coordinates from graph data, not pixel scanning),
Physical (trip paths from Natalie's plan, not re-derived from telemetry), WebClerk (prices from
Alice's decision, not re-read from cached display values), Allie (synthesis from indexed corpus,
not re-parsing raw logs).

### 20. Template Geometry Protection — Established 2026-06-09

Station template geometry.json files contain hand-authored Bezier curves and Z corrections
that **cannot be regenerated automatically**. Generate Geometry JSON will destroy them if
run without awareness. Three protection layers are in place:

**Layer 1 — Console gate** (`jpod_console.rb`): Before running Generate Geometry JSON,
the tool reads the existing geometry.json and shows `UI.messagebox(MB_YESNO)` listing all
protected tracks. User must confirm to proceed.

**Layer 2 — Per-template notes.md**: Each template folder has `notes.md` documenting which
tracks are hand-authored, why, junction coordinates, and the git restore command.

**Layer 3 — This section**: Per-template protection map for Claude Code sessions.

**What triggers protection** in `save_geometry()` (`jpod_path_json.rb`):
- Track has >2 pts_mm (Bezier or ArcCurve) → preserved, length_mm updated
- Track has `"authored": true` flag → preserved (hand-corrected 2-pt track, e.g. Z fix)

**Per-template protection map:**

| Template | Protected tracks | Key concern |
|----------|-----------------|-------------|
| `JPods_station_parking` | gw_platform_in1, gw_platform_in2, gw_lift_in, gw_lift_parking, gw_platform_out1, gw_platform_out2 (Bezier); gw_lift (straight, confirmed) | Series junction gaps must stay 0.0mm; tangents from adjacent track angles, not chord |
| `station_thru_dip` | gw_lift_in, gw_platform_in, gw_platform_out (Bezier); gw_uturn_0, gw_uturn_1 (arc) | 3D curves with Z transition; chord direction cannot reproduce these |
| `station_line_end` | gw_lift_in, gw_platform_in (Bezier); gw_uturn_0, gw_cp_in_0 (authored=true) | Z correction: gw_cp_in_0 and gw_uturn_0 must be Z=10242.7, NOT 8242.7 (model stores them 2m low) |
| `traffic_circle7` | None currently | Flat ring; Generate Geometry JSON is safe |

**Restore any template from git:**
```
git -C "$SU_PLUGINS" checkout HEAD -- templates/track_formations/<template>/geometry.json
```

**Never run Generate Geometry JSON on station_thru_dip or station_line_end** without
reading their notes.md first. These templates have 3D Z transitions that auto-extraction
cannot reconstruct.

### 21. Ring Junction Endpoints Come From the Arc — Established 2026-06-09

**Rule:** Every endpoint that touches a ring junction in a traffic-circle template must equal
the adjacent ring arc's own FIRST or LAST pt. Never use switch-box offset coordinates.

**The proof:** traffic_circle7 short connectors (gw_c_0_1, gw_c_1_2, gw_c_2_3, gw_c_3_0)
and approach tracks (gw_in_*, gw_out_*) had endpoints ~500mm inside the ring radius — at
switch-box offset positions extracted from model geometry, not on the ring centerline.
Effect: ribbons visually crossed the guideway. Fixed by setting every junction endpoint to
the adjacent arc's FIRST or LAST pt. Correct connector length = 1000mm; any deviation means
an endpoint is off the ring.

**Diagnosis:**
- Ribbon crosses guideway at junction → endpoint not on ring (check radius from ring center)
- gw_in/gw_out draws straight → needs Bezier (13-pt); ring-side endpoint wrong
- Length of short connector ≠ 1000mm → one or both endpoints off-ring

**For any ring-topology template:**
1. Four ring arcs define all eight junction EP coordinates (their FIRST and LAST pts)
2. Short connectors: FIRST = one arc's exit pt, LAST = next arc's entry pt
3. Approach in/out tracks: ring-side endpoint = same EP coordinate as adjacent connector
4. Vehicle direction on each arc: determine CCW vs. CW; arcs may be stored LAST→FIRST
5. Approach Bezier: sv = CCW ring tangent at diverge EP; ev = REVERSE of CP track direction

**Detail in:** `templates/track_formations/traffic_circle7/notes.md`

---

### 22. One File Per Station Template — Established 2026-06-09

**Rule:** Every station template has exactly one authoritative data file for topology
and behavior combined: `lines.json`. There is no separate behavioral override file.

**The proof:** Separating topology (lines.json) from behavior (feature.json) requires
designers and users to keep two files coordinated across every track rename, every
EP change, and every chain update. In the field this coordination fails. Silent
divergence — topology updated, behavior not — produces routing failures that are
hard to diagnose because both files look individually valid.

**The physical argument:** In a real JPods network you cannot reprogram a station to
behave differently without physically changing the track layout. The software must
reflect this. If the behavior must be different, design a different station with
different tracks. One topology → one behavior. One file.

**What lines.json contains:**

| Section | Owner | Gate |
|---------|-------|------|
| `eps[]`, `lines{}` | Designer (topology) | `eps_header.approved_by` — Noelle enforces |
| `chains_*`, `landing_chains`, `hold_loop_chain`, `parking_chain`, `pass_chains` | Sally (behavior) | `chains_header.approved_by` — Sally will not operate unsigned |

Two approvals, two agents, one file. The section headers make ownership explicit
without creating a synchronization risk.

**Template folder committed files (exactly these six):**
```
model.skp       — geometry source (designer)
lines.json      — topology + behavior (designer + Sally, both approved by Bill)
cp.json         — CP positions (Extract Template generates once)
geometry.json   — vehicle paths (Extract Template generates, Bezier-protected)
notes.md        — documents protected geometry.json tracks
image.png       — thumbnail
```

`feature.json`, `extracted.json`, and all `lines~*.json` backup files are not
committed. `model.*.json` files are runtime artifacts — never committed.

**Corollary:** The Console tool "Sally: Draft Chains" drafts the behavioral sections
of lines.json, not a separate file. Sally drafts into lines.json; Bill approves by
setting `chains_header.approved_by`.

---

## Current Active State (as of 2026-05-18)

### SketchUp Plugin — What Works

- Connect Guideways tool: CP detection, waypoint placement, live Bezier during drag
- Cursor state machine: hand (hover), 4-arrow (drag), crosshair (placement), pencil (gate)
- Build pipeline: runs without crash; **4 segments confirmed built on CA_Gilroy_Clean 2026-05-18**
- **CP tangent direction: CONFIRMED CORRECT** — cap_pt validation added; explicit gate datum
  overrides cluster/radial derivation; all tangents now reliably outward
- **Bezier preview density: CONFIRMED CORRECT** — PREVIEW_SEG_M=3m adaptive; no more 15m
  coarse segments on long connections
- Clearance height: CLEARANCE_HEIGHT = 4.6m; legacy Z zeroed in markers and center_pts
- **Waypoint marker Z: CONFIRMED CORRECT** — terrain + CLEARANCE_HEIGHT default; user adjusts Z; 1/5/10m reference circles at terrain level; stem from terrain to beam level; `ground_z_at` used for placement to skip existing marker stems
- **CP anchor Z: CONFIRMED CORRECT** — `from_cp[:center].z + BEAM_DEPTH` (non-traffic) or `+ BEAM_DEPTH/2` (traffic circle); confirmed flush connection at S012 and S044 on 2026-05-14

### Change Control — Marker Z and CP Anchor Z

**These two algorithms are confirmed working. Do not change either without a written plan.**

Three CP anchor alternatives were tested on 2026-05-14 and all failed before restoring
the committed code. The documented failures are in `readmes/sketchup/jpods-plugin.md`
Rules 9–10 and `readmes/sketchup/jpods-cp-regression-guard.md`.

Before proposing any change to marker Z or CP anchor Z:
1. State the specific problem being solved
2. Cite the exact code location being changed
3. Describe why the current algorithm fails for that case
4. Describe the proposed algorithm and which failure modes it avoids
5. Get Bill's sign-off before touching code

### SketchUp Plugin — Open Issues

- **Station templates** (F-07): station .skp stubs still at 7.5m stub height — structural
  redesign needed, not code. Logged in feature-list.md.
- **Noelle direction violations**: S013, S044 flagged "missing detectable platform guideways"
  — station model definition issue, not plugin bug.
- **Station looping**: pods accumulate at station U-turns — deferred to ~2026-05-15.

---

## Reload Command (SketchUp Ruby Console)

To reload a changed file without restarting SketchUp:
```
load Sketchup.find_support_file('jpod_network.rb', 'Plugins/su_jpods')
```
Then: Extensions > JPods > Create > Build to test.

**Always use `Sketchup.find_support_file` — never a literal path with spaces.**
The path `Application Support/SketchUp 2026` contains spaces. Markdown code blocks
and backtick formatting introduce extra whitespace at those spaces when rendered,
producing a broken command that most users cannot diagnose. `find_support_file`
has no spaces and works regardless of SketchUp version or user home directory.

Replace the filename to reload other files:
```
load Sketchup.find_support_file('jpod_structure_tool.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_connect_tool.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_animator.rb', 'Plugins/su_jpods')
```

Reload only the changed file — SketchUp state persists across reloads,
so a full restart is only needed if constants change.

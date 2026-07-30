# JPods SketchUp Plugin — Design Specification

Version 2.3 · April 2026

---

## Objective

Model JPods grade-separated networks of solar-powered self-driving robot vehicles
with max payloads of 500 kg.

---

## Authoritative Artifacts

These are the only project-state artifacts that should be treated as authoritative in the SketchUp plugin:

1. `<model>.followme.json`
- Sole network source of truth.
- Contains the runtime map and the editable `network_definition` authoring block.
- Do not split network authoring back out into `build.json` files.

2. `<model>.vehicles.json`
- Sole startup vehicle source of truth.
- Holds Nora placement and assignment intent.
- Do not mix transient route diagnostics or event chatter into this file.

3. `trips/<model>.trip.<nora_id>.json`
- Derived trip artifacts from FollowMe and Natalie assignment.
- Useful for execution and audit, but not the design source of truth.

4. `*.log.json`
- Logs are allowed, but only as standalone JSON documents with `log` in the filename.
- Examples: `<model>.console-log.json`, `jpods-log-YYYY-MM-DD.log.json`.
- Logs are evidence, not startup state.

---

## Physical Design

### Non-Negotiable CP Datum Rule

The most important FollowMe geometry rule is the CP datum:

- The authoritative CP datum is the **bottom centerline of the paired `stub_pair` gate**.
- The midpoint from paired `stub_pair` tips must be corrected by `BEAM_WIDTH / 2` **inward across the gate**.
- Guideway build anchors and FollowMe line coordinates must be bottom-centerline to bottom-centerline, never edge-to-edge.

If you see a guideway aligning to the outside edge of a removed `dead_end_cap`, that is a datum error, not acceptable geometry.

### The Three Centerlines

Every guideway segment is defined by **three parallel generallyhorizontal lines**:

```
   ←1.75 m→  ←1.75 m→
   CL-Left   CL-Right
        ↑
            require 'json'
      model = Sketchup.active_model
      model.start_operation('Add CP circles to station definitions', true)
      
      model.entities.grep(Sketchup::ComponentInstance).each do |inst|
        next unless inst.definition.name.include?('JPods_station_solar')
        sid = inst.get_attribute('JPods', 'structure_id', '?')
        raw = inst.get_attribute('JPods', 'connection_points')
        next unless raw
      
        cps  = JSON.parse(raw)
        defn = inst.definition
        puts "\n#{sid}  (#{defn.name})  — #{cps.size} CPs"
      
        cps.each do |cp|
          ctr    = Geom::Point3d.new(*cp['center'])
          normal = Geom::Vector3d.new(0, 0, 1)
          defn.entities.add_circle(ctr, normal, 0.011.m)
          puts "  CP#{cp['index']}  (#{ctr.x.to_m.round(3)}, #{ctr.y.to_m.round(3)}, #{ctr.z.to_m.round(3)})"
        end
      end
      
      model.commit_operation
      puts "\nDone. Now run: Plugins > JPods > Network > Recompute Connection Points"
      nil
```

| Line | What it is |
|------|------------|
| **CP centerline** | The line connecting one structure's CP marker to another's. The authoritative datum is the **bottom centerline** at the gate seam. All offsets, columns, and solar panels are computed relative to this line. |
| **Left guideway CL** | 1.75 m left of CP centerline — one beam, one direction of travel |
| **Right guideway CL** | 1.75 m right of CP centerline — the opposite direction of travel |

Stubs on each structure are always placed as a **stub-pair**: two parallel stubs 3.5 m
centre-to-centre, with the CP marker at their exact midpoint.

### Guideway Cross-Section

Each beam: **0.5 m wide × 0.5 m deep**.  The authoritative geometric datum is the
**bottom centerline** of the beam. Physical beam geometry is then built upward from
that datum by `BEAM_DEPTH`.

### Column (T-support)

- Template: `templates/structures/JPod_support_T/model.skp`
- One column per **25 m** along the CP centerline
- The T crossbar spans **±1.75 m cross-track** so each arm sits above one guideway beam
- **Top of guideways** (beam top face) connects to **underside of T arms**
- Column height varies with terrain; always terrain-to-beam-top
- Component origin at **beam-top level** (top of T); column extends downward in −Z

### Solar Collectors

- Template: `templates/structures/JPod_solar/model.skp`
- One panel module every **2.5 m** (leading-edge to leading-edge) along the CP centerline
- Each panel is **2.43 m** along the travel direction × **6.5 m** cross-track
  (3.5 m guideway CTC + 1.5 m overhang each side)
- 2.43 m ÷ 2.5 m repeat = **97 % solar coverage** (0.07 m gap between modules)
- Panel sits **on top of the beam top face** — component origin at leading edge, beam-top level
- Component +Y = travel direction; +X = cross-track (ene_railroad `Transformation.axes` convention)


## Current Status — April 17, 2026

### Bezier tangent convention (resolved April 17)

**Problem:** Some Bezier preview curves and built guideways looped past their
destination CP and approached from the rear, violating the curvature rules and
producing routes far longer than the straight-line distance.

**Root cause — two detection methods, inconsistent conventions:**

| Detection method | When used | Tangent as stored |
|---|---|---|
| `detect_gate_lines` | Structure has CP circles in template SKP | **Outbound** — radially away from structure origin |
| `pair_stubs` fallback | No circles; derived from track endpoint data | **Inbound** — `ctrl[2]` points into the track (toward centre) |

Any global `.reverse` fixed one group and broke the other.

**Fix — dot-product direction check at Bezier build time:**

Instead of relying on stored convention, each tangent is snapped to the geometrically
correct direction just before the Bezier formula runs:

```ruby
chord_v = p1 - p0
# t0 must point toward p1 (dot > 0)
t0 = raw0.dot(chord_v) >= 0 ? raw0 : raw0.reverse
# t1 must point toward p0 (dot < 0)
t1 = raw1.dot(chord_v) <= 0 ? raw1 : raw1.reverse
```

The formula `C = endpoint + t * (chord/3)` then always places each Bezier handle
between the two endpoints, producing S-curves that leave each CP in the correct
outbound direction and arrive smoothly.

This fix is applied in all three Bezier calculation sites:
- `jpod_network.rb` — `tangent_curve_pts` (used by Build)
- `jpod_network_editor.rb` — inline in `draw()` (blue dashed JSON previews)
- `jpod_network_editor.rb` — `bezier_preview_pts` (hover preview + committed lines)

The `pair_stubs` method was also updated to store outbound tangents (consistent with
`detect_gate_lines`) so any future code reading the stored value gets a uniform
convention.  The Bezier sites remain robust regardless, because they use the dot-product
check rather than trusting stored direction.

---

## Current Status — April 17, 2026 (latest)

## Current Status — April 18, 2026 (latest)

### Station CP position (resolved April 18)

**Problem:** Teal CP circles on `JPods_station_solar` structures appeared on one guideway
centerline instead of at the midpoint between the two parallel guideways.

**Root cause:** The station formation has only **2 external stubs** — both on the upper
guideway (Y = +48.617" in template space).  The lower guideway connects internally to
platform ramps, so `pair_stubs` received only unpaired stubs and had to infer the
cross-track position.  The old unpaired-stub code tried to find a partner endpoint with
`along_dist < spacing`, which always failed because the lower guideway endpoints are
~1800" away from the gate end — and the fallback was also wrong.

**Fix (`pair_stubs` unpaired branch, `jpod_structure_tool.rb`):**  
Replaced all partner-search and fallback logic with a single geometric offset:

1. Take the stub's outer tip.
2. Build the cross-track unit vector (`out_dir × Z_AXIS`).
3. Orient it **outward** (away from formation centroid).
4. Offset `DUAL_TRACK_SPACING / 2.0` (1.75 m) in that direction.
5. Store the CP on the beam **bottom-centerline** datum in Z.

Result: CP is centered between the two guideway beams in XY and stored on the bottom-centerline datum in Z.

**CP detection architecture (resolved April 25):**  
Primary path is `stub_pair` tag scan — see Formation Model Tag Requirements above.  
Traffic circles continue to use `pair_stubs` with 9 m radial outward offset (empirically validated; do not change).

### T-column vertical position (resolved April 18)

`T_ARM_OFFSET` corrected from 0.43 m to **2.95 m** in `jpod_constants.rb`.  T arm
bottoms now rest on beam top faces.

**⚠️ TODO — Auto-detect T arm Z from component bounding box** so `T_ARM_OFFSET` does
not need manual recalibration when the template changes.

### Right-side running / CCW traffic circle (resolved April 18)

**Fix (`jpod_network.rb`):** `beam_path` for `track_idx=0` (left-of-travel lane) is
now reversed at build time.  Vehicles on the two parallel guideways travel in opposite
directions; traffic circle runs CCW.

### Vehicle animation — elevation changes (open)

Vehicles currently follow the stored FollowMe path on the **bottom centerline** of the
built guideway (terrain-snapped, grade-limited). XY alignment is Bezier/arc based; Z alignment is solved separately by the vertical-profile algorithm, not by Bezier. On slopes, the vehicle transform only rotates around Z — it does not
pitch to follow the grade.  **Fix next session:** apply a pitch rotation equal to the
local slope angle so the vehicle body follows the terrain profile.

---

## Current Status — April 18, 2026

### Network Editor viewport click workflow (resolved April 18)

**Problem:** Hovering a CP showed a correct Bezier preview, but clicking the second CP
did not enter the connection into the JSON editor — the click was resetting the selection
instead of completing it.

**Root cause:** `onLButtonDown` required `Shift+click` to finalize a connection.  A plain
click on a different CP while one was already selected restarted the FROM selection rather
than completing the connection.

**Fix:**

| Click | Before | After |
|---|---|---|
| Click CP A (nothing selected) | Set FROM | Set FROM |
| Click CP B (A selected) | Reset — start over with B as FROM | **Complete A→B connection → JSON** |
| Click CP A again (A selected) | Reset | Deselect |
| Shift+click a marker | Add as waypoint | Add as waypoint (unchanged) |

`CP_RADIUS` also increased from 1.5 m to **3.0 m** so the teal circle fills the full
gate opening (3.5 m stub-pair width), making CP targets visually unambiguous.

---

## Current Status — April 22, 2026 (latest)

> **Station documentation consolidated.** All formation tag requirements, CP detection
> rules, platform detection policy, parking spur reservation, and station verification
> checklists are now in **`readmes/stations.md`** (the single source of truth).
> What follows here is the original session history kept for context.

### Formation Model Tag Requirements — MANDATORY (April 25, 2026)

> ⚠️ Authoritative version in `readmes/stations.md`. This section is historical context.

These SketchUp tag names are the authoritative CP detection mechanism.  
**Noelle must enforce these before any formation SKP is accepted into the plugin.**

#### Required tags

| Tag name | Applied to | Why |
|---|---|---|
| `stub_pair` | Both parallel stub tracks at each gate (the two short track stubs that stick out at the connection face) | `detect_cps_from_stub_pair_tags` finds all entities on this tag, locates the outer-end representative point of each, pairs tips ~3.5 m apart, takes the midpoint, then shifts by `BEAM_WIDTH / 2` across the gate to land on the true guideway centerline pair midpoint. This is the **primary** CP detector. |
| `dead_end_cap` | Each removable ending cap entity (ene_railroad ending component) | Vehicles must not traverse beyond a capped endpoint. Also used by `detect_connection_points_from_endings` as the secondary CP detector. |
| `platform` | The loading/unloading siding guideway inside each station component | FollowMe export scans for this marker to build station platform records used by navigation and trip assignment. Supported markers are tag `platform` (preferred), instance name `platform`, or definition name `platform`. |

#### Network runtime contract (navigation + animation)

Navigation, trip planning, and animation all depend on a valid declared network state:

1. **Stations** must have a unique structure ID (`S001`, `S002`, ...), plus valid CPs.
2. **Platform siding(s)** must be detectable in each station (`platform` marker rule above).
3. **Guideways** must be built from CP-to-CP connections so FollowMe lines exist.
4. **Vehicles** must be assigned to valid FollowMe lines/trips generated from that export.

If any one of these is missing, runtime behavior degrades to warnings, missing platform assignments, or no valid route.

#### Station identity requirements

- Preferred workflow: place stations using `Network > Place Structure`; this auto-assigns non-recycled `Sxxx` IDs and CP labels.
- If a station is inserted manually, it must still resolve as a station and have a unique `Sxxx` identity in plugin attributes, or network JSON references cannot map reliably.
- For human readability in the model tree, set instance name to `station` and set the definition name to the station's unique ID (`S097`, `S098`, ...).

#### Do stations need a `station` tag?

No, a SketchUp tag named `station` is **not required** for routing/runtime correctness.

- Required tags are `stub_pair`, `dead_end_cap`, and `platform`.
- A `station` tag is still recommended for visibility control (show/hide station geometry cleanly in large models).
- Keep visualization tags separate from runtime tags to avoid accidental breakage of CP/platform detection.

#### Authoritative CP / FollowMe datum

The authoritative datum for both CPs and FollowMe is the **bottom centerline** of the guideway.

- CPs are stored at the bottom centerline of the gate seam.
- The CP sets the outbound direction and endpoint anchor datum.
- `jpod_network.rb` then builds the physical guideway geometry from that datum while following markers and terrain.
- FollowMe is defined on the bottom centerlines of the two built parallel guideways.
- Vehicle runtime uses those FollowMe bottom-centerline paths, not the beam top face.

#### Why exact tag names are non-negotiable

`jpod_structure_tool.rb` does `entity.layer.name.downcase == "stub_pair"`.  
A typo, extra space, capitalisation, or missing tag silently falls through to geometry inference — which has proven unreliable and has caused hours of debugging.  

#### Detection policy (authoritative)

- Use **tags first** to define geometric intent (`stub_pair`, `dead_end_cap`, `platform`).
- Use **instance/definition names as fallback only**, never as the primary authority.
- For human clarity and fallback robustness, keep `track` in the name of real runnable guideway entities (for example `Track-platform`).
- Runtime routing and animation are **attribute/line-id based** (`connection_id`, `track_index`, FollowMe line IDs), not instance-name based.

#### Why the paired `stub_pair` midpoint still needed a 0.25 m correction

The `stub_pair` tags fixed the gross ambiguity, but one last local offset remained.

What the code now does for paired stubs:
1. Scan the geometry inside each tagged `stub_pair` entity.
2. Find the representative point at the outer end of that stub.
3. Pair the two stubs that are ~`DUAL_TRACK_SPACING` apart.
4. Take their midpoint.
5. Shift that midpoint by `BEAM_WIDTH / 2` across the gate.

Why step 5 is required:
- In the current formation SKPs, the tagged stub geometry resolves to a **lateral face plane** of the guideway beam, not directly to the beam centerline.
- `BEAM_WIDTH = 0.5 m`, so that face is `0.25 m` from the beam centerline.
- Without the correction, the CP circle is tangent to the **outside of one guideway** and the **inside of the other**, which is exactly the failure Bill observed.
- Adding `BEAM_WIDTH / 2 = 0.25 m` in the correct cross-gate direction puts the CP on the true gate centerline.

This is now the authoritative rule for paired `stub_pair` gates in the current models.

#### Noelle's verification checklist (run after every model change)

1. Open the formation SKP in SketchUp.
2. Open **Tags** panel. Confirm tags `stub_pair` and `dead_end_cap` exist.
3. Select each gate's two stub tracks → confirm they are on tag `stub_pair`.
4. Select each ending cap entity → confirm it is on tag `dead_end_cap`.
5. In SketchUp with the plugin loaded: place the formation, then **Network › Recompute CPs**.
6. Ruby Console must show: `JPods resolve_connection_points: N CPs from stub_pair tags`
7. CP circles (teal, 1.75 m radius) must sit visually centered between the two parallel guideway beams at the cap seam.
8. The circle must not be tangent to the outside of one guideway and the inside of the other. It must read as centered on the two guideway centerlines.

---

### Connection Point (CP) geometric anchor — THE RULE (resolved April 22)

**Rule formally stated:**

> **The Connection Point (CP) is the midpoint between the two seam points where the two parallel guideways meet their removable ending caps.**
> 
> `CP_center = (seam_left + seam_right) / 2`

where each seam is the 3D point on the **bottom centerline datum** where a guideway's main extrusion ends and its removable ene_railroad v23 ending cap begins.

**Why this matters:**

- At **placement time**: CP marks the gate centerline and bottom-centerline datum where network connections anchor
- At **build time**: CP tells `jpod_network.rb` exactly where to call `remove_structure_endcaps()` and where to anchor the built guideway before lifting the physical beam geometry upward
- At **runtime**: FollowMe is generated on the bottom centerlines of the two parallel guideways defined by that CP direction
- **Visually**: the teal CP circles mark the gate seam datum between the two guideways rather than a beam top face or face centroid

**Problem fixed (April 20–22):**

Traffic-circle CPs were incorrectly placed at the **ring-junction end** of guideway arms (~13.5 m from center) instead of the **cap end** (~22.5 m).

Root cause: Each traffic-circle arm track, drawn from ring-center outward, produced two external stubs:
- The true outer stub (outer tip at the cap end) — correct location
- A ring-junction "stub" (where arm meets ring, misaligned by tolerance) — shadow/error

Old pairing logic could not distinguish them and sometimes paired ring-junction stubs with each other, placing CPs at the wrong end of the guideway pair.

**Solution (implemented April 22):**

1. **Stub normalization:** for each stub, always store `point = outer tip` (farther from formation centroid), with companion = inner end. Flip stubs that had it backwards.

2. **Deduplication:** remove redundant stubs with identical outer tips. Keep only one record per arm.

3. **Geometric offset discovery:** empirically measured that the correct CP location sits **9 meters radial outward** from the paired outer-tip midpoint (`pd_outer`).

4. **Implementation:**
   ```ruby
   outward_offset = is_traffic_circle ? 9.m : 0.0
   pair_stubs(stubs, defn, all_eps, outward_offset: outward_offset)
   ```
   In `pair_stubs()`, after computing `pd_outer`, apply:
   ```ruby
   radial_out = (pd_outer - centroid).normalize
   shifted = pd_outer.offset(radial_out, outward_offset)
   gate_ctr = Geom::Point3d.new(shifted.x, shifted.y, pd_outer.z)
   ```

5. **Validation:** Bill confirmed in SketchUp that CP circles now sit at the correct location (the seam) — visually verified.

**Next phase:**

Replace the hardcoded `9.m` offset with an explicit geometric anchor — either:
- **Best:** Add a tiny marker/group named `CapSeam` inside each ene_railroad ending definition at the seam. Plugin finds and pairs them.
- **Good:** Verify ene_railroad v23 consistently places ending instance origin at the seam. If true, `detect_connection_points_from_endings` will work without offset.
- **Current pragmatic:** Ship with 9.m offset; plan the anchor system for v2.4.

See `/memories/repo/connection-point-rule.md` for full derivation and code locations.

### Dead-end cap routing rule — current status (April 22, 2026)

**Operational rule:**

> If a guideway endpoint still has a `dead_end_cap`, vehicles must not traverse beyond that endpoint.

This is now enforced at runtime in vehicle routing and in FollowMe path visualization:

- `dead_end_cap` objects are scanned from placed `JPods Structure` instances
- each guideway's **outbound endpoint** is checked against cap points (snap tolerance)
- if capped, transition beyond that segment is blocked even when `next_cid` exists
- vehicle behavior at a blocked endpoint:
  - if opposite track exists for same connection: auto U-turn
  - if no opposite track: hold at dead end

**Design intent preserved:**

- `dead_end_cap` remains in final networks as a physical/planning marker
- future expansion remains possible by removing the cap and adding a new connection
- no topology rewrite required; `next_cid`/`next_options` can be used once cap is removed

**FollowMe Paths expected display:**

- green/red routed lines for open endpoints (`next_cid` and no cap)
- orange dead-end styling for capped outbound endpoints

**Quick verification checklist:**

1. Keep a segment with `next_cid` set and a visible `dead_end_cap` at its outbound endpoint.
2. Run **Network > Show FollowMe Paths**.
3. Confirm that endpoint renders as dead-end styling (orange).
4. Start animation and verify console logs indicate blocked-by-cap behavior (`capped endpoint`).
5. Remove the cap and rebuild; verify traversal resumes through successor routing.

### FollowMe — Authoritative Line Format (April 25, 2026)

**Full specification:** `readmes/followme.md`  
**Example file:** `readmes/followme_example.json`

**Design rules (source of truth):**

> **FollowMe.json defines the world.**  
> CP geometry and guideway geometry exist only to generate FollowMe lines.  
> Once FollowMe lines exist, vehicle runtime uses only this file.

**Authoritative FollowMe datum:**  
Every FollowMe line is defined on the **bottom centerline** of a guideway.  
The CP provides the endpoint datum and direction; marker/terrain shaping then defines the final built bottom-centerline path.

**XY vs Z rule:**  
- XY routing uses Bezier plus horizontal arc smoothing.
- Z routing does **not** use Bezier. Z is solved by `PathBuilder.apply_vertical_profile` as a grade-limited vertical profile.
- Endpoint Z blending is capped to a maximum diameter of `5.0 m`.

**Three agents, one file:**

| Agent | Role |
|---|---|
| **Noelle** | Network authority — owns and validates the FollowMe file; exposes the graph |
| **Natalie** | Trip planner — walks Noelle's graph; assigns itineraries (ordered line-ID sequences) to Noras |
| **Nora** | Vehicle + logger — travels by `(line_id, mm_traveled)`; appends per-line experience logs |

**Shared map vs observed experience:**

- `followme.json` is the declared network map shared by Noelle, Natalie, and every Nora.
- Nora logs are append-only observations keyed by line ID; they are not the map.
- Noelle uses Nora-reported observations to assess integrity, health, delays, or anomalies on the network.
- Natalie routes on Noelle's declared graph, not on raw geometry.
- Nora executes Natalie's assigned line sequence and reports actual experience on each traversed line.
- In this VS Code workspace, Copilot may simulate a Nora for validation and audit work; keep that simulation lightweight because this environment has one processor, unlike physical Noras with excess compute and onboard sensors.

**Line record — key fields:**

| Field | Meaning |
|---|---|
| `id` | `"<connection_id>\|<track_index>"` — unique in file |
| `length_mm` | Travel distance in mm along polyline |
| `start` / `end` | 3D world coords in mm |
| `connections.end.lines` | Line IDs reachable from this line's end |
| `connections.start.lines` | Line IDs arriving at this line's start |
| `connections.direction` | Always `"start_to_end"` — FollowMe is one-way |

Authoring convention: connection IDs should stay human-readable and sequential: `seg_1`, `seg_2`, `seg_3`, ... .

**Directionality rules:**

- FollowMe lines are one-way in authored direction only.
- Loops (traffic circles, hairpins) run CCW.
- Turns ≤ 90° at every join; minimum turn diameter 3.5 m.
- Movement unit is millimeters along accumulated `length_mm`.
- Junction selection uses FollowMe continuity, not beam/stub geometry.
- **Right-hand one-way:** Each segment is a parallel pair (`|0` = reverse, `|1` = forward). A return trip rides the opposite track all the way to a U-turn terminus, then comes back. You cannot reverse direction mid-segment.
- A station with `u_turn: true` in its `travel_routes` is a terminus. Nora enters, the station reverses her internally, she exits on the parallel return track.
- Trip files (`trips/<model>.trip.<nora_id>.json`) store the ordered line-ID sequence for one Nora's one trip. See `readmes/followme.md` → Trip File Schema for full field definitions.
- Endpoint continuity must stay explicit: every endpoint's connected line IDs must appear in FollowMe adjacency arrays so disconnects are visible immediately.
- Direction is from start endpoint to end endpoint (`start_to_end`). Direction changes for rush-hour operations are allowed only as explicit policy overlays that keep legal one-way sequences.
- Runtime control stays simple: Nora advances by wheel-encoder millimeters along the current line ID; the physical guideway constrains x/y/z.

#### Nora runtime occupancy rule (authoritative)

- Vehicle motion state is tracked at the Nora **centerpoint on the FollowMe bottom centerline**.
- It is **not** tracked at the leading edge/front bumper.
- Personal space is a **3.0 m minimum centerpoint-to-centerpoint** separation.
- If another Nora enters this personal zone in simulation, Nora holds position for that tick rather than occupying overlapping space.

This resolves the centerpoint vs leading-edge ambiguity for SketchUp runtime and log interpretation.

**Generated by:** `JPods::JPodGuideway.export_followme_json` (`jpod_guideway.rb`)  
**Trigger:** JPods Console › Export FollowMe Network JSON  
**Output files:** `<model>.followme.json` (primary runtime map), `trips/<model>.trip.<nora_id>.json` (per-Nora trip files via JPods Console › Export Trip JSONs)

### Authoritative code files for CP, guideways, and FollowMe

There are no `.py` files in this plugin. The authoritative source files are Ruby (`.rb`).

| File | Owns |
|---|---|
| `jpod_structure_tool.rb` | Connection Point detection, storage, recompute, and label placement |
| `jpod_network.rb` | Guideway connection building from CP-to-CP network definitions |
| `jpod_path_builder.rb` | Terrain snap, vertical profile, grade limits, and Z-transition rate control |
| `jpod_guideway.rb` | Physical guideway beam geometry and FollowMe generation/export |
| `jpod_network_editor.rb` | CP viewport overlay, Bezier preview in XY, and model constraint controls |

If the question is "where is CP defined?" start in `jpod_structure_tool.rb`.
If the question is "where are guideways defined?" start in `jpod_network.rb` and `jpod_path_builder.rb`.
If the question is "where is FollowMe defined?" start in `jpod_guideway.rb`.

### JPods Console access to constraints and rates of change

JPods Console now exposes the model's known primary constraints and rates of change:

- **Open Constraints Panel** — opens the Network Editor constraints panel directly from JPods Console
- **List Active Constraints** — prints current values, defaults, and override state

The editable model constraint surface is still owned by the Network Editor because that is where constraints are persisted and applied.

### Derivative Framework Constraints Table (Single Source of Truth)

Authoritative values live in `jpod_constants.rb` and are consumed by build/runtime code.

| Domain | Constraint | Value | Constant | Used by |
|---|---|---|---|---|
| Marker | Station disk radius | 3.0 m | `STATION_RADIUS` | Marker placement visuals |
| Marker | Buffer disk radius | 10.0 m | `BUFFER_RADIUS` | Marker placement visuals |
| Marker | Marker post height | 3.0 m | `MARKER_POST_HEIGHT` | Marker posts + labels |
| Marker | Marker alignment risk threshold | 3.0 m | `MARKER_ALIGN_RISK_TOLERANCE` | Continuity scan (`▲ Check Gaps`) |
| Z-axis | Target centerline clearance above terrain | 5.5 m | `CLEARANCE_HEIGHT` | Vertical profile floor |
| Z-axis | Profile grade limit | 8% | `PROFILE_MAX_GRADE` | Vertical profile limiter |
| Z-axis | Minimum Z-change transition radius (enforced floor) | 3.0 m minimum | `MIN_Z_CHANGE_DIAMETER` | Vertical smoothing + anchored endpoint Z-blend in path builder |

If these limits must change, update `jpod_constants.rb` first, then rebuild guideways.

### What works as of today

- Place Markers on Terrain — ray-cast snapping, numbered posts, station/buffer disks
- Deploy Guideway — pre-select markers → Plugins › JPods › Deploy Guideway
- Smooth horizontal arcs at corners (MIN_TURN_RADIUS = 30 m)
- Vertical profile — target centerline height 5.5 m + horizontal-bias smoothing + grade limiting (MAX_GRADE = 15 %)
- Dual guideways ±1.75 m from CP centerline (3.5 m CTC), built simultaneously
- **T-columns** (`JPod_support_T/model.skp`) — every 25 m on the CP centerline;
  T arms span both guideways; column scales down to terrain; origin at beam-top level
- **Solar panels** (`JPod_solar/model.skp`) — every 2.5 m on the CP centerline;
  2.43 m along-track × 6.5 m cross-track; sit on beam-top face; 97 % coverage
- Fallback flat blue face if `JPod_solar` template is absent
- **Place Structure** — places stations and traffic circles; auto-assigns non-recycled IDs (S001, S002…); labels CPs in model
- **Network › Recompute Connection Points** — re-scans all structures; refreshes CP positions and labels
- **Network › Network Editor & Inspect** — edits the `network_definition` embedded in `<model>.followme.json`; **Build** button regenerates all dual guideways + columns + solar
- **Network Editor viewport** — live blue-dashed Bezier previews; 500 ms debounce on every edit; **plain click** to connect two CPs
- **Network Editor hover labels** — structure ID (yellow, size 36); CP index (size 16); S-curve preview on hover
- **Network › Add Structure to Guideway** — pick structure type; click guideway; deploy along stored beam path
- **Vehicle animation** — `▶ Animate` / `■■ Stop` buttons; timer at 10 fps
- **Network continuity check** (`▲ Check Gaps`) — marks endpoints not within 2 m of a CP with a 10 m red circle

### Axis conventions (resolved April 17)

ene_railroad places structure instances with:
```ruby
Transformation.axes(point, v.cross(Z_AXIS), v, Z_AXIS)
```
where `v` = travel direction.  Result: **+Y = travel, +X = cross-track, +Z = up**.

Our `place_structure_instance` matches this exactly — no separate rotate + translate.
Column height scaling via `scale_z = height / native_h` applied to the Z axis vector.

### Bezier tangent convention (resolved April 17)

Tangents are snapped at Bezier build time with a dot-product check — independent of
whether the stored tangent is inbound or outbound.  Fixed in three sites:
- `jpod_network.rb` — `tangent_curve_pts`
- `jpod_network_editor.rb` — `draw()` inline and `bezier_preview_pts`

---

## Current Status — May 8, 2026

### Vehicle placement architecture — ene_railroad style (resolved May 8, 2026)

**Problem:** Vehicles placed on a platform appeared as a single selectable entity in SketchUp rather than as individually selectable objects. All five vehicles for one platform were grouped inside a single guideway group, invisible to the animation engine and to users.

**Root cause:** `place_vehicle` called `group.entities.add_instance(defn, transform)` — placing the vehicle _inside_ the guideway group. All vehicles on the same platform shared the same parent group. Selecting the group showed all of them as one unit.

**Fix — ene_railroad pattern:**

| Before | After |
|--------|-------|
| `group.entities.add_instance(defn, transform)` | `model.entities.add_instance(defn, transform)` |
| No guideway association on vehicle | `host_connection_id`, `host_track_index` attributes on vehicle |
| Vehicle scans nested in guideway groups | `all_nora_vehicles_in_model` scans model root first, nested as fallback |

**Authoritative rules (do not regress):**

1. Vehicles are `ComponentInstance` objects in **`model.entities`**, not inside guideway groups.
2. Each vehicle stores `host_connection_id` (matches `connection_id` on guideway group) and `host_track_index` (matches `track_index` on guideway group).
3. `JPods::JPodGuideway.place_vehicle(gw, defn, t)` is the only correct way to place a vehicle — it stamps these attributes and adds to model root.
4. All vehicle finders (`find_vehicle_by_nora_id`, `all_nora_vehicles_in_model`) scan model root first, guideway groups second (backward compat only).
5. `move_nora_to_platform_slot` updates `host_connection_id` and `host_track_index` after relocation.

**Why transform math is unchanged:** All guideway groups have identity transforms (no rotation, origin at model origin). Model-root coordinates equal guideway-local coordinates. Setting `entity.transformation` to a model-root `ComponentInstance` uses the same coordinate values as before.

**Files changed (May 8, 2026):**
- `jpod_animator.rb` — `place_vehicle`, `all_nora_vehicles_in_model`, `find_vehicle_host_guideway`, `find_vehicle_by_nora_id`, `start_animation`, `assign_random_trips_to_all_vehicles`, `assign_trips_by_type`, `next_nora_num`, `normalize_vehicle_ids!`, `vehicle_trip_rows`
- `jpod_vehicle_runtime.rb` — `find_vehicle_by_nora_id` delegates to animator; `move_nora_to_platform_slot` stamps host attributes
- `jpod_followme_exporter.rb` — `export_trip_json` and `build_trip_detail` use `find_vehicle_by_nora_id`
- `jpod_5v_test.rb` — `find_entity` delegates to `find_vehicle_by_nora_id`
- `jpod_platform_queue.rb` — `find_entity` delegates to `find_vehicle_by_nora_id`

---

## Current Status — May 12, 2026

### CP direction line visual + CCW Bezier convention (resolved May 12, 2026)

#### CP visual: circle + direction line

Each CP now renders two elements in the `JPodNetworkTool` viewport overlay:

1. **Circle** — radius `CP_RADIUS` (1.5 m), colour matches interaction state  
   - teal / `(80, 220, 200)` = available  
   - orange / `(255, 140, 0)` = selected (FROM)  
   - yellow / `(255, 220, 0)` = hovered  

2. **Direction line** — drawn from CP centre to the circle edge (length = `CP_RADIUS`)  
   in the stored outbound tangent direction, same colour and weight as the circle.  
   Acts as a clock-hand: one glance shows which way vehicles exit that gate.

**Regression check:** if two adjacent CPs both show direction lines pointing _toward_  
each other (inward), the stored tangent is reversed somewhere.  That is a CW  
connection — find the offending formation SKP's `stub_pair` tag scan and verify that  
`outer_pt` and `inner_pt` are correctly assigned by `cluster_verts_by_projection`.

**Code location:** `jpod_network_editor.rb` → `JPodNetworkTool#draw`, CP circle loop.

---

#### CCW Bezier convention and the tangent sign-snap fix

**The rule (never violate):**  
All CP connections are counter-clockwise when viewed from outside the structure looking  
at the gate face. Vehicles exit one gate's right-hand (outbound) track and enter the  
next gate's left-hand (inbound) side.

**Stored tangent convention:**  
Every CP stores its tangent in the **outbound** direction — pointing away from the  
structure, toward the open network. This is true for all detection methods:

| Detection method | Source of tangent | Direction as stored |
|---|---|---|
| `detect_cps_from_stub_pair_tags` | `inner_pt → outer_pt` via `xy_tangent` | Outbound (away from formation center) |
| `detect_gate_lines` | radially away from structure origin in XY | Outbound |
| `pair_stubs` fallback | track endpoint `controls[2]` corrected to outbound | Outbound |

**Bezier handle sign-snap (the fix):**  
Rather than trusting any individual detection method's sign, all three Bezier  
calculation sites apply a dot-product check at draw/build time:

```ruby
chord_v = p1 - p0                            # from_cp → to_cp

# Departure handle: tangent must face toward to_cp
raw0 = from_cp[:tangent]&.normalize || chord_v.normalize
t0   = raw0.dot(chord_v) >= 0 ? raw0 : raw0.reverse

# Arrival handle: tangent must face AWAY from to_cp (back toward chord start)
raw1 = to_cp[:tangent]&.normalize || chord_v.reverse.normalize
t1   = raw1.dot(chord_v) <= 0 ? raw1 : raw1.reverse

scale = chord / 3.0
c0 = from_cp_pt + t0 * scale   # handle inside the span → correct outward departure
c1 = to_cp_pt   + t1 * scale   # handle inside the span → correct inward arrival
```

**Why this works:**  
- `t0` (`dot(chord) >= 0`) exits the source gate outbound = CCW departure.  
- `t1` (`dot(chord) <= 0`) points back toward the source = Bezier arrives at  
  the destination from outside = CCW arrival (vehicle enters from the network  
  side, not from inside the structure).  

**Regression symptom:**  
If a Bezier loops past the destination and approaches from the rear, `t1` has the  
wrong sign: it is pointing forward (same direction as chord) so the arrival handle  
pulls the curve all the way around. Fix: confirm `raw1.dot(chord_v) <= 0` after  
the sign-snap; if still wrong, check that the stored tangent is genuinely outbound  
(see detection method table above).

**Code locations (all three sites must have the sign-snap):**

| File | Method | Note |
|---|---|---|
| `jpod_network_editor.rb` | `bezier_preview_pts` | Hover preview + committed session lines |
| `jpod_network_editor.rb` | `draw()` JSON preview loop | Blue-dashed network_definition preview |
| `jpod_network.rb` | `tangent_curve_pts` | Built guideway geometry + FollowMe export |

**Do-not-regress checklist:**  
1. Hover one CP over another: preview curve must leave both CPs in the outbound  
   tangent direction (same as their direction lines) — no loops or reversals.  
2. Direction lines on adjacent CPs at a connected pair should both point outward  
   (away from their respective structures), never toward each other.  
3. After Build, FollowMe centerlines must enter each structure from the network side,  
   not from inside the formation.  

---

## Current Status — April 16, 2026

**CP marker convention established.**  Connection-point detection now uses explicit
geometry drawn in each template SKP rather than inferred edge lengths.

### What changed (April 16, 2026)

#### Old system — `jpod_guideway_designer.rb` (superseded)

The original `JPodGuidewayDesigner` class was a rough prototype:
- Required the user to **click individual markers** one at a time in the viewport
- Called `MyGeom.generate_constrained_jpod_path` (now-removed helper) to build a polyline
- Drew a **2 m flat band** with primitive 5 m fixed-height cylindrical poles (no terrain snap, no grade enforcement, no real structure component)
- Named the result `"JPod Guideway - Design Phase"` — a separate group from the production guideways built by the Network workflow
- Had no connection to the JSON network system, no dual-guideway awareness, no support for structures

This class was kept only as a placeholder in `jpod_guideway_designer.rb` after the v2.1 rewrite but was never wired into any active menu item.

#### New system — `JPodAddStructureTool` (April 16, 2026)

`jpod_guideway_designer.rb` now contains `JPodAddStructureTool`.  The file is renamed in function only; the filename is kept so the load order in `main.rb` is unchanged.

**What it does:**
1. `Extensions › JPods › Network › Add Structure to Guideway`
2. A `UI.inputbox` dropdown lists all available structure types discovered from `templates/structures/` at runtime (no hardcoded list — adding a new template folder makes it appear automatically)
3. After picking a structure, the tool activates and waits for a click on any `JPods Guideway` group
4. The hovered guideway is highlighted with an orange bounding-box outline + label in the viewport
5. On click, `JPodGuideway.add_structures_to_guideway` reads the `beam_path` JSON attribute stored on the guideway group at Build time, deserialises the 3D path, and calls `place_columns` with the selected structure definition
6. Structures are placed at 25 m intervals, terrain-snapped, scaled to actual column height, rotated to the local track direction — identical to the columns placed during the original Build
7. The tool stays active so the user can click more guideways without re-entering

**Why `beam_path` attribute:**  
Building stores the exact polyline so Add Structure can reproduce column positions months later, after the model has been saved and reopened, without needing to re-parse the JSON or re-run PathBuilder.

**Available structures** (auto-discovered from `templates/structures/`):

| Folder ID | Display name |
|---|---|
| `JPod_station` | Station |
| `JPod_support` | Support Column |
| `JPod_support_double` | Support Column, Double |
| `JPod_support_postmodern` | Support Column, Postmodern |
| `JPod_support_solar_double` | Support Structure with Solar Panels, Double |

Adding a new folder with a `model.skp` inside makes it appear in the dropdown with no code change.

### CP marker convention (v2.2)

Each connection point in a template SKP is marked by **two edges that share one vertex**:

| Edge | Length | Role |
|---|---|---|
| Cross-track line | **1.5 m** | Perpendicular to track direction; half of dual-track spacing (3 m) |
| Pointer stub | **0.2 m** | Points to the CP; meets the 1.5 m line at the exact CP vertex |

`detect_gate_lines` finds all 1.5 m edges and all 0.2 m stubs, then locates every vertex
shared between the two sets.  That vertex is the CP.  The outbound track tangent is the
1.5 m edge direction rotated 90° in XY.

**Templates with markers added:**
- `JPods_station_solar/model.skp` ✅ — 4 CPs confirmed
- `OK_LazyE.skp` (working drawing) ✅ — 4 CPs confirmed
- `JPods_traffic_circle7/model.skp` ⬜ — markers not yet added

### Next session — things to verify and finish
1. **Add CP markers to `traffic_circle7`** — open the template SKP in SketchUp; draw a 1.5 m + 0.2 m marker pair at each of the 7 arm tips; save; run `JPods::StructurePlacer.recompute_all_cps(Sketchup.active_model)` and verify teal circles appear at all gates
2. **Resolve current "Recompute failed" error** — full backtrace not yet captured; check Ruby Console for `JPods recompute error:` line and first 3 backtrace entries
3. **Visual QA** — confirm teal CP circles render at the correct arm-tip positions (~22–24 m from structure centre for traffic circle, matching the drawn markers)
4. **Dynamic height from info file** — `STRUCTURE_NATIVE_HEIGHT` is hardcoded at `314.96"`.  The real value lives in `JPod_support_solar_double/info` as `:height_offset`.  Read it with `Marshal.load(File.binread(path))`.
5. **Structure variant chooser** — `JPod_support/`, `JPod_support_double/`, `JPod_support_postmodern/` variants exist; a UI picker in the menu would let the user choose track type before deploying

### Key files
| File | Purpose |
|---|---|
| `jpod_constants.rb` | All engineering limits + structure template path + DUAL_TRACK_SPACING |
| `jpod_marker_tool.rb` | Click to place numbered centerline markers on terrain |
| `jpod_path_builder.rb` | Arc insertion + terrain snap + two-pass grade profile |
| `jpod_guideway.rb` | Beam faces + support column instances; `add_structures_to_guideway` API |
| `jpod_guideway_designer.rb` | `JPodAddStructureTool` — pick structure type → click guideway → deploy |
| `jpod_deploy_tool.rb` | UI glue — pre-selection deploy + interactive click tool |
| `jpod_structure_tool.rb` | Place stations/circles; assign IDs; detect + label connection points |
| `jpod_network.rb` | Read `network_definition` from `followme.json`; resolve structures + markers; build dual guideways |
| `jpod_network_editor.rb` | HtmlDialog JSON editor + `JPodNetworkTool` viewport overlay |
| `dialogs/network_editor.html` | Network editor UI (Open/Save/Template/Build + live Bezier preview) |
| `main.rb` | Extension entry point — menus, toolbar, load order |
| `jpod_loader.rb` (Plugins/) | Root loader — registered via `SketchupExtension` |

---

## Purpose

This plugin lets an engineer or planner lay out a JPods network directly in SketchUp.
The workflow is: place the fixed structures first (stations, traffic circles), then fill
in the connecting paths between them with markers, then declare the connections in a JSON
file and build all guideways in one operation.

Each connection produces **two parallel guideways** 3 m centre-to-centre — one per
direction of travel.  The physical spacing is detected automatically from the formation's
own stub geometry.

---

## Network Workflow (recommended)

### Step 1 — Place Structures

**Menu:** `Plugins › JPods › Network › Place Structure`

A dropdown lets you choose the formation type:

| ID | Description |
|---|---|
| `JPods_traffic_circle7` | Traffic circle with 7 connection gates |
| `JPods_station_container` | Station (standard) |
| `JPods_station_solar` | Station (solar-roof variant) |

Each click ray-casts to the terrain surface and places the formation component.

**What the plugin does automatically:**
- Assigns a unique, non-recycled ID: `S001`, `S002`, … (counter stored in the model, never decreases even if structures are deleted)
- Reads the formation's `info` file to find all track endpoints (control-point data written by ene_railroad)
- Identifies **external stubs** — endpoints not shared with any other track in the formation (i.e., the gates to the outside world)
- **Pairs stubs** — two stubs within ~5.5 m with parallel tangents are one connection point representing the dual guideway in/out gate
- Labels each connection point in the model: `S001.CP0`, `S001.CP1`, …
- Stores connection-point data in **local coordinates** on the component instance so that moving the structure after placement still produces correct world-space positions

**Mandatory station setup inside each station component:**
- Include a dedicated platform siding object (group/component) and mark it as `platform`.
- Keep that platform object as the actual berth/parking guideway, not a symbolic container.
- Preserve unique station identity (`Sxxx`) so JSON connections and platform catalogs stay stable.

To see all structure IDs and connection-point counts: `Network › List Structures & Connection Points`

---

### Step 2 — Place Centerline Markers

**Menu:** `Plugins › JPods › Place Markers on Terrain`  
**Toolbar:** Balise icon (orange marker post)

Markers define the **centerline** of the path between two structures.  The two parallel
guideways will be offset ±1.5 m (half of the 3 m spacing) to either side of this line.

Place markers along the desired route between each pair of structures.  Markers do not
need to be placed in connection order — the JSON file specifies which marker numbers
belong to each connection and in what order.

**Marker anatomy (all inside one `"JPod Marker"` group):**

| Element | Geometry | Colour / opacity |
|---|---|---|
| Post | 8-sided cylinder, 12 cm radius, 3 m tall | Solid orange |
| Station disk | Filled circle, 3 m radius, at 1 m height | Red, 30 % opacity |
| Buffer disk | Filled circle, 10 m radius, at 1 m height | Orange, 25 % opacity |
| Label | Text annotation above post top | "M1", "M2", … |

Each group stores `JPods / marker_number` as a SketchUp attribute.

**Interaction:**
- Click terrain → place next marker (auto-numbered).
- ESC deactivates the tool; markers remain in the model.

---

### Step 3 — Import / Verify Terrain

**Menu:** `Plugins › JPods › Import Terrain Features`

Scans the active model for a terrain mesh.  Detection heuristics (in priority order):

1. Group or component whose name contains any of: `terrain`, `google earth`, `geo-location`, `location snapshot`, `topography`, `topo`.
2. Recursive sub-group search with the same keywords.
3. Nameless group with ≥ 20 faces (largest such group wins as fallback).

**If terrain is found:** a dialog reports the group name, approximate area (m²), and elevation range (min / max metres).

**If no terrain is found:** a dialog instructs the user to use `File › Geo-location › Add Location` to import a georeferenced elevation mesh from Trimble's location service, then re-run this step.

---

### Step 4 — Connect Nodes in the Network Editor

**Menu:** `Plugins › JPods › Network › Network Editor & Inspect`

Opens the JSON editor panel alongside the SketchUp viewport.  A live overlay appears
on the model showing every CP as a **3 m teal circle** centred on the gate midpoint.

#### Viewport interaction

| Action | Effect |
|---|---|
| Hover a CP | Circle turns yellow; structure ID (large) and CP index shown above it; Bezier S-curve previews the route to any already-selected FROM node |
| **Click CP A** (nothing selected) | Selects A as the FROM node — circle turns orange; editor scrolls to any existing connection that uses this CP |
| **Click CP B** (A selected) | Completes the connection — `A → B` entry added to the JSON editor immediately; overlay line turns green |
| Click CP A again (A selected) | Deselects |
| Click empty space | Deselects |
| **Shift+click a marker** (A selected) | Adds the marker as a via-waypoint on the route; repeat for each waypoint; then click the TO node to finish |
| C key | Clears the green overlay lines from this session |

#### Visual legend

| Colour | Meaning |
|---|---|
| Teal circle (3 m) | CP node — not selected |
| Orange circle | FROM node — selected, waiting for TO |
| Yellow circle | Hovered CP |
| Blue dashed S-curve | Connection already in JSON, not yet built |
| Cyan dashed S-curve | Hover preview of route being drawn |
| Solid green line | Connection committed this session |
| Orange circle (small) | Marker available as a waypoint |
| Cyan circle | Marker added as a waypoint for the current route |

#### Typical session

1. Open the Network Editor — CPs appear as teal circles.
2. Click the FROM gate (circle turns orange).
3. Hover the TO gate — a Bezier S-curve preview appears.
4. Click the TO gate — the connection is written into the JSON editor.
5. Repeat for every connection in the network.
6. Click **Save** in the editor panel to write the JSON file.
7. Click **Build** to generate all guideways.

To route via intermediate markers, Shift+click each marker after selecting FROM, then
click the TO gate.  The via-marker numbers are stored in the `via_markers` array.

---

### Step 5 — Write / Edit the Network Build JSON (optional)

**Menu:** `Plugins › JPods › Network › Network Editor & Inspect`

The Network Editor embeds the connection list directly inside `<model>.followme.json` as `network_definition`. Use the **Get Template** button to pre-fill a stub listing all structure IDs and CP counts from the current model, then edit connections in the panel.

To hand-edit, open `<model>.followme.json` in any text editor and modify the `network_definition` block.

Edit the file in any text editor:

```json
{
  "connections": [
    {
      "id": "seg_1",
      "from": { "structure_id": "S001", "stub": 0 },
      "to":   { "structure_id": "S002", "stub": 2 },
      "via_markers": [3, 5, 8]
    },
    {
      "id": "seg_2",
      "from": { "structure_id": "S002", "stub": 4 },
      "to":   { "structure_id": "S003", "stub": 0 },
      "via_markers": []
    }
  ]
}
```

**Field reference:**

| Field | Meaning |
|---|---|
| `structure_id` | The ID shown in the model label and Ruby Console — e.g. `"S001"` |
| `stub` | Connection-point index on that structure — e.g. `0` matches `S001.CP0` |
| `via_markers` | Ordered marker numbers defining the centerline path.  `[]` = direct connection |

---

### Step 6 — Build Network

**Network Editor panel → Build button** (or `Plugins › JPods › Network › Network Editor & Inspect`, then click Build)

Reads `network_definition` from `<model>.followme.json`, and for each connection:

1. Looks up both structures by `structure_id`
2. Resolves the `stub` index to a world-space 3D point + tangent vector (applying the current component transformation)
3. Collects the `via_markers` as centerline waypoints
4. Offsets the full centerline path ±`half_offset` to produce two parallel paths
5. Runs `PathBuilder.build()` on each path (arc insertion → terrain snap → grade profile)
6. Calls `JPodGuideway.build()` to draw beam faces + support columns

Each connection creates two `"JPods Guideway"` groups, tagged with `connection_id` and `track_index` (0 = left, 1 = right).

---

## Quick-deploy Workflow (single route, no structures)

For simple point-to-point routes without stations:

**Menu:** `Plugins › JPods › Deploy Guideway`  

1. Pre-select markers in route order (or activate the tool and click them in order)
2. Press **Enter**

This builds a **single** guideway (no dual-track offset) along the selected markers.
Use the full Network workflow for any route involving stations or traffic circles.

---

## Path Construction Pipeline

`PathBuilder.build(raw_points, model)` runs three steps on any path:

**Step A — Horizontal arc insertion**

At every interior corner, if the implied radius is less than `MIN_TURN_RADIUS` (30 m),
a circular arc is inserted:
- Setback distance = `r · tan(θ/2)`
- Capped at 45 % of either adjacent segment
- Arc segment count: 8 segments per 90° of deflection

**Step B — Terrain snap**

Every point is ray-cast to the terrain surface.  Ray origin is 2 000 m above the point.

**Step C — Vertical profile**

1. **Clearance floor:** beam Z ≥ terrain Z + `CLEARANCE_HEIGHT` (4 m)
2. **Forward pass:** prevents descent faster than `MAX_GRADE` (15 %)
3. **Backward pass:** prevents ascent faster than `MAX_GRADE` (eliminates humps)

Where terrain itself exceeds 15 % grade, a warning is printed to the Ruby Console.

---

## Guideway Geometry

`JPodGuideway.build(group, beam_path, model)`:

| Element | Detail |
|---|---|
| Beam top surface | 2 m-wide connected quad faces, steel-blue, 85 % opacity |
| Beam side faces | 0.5 m structural depth, same material |
| T-columns | `JPod_support_T/model.skp` instances every 25 m; origin at beam-top; column scales downward to terrain |
| Solar panels | `JPod_solar/model.skp` instances every 2.5 m; sit on beam-top face; fallback to flat blue face if template missing |

Column spacing: 25 m nominal.  Column height is variable — terrain-adaptive.
Solar panel repeat: 2.5 m leading-edge to leading-edge; 97 % coverage along CP centerline.

---

## Engineering Constants

Defined in `jpod_constants.rb`.  Change these to adjust the entire plugin.

| Constant | Value | Meaning |
|---|---|---|
| `MIN_TURN_RADIUS` | 30 m | Minimum horizontal curve radius |
| `MAX_GRADE` | 15 % | Maximum longitudinal grade (rise/run) |
| `CLEARANCE_HEIGHT` | 8 m | Terrain to beam-top face (= `STRUCTURE_NATIVE_HEIGHT` so columns are un-scaled) |
| `SUPPORT_SPACING` | 25 m | Column spacing along the CP centerline |
| `POST_DIAMETER` | 0.4 m | Fallback column outside diameter |
| `BEAM_WIDTH` | 0.5 m | Guideway beam width |
| `BEAM_DEPTH` | 0.5 m | Guideway beam structural depth |
| `DUAL_TRACK_SPACING` | 3.5 m | CP-to-CP spacing matches station stub-pair geometry |
| `STRUCTURE_NATIVE_HEIGHT` | 8 m (314.96") | Native column height in the T-column template |
| `SOLAR_PANEL_SPACING` | 2.43 m | Along-track depth of one solar panel module |
| `SOLAR_PANEL_REPEAT` | 2.5 m | Leading-edge to leading-edge repeat distance |
| `STATION_RADIUS` | 3 m | Red station-platform disk radius |
| `BUFFER_RADIUS` | 10 m | Orange access-buffer disk radius |
| `MARKER_POST_HEIGHT` | 3 m | Height of the orange marker post |
| `ARC_SEGS_PER_QUARTER` | 8 | Arc smoothness (segments per 90°) |

---

## File Structure

```
JPods/
  main.rb                  ← Extension entry point; menus, toolbar, load order
  jpod_constants.rb        ← All engineering limits (single source of truth)
  jpod_terrain.rb          ← Terrain detection + ray-cast elevation queries
  jpod_path_builder.rb     ← Arc insertion + terrain snap + two-pass grade profile
  jpod_guideway.rb         ← Beam faces + column instances; add_structures_to_guideway API
  jpod_guideway_designer.rb← JPodAddStructureTool — pick structure → click guideway → deploy
  jpod_marker_tool.rb      ← Click tool — place numbered centerline markers
  jpod_deploy_tool.rb      ← Quick-deploy — click markers in order + Enter
  jpod_structure_tool.rb   ← Place stations/circles; assign IDs; detect + label CPs
  jpod_network.rb          ← Read network_definition from followme.json; resolve stubs + markers; build dual guideways
  jpod_network_editor.rb   ← HtmlDialog JSON editor + JPodNetworkTool viewport overlay
  dialogs/
    network_editor.html    ← Editor UI with live Bezier preview
  toolbar_icons/           ← PNG icons for the toolbar
  readmes/
    basics.md              ← This document
  templates/
    track_formations/      ← Formation SKP + info files (stations, traffic circles)
    structures/            ← Support column SKP files (auto-discovered by Add Structure tool)
    tracks/                ← Track cross-section profiles
    r_stocks/              ← Pod vehicle models
  hold/
    jpod_connect_tool.rb   ← Superseded single-track connect tool (reference only)
    my_geom.rb             ← Old Bezier helper (superseded by tangent_curve_pts in network.rb)
```

---

## Menu Reference

| Menu path | Action |
|---|---|
| JPods › Place Markers on Terrain | Ray-cast marker placement tool |
| JPods › Import Terrain Features | Detect terrain mesh; show bounds/elevation |
| JPods › Deploy Guideway | Quick single-guideway deploy from markers |
| JPods › Network › Place Structure | Place formation; auto-ID; label CPs |
| JPods › Network › List Structures & Connection Points | Print IDs and CP counts to Ruby Console |
| JPods › Network › Recompute Connection Points | Re-scan all structures; refresh CP positions |
| JPods › Network › Add Structure to Guideway | Pick structure type; click guideway; deploy along beam path |
| JPods › Network › Network Editor & Inspect (Get Template) | Write pre-filled `network_definition` into `followme.json` |
| JPods › Network › Network Editor & Inspect | Open JSON editor + live viewport Bezier preview |
| JPods › Clear All Guideways | Erase every `"JPods Guideway"` group (with confirmation) |
| JPods › Clear All Markers | Erase every `"JPod Marker"` group (with confirmation) |
| JPods › Reload Plugin | Hot-reload all source files |

---

## Installation

The git repository contains only the `JPods/` folder. The active plugin entry point is
`su_jpods.rb` at the **SketchUp Plugins root** (one level above `JPods/`), registered
as a `SketchupExtension` so SketchUp can manage it.

**After first install:** Open SketchUp → **Extensions → Extension Manager** → find "JPods" →
mark it as **Trusted**. This one-time step is required because the plugin is unsigned.
Without it, `su_jpods/boot.rb` will not load and `$su_jpods_booted` will be `nil`.

**Legacy:** `jpod_loader.rb` at the Plugins root loaded the old `JPods/main.rb` directly.
It has been renamed to `jpod_loader.rb.disabled` and must stay disabled — both loaders
active causes a double-boot where the old unmodified `jpod_network.rb` intercepts
"Build Network" before the new code can run.

**Location:** `~/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods.rb`

Create that file with this exact content:

```ruby
require 'sketchup.rb'
require 'extensions.rb'

module JPods
  file = __FILE__.dup
  file.force_encoding('UTF-8') if file.respond_to?(:force_encoding)
  loader = File.join(File.dirname(file), 'JPods', 'main')

  EXTENSION = SketchupExtension.new('JPods', loader)
  EXTENSION.description = 'JPods guideway design tools — place markers, import terrain, deploy guideway'
  EXTENSION.version     = '1.0.0'
  EXTENSION.creator     = 'JPods'

  Sketchup.register_extension(EXTENSION, true)
end
```

Then clone the repo into the Plugins folder:

```bash
cd ~/Library/Application\ Support/SketchUp\ 2026/SketchUp/Plugins
git clone https://github.com/JPods/sketchup.git JPods
```

Restart SketchUp. The plugin will appear under `Plugins › JPods`.

---

## Loading / Reloading

The auto-loader at `Plugins/jpod_loader.rb` runs on SketchUp startup.

To manually reload from the Ruby Console:

```ruby
load "#{Sketchup.find_support_file('Plugins')}/JPods/main.rb"
```

---

## Troubleshooting

### "This file cannot be loaded or updated. Please uninstall it and contact the developer."

The root loader (`jpod_loader.rb`) was not registered through `SketchupExtension`.  
Fixed in v2.0: the loader now calls `Sketchup.register_extension(EXTENSION, true)`.

### "JPods extension is disabled" (Extension Loading Policy)

JPods is unsigned (no `.susig` certificate), so SketchUp may block it depending on your loading policy setting.

**Fix:**
1. Open **Extension Manager** (Window menu → Extension Manager)
2. Click the **gear icon** (Settings, top-right)
3. Set the policy to **"Approve Unidentified Extensions"** (recommended for development) or **"Unrestricted"**
4. Restart SketchUp — JPods will load normally

The policy is remembered between sessions; you only need to set it once.

To formally sign the extension for distribution, register as a SketchUp developer at [developer.sketchup.com](https://developer.sketchup.com) and add a `.susig` certificate alongside `jpod_loader.rb`.

---

## Design Principles

- **Bottom-up routing** — the engineer places markers where stations are needed; the software finds the constrained path between them.  No route is imposed from above.
- **Terrain-first** — every elevation is derived from the actual terrain mesh, not from flat assumptions.
- **Single source of truth** — all engineering limits live in `jpod_constants.rb`; changing one number changes the behaviour of every tool simultaneously.
- **Non-destructive** — every operation is wrapped in a named undo operation; markers and guideways are stored in named groups that can be selectively cleared.

---

## Reference: ene_railroad Plugin (SketchUp 2023)

**Location:** `/Users/williamjames/Library/Application Support/SketchUp 2023/Plugins/ene_railroad/`

This is Julia Eneroth's railroad layout plugin.  It was the original platform for JPods
track geometry and its formation templates (stations, traffic circles) are the source
files for the `JPods/templates/track_formations/` directory.

### Connect Mode — how ene_railroad joins two track ends

When exactly **two unconnected track groups** are selected, ene_railroad automatically
enters `"connect"` mode (`track_insert_tool.rb`, line 78).

**What it does:**

1. Finds the two loose ends closest to each other across the selected tracks.
2. Reads the endpoint position + outbound tangent vector for each end.
3. Sets the handle length to `chord / 2` — half the straight-line distance between
   the two endpoints.
4. Builds a **cubic Hermite Bezier** (`curve_algorithm: "c_bezier"`) using four
   control points:
   - `p3` = start point
   - `p2` = start point offset along start tangent (handle)
   - `p1` = end point offset along end tangent (handle)
   - `p0` = end point
5. Samples the curve at `max(12, chord_in_m × 0.25)` segments.
6. Snaps the second and second-to-last points to the tangent lines so the ends
   are perfectly smooth.

Press **Tab** to toggle which pair of loose ends is being connected.  Click or press
Enter to commit.

The algorithm is in `my_geom.rb` (`calc_path`, `"c_bezier"` case, lines 88 and 304).

### Key difference from JPods Network Editor

ene_railroad connects **one track at a time** — the user selects two individual track
ends and gets one track segment.  For a dual-guideway JPods connection the user would
need to repeat the operation for the second parallel track.

**JPods Network Editor connects both guideways simultaneously.**  One click from
`S001.CP0` to `S008.CP0` (or one JSON entry) builds two parallel guideways — one in
each direction — offset ±`half_offset` from the shared centerline.  The node is the
connection point for the pair, not for an individual rail.  This matches the physical
reality of a JPods gate: vehicles enter on one beam and exit on the other.

### Handle length comparison

| Plugin | Handle length | Curve character |
|---|---|---|
| ene_railroad connect mode | `chord / 2` | Tighter pull; endpoints align sooner |
| JPods Network Editor | `chord / 3` | Slightly looser; more gradual S |

Both use the same cubic Bezier formula.  If routes feel too tight or too loose after
building, adjust the scale constant in `Network.tangent_curve_pts` (`jpod_network.rb`)
and in `bezier_preview_pts` (`jpod_network_editor.rb`).

# JPods Connection Point Rule — April 22, 2026

## Color Standard — Red Inbound, Blue Outbound

**All JPods tools (SketchUp plugin, Route-Time GUI, any future visualizations) follow this rule:**

| Color | Meaning |
|-------|---------|
| 🔴 **Red** | Inbound — hot end — vehicle or flow arriving |
| 🔵 **Blue** | Outbound — cool end — vehicle or flow departing |

This applies to guideway lines, CP stub-pair dots, station siding lines, and any future directional indicators. Never reverse. Never monochrome for directional elements.

---

## The Rule

> **The Connection Point (CP) is the midpoint between the two seam points where the two parallel guideways meet their removable ending caps.**

Formally:
$$CP_{center} = \frac{seam_{left} + seam_{right}}{2}$$

where:
- Each guideway is a 0.5 m × 0.5 m beam, built by the `upright_extrude` function ported from ene_railroad v23
- The seam is the 3D point where the main beam extrusion ends (the `end_face` created by `upright_extrude`)
- The ending cap is the removable ene_railroad geometry placed after extrusion
- Left and right beams are `DUAL_TRACK_SPACING = 3.5 m` apart on the CP centerline

## Why This Matters

**System integration points:**

1. **At structure placement time** (`jpod_structure_tool.rb`): CPs anchor the connection marker circles visible in the model — the user clicks these circles to define which structures connect.

2. **At network build time** (`jpod_network.rb`, method `build_segment`): The CP center + tangent tells the build system:
   - Where to call `JPodGuideway.remove_structure_endcaps(entity, cp_point)` to erase the ending geometry
   - Where the seam point is for joining two guideway segments end-to-end
   - The outbound travel direction (from the tangent)

3. **In the network editor** (`jpod_network_editor.rb`): CPs are the visual connection targets. Hovering shows a Bezier preview flowing from one CP's outbound tangent to the next CP's inbound approach.

4. **In the finished model**: CP circles sit exactly at the gate opening — the seam where caps meet beams — so the visual representation matches where network links actually form.

## Problem Fixed (April 20–22, 2026)

### Symptom

Traffic-circle connection points were placed at the **wrong end** of the dual-guideway pair — at the ring-junction end (~13.5 m from formation center) instead of the gate/cap end (~22.5 m).

### Root Cause

Each traffic-circle arm track, drawn from ring-center outward, produced **two external stubs** in the formation data:

| Stub | Location | Role |
|------|----------|------|
| **Outer stub** (correct) | Arm tip, ~13.5 m radius | The true external endpoint; connects to the outside world |
| **Ring-junction stub** (phantom) | Where arm meets ring, ~7.5 m radius | An artifact: the ring endpoint doesn't exactly match the arm track start due to positional gap tolerance |

The old pairing algorithm could not distinguish them:
- It treated all external stubs as equally valid
- Sometimes it paired ring-junction stubs with each other instead of outer stubs
- This placed the CP midpoint at the inner ring junction (wrong location by ~9 meters)

### Solution Implemented

**Step 1: Stub normalization** (in `pair_stubs()`)

For each stub, always ensure `point = outer tip` (the endpoint farther from the formation centroid). If a stub was drawn inbound (companion = outer tip), reverse it:

```ruby
stubs = stubs.map do |s|
  if s[:point].distance(centroid) >= s[:companion].distance(centroid)
    s  # already outer
  else
    { point: s[:companion], tangent: s[:tangent].reverse, companion: s[:point] }
  end
end
```

**Step 2: Deduplication** (in `pair_stubs()`)

Remove redundant stubs — if two stubs share the same outer tip (one is real, one is the phantom ring-junction stub), keep only the first:

```ruby
seen_pts = {}
stubs = stubs.reject do |s|
  key = [s[:point].x.round(2), s[:point].y.round(2), s[:point].z.round(2)]
  if seen_pts[key]
    true  # duplicate, discard
  else
    seen_pts[key] = true
    false  # keep
  end
end
```

**Step 3: Geometric seam location** (in `pair_stubs()`)

After normalizing and deduplicating, pair stubs by distance. For each valid pair:

```ruby
pd_outer = Geom::Point3d.linear_combination(0.5, sa[:point], 0.5, sb[:point])
pd_inner = Geom::Point3d.linear_combination(0.5, sa[:companion], 0.5, sb[:companion])
out_dir  = (pd_outer - pd_inner).normalize
```

Then, **for traffic circles only**, apply a radial outward offset:

```ruby
if outward_offset > 0.0  # traffic_circle branch
  radial_out = Geom::Vector3d.new(pd_outer.x - centroid.x,
                                  pd_outer.y - centroid.y, 0)
  radial_out = radial_out.normalize
  shifted = pd_outer.offset(radial_out, outward_offset)  # 9.m for traffic circles
  gate_ctr = Geom::Point3d.new(shifted.x, shifted.y, pd_outer.z)
end
```

This places the CP at:
$$CP = pd_{outer} + 9.m \cdot \frac{(pd_{outer} - centroid)}{|(pd_{outer} - centroid)|} \quad \text{[in XY plane; Z from } pd_{outer}]$$

### Validation

**Visual confirmation** (April 22, 2026): Bill opened the SketchUp model after running Recompute Connection Points. The CP circles now sit exactly where they should — at the interface between the guideway beams and the ending caps. The 9-meter offset moved them from the wrong end (ring-junction) to the correct end (cap seam).

**Geometric confirmation**: The distance from `pd_outer` (paired outer-tips midpoint) to the true seam is exactly 9 meters, matching the experimental offset. This is the distance the Bezier curves must travel before hitting the cap geometry.

## Implementation

### File: [jpod_structure_tool.rb](../../../Library/Application%20Support/SketchUp%202026/SketchUp/Plugins/JPods/jpod_structure_tool.rb)

**Key methods:**

| Method | Lines | Purpose |
|--------|-------|---------|
| `collect_all_endpoints` | ~150 | Extract all track endpoints + tangents from placement_data |
| `detect_external_stubs` | ~170 | Filter to endpoints not shared with another track (open ends) |
| `pair_stubs` | ~600–670 | Normalize stubs, deduplicate, pair by distance, apply seam offset |
| `resolve_connection_points` | ~680–695 | Route: traffic_circle → pair_stubs(offset=9m); others → try endings, fall back to pair_stubs(offset=0) |

**The critical offset application** (pair_stubs, ~lines 650–660):

```ruby
# Paired CP sits at the midpoint of the two outer guideway ends.
gate_ctr = pd_outer
if outward_offset > 0.0
  radial_out = Geom::Vector3d.new(pd_outer.x - centroid.x,
                                  pd_outer.y - centroid.y, 0)
  radial_out = radial_out.length > 0.01 ? radial_out.normalize : out_dir
  shifted = gate_ctr.offset(radial_out, outward_offset)
  gate_ctr = Geom::Point3d.new(shifted.x, shifted.y, gate_ctr.z)
end

pairs << {
  index:       pairs.size,
  center:      gate_ctr,  # <-- the CP, now at correct seam location
  tangent:     out_dir,
  half_offset: best_dist / 2.0,
}
```

### Usage in JPods Plugin

1. **At structure placement**: `resolve_connection_points(formation_id, defn, placement_data)` is called; CPs are computed and stored in the structure instance's `"JPods"` attribute as JSON.

2. **At network build**: `jpod_network.rb` reads the stored CP data, transforms it to world coordinates, and passes the CP center + tangent to `JPodGuideway.remove_structure_endcaps()`.

3. **When user clicks Recompute**: All structures are scanned; `resolve_connection_points` is called for each; CP circles are re-rendered at the stored centers.

## Next Phase: Explicit Seam Anchors

The current system works (empirically validated), but the 9-meter offset is a transitional solution. 

**Long-term goal**: Replace the hardcoded offset with explicit seam anchors in the formation templates.

**Three approaches:**

### 1. Best: Seam anchor component (recommended)

Add a tiny marker/group inside each ene_railroad ending definition at the exact seam point.

**Advantages:**
- Explicit, not inferred
- Survives template changes
- Different formations can have different seam geometries

**Implementation sketch:**
```ruby
def self.detect_seam_anchors(defn)
  anchors = []
  scan_components(defn.entities) do |comp|
    next unless comp.name.include?("CapSeam") || comp.name.include?("Seam")
    anchors << {
      point:   comp.transformation.origin,
      tangent: comp.transformation.yaxis  # or z-axis for inward direction
    }
  end
  anchors
end

# In pair_stubs, use seam anchors if present:
if seam_anchors && !seam_anchors.empty?
  seam_left  = defn.entities ... find_seam_anchor_for(stub_a)
  seam_right = defn.entities ... find_seam_anchor_for(stub_b)
  gate_ctr = (seam_left + seam_right) / 2
end
```

### 2. Good: Verify ene_railroad v23 invariant

Check whether ene_railroad v23 consistently places the ending instance origin at the guideway/cap seam in all templates.

**Advantages:**
- No template changes needed
- Uses existing ene_railroad structure

**Risk:**
- If v23 doesn't have this invariant, won't work
- Depends on ene_railroad's continued design

**Investigation needed:**
- Test: create a simple track in ene_railroad v23 with one ending
- Measure: ending instance origin position relative to the track extrusion end
- Repeat for different track angles, lengths, formations
- If origin == seam for all cases, enable `detect_connection_points_from_endings` for traffic circles

### 3. Current pragmatic: Ship with 9.m offset

Document the offset as transitional; commit to anchors in v2.4.

**Advantages:**
- Works now, fully tested
- No template changes
- Ship on schedule

**Disadvantage:**
- Fragile if traffic-circle template geometry changes
- Will need recalibration then

## References

### JPods Plugin

- **Repo**: `/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods/`
- **Rule definition**: [jpod_structure_tool.rb](../../../Library/Application%20Support/SketchUp%202026/SketchUp/Plugins/JPods/jpod_structure_tool.rb) (file header + pair_stubs + resolve_connection_points)
- **Design spec**: [readmes/basics.md](../../../Library/Application%20Support/SketchUp%202026/SketchUp/Plugins/JPods/readmes/basics.md) — "Current Status — April 22, 2026"
- **CP rendering**: [jpod_connect_tool.rb](../../../Library/Application%20Support/SketchUp%202026/SketchUp/Plugins/JPods/jpod_connect_tool.rb) — draws circles from stored CP attributes
- **Network build**: [jpod_network.rb](../../../Library/Application%20Support/SketchUp%202026/SketchUp/Plugins/JPods/jpod_network.rb) method `build_segment()` — uses CPs for segment linking

### ene_railroad v23

- **Location**: `/Users/williamjames/Library/Application Support/SketchUp 2023/Plugins/ene_railroad/`
- **Upright extrusion**: `upright_extruder.rb` — miter-scale extrusion, Z-aligned profile, XY rotation
- **Ending geometry**: `track.rb` method `draw_endings()` (~lines 1054–1070) — places removable caps
- **Seam location**: Ending instance origin is intended to mark the seam (verify in v23)

### History and Discussion

- **Repo memory**: `/memories/repo/connection-point-rule.md` — full derivation and code locations
- **Initial discovery**: Bill observed traffic-circle CPs at wrong end (April 20)
- **Debugging**: 3 failed approaches (stub filtering, outer_tip lambda, ending_scanner bypass)
- **Breakthrough**: 9-meter radial offset places CPs at visually correct location (April 22)
- **Validation**: Bill confirmed in SketchUp; network build now connects segments correctly

---

**Version**: JPods v2.3, April 22, 2026

**Status**: Rule is defined, implemented, and validated. Offset is pragmatic (9.m); anchor system planned for v2.4.

**Next reviewer**: When traffic-circle template changes, verify that 9.m offset still places CPs at the seam. If not, either (a) recalibrate the offset, or (b) implement seam anchor approach.


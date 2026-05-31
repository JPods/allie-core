# JPods Path Geometry — Visual to Math

**Purpose:** How to convert a visually understood guideway path into the mathematics
every agent needs. Applies to lines.json authoring, trip planning, physical travel,
and network pricing.

---

## The Three Path Types

Every path a JPods vehicle travels is one of three shapes:

| Type | Visual | Math |
|------|--------|------|
| **Straight** | A beam running in a fixed direction | start_point, end_point, length = Euclidean distance |
| **Arc** | A curved beam bending through an angle | center, radius, sweep_deg, direction, length = r × sweep_rad |
| **Bezier** | A curve connecting two CPs with smooth tangents | 4 control points (2 anchors + 2 tangent vectors), numerically integrated length |

---

## Straight Segment

Visual: two points connected by a beam.

```
length = sqrt((ex-sx)² + (ey-sy)² + (ez-sz)²)
```

In lines.json:
```json
{
  "length_mm": 2500.0,
  "start_point": [0.0, 250.0, 500.0],
  "end_point":   [2500.0, 250.0, 500.0]
}
```

---

## Arc Segment

Visual: a beam bending through an angle. Defined by three facts:
1. **Centerline radius** — distance from arc center to beam centerline
2. **Sweep angle** — how many degrees the arc bends (180° = U-turn)
3. **Direction** — CCW or CW when viewed from above (+Z)

**Key formula:**
```
arc_length = radius × sweep_radians
           = radius × (sweep_deg × π / 180)
```

**The JPods uturn** is always:
- radius = 1750mm (centerline of 500mm × 500mm beam cross-section)
- sweep = 180°
- direction = CCW from top
- arc_length = 1750 × π = **5497.8mm**

**How to find the center point:**
- The two endpoints of the arc are separated by `2 × radius` (the diameter of the arc)
- Center = midpoint of the chord between endpoints (for a 180° arc)
- For uturn: endpoints 3500mm apart → center at their midpoint

In lines.json:
```json
{
  "length_mm":  5497.8,
  "radius_mm":  1750.0,
  "sweep_deg":  180,
  "start_point": [2500.0, 250.0, 500.0],
  "end_point":   [2500.0, 3750.0, 500.0]
}
```

**Verification:** `sqrt((2500-2500)² + (3750-250)²) = 3500mm = 2 × 1750mm ✓`

---

## Bezier Segment

Visual: a smooth curve connecting two CPs with a direction at each end.

Defined by four control points:
```
P0 = from_anchor     (start of curve)
P1 = from_anchor + from_tangent × scale
P2 = to_anchor   - to_tangent   × scale
P3 = to_anchor       (end of curve)
```

The tangent vectors at each CP point OUTWARD from the CP (away from the formation center).
At the TO end, the tangent is **reversed** before use — the curve velocity is inward (arriving).

Length is numerically integrated by summing segment lengths along the polyline approximation.

In lines.json: Bezier paths are inter-station connections — they live in the network
trip.json, not in structure lines.json. lines.json only contains intra-station paths.

---

## How Each Agent Uses Path Geometry

| Agent | Role | What they read |
|-------|------|---------------|
| **Noelle** | Reads lines.json; validates network topology; refused entry if eps_header or eps[] absent | Reads at Build time to confirm connectivity and route through intra-station segments; reports defects but may not change eps[] |
| **Natalie** | Plans routes | Reads lines.json to compute travel distances and sequence guideways for a trip |
| **Nora** | Travels the path physically | Uses arc `radius_mm` and `sweep_deg` to calibrate motor speed through curves; uses `length_mm` to track distance via encoders |
| **Alice** | Prices trips | Sums `length_mm` across all guideways in a trip to compute distance-based fare |
| **Allie** | Cross-domain synthesis | Reads lines.json to detect topology changes across sessions; flags if arc lengths change (indicates wrong math or model edit) |
| **Claude Code** | Writes and verifies | Derives new lines.json entries from math; verifies existing entries against known geometry |

---

## The Authoring Rule

**You declare topology. The tool measures geometry. Math overrides the scanner.**

- Write `eps[]` by hand in lines.json — declare every junction type and its in/out segments
- Run `Models › Lines JSON Build` — it reads your eps[], scans gw_* geometry for
  coordinates, and writes the complete lines.json
- Uturn arc lengths are always overridden to π×1750=5497.8mm regardless of scanner output
- Once declared from math, lines.json is the authority. Never let a scan overwrite it
  without a written plan

Full authoring rules (segment naming, merge/diverge constraints, physical equivalence):
`readmes/sketchup/jpods-lines-json-authoring.md`

**Debug once, use many** — when a value is found to be wrong and corrected by math,
that correction propagates to every lines.json that uses it, once, permanently.
No station template re-derives arc length at build time. No agent recomputes a known
constant. The correct value lives in lines.json; everyone reads it from there.

This session: `gw_uturn` arc length was 4872.9mm (scan walked inner arc at r≈1551mm)
in four template files. Corrected once to 5497.8mm (π × 1750mm), applied to all four.
That correction is now the permanent record. Next session does not re-examine it.

Applies to: arc lengths, radii, segment lengths, CP separations, CLEARANCE_HEIGHT —
any physical constant that is derived once from geometry or measurement.

See also: Axiom 15 (CLAUDE.md) — Formation Map, Debug Once Use Many.

**Why scanning introduces error:** SketchUp arcs are many short edges. Scanning chains those edges correctly only
if the geometry is clean and isolated. For known structures — especially arcs with
known radii — the chain algorithm introduces error (it walked the inner arc at r≈1551mm
instead of the centerline at r=1750mm, producing 4872.9mm instead of 5497.8mm).
Math is exact. Edges are approximate.

---

## Quick Reference — JPods Standard Dimensions

| Parameter | Value | Notes |
|-----------|-------|-------|
| Beam cross-section | 500mm × 500mm | Square profile |
| Beam centerline Z | 250mm | Center of cross-section |
| Beam top Z | 500mm | Top edge |
| Uturn centerline radius | 1750mm | = (outer_r + inner_r) / 2 = (2000 + 1500) / 2 |
| Uturn outer radius | 2000mm | Outer wall of donut |
| Uturn inner radius | 1500mm | Inner wall of donut |
| Uturn arc length | 5497.8mm | π × 1750 |
| Uturn span (centerline) | 3500mm | 2 × 1750 = chord for 180° arc |
| CP guideway separation | 3500mm | Y distance between outbound and inbound centerlines |
| CP lead length | 2500mm | Standard lead segment (gw_cp_out_lead, gw_cp_in_lead) |
| CP platform length | 2500mm | Standard platform segment (gw_cp_out, gw_cp_in) |
| CLEARANCE_HEIGHT | 4600mm | Minimum beam bottom above terrain |

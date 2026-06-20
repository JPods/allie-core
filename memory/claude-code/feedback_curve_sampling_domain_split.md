---
name: Curve sampling — 1000mm polyline for SU, true analog for physical
description: SketchUp uses ~1000mm point spacing to simulate Bezier/arc curves visually; physical model needs true analog curve following, not discrete waypoints
type: feedback
---

Bezier and circular arc curves are represented differently in SketchUp vs. the physical model.

**SketchUp (SU): polyline approximation**
- One pt per ~1000mm of arc length, minimum 4 pts on any visible arc
- Chord deviation <10mm per segment at 15m radius — visually smooth
- Applies to: extracted.json pts_mm, path.json pts, followus ribbon, all SketchUp visualizations
- Implemented in: `_bezier_pts_from_tangents_mm`, `_arc_pts_from_center_mm` (ARC_SAMPLE_MM = 1000.0)

**Physical (PH): true analog**
- Discrete waypoints produce jerky motion — unacceptable for vehicle dynamics
- Nora's motor control must follow the actual curve continuously (smooth velocity profile)
- Ezone boundaries follow the real arc, not the polyline approximation
- This is a separate unsolved problem from SU visualization

**Why:** A polyline at 1000mm intervals looks smooth to a human eye in SketchUp. The same
polyline as physical waypoints would cause the vehicle to slow, turn, accelerate, slow, turn
at every 1m interval — visible as stuttering at speed. Physical curve following requires
parametric curve tracking (constant curvature rate), not waypoint stepping.

**How to apply:** Never use SU path.json pts directly as Pi motor waypoints. When physical
curve following is implemented, it must derive from the Bezier/arc parameters (center, radius,
sweep), not from the sampled polyline pts.

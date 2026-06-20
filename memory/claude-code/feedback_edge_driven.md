---
name: Edge-driven specs, sensors, and metrics
description: All position, clearance, ezone, and sensor references must anchor to hard physical edges — never to calculated centerlines
type: feedback
---

All JPods specs, sensors, and metrics are edge-driven. No calculated centerline is ever the authoritative reference.

**Why:** SketchUp proved this the hard way. FollowMe walks edges natively. When centerlines were computed (e.g., Bezier center between two structural stubs) and fed to the build pipeline, the animation system produced wrong heights, collapsed paths, and Z drift — because the geometric authority in SketchUp is the edge, not the midpoint. The same failure class extends to physical sensors and routing logic.

**How to apply:**
- Beam clearance: measured to the bottom edge of the beam, not the centerline. Spec is "4.6m to beam bottom edge."
- Platform position: defined by the platform edge (boarding threshold), not platform midpoint.
- Ezone boundaries: defined by the entry/exit edge of the guideway segment, not a centerline offset radius.
- TOF sensor targets: aim at a beam face edge or station wall face — never a calculated center.
- AprilTag placement: mounted on a physical edge or corner surface so position = tag face, not a derived midpoint.
- Routing (Natalie): line start/end = stub edge at the gate, not a midpoint of the connection.
- SketchUp build pipeline: Bezier Z zeroed before PathBuilder; PathBuilder's floor_z (terrain + CLEARANCE_HEIGHT) establishes the edge-referenced beam elevation.

**Authoritative hierarchy:**
1. Hard physical edge — always primary
2. Derived centerline — for display or computation only, never stored as a reference
3. If a centerline is needed, compute it from two known edges at display time

**The rule of thumb:** If the value would change when a beam width or offset changes and the change is not automatically detected, the reference is wrong. Edge references self-correct when geometry changes; centerline offsets silently diverge.

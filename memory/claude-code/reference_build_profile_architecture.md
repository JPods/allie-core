---
name: Build profile Z pipeline — what each stage does
description: Complete Z pipeline for build: bezier → terrain snap → desired_z → grade clamp → smooth → blend; which stage causes which defect
type: reference
---

The build Z pipeline (build_path.rb `apply_vertical_profile`):

1. **Bezier** — waypoint beam_z flows through as 3D control points. Read from entity `beam_z` attribute (NOT bounds.center).
2. **Terrain snap** — raycast each bezier point to get terrain Z. Skip JPods entities via bounding-box jump. z=0 fallbacks interpolated from neighbors.
3. **Smoothed terrain** — Gaussian with VERTICAL_SMOOTH_RADIUS (80m). Produces `floor_z` = smoothed terrain + clearance.
4. **Desired Z** — piecewise linear through [CP_start, WP1, WP2, ..., CP_end]. Waypoint Z = beam_z attribute directly (no extra clearance).
5. **Grade envelopes** — piecewise between waypoint anchors (NOT between CPs). Each WP-to-WP span gets own forward/backward grade limits.
6. **Clamp** — desired_z clamped to smoothed floor and grade limits. `hard_floor_z` (raw terrain) is NOT in the clamp — it's a safety log only.
7. **Profile smooth** — Gaussian with MIN_Z_CHANGE_DIAMETER (60m). Rounds corners between spans.
8. **Endpoint blend** — Hermite blend within first/last anchor span only (10m or 35%).

**Defect sources and fixes (session 2026-06-23):**
- bounds.center instead of beam_z → wrong waypoint Z
- Double clearance (beam_z + CLEARANCE_HEIGHT) → target 4.6m too high
- Grade cones from CPs → overrode waypoint Z at distance
- Hard pin after smoothing → spike at waypoint index
- hard_floor_z in min_z_bounds → every mesh bump forced beam up
- Terrain raycast z=0 at markers → 20m+ floor spikes

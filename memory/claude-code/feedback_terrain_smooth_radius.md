---
name: Terrain smoothing pulls adjacent features
description: SU terrain-following Gaussian smooths in adjacent steep terrain; 80m radius too wide for roads on hillsides; user needs per-network control
type: feedback
---

SU terrain-following creates lumpy Z on roads that have steep terrain adjacent. The VERTICAL_SMOOTH_RADIUS (80m Gaussian) averages terrain Z over too wide a window, pulling steep hillside Z into the road grade. Physical terrain is a consistent grade but SU scrambles it.

**Why:** The s005→s006 segment runs down a road on a hillside. The road grade is consistent but the terrain to either side is steep. The 80m smoothing window averages the steep hillside into the road surface, creating lumps in what should be a smooth descent.

**How to apply:** Expose XY and Z smooth radii as per-network user controls in Network Display. Smaller Z radius = tighter terrain following on the actual path. Consider: the terrain raycast samples points along the bezier path, so the smooth radius should be relative to path features, not absolute terrain span.

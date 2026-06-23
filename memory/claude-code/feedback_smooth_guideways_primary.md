---
name: Smooth guideways are a primary requirement
description: All XYZ changes apply accelerations/g-forces; columns absorb terrain with variable height; guideway must be smooth; SU terrain mesh is noisy — never treat it as physical reality
type: feedback
---

Smooth guideways are a primary requirement. All changes in XYZ apply accelerations and g-forces that must be minimized. Columns vary in height to absorb terrain variation — the guideway stays smooth.

**Why:** A pod at speed cannot handle sharp Z transitions. SU terrain meshes are noisy approximations of real terrain. The profile algorithm was giving priority to unrealistic SU map rendering, creating lumpy beams that follow mesh noise instead of actual terrain grade. Adjacent steep terrain (hills next to a road) was being averaged into the road profile.

**How to apply:**
- Smoothed terrain floor governs the profile — raw terrain (`hard_floor_z`) is a safety log, not a profile driver
- Three user controls in Build Profile bar: XY smooth (5m default), Z smooth (3m default), Z span (15m default)
- Z span = terrain averaging window. 15m follows actual path grade without pulling in adjacent hills. Was 80m (too wide).
- XY smooth = horizontal path jitter dampening. 5m. Was 3m.
- Columns will be whatever height is needed. Never sacrifice beam smoothness for short columns.
- Waypoint beam_z flows through the profile via piecewise interpolation, not hard pins
- Terrain raycast: bounding-box skip + z=0 interpolation works; Entities.raytest does NOT exist in SketchUp API

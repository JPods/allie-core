---
name: Frame of reference discipline — declare which frame every coordinate is in
description: JPods has three geometry frames (structural/vehicle-path/vertical) that must never be silently mixed; every coordinate must declare its frame; discovered 2026-06-07
type: feedback
---

Every JPods coordinate must explicitly declare which frame of reference it is in. Silently mixing frames produced multiple bugs in the same session (gw_uturn inside rail, Z-disconnected ribbon, wrong arc radius check).

**The three frames:**

| Frame | What | Key values |
|-------|------|-----------|
| Structural | Inside rail edge; what SketchUp ArcCurves and FollowMe paths are built on | radius = 1500mm |
| Vehicle path | Pod centerline; where the vehicle actually travels | centerline = inside + 250mm |
| Vertical | Beam center, beam top, or terrain | varies ±250mm (BEAM_DEPTH/2) |

**Conversions (all must be explicit and named):**
- Inside rail → centerline: +BEAM_WIDTH/2 (250mm) radially outward
- Beam center → beam top: +BEAM_DEPTH/2 (250mm)
- Terrain → beam bottom: +CLEARANCE_HEIGHT (4600mm)

**Declared frames for established data:**
- extracted.json / path.json pts → vehicle path frame, beam center Z
- followus ribbon_z → display only, lifted above beam top; not vehicle path
- CLEARANCE_HEIGHT → terrain → beam bottom (structural)

**Why:** Three bugs in one session had identical root cause — a coordinate created in one frame consumed in another with no conversion documented. When facing a geometry bug, first question: which frame is each coordinate in?

**How to apply:** In every function that accepts or returns coordinates, add a comment naming the frame. When crossing a frame boundary, name both frames and the conversion explicitly. Challenge every coordinate that "looks right" — it might be right in the wrong frame.

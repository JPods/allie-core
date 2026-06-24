---
name: 500mm gaps are edge-not-centerline hallucinations
description: Any ~500mm gap in track connection is Noelle measuring edge-to-edge across the dual track instead of centerline-to-centerline; use math not edges; Axiom 10
type: feedback
---

All ~500mm gaps are hallucinations. They come from measuring the distance between guideway EDGES on opposite sides of the dual track instead of CENTERLINES. Dual track spacing is ~500mm (BEAM_WIDTH = 500mm, 250mm each side of centerline). This error causes Noelle to reverse tracks incorrectly, which jams pods.

**Why:** This has been fixed before and keeps coming back. The gap detection code measures pts.first and pts.last against the predecessor's last point. If it accidentally measures to the wrong edge (opposite rail), the gap appears to be ~500mm — close enough to "connect" but from the wrong end, triggering a reversal.

**How to apply:**
- Any gap ≈ 500mm (±100mm) is a red flag — it's edge-to-edge, not center-to-center
- USE MATH, NOT EDGES — Axiom 10 (Explicit Model Datum Beats Derived Reference)
- Centerline-to-centerline gap should be < 50mm for a valid connection
- If gap is 400-600mm, LOG A WARNING and DO NOT reverse — it's the wrong measurement
- The correct reference is always the track centerline, never the beam edge
- This principle applies to all programs: SU, Physical, Route-Time

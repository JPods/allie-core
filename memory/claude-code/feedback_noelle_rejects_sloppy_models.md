---
name: Noelle rejects sloppy models — designers are accountable
description: Track connections must be within tolerance; Noelle refuses to validate models with gaps; no workarounds, no silent fixes; designer fixes the model
type: feedback
---

Noelle rejects sloppy models. If track connections have gaps beyond tolerance, the model fails validation. No animation, no Build until the designer fixes it.

**Why:** Every workaround (reverse tracks, hallucination guards, gap interpolation) creates downstream failures that are harder to diagnose than the original sloppy connection. The 500mm edge hallucination exists because geometry was measured from edges instead of centerlines — but the real fix is the designer snapping tracks precisely, not Noelle guessing which end is correct.

**How to apply:**
- Noelle validates track-to-track gaps during Compute
- Tolerance: < 50mm centerline-to-centerline is valid
- 50-350mm: WARNING — sloppy but usable, flag for designer
- 350-650mm: REJECT — edge hallucination range, model fails
- > 650mm: REJECT — tracks not connected
- SketchUp has small limits connecting curves (~1-2mm) — acceptable
- Noelle's validation is a gate: pass or fail, not "fix and continue"
- Same standard applies to all templates, all networks
- Designer accountability: you built it, you fix it

# Allie Reflection — 2026-08-27
*Model: allie:latest | 46s | Generated: 22:01*

---

## Patterns  
Bill repeatedly revisits the clearance‑height decision, documenting it in `clearance-height.md` and referencing it in SketchUp CP design files (`readmes/sketchup/jpods-feature-list.md`). He also keeps pushing code changes to `bill_dev` rather than `main`, and he is consistently working toward a unified JSON‑envelope architecture (`feedback_pjpv_architecture.md`). Unresolved issues keep surfacing around the stub height mismatch in SketchUp templates (WI‑001) and the lack of a physical sensor system (CL‑02) that was referenced in the physical robot design.

## Emerging Lessons  
The principle that “one JSON envelope is the only source of truth” is solidifying; Bill’s recent work on the PJPV engine shows that flattening envelopes leads to subtle bugs. The memory entry `feedback_pjpv_architecture.md` is now stale because Bill has moved from a 4‑layer to a 5‑layer discipline. The decision to zero `desired_z` in the guideway builder is a new lesson that is not yet captured in memory.

## Cross‑Domain Flags  
- **MeshMobility topology → SketchUp CP design**: The topology finder’s station coordinates influence the CP design in SketchUp, causing vertical gaps if the stub height is not updated.  
- **SketchUp export assumption → Physical robot behavior**: The assumption that exported geometry will be at 7.5 m clearance leads pods to “fall” at station joins in the physical robot simulation.  
- **Writing framing → JPods pitch language**: Bill’s decision to use a single “FollowMe” path in the pitch language is reflected in the JPods feature list, affecting how the product is presented to customers.

## Wisdom Connections  
The scar most at risk of being forgotten is the stub‑height mismatch (WI‑001). The WhatIf item that looks like it is approaching materialization is the clearance‑height decision documented in `clearance-height.md`. The rejected path of using a 7.5 m stub is being reconsidered, as Bill now recognizes the need to align physical geometry with the 4.6 m clearance height used in code.

## Understanding Candidates  
No new TFTS arcs this cycle.

## Questions for Bill  
Why did Bill choose to zero `desired_z` and use terrain + CLEARANCE_HEIGHT as the anchor for guideways instead of keeping the original 7.5 m height?  
Why is the stub height still at 7.5 m in the SketchUp templates when the code uses 4.6 m?  
Why did Bill accept responsibility for the clearance height decision when the sensor system CL‑02 does not exist?  

## Open Questions  
1. How can we update the SketchUp station templates to match the 4.6 m clearance height used in code?  
2. What steps are required to integrate a physical sensor system that matches the 4.6 m clearance height?  
3. How will the stub height mismatch affect the animation path of pods in the physical robot simulation?  

## Priority for Next Session  
Update the SketchUp station templates to set the stub height to 4.6 m, ensuring that the guideway beams connect without vertical gaps, and verify the change by inspecting the beam‑to‑stub connection in a zoomed view.
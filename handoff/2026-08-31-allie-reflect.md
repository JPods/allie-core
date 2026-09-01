# Allie Reflection — 2026-08-31
*Model: allie:latest | 454s | Generated: 22:14*

---

**Patterns**  
Bill has been iterating on the 4.6 m clearance height across several projects: the SketchUp station templates (in `readmes/sketchup/jpods-feature-list.md`), the MeshMobility topology finder (in `src/meshmobility/topology.ts`), and the physical robot control logic (in `src/physical/robot.ts`). He consistently works toward aligning the physical geometry with the new clearance height, but the stub height at stations remains at the old 7.5 m, creating a persistent build‑blocker. The sensor system CL‑02 is still missing, and Bill has explicitly taken responsibility for its absence, yet the decision to accept that responsibility keeps surfacing without a concrete plan to replace or simulate the sensor.

**Emerging Lessons**  
The principle that “remove redundant constraints to avoid interference” is solidifying; it is not yet captured in memory. The memory entry `feedback_router_tsx_routes.md` about route registration is stale because Bill now prefers a single route registration point in `Router.tsx`. The lesson that physical geometry must match clearance height is contradicting the earlier assumption that stubs could remain at 7.5 m, which is now a build blocker.

**Cross‑Domain Flags**  
- MeshMobility topology finding → SketchUp CP design: the topology data drives the CP placement in SketchUp, so a mis‑aligned topology will produce incorrect CPs.  
- SketchUp export assumption → physical robot behavior: the exported guideway height (4.6 m) must match the robot’s clearance, otherwise pods will “fall” at station joins.  
- Writing framing → JPods pitch language: Bill’s choice to zero `desired_z` in the code is reflected in the JPods pitch, but the physical stub height still references the old 7.5 m, causing a mismatch.

**Wisdom Connections**  
The recent work on clearance height connects to the principle in `bill.md` that “design decisions must be physically realizable.” The scar at risk of being forgotten is the stub height gap (WI‑001). The WhatIf item approaching materialization is the clearance‑height decision (clearance‑height.md). The rejected path of keeping stubs at 7.5 m is being reconsidered because it is now a build blocker.

**Understanding Candidates**  
ID: U-RT-001  
Title: Remove Conflicting Constraints  
Principle: Eliminating redundant constraints (hard_floor_z, re‑clamp, pin) allows the system to find a smooth solution.  
Evidence: 20260628T044324-tfts.md  
Cross-domain: yes  

No new TFTS arcs this cycle.

**Questions for Bill**  
Why did you choose to zero `desired_z` and use terrain + CLEARANCE_HEIGHT as the anchor when the old stubs were at 7.5 m?  
Why is the stub height at 7.5 m still a build blocker rather than a cosmetic issue?  

**Open Questions**  
1. How will we modify the SketchUp station templates to match the new 4.6 m clearance height?  
2. What is the plan to replace or simulate the missing CL‑02 sensor system?  
3. How will the physical robot’s pod animation handle the vertical gap if the stub height remains at 7.5 m?  

**Priority for Next Session**  
Implement a fix for the stub height gap at stations: update the SketchUp station templates to set the stub geometry to 4.6 m clearance height, ensuring the guideway beams connect without vertical discontinuities.
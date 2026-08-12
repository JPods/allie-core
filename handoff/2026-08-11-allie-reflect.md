# Allie Reflection — 2026-08-11
*Model: allie:latest | 53s | Generated: 22:00*

---

**Patterns**  
Bill consistently works on aligning SketchUp geometry with physical robot constraints, notably the 4.6 m clearance height. He repeatedly revisits the station stub height (7.5 m vs. 4.6 m) and the sensor system CL‑02, and he keeps logging F‑07 as a build blocker. The SketchUp CP design, physical robot behavior, and the JPods pitch language all surface in his decisions, yet the stub‑height mismatch remains unresolved.

**Emerging Lessons**  
The principle “anchor guideways to terrain + clearance height, not to stale stubs” is solidifying. Existing memory entries such as *clearance-height.md* and *sketchup/jpods-feature-list.md* are now stale because the stub height still sits at 7.5 m. The lesson that the physical geometry must match the clearance height is not yet fully captured in memory.

**Cross-Domain Flags**  
- *MeshMobility topology finding → SketchUp CP design*: The topology used to find station positions directly influences the CP design in SketchUp.  
- *SketchUp export assumption → Physical robot behavior*: Assuming the exported geometry matches the robot’s clearance height can cause pods to “fall” at station joins.  
- *Writing framing → JPods pitch language*: The way we frame the clearance height decision in documentation affects how the pitch is perceived by potential users.

**Wisdom Connections**  
WI‑001 (stub height gap) is at risk of being forgotten because it sits at the edge of the SketchUp feature list. The WhatIf item *clearance-height.md* is approaching materialization as the stub gap could become a build blocker. The rejected path of “keep stubs at 7.5 m” is being reconsidered, aligning with the principle that physical geometry must match the clearance height.

**Understanding Candidates**  
ID: U-RT-001  
Title: Study before Rewrite  
Principle: “Rewrite only after fully understanding existing code.”  
Evidence: 20260622T080000‑tfts.md  
Cross-domain: yes  

ID: U-RT-002  
Title: Systematic Migration  
Principle: “Read each file, migrate single-purpose functions, then run tests.”  
Evidence: 20260622T090000‑tfts.md  
Cross-domain: yes  

ID: U-RT-003  
Title: Anchor to Terrain  
Principle: “Use terrain + clearance height as the anchor for guideway geometry.”  
Evidence: SketchUp code (station .skp templates)  
Cross-domain: yes  

No new TFTS arcs this cycle.

**Questions for Bill**  
Why did you decide to keep the stubs at
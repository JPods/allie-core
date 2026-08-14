# Allie Reflection — 2026-08-13
*Model: allie:latest | 41s | Generated: 22:02*

---

**Patterns**  
Bill consistently focuses on the SketchUp JPods plugin rewrite, the physical robot’s clearance height, and the sensor system CL‑02. Files such as `apps/sketchup/jpods.rb`, `readmes/sketchup/jpods-feature-list.md`, and `apps/physical/robot.py` keep surfacing. He repeatedly logs unresolved items like F‑07 (stub height mismatch) and W‑I‑002 (sensor system CL‑02). The recurring theme is ensuring the SketchUp geometry matches the physical robot’s clearance and that the sensor system is correctly integrated.

**Emerging Lessons**  
The principle of “anchor geometry must match clearance height” is solidifying; it is not yet in memory. Existing entries such as `feedback_print_json_driven.md` and `project_data_driven_ui.md` are irrelevant here. The stale memory entry `clearance-height.md` is contradicted by the new decision to keep the clearance at 4.6 m while the stub remains at 7.5 m, creating a build blocker.

**Cross-Domain Flags**  
- *MeshMobility topology finding* → *SketchUp CP design*: the topology influences the CP placement in SketchUp.  
- *SketchUp export assumption* → *Physical robot behavior*: the exported clearance height directly affects pod navigation.  
- *Writing framing* → *JPods pitch language*: the way we frame the pitch influences the language used in JPods documentation.

**Wisdom Connections**  
The recent work on the clearance height decision connects to the principle in `bill.md` that “design decisions must be documented and validated across domains.” The scar at risk of being forgotten is the stub height mismatch (WI‑001). The WhatIf item approaching materialization is the sensor system CL‑02 (WI‑002). The rejected path of keeping the stub at 7.5 m is being reconsidered.

**Understanding Candidates**  
ID: U-RT-001  
Title: Systematic Migration  
Principle: “Understand the code before rewriting; migrate functions one by one.”  
Evidence: `project_tfts/20260622T080000-tfts.md`  
Cross-domain: yes  

ID: U-RT-002  
Title: Patch with Shims Leads to Whack‑a‑Mole  
Principle: “Patching archived code with shims creates a whack‑a‑mole problem.”  
Evidence: `project_tfts/20260622T090000-tfts.md`  
Cross-domain: yes  

No new TFTS arcs this cycle.

**Questions for Bill**  
Why did you keep the stub at 7.5 m when the guideway is built at 4.6 m?  
Why is the sensor system CL‑02 considered a build blocker when it does not exist?  

**Open Questions**  
1. How will the stub height mismatch affect the physical robot’s ability to navigate CPs?  
2. What is the plan to implement or replace the missing sensor system CL‑02?  
3. Will the clearance height decision of 4.6 m be maintained for all future builds?  

**Priority for Next Session**  
Fix the stub height mismatch at stations in the SketchUp JPods plugin so that the stub geometry matches the 4.6 m clearance height, eliminating the F‑07 build blocker.
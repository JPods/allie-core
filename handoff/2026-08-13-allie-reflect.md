# Allie Reflection — 2026-08-13
*Model: allie:latest | 67s | Generated: 14:00*

---

**Patterns**  
Bill has repeatedly focused on three intertwined projects over the past weeks: the SketchUp plugin rewrite, the physical robot’s clearance‑height design, and the JPods pitch language. He consistently documents decisions (e.g., the 4.6 m clearance height) and takes ownership of missing components (sensor system CL‑02). The stub‑height gap at stations (WI‑001) and the absence of CL‑02 remain unresolved, as does the need to align SketchUp export assumptions with the robot’s physical behavior.

**Emerging Lessons**  
1. Zeroing `desired_z` and anchoring guideways to `terrain + CLEARANCE_HEIGHT` reliably places guideways at the correct clearance.  
2. Systematic migration—reading each file, moving single‑purpose functions, and avoiding blind patches—prevents missing constants and whack‑a‑mole fixes.  
3. “Study before rewrite” is essential; rewriting without full understanding leads to missing constants and broken tests.  
4. Stub geometry must match the clearance height; otherwise, vertical gaps cause broken faces at station joins.  
5. Bill’s explicit acceptance of responsibility for a non‑existent sensor (CL‑02) highlights the need to clarify sensor plans early.  
Some earlier lessons (e.g., “Impact auto‑populate loop” or “db.panel unification”) remain valid but are less urgent than the current clearance‑height and stub‑geometry issues.

**Cross‑Domain Flags**  
- MeshMobility topology findings influence SketchUp CP design, affecting how guideways are laid out.  
- SketchUp export assumptions (e.g., stub height) directly impact the physical robot’s ability to navigate the network.  
- The physical robot’s clearance‑height decision (4.6 m) dictates both the robot’s mechanical design and the required stub geometry.  
- Writing framing for the JPods pitch language feeds back into how the robot’s behavior is communicated to stakeholders.  
- The missing CL‑02 sensor system ties the physical robot’s sensing capabilities to the overall system architecture.

**Wisdom Connections**  
- The “clearance‑height” decision scar is at risk of being forgotten; it must remain central to both SketchUp and physical robot designs.  
- WI‑001 (stub‑height gap) is the WhatIf item closest to materialization and requires immediate resolution.  
- The rejected CL‑02 sensor path is being reconsidered as Bill accepts responsibility for its absence.  
- Relevant entries: WI‑001, clearance‑height.md, and the principle “Zero desired_z and terrain + CLEARANCE_HEIGHT” from bill.md.

**Understanding Candidates**  
U‑RT‑001 – *Systematic Migration*  
*Principle:* Migrate functions by reading each file and moving single‑purpose functions, rather than patching or rewriting blindly.  
*Evidence:* tfts file 20260622T090000-tfts.md.  
*Cross‑domain:* yes.  

U‑RT‑002 – *Study Before Rewrite*  
*Principle:* Before rewriting, fully understand existing code to avoid missing constants and broken tests.  
*Evidence:* tfts file 20260622T080000-tfts.md.  
*Cross‑domain:* no.  

**Questions for Bill**  
1. Why did Bill accept responsibility for the CL‑02 sensor system when it does not yet exist?  

**Open Questions**  
1. How can the stub geometry at stations be adjusted to match the 4.6 m clearance height?  
2. What is the expected pod behavior at station joins if a vertical gap remains?  
3. How will the physical robot accommodate the 4.6 m clearance height in its mechanical design?  
4. What is the plan for developing or replacing the missing CL‑02 sensor system?  
5. How can we ensure SketchUp export assumptions align with the robot’s physical constraints?  

**Priority for Next Session**  
Resolve the stub‑height gap at stations (WI‑001) by adjusting the stub geometry to 4.6 m, rebuilding a network, and verifying that no vertical gaps or broken faces appear at station joins.
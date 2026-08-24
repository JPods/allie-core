# Allie Reflection — 2026-08-23
*Model: allie:latest | 1075s | Generated: 22:29*

---

**Patterns**  
- Bill has repeatedly focused on establishing a 4.6 m clearance height for all guideway beams, zeroing `desired_z` and anchoring beams to `terrain + CLEARANCE_HEIGHT`.  
- The stub geometry for stations remains at the legacy 7.5 m height, creating a vertical mismatch that is flagged as a build blocker (F‑07).  
- MeshMobility’s topology logic and MCP registration have been revisited, but the CL‑02 sensor system remains unimplemented.  
- Across SketchUp, MeshMobility, and physical projects, Bill consistently prioritizes aligning virtual models with real‑world constraints, yet the stub‑height issue and missing sensor system persist as unresolved items.

**Emerging Lessons**  
- The “JSON envelope is source of truth” principle is reinforced by the recent need to zero `desired_z` and use terrain + CLEARANCE_HEIGHT; any deviation from this practice risks inconsistencies.  
- The stub‑height mismatch contradicts the earlier clearance‑height decision documented in `clearance-height.md`; the memory entry for structural geometry must be updated to reflect the 4.6 m standard.  
- The acceptance of responsibility for a non‑existent CL‑02 sensor system highlights a gap in the physical‑system design that must be addressed.

**Cross‑Domain Flags**  
- *MeshMobility → SketchUp CP design*: The topology guard logic (distance‑based reversal guard) directly influences how station stubs are generated in SketchUp.  
- *SketchUp export → Physical robot behavior*: The zeroing of `desired_z` and use of terrain + CLEARANCE_HEIGHT in SketchUp export must be mirrored in the physical robot’s path‑planning to avoid vertical gaps.  
- *Writing framing → JPods pitch language*: The decision to keep stubs at 7.5 m while beams are at 4.6 m is reflected in JPods documentation, potentially confusing stakeholders about the true clearance height.

**Wisdom Connections**  
- The stub‑height mismatch (F‑07) is a build‑blocker scar that risks being overlooked; it must be resolved before further development.  
- WI‑001 (“Stub‑height mismatch”) is approaching materialization as a critical issue.  
- The rejected path of using an incorrect MCP registration file is reconsidered, linking to the principle that the correct config file must be used for MCP registration.

**Understanding Candidates**  
- **U‑RT‑001** – *Guard Reversal Logic*: Guard reversal only when distance is within a safe range. Evidence: 20260624T100000‑tfts.md. Cross‑domain: Yes.  
- **U‑RT‑002** – *Correct MCP Registration File*: Use the proper MCP registration file for server configuration. Evidence: 20260624T192222‑tfts.md. Cross‑domain: Yes.  
- **U‑RT‑003** – *Apply Waypoint Z at Markers*: Ensure waypoint Z is applied to markers to avoid elevation loss. Evidence: 20260628T043254‑tfts.md. Cross‑domain: Yes.

**Questions for Bill**  
1. Why did you choose to keep the station stub at 7.5 m while the guideway beams are at 4.6 m?  
2. Why did you decide to zero `desired_z` and use `terrain + CLEARANCE_HEIGHT` as the anchor for guideway beams?  
3. Why did you accept responsibility for the CL‑02 sensor system that does not currently exist?

**Open Questions**  
1. How should the structural geometry of station stubs be adjusted to match the 4.6 m clearance height used for guideway beams?  
2. What steps are required to implement the CL‑02 sensor system or provide an alternative solution?  
3. How can we ensure that the physical robot’s path‑planning aligns with the SketchUp export without vertical gaps?  
4. What documentation updates are needed to reflect the stub‑height mismatch and the acceptance of responsibility for CL‑02?  

**Priority for Next Session**  
Adjust the structural geometry of station stubs to match the 4.6 m clearance height used for guideway beams, eliminating vertical gaps at station joins and resolving the F‑07 build blocker.
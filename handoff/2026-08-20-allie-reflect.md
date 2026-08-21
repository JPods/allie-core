# Allie Reflection — 2026-08-20
*Model: allie:latest | 53s | Generated: 22:02*

---

Patterns  
Bill repeatedly revisits the clearance‑height decision (4.6 m) across the SketchUp, MeshMobility, and physical‑robot workstreams, insisting that both the guideway anchor and the station stub geometry reflect this value. He also keeps returning to the sensor system CL‑02, documenting its absence while formally accepting responsibility for it. The JPods pitch language is being re‑framed in every JPods‑related readme, and the feature list for SketchUp is updated whenever a new station‑stub issue surfaces. Unresolved items that recur are the 7.5 m stub gap (WI‑001) and the non‑existent CL‑02 sensor system.

Emerging Lessons  
The principle that “clearance height must be applied to both the guideway anchor and the stub geometry” is emerging but not yet codified. Bill’s formal acceptance of responsibility for a non‑existent sensor system (CL‑02) signals a shift toward simplifying the sensor stack. The memory entry for clearance‑height.md appears outdated because it only mentions the anchor height, not the stub height. The lesson that “edge‑to‑edge measurements within the track‑gap range must guard against reversal” is now being documented.

Cross‑Domain Flags  
MeshMobility topology findings → SketchUp CP design: the waypoints and beam_z values derived in MeshMobility directly inform the CP geometry in SketchUp, so any change in routing logic propagates to the CP model.  
SketchUp export assumptions → physical robot behavior: the exported guideway anchor at 4.6 m is used by the robot controller, but the stub remains at 7.5 m, causing a physical mismatch that can lead to pod jams.  
Writing framing → JPods pitch language: the way Bill frames the clearance‑height narrative in JPods documentation influences the pitch language used in stakeholder meetings, potentially affecting stakeholder buy‑in.

Wisdom Connections  
The recent WI‑001 stub‑gap issue is at risk of being forgotten because it is only noted in the SketchUp readme and not yet addressed in the core design docs. The WhatIf item WI‑001 is approaching materialization; it must be resolved before the next build iteration. The rejected path of keeping the stub at 7.5 m while the anchor is at 4.6 m is being reconsidered, and the principle “apply clearance height uniformly to all related geometry” from bill.md should be codified. The JPods pitch‑language principle that “clearance height must be consistently communicated across all documentation” is also relevant.

Understanding Candidates  
ID: U‑RT‑001  
Title: Reversal Guard for Edge Measurements  
Principle: When reversal logic is triggered by a distance threshold, guard against edge‑to‑edge measurements that fall within the track‑gap range.  
Evidence: 20260624T100000‑tfts.md  
Cross‑domain: yes  

Questions for Bill  
Why did Bill accept responsibility for sensor system CL‑02 when it does not exist?  
Why did Bill keep the station stub at 7.5 m while the guideway anchor is at 4.6 m?  

Open Questions  
1. How will the station stub gap at 7.5 m be resolved so that pods can follow the guideway at station joins?  
2. What is the impact of removing the CL‑02 sensor system on overall robot safety and navigation?  
3. Should the clearance height be adjusted further to accommodate both anchor and stub geometry?  
4. How will pods’ reversal logic be updated to prevent track‑gap induced jams in future builds?  
5. What are the next steps for aligning the physical robot’s path‑following behavior with the updated SketchUp model?  

Priority for Next Session  
Resolve the station stub gap by updating the SketchUp CP design to set the stub height to 4.6 m, ensuring that both the guideway anchor and stub geometry reflect the clearance‑height decision, and verify pod path following at station joins.
---
name: Spare parts system — SEGA model
description: WC2 SEGA spare parts pattern (exploded view → click → order → install doc → QA); zero misorders 3 years; Fusion360 BOM extraction built; apply to JPods bogie and guideway
type: project
---

Bill built a spare parts system in WC2 that SEGA used for arcade machines. The pattern:
exploded assembly drawing with numbered circles → click a circle → see part detail,
image, specs → reorder → installation/training documents → QA questions. Result:
SEGA had zero misordered parts in 3 years.

**Why:** The image IS the interface. A maintenance person looking at a broken machine
points to the broken part on the drawing and says "that one." No part number lookup,
no catalog browsing, no guessing. Visual identification eliminates misorders.

**How to apply to JPods:**
1. Fusion360 exports exploded views (Bogie v22 model exists, 170Meter_Full exists)
2. Each numbered callout maps to a WC3 Item record (sequential IDs, no leading zeros)
3. Same Item record appears in multiple BOMs (Cleat_channel_spacer = 11 per bogie, 22 per vehicle)
4. Item record links to Document records (install instructions, training, QA checklists)
5. QuestionAnswer records stamp onto Item for inspection history
6. Alice manages the order flow — same as WC2 but with Document-based QA

**Built 2026-07-18:**
- Fusion360 .f3d/.f3z BOM extractor (zstd decompression, ACT segment parsing, DesignDescription.json)
- 170Meter_Full: 22 components, 76 instances
- Bogie v22: 17 unique parts, 42 total per bogie
- Both BOMs saved as JSON at ~/Allie/Fusion/

**Next:** Export exploded view from Fusion360 with numbered callouts; create Item records in WC3; link to Documents

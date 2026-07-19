# Allie Reflection — 2026-07-18
*Model: allie:latest | 65s | Generated: 22:01*

---

### Patterns  
Bill consistently works on aligning the virtual and physical representations of JPods stations. In SketchUp, the `station.skp` templates still contain 7.5 m stubs while the guideway geometry is built at 4.6 m clearance, creating a vertical gap at every station join. In the physical domain, Bill has accepted responsibility for the missing CL‑02 sensor system and the clearance‑height decision. Across MeshMobility, SketchUp, and Physical, the recurring pattern is the need to reconcile clearance height and stub geometry, a problem that remains unresolved and is logged as F‑07.

### Emerging Lessons  
The principle that “understand existing code before rewriting” is solidifying; it explains why the first rewrite of `build.rb` produced incorrect geometry. The memory entry “Reload and restart as a development rule” is still valid, but the entry “Shift+hover=tooltip” may be stale because the new UI now uses a single‑key help system. The WhatIf item WI‑001 (stub‑gap) is approaching materialization and should be tracked closely.

### Cross‑Domain Flags  
- **MeshMobility topology → SketchUp CP design**: The topology finder’s station positions dictate CP placement in SketchUp, so any change in station geometry affects the SketchUp model.  
- **SketchUp export assumption → Physical robot behavior**: Assuming the guideway beam attaches at 7.5 m leads to a vertical discontinuity that the physical FollowMe path will cross, potentially causing robot
---
name: Guideway constraint rule — all platforms
description: All physical systems must have guideways (physical or animated). Animated paths require designer-declared constraint mechanisms. No undeclared animated paths.
type: feedback
---

All physical systems will have guideways — physical or animated. If animated, the designer must provide the necessary constraint mechanisms.

**Why:** A pod without a guideway (physical or constrained-animated) is not a JPod — it's a robot in the wild. The 4WD floor robots use AprilTag corridors as animated guideways. FullScale/SkyRide ground demos need equivalent constraints declared in the map file.

**How to apply:** When designing any physical deployment or map file, require `constraint_type` declaration for animated paths. Valid types: `apriltag_corridor`, `magnetic_tape`, `painted_line`, `virtual_fence`. Each requires a corresponding sensor declaration. Reject map files with undeclared animated paths.

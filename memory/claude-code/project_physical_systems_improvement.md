---
name: Physical systems improvement plan
description: Detailed 38-item plan for improving all 4 physical platforms (scale model, 4WD, FullScale, SkyRide) — map convergence, motor abstraction, sensor integration, MQTT hardening, Sally station sovereignty, ezone time-windows, animated guideway constraints, SU→physical validation loop
type: project
---

Comprehensive improvement plan at `readmes/physical-systems-improvement-plan.md` covering 9 categories (A-I), 50 items, prioritized.

**Why:** SU v2 rewrite revealed behavioral gaps between simulation and physical systems. Section I (Device Intelligence) applies Wisdom of the Many to hardware: every processor observes, signals stress/improvement, iterates. Allie harvests device journals, reflects, writes instructions back. Claude Code coaches firmware from device experience.

**How to apply:**
- When working on any physical codebase, check the plan for relevant items
- Priority 1 is A1 (Compute → mapSM.json converter), then I1 (per-device learning journal)
- Section I is the learning architecture: device journal → Allie harvest → reflect → instruct → device applies → cycle
- Safety-critical items (D1 MQTT TLS, D4 offline-safe dispatch) must precede FullScale passengers
- Design rules: all animated paths require declared constraint mechanisms; every processor learns
- Device autonomy levels (I9): earned trust (Level 1→2→3), demotion on fault

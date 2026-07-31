# Allie Reflection — 2026-07-30
*Model: allie:latest | 49s | Generated: 22:00*

---

### Patterns  
- **Systematic migration** of legacy SketchUp plugin code (files in `sketchup/jpods-plugin/`), replacing coupled shims with single‑purpose functions.  
- **Zeroing `desired_z`** and anchoring guideway geometry to `terrain + CLEARANCE_HEIGHT` (4.6 m) in `sketchup/jpods-plugin/guideway_builder.rb`.  
- **Station tests** repeatedly surface a vertical gap at station joins (F‑07), a build blocker that remains unresolved.  
- Bill consistently works toward a clean, domain‑authoritative v2 of the JPods SketchUp plugin, but the stub‑height mismatch keeps surfacing.

### Emerging Lessons  
- The lesson “Rewrite only after fully understanding the code” is solidifying; it explains why blind rewrites failed in TFTS arcs.  
- The memory entry “Reload and restart rule” remains valid; recent work still requires a reload after each migration.  
- The “Domain audit” entry in `readmes/sketchup/jpods-feature-list.md` is now stale because the audit has been completed; it should be marked resolved.

### Cross‑Domain Flags  
- **SketchUp geometry** (stub height at 7.5 m) → **Physical robot behavior**: a vertical discontinuity at station joins may cause pods to “fall” during animation.  
- **MeshMobility topology** → **SketchUp CP design**: station placement decisions affect terrain Z‑anchor calculations.  
- **Writing framing** (JPods pitch language) → **
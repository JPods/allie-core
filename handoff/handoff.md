# Handoff — 2026-06-22 (early AM)

## Where We Stopped

3+circle network model. Build works (old pipeline + shims + Noelle v2).
Populate works (colored pods at ~70% capacity). Vehicles Display page
needs rewrite — missing features from old version.

## What was completed since last handoff

### Build pipeline resolved
- Old build pipeline loaded from codearchive (proven code, no edits)
- `build_shims.rb` fixes PathBuilder namespace + JPodGuideway fallbacks
- `jpod_guideway_compat.rb` changed from module to class (old code uses class)
- `main.rb` old load list removed — boot.rb is sole authority
- NoelleNetworkBuilder.from_json builds geometry → Noelle v2 reads groups → network.json

### Populate fleet implemented
- `JPodGuideway.populate_fleet` in compat shim: reads SallyV2 stations,
  places ~70% capacity at each, colored pods, registered with Sally

### Build v2 attempted then shelved
- `build/build.rb` written (290 lines) — bezier centerline, Z profile,
  beam extrusion, columns, solar. But didn't match old pipeline quality.
- Kept in build/ for reference but not loaded. Old pipeline is authority.
- Scar: don't rewrite code you don't fully understand. Study it first.

### Root cause: main.rb double-loading
- main.rb had its own v3.0 load list that ran AFTER boot.rb v4.0
- Caused "not found" errors for all archived files, double-loaded others
- Fixed: removed old load list from main.rb, boot.rb is sole authority

## Open items for next session

1. **Vehicles Display page rewrite** — study old version from
   `https://github.com/JPods/sketchup/tree/claude_preReWrite_2026-06-21`
   then build clean v2 version. Features: vehicle list, trip assignment,
   random dispatch, camera follow, trip detail panel.

2. **3+circle animation test** — Build works, Populate works, need to
   Start animation and verify pods route correctly through traffic circle.

3. **Build v2 rewrite** — study old pipeline (Plan/PathResolver/BeamExtruder)
   properly, then rewrite without archived dependencies. Current approach
   loads codearchive which defeats the purpose.

4. **Console v2 rewrite** — ~200 references to old modules still in
   jpod_console.rb behind compat shims. Needs proper rewrite.

## Scars from this session

- **Don't rewrite code you don't understand** — study it first, understand
  how it works, THEN rebuild. My v2 Build produced geometry but missed
  bezier connections, Z offset, solar, columns.
- **class vs module** — old JPodGuideway is a class, not a module. Ruby
  can't change one to the other. Check before defining.
- **main.rb had its own load list** — two boot paths = invisible conflicts.
  One authority (boot.rb), one load list, always.
- **PathBuilder namespace** — nested class can't see sibling module.
  Fix with alias in shim, not by editing archived code.

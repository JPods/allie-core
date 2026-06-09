# Handoff — 2026-06-09

## What was accomplished

### 1. Four-layer protection for hand-authored geometry.json tracks
- **Layer 1 — Console gate** (`jpod_console.rb`): UI.messagebox before Generate Geometry JSON on protected templates
- **Layer 2 — notes.md** in each template folder: protected tracks, endpoints, Bezier convention, git restore
- **Layer 3 — CLAUDE.md Axiom 20**: per-template protection map for future Claude Code sessions
- **Layer 4 — Allie memory**: reference_template_geometry_protection.md

### 2. traffic_circle7 Show Formation Tracks fixed
- gw_c_0_1, gw_c_1_2, gw_c_2_3, gw_c_3_0: endpoints corrected to ring arc FIRST/LAST (0mm gaps, 1000mm length each)
- gw_in_0..3, gw_out_0..3: 2-pt diagonals → 13-pt Bezier curves with correct ring-side endpoints
- Root cause: switch-box offset coordinates (~500mm inside ring radius) used instead of arc endpoints

### 3. Axiom 21 + recovery guide
- CLAUDE.md Axiom 21: ring junction endpoints come from arc FIRST/LAST
- `readmes/sketchup/formation-tracks-recovery.md`: full per-template recovery guide with Python recompute script for traffic_circle7

## State of Show Formation Tracks (all 4 templates)

| Template | Status |
|----------|--------|
| traffic_circle7 | Fixed 2026-06-09 — reload and verify |
| JPods_station_parking | Fixed 2026-06-08 — verified working |
| station_thru_dip | Fixed 2026-06-08 — verified working |
| station_line_end | Fixed 2026-06-08 — verified working |

## Next steps

1. Reload su_jpods in SketchUp, open traffic_circle7, run Show Formation Tracks — verify smooth curves and no ribbon crossing
2. Verify station_dip template if it exists
3. Sally chains verification against updated geometry.json coordinates

## Key files changed this session

```
su_jpods/jpod_console.rb                                  — Layer 1 gate
su_jpods/templates/track_formations/*/notes.md            — Layer 2 docs
su_jpods/templates/track_formations/traffic_circle7/geometry.json
Allie/CLAUDE.md                                           — Axioms 20, 21
Allie/readmes/sketchup/formation-tracks-recovery.md       — recovery guide
```

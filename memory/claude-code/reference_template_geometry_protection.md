---
name: Template geometry protection map
description: Per-template protected tracks in geometry.json; which are hand-authored Bezier/arc/Z-corrected and must not be regenerated; protection mechanisms
type: reference
---

Station template geometry.json files contain hand-authored data that auto-extraction
cannot recreate. Three protection layers exist as of 2026-06-09:

1. **Console gate** (`jpod_console.rb`): `generate_geometry_json` shows UI.messagebox
   listing protected tracks before proceeding. User must confirm.
2. **Per-template notes.md**: Each template folder has a notes.md with track table,
   junction coordinates, Bezier convention, and git restore command.
3. **save_geometry() preservation** (`jpod_path_json.rb`): Tracks with >2 pts OR
   `"authored": true` are preserved; only `length_mm` is updated on regeneration.

## Per-template protection map

| Template | Protected tracks | Key concern |
|----------|-----------------|-------------|
| `JPods_station_parking` | gw_platform_in1/in2, gw_lift_in, gw_lift_parking, gw_platform_out1/out2 (12-pt Bezier each) | Series junction gaps must be 0.0mm (EP6, EP7, EP11 are authoritative shared coords); all at Z=5143.9 |
| `station_thru_dip` | gw_lift_in (25-pt), gw_platform_in (17-pt), gw_platform_out (20-pt), gw_uturn_0/1 (7-pt arc) | 3D Z-transition curves; chord direction cannot reproduce; tangents from lines.json topology |
| `station_line_end` | gw_lift_in (22-pt), gw_platform_in (22-pt), gw_uturn_0 (7-pt, authored=true), gw_cp_in_0 (2-pt, authored=true) | Z correction: gw_cp_in_0 + gw_uturn_0 MUST be Z=10242.7 not 8242.7 — model stores them 2m low |
| `traffic_circle7` | None | Flat ring; Generate Geometry JSON is safe |

## Critical Z correction — station_line_end

gw_cp_in_0 and gw_uturn_0 are stored in the model 2000mm below CP operating height.
Correct Z = 10242.7mm. If Show Formation Tracks shows a disconnected ribbon 2m below
the CP, check these tracks and restore Z from git.

## Restore command

```bash
git -C "$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods" \
  checkout HEAD -- templates/track_formations/<template>/geometry.json
```

Full detail: each template's `notes.md`; Axiom 20 in ~/Allie/CLAUDE.md.

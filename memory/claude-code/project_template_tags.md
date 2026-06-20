---
name: Track formation template tag status
description: Which tracks in each of the 5 template models are still on Layer0 and need semantic tags in SketchUp before routing or export works
type: project
---

All 5 template models in `su_jpods/templates/track_formations/` have been audited.
Most tracks are on Layer0 (untagged). Export is now blocked until all are tagged.
Full checklist at `su_jpods/readmes/track-formation-tags.md`.

**Why:** Noelle routes by tag name. Layer0 = no name = unroutable. Noras use length_mm as their odometer — null length means wrong stop position.

**How to apply:** Before any session touching station routing or animation, check whether the validator passes. Run `Create > Validate Template Tags` in SketchUp. If blocked, the checklist below is what remains.

## Status as of 2026-05-16

### station_line_end — 5 tracks need tags
| Length (mm) | Assign tag |
|------------|-----------|
| 20,358.9 | `platform_in_ramp` |
| 4,873.7 | `uturn0` |
| 4,872.9 | `uturn1` |
| 19,905.9 | `track_far_ramp` |
| 21,084.4 | `track_far` |

### JPods_station_parking — 3 tracks need tags (identity unknown, must see in model)
- 63,560 mm → likely `platform_in_ramp`
- 10,130 mm → likely `parking_in` or `uturn`
- 4,870 mm → likely `stub_pair` or `uturn0`

### station_solar — 2 tracks need tags (same geometry as station_parking)
- 63,560 mm → same as station_parking
- 10,130 mm → same as station_parking

### station_thru_dip — 4 tracks need tags + 1 tag name fix
- 63,560 mm × 2 (may be duplicate — verify) → identify in model
- 4,870 mm → identify in model
- 380 mm → verify/delete (likely construction artifact)
- Tag `"platform, in"` (comma-space) must be renamed `platform_in`

### traffic_circle7 — structural rework required, not just tagging
Ring must be split into arc segments per CP before any tag assignment.
This template is blocked until model is rebuilt.

## Enforcement in plugin
`validate_template_tags(model)` loads each model.skp, harvests Track groups,
fails if any are Layer0. `export_feature_jsons` calls it first — blocked on failure.
Menu: Create > Validate Template Tags.

## Length parsing
`parse_length_mm_from_identity(name)` extracts mm from identity strings.
Handles both period and comma decimal separators (European SketchUp locale).
This is the primary length source — more reliable than edge-sum on nested geometry.

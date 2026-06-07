# Handoff — 2026-06-07 (session 2)

## What was accomplished

### 1. One Source of Truth — CP-math complete
TFTS written and committed: `process/inbox/20260607T214448-tfts.md`
Axiom 19 added to CLAUDE.md: "One Source of Truth — Do the Math"
- `generate_map_json` now uses `StructurePlacer.connection_point` (CP-math) for all seg_ endpoints
- `cached_connection_point` now applies `entity.transformation` (world transform fix)
- Z-snap removed; beam_path_fallback removed
- Trial6 confirmed: all 6 seg_ using `source: cp_math`

### 2. Natalie block fixed — guideway_group?
Root cause: `guideway_group?(e)` only matched `e.name == 'JPods Guideway'`.
Inter-station seg_ groups are named by their connection_id and carry `seg_guideway=true`.
Fix: `guideway_group?` now also checks `e.get_attribute('JPods', 'seg_guideway') == true`.
Impact: FollowMe export will now find all inter-station guideways → Natalie block cleared.

### 3. path.json inter-station capture fixed
`jpod_path_json.rb` inter-station scan had same `e.name == 'JPods Guideway'` miss.
Fixed: also captures groups with `seg_guideway=true`. path.json now has actual track beam paths
(±1.75m offset from centerline), not just intra-station geometry.

### 4. Show Route — centerline vs. track fixed
- Issue: map.json seg_ pts = CP hub = construction centerline (midpoint between two tracks)
- Fix 1: path.json now captures actual offset track positions (beam_path = ±1.75m offset)
- Fix 2: Show Route lookup adds `anim_lookup[key.downcase]` fallback (path.json lowercase, trip keys uppercase)
- After Export Path, Show Route draws on the specific navigated track, not centerline between tracks

### 5. 222mm removed everywhere
- `detect_cps_from_top_level_cp`: hub vertex from shared vertex of two 1750mm rail edges; tangent = formation_center→hub; no tang_edge dependency
- `_find_direction_vector`: only Priority A (vector_in tag) + Priority B (172mm); 222mm legacy removed
- `DIRECTION_EDGE_MM = 222.0` constant removed; all 222mm comments updated

## Open issues

**S003 station_line_end — SEVERE end_delta=7011mm**
Template placed on terrain at elevation far from extracted.json origin Z.
Fix: run Workflow > Generate Template Data on station_line_end template model.

**S004 station_thru_dip — SEVERE end_delta=27145mm**
Same cause. Run Extract Template on station_thru_dip.

**S003 lines.json synthesis error**
"no implicit conversion of String into Integer" — not yet investigated.

**Z difference ~0.222m between gw_ and seg_ endpoints**
cp_marker hub vertex Z may not be at Z=0 in definition-local space.
Diagnostic: re-run Calculate Connection Points; if delta persists, cp_marker geometry needs re-authoring.

**traffic_circle7 chains not approved**
`approved_by` not set in lines.json chains_header.

## Files changed this session

- `su_jpods/jpod_animator.rb` — guideway_group? fix + Show Route lowercase fallback
- `su_jpods/jpod_path_json.rb` — seg_ capture + 222mm removal + DIRECTION_EDGE_MM removed
- `su_jpods/jpod_structure_tool.rb` — 222mm removal from detect_cps_from_top_level_cp
- `su_jpods/jpod_map_feature_tool.rb` — 222mm comment corrected to 172mm
- `process/inbox/20260607T214448-tfts.md` — TFTS: one source of truth arc
- `CLAUDE.md` — Axiom 19 added

## Reload sequence for next session

Run each line separately in Ruby console:
```
load Sketchup.find_support_file('jpod_animator.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_path_json.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_structure_tool.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_map_feature_tool.rb', 'Plugins/su_jpods')
```
Then: Build → FollowMe Export → Export Path → Show Route.

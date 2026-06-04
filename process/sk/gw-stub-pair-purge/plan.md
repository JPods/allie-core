# Plan: Purge gw_stub_pair — Canonical CP Naming Throughout
**Written:** 2026-06-03  
**Author:** Claude Code  
**Status:** DRAFT — not yet executed

---

## Goal

Every reference to `gw_stub_pair_*` is eliminated from Ruby code, JSON data files,
and template files. After this purge:

- **CP detection** uses only `cp_marker_*` tags.
- **Inbound track names:** `gw_cp_in_N` (CP stub), `gw_cp_in_lead_N` (lead to ring).
- **Outbound track names:** `gw_cp_out_N` (CP stub), `gw_cp_out_lead_N` (lead from ring).
- **map.json** inter-station segments route directly to `STATION.gw_cp_in_N` — no
  intermediate `gw_stub_pair_N_in` hop.
- **No dual-name wiring** in noelle.rb: one name per CP, no stub_pair→gw_cp_in bridge.

The jumps in animation (NORA_0007 at S002, pods stacking at S004) are caused by
noelle.rb generating map.json with mixed names (`gw_stub_pair_N_in` → `gw_cp_in_N`)
and a 4400mm geometric gap between them. This purge eliminates that gap at its source.

---

## What Currently Exists (Confirmed by Grep, 2026-06-03)

### Two file formats per template — both active

| File | Format | Track names | Who reads it |
|------|--------|-------------|-------------|
| `line.json` | OLD — array of objects | `gw_stub_pair_*` present | `jpod_animator.rb` (color/role), `jpod_structure_tool.rb` (auto-tag) |
| `lines.json` | NEW — dict with gw_cp_in/out keys | Canonical names only | `jpod_path_json.rb`, `noelle.rb`, `jpod_console.rb` |

### Ruby files with gw_stub_pair references

| File | Reference count | Nature of references |
|------|----------------|---------------------|
| `jpod_structure_tool.rb` | ~20 | CP detection: `scan_stub_pair_tips`, `STUB_PAIR_TAG`, proximity-based CP index assignment |
| `noelle.rb` | ~20 | map.json generation: synthesizes `gw_stub_pair_N_in/out` entries; wires them to `gw_cp_in/out_N` |
| `jpod_noelle_bridge.rb` | 3 | stub-tip Z lookup reads `gw_stub_pair_N_out` from path.json |
| `jpod_path_json.rb` | 2 | Special handling branch `if tag_name.start_with?('gw_stub_pair')` |
| `jpod_animator.rb` | 4 | Color coding of gw_stub_pair entities; filter from drive-on tracks |
| `jpod_vehicle_anim.rb` | 2 | Comments only |

### JSON data files with gw_stub_pair

| File | References | Action |
|------|-----------|--------|
| `noelle_features.json` | 4 | Replace `gw_stub_pair_0_in/out` with `gw_cp_in_0/out_0` in `in_cp0`/`out_cp0` sequences |
| `templates/.../line.json` (4 templates) | ~6–10 each | These are the OLD format files. Migrate their useful content into `lines.json`, then retire `line.json`. |
| `templates/.../lines.json` (4 templates) | 0 | Already clean — no action needed on track data |
| `station_test.map.json`, `test_eol_station.map.json` | present | Test fixtures — update or delete |

---

## What `cp_marker_*` Detection Already Does

`jpod_structure_tool.rb` lines 783–784 show `cp_marker_*` is already recognized as a
CP entity type. The purge does NOT require adding new detection logic — it requires
removing the parallel `gw_stub_pair`-based detection paths so only `cp_marker_*` remains.

Current CP detection priority order (to be collapsed to one path):

1. `cp_marker_*` tag on instance inside station (already works)
2. `gw_stub_pair` tag scan with `scan_stub_pair_tips` → **REMOVE**
3. Formation-center proximity fallback → **REMOVE** (fragile, documented DNW)
4. `atan2` sort fallback → **KEEP** as last resort (valid geometric fallback)

---

## Migration Sequence

### Phase 0 — Verify prerequisites (before writing any code)

- [ ] Confirm all 4 template `.skp` models have `cp_marker_*` components placed at all CPs.
  - If any template is missing `cp_marker_*`, Bill places them before Phase 1 starts.
  - Run Console → Proof Lines on each template — any "missing track" or CP detection
    warnings indicate an incomplete template model.
- [ ] Confirm `lines.json` exists for all 4 templates and has `gw_cp_in/out_*` keys.
  - Already verified: station_thru_dip, JPods_station_parking, station_line_end, traffic_circle7.

### Phase 1 — `noelle_features.json` (5 min, low risk)

File: `su_jpods/noelle_features.json`

Replace in every `in_cpN` / `out_cpN` sequence array:
- `"gw_stub_pair_0_in"` → `"gw_cp_in_0"`
- `"gw_stub_pair_0_out"` → `"gw_cp_out_0"`
- `"gw_stub_pair_1_in"` → `"gw_cp_in_1"`
- `"gw_stub_pair_1_out"` → `"gw_cp_out_1"`

These sequences declare the track order a pod follows entering/exiting a station.
After replacement, the declared order matches the actual track names in lines.json.

### Phase 2 — `noelle.rb` inter-station connection generation (biggest change)

File: `su_jpods/noelle.rb`

**Section A — Line ~1392–1470: inter-station segment wiring**

Current code generates map.json inter-station successors pointing to:
```
{ "FROM_SID.gw_stub_pair_FROM_CP_out" => ["seg_..."] }   # predecessors
{ "seg_..." => ["TO_SID.gw_stub_pair_TO_CP_in"] }         # successors
```

Change to:
```
{ "FROM_SID.gw_cp_out_FROM_CP" => ["seg_..."] }
{ "seg_..." => ["TO_SID.gw_cp_in_TO_CP"] }
```

This is the single most impactful change — it eliminates the mixed-name hop in map.json.

**Section B — Lines ~1712–1715: length validation table**

Remove the four `gw_stub_pair_*` entries from the length-range validation hash.
These tracks no longer exist; validating them produces false positives.

**Section C — Lines ~1899–2090: "Synthesize gw_stub_pair" block**

This block synthesizes `gw_stub_pair_N_in/out` map.json entries from CP geometry.
Replace the synthesis role strings:
```ruby
# BEFORE:
role = "gw_stub_pair_#{n}_#{dir_label == 'outbound' ? 'out' : 'in'}"
out_id = "#{sid}.gw_stub_pair_#{n}_out"
in_id  = "#{sid}.gw_stub_pair_#{n}_in"

# AFTER:
role = "gw_cp_#{dir_label == 'outbound' ? 'out' : 'in'}_#{n}"
out_id = "#{sid}.gw_cp_out_#{n}"
in_id  = "#{sid}.gw_cp_in_#{n}"
```

**Section D — Lines ~2468–2586: stub_pair↔gw_cp wiring block**

This block wires `gw_stub_pair_N_in` → `gw_cp_in_M` via tangent dot-product matching.
After Phase 2A–2C, this bridge is unnecessary — the inter-station seg already points
directly to `gw_cp_in_N`. Remove the entire wiring block.

If removing the full block is risky in one pass, guard it with a flag:
```ruby
LEGACY_STUB_PAIR_WIRING = false   # set true only for debugging
```
Then delete after confirming Build produces clean map.json.

### Phase 3 — `jpod_structure_tool.rb` CP detection cleanup

File: `su_jpods/jpod_structure_tool.rb`

**3A. Remove `STUB_PAIR_TAG` constant and `scan_stub_pair_tips` method**
- `STUB_PAIR_TAG = "gw_stub_pair"` (~line 202) — delete
- `scan_stub_pair_tips(...)` (~lines 532–577) — delete the method

**3B. Simplify `pair_stubs` method (~line 1527)**
`pair_stubs` returns CP geometry from gw_stub_pair scans. After purge, CP geometry
comes exclusively from `cp_marker_*` detection. Gut `pair_stubs` to return `[]`
immediately (it becomes a no-op shim, then can be removed in a follow-up).

**3C. CP index assignment (~lines 590–948)**
The block that assigns CP indices by proximity to `gw_stub_pair_N_in` bounding boxes
is replaced by assignment directly from `cp_marker_*` instance tags (the `_N` suffix
in `cp_marker_N` IS the index). Read the index from the tag, not from proximity to
a gw_stub_pair group.

**3D. Remove gw_stub_pair diagnostic messages**
Lines 1707, 1871, 1883, 1978–1996, 2631, 2633: update error messages to reference
`cp_marker_*` instead of `gw_stub_pair`.

**3E. Warn on detection source (~line 1137)**
Current code prints a WARN if CP detection used something other than gw_stub_pair.
After purge, the WARN condition flips: warn if cp_marker_* is NOT the detection source.

### Phase 4 — `jpod_path_json.rb` export cleanup

File: `su_jpods/jpod_path_json.rb`

**Line 611:** Special case for `tag_name.start_with?('gw_stub_pair')` — remove this
branch. All inbound track geometry now comes from `gw_cp_in_*` entries in lines.json.

**Line 801:** Comment says gw_stub_pair is included in vehicle travel tracks —
update comment to reflect gw_cp_in_N/gw_cp_out_N are the CP interface tracks.

### Phase 5 — `jpod_noelle_bridge.rb` stub-tip Z lookup

File: `su_jpods/jpod_noelle_bridge.rb`

**Lines 129–137:** Departure Z lookup reads `gw_stub_pair_N_out` outer endpoint Z
from path.json to set the inter-station segment departure height.

Change the filter from:
```ruby
next unless lid =~ /gw_stub_pair_\d+_out$/
```
to:
```ruby
next unless lid =~ /gw_cp_out_\d+$/
```

After this change, departure Z is read from `gw_cp_out_N` — which is the actual
CP stub track at the correct height.

### Phase 6 — `jpod_animator.rb` color coding and filter

File: `su_jpods/jpod_animator.rb`

**Line 253:** Color-coding comment references gw_stub_pair — update to gw_cp_in/out.

**Lines 450–459:** Yields world_pt/material for each gw_stub_pair entity.
After purge, this yield block is unused (no code uses gw_stub_pair for coloring).
Remove or redirect to gw_cp_in/gw_cp_out entity scanning.

**Lines 2005–2017:** Filter excludes gw_stub_pair from drive-on tracks:
```ruby
return false if n.start_with?("gw_stub_pair")
return false if tag.start_with?("gw_stub_pair")
```
Replace with:
```ruby
# gw_cp_in_N and gw_cp_out_N are CP stubs — not drive-on tracks
return false if n =~ /\Agw_cp_(in|out)_\d+\z/
return false if tag =~ /\Agw_cp_(in|out)_\d+\z/
```
Note: `gw_cp_in_lead_N` and `gw_cp_out_lead_N` ARE drive-on tracks — they connect
the ring to the CP stub. Only the digit-suffix stubs are excluded.

### Phase 7 — `line.json` → retire

The old-format `line.json` files are read for two purposes:
1. `jpod_animator.rb` line 4031: layer→role color mapping
2. `jpod_structure_tool.rb` line 2075: auto-tagging tracks by length

After purge, both purposes must migrate to `lines.json`:

**For animator color mapping:** `lines.json` already has every track with its name,
which encodes role (gw_cp_in = inbound, gw_cp_out = outbound, gw_uturn = turn, etc.).
The animator can derive color from track name pattern without needing a separate file:
- `gw_cp_in_*` or `gw_cp_in_lead_*` → RED (inbound)
- `gw_cp_out_*` or `gw_cp_out_lead_*` → BLUE (outbound)
- `gw_uturn_*` → PURPLE (turn)
- `gw_platform_*` → ORANGE (platform)
- `gw_*_main` or `gw_near_main*` → GRAY (main ring)

This is simpler than parsing `line.json` arrays. Update `line_json_roles` to read
from `lines.json` dict keys and derive role from name pattern.

**For auto-tagging by length:** `lines.json` has `length_mm` per track. The auto-tag
function can build its `length → tag` map from `lines.json` instead of `line.json`.
Update `jpod_structure_tool.rb` line 2075 to open `lines.json` instead.

Once both callers are migrated, `line.json` files are no longer read. Rename to
`line.json.retired` to confirm nothing breaks, then delete.

### Phase 8 — Template model verification (Bill's task)

After code changes, for each station template `.skp`:
1. Open template in SketchUp.
2. Console → Workflow → Generate Formation Map (overwrites if needed).
3. Console → Populate Template Geometry — should report direction corrections for
   `gw_cp_in_*` / `gw_cp_out_*` tracks if 222mm direction edges are in place.
4. Console → Proof Lines — all tracks should pass.
5. Close template.

### Phase 9 — Build + verify

1. Open animation test model (`animation2.skp`).
2. Extensions → JPods → Create → Build.
3. Inspect generated `animation2.map.json`:
   - `seg_*` entries should have successors pointing to `STATION.gw_cp_in_N`.
   - No `gw_stub_pair` keys anywhere in the file.
4. Console → Proof Lines — confirm no SEVERE status.
5. Animate — confirm no jumps, no instant completions.

---

## Risk Register

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Template missing `cp_marker_*` — Phase 3 returns 0 CPs | Medium | Phase 0 check; Build will abort with explicit error |
| `gw_cp_out_N` Z lookup returns nil (track absent from path.json) | Low | noelle_bridge already has nil guard; add explicit log |
| `gw_cp_in_N`/`gw_cp_out_N` filter excludes lead tracks incorrectly | Low | Regex `\Agw_cp_(in\|out)_\d+\z` matches only digit-suffix stubs, not leads |
| Wiring block removal breaks a template that ALSO uses old names in its `.skp` | Medium | Phase 0 model audit; if any .skp still has gw_stub_pair geometry, retag before proceeding |
| `line.json` read by code not found in grep | Low | Rename to `.retired` first, reload plugin, confirm no errors before deleting |

---

## What Does NOT Change

- `lines.json` track data — already canonical, no edits needed
- `gw_cp_in_lead_N`, `gw_cp_out_lead_N` — stay exactly as named
- `gw_uturn_N`, `gw_near_main`, `gw_far_main`, `gw_platform_*` — stay unchanged
- `jpod_vehicle_anim.rb` routing logic — comments updated, no functional change needed
  after noelle.rb generates clean map.json
- `jpod_path_json.rb` CCW direction correction — stays; it works on `gw_cp_in_*` names
- `jpod_sally.rb` — already uses `gw_cp_in_N` / `gw_cp_out_N` exclusively; no change

---

## Execution Order (Recommended)

```
Phase 0  → Bill: verify cp_marker_* in all template .skp files
Phase 1  → noelle_features.json (5 min, no code)
Phase 7  → line.json migration (animator + auto-tag callers)
Phase 2  → noelle.rb (biggest; do in one sitting; test with Build immediately after)
Phase 3  → jpod_structure_tool.rb (CP detection cleanup)
Phase 4  → jpod_path_json.rb (2 small edits)
Phase 5  → jpod_noelle_bridge.rb (1 filter line)
Phase 6  → jpod_animator.rb (color filter update)
Phase 8  → Bill: template model verification
Phase 9  → Build + animate + verify
```

Phases 1 and 7 are independent and can be done before Phase 0 completes.
Phases 3–6 are independent of each other; do after Phase 2.
Phase 9 cannot start until all prior phases are complete.

---

## Definition of Done

- `grep -r "gw_stub_pair" su_jpods/*.rb` returns zero matches.
- `grep -r "gw_stub_pair" su_jpods/noelle_features.json` returns zero matches.
- Build on animation test model produces `animation2.map.json` with zero `gw_stub_pair` keys.
- Animation runs: no jumps, no instant maneuver completions, no pods stacking at S004.
- Proof Lines passes for all 4 station templates.

# Handoff — 2026-06-06

## Where We Stopped

Working through the template data pipeline. traffic_circle7 extracted and Proof clean (4 OK, 20 WARN, 0 SEVERE). The other 3 templates need Extract Template + Proof run with the same fixes now in place.

## What Was Completed This Session

### 1. Permanent Segment ID Registry (noelle.rb)
- `{model}.segment_registry.json` alongside `.skp`
- IDs increment only upward; retired segments get `retired_at`, never reassigned
- Map schema v4 — `id` field on every line entry
- jpod_vehicle_anim.rb comments updated for v4

### 2. Proof Lines — 3 Major Fixes (jpod_path_json.rb)

**Template-model scope:**
- `populate_from_open_template` sets `@active_template_formation`
- `proof_lines` reads it; shows ONLY that template (other stations excluded)
- Label: `traffic_circle7 (to_be_assigned)` — no S-prefix until placed in network
- Summary line uses formation name, not station_id

**bbox sanity check — Priority 1.5 (Extract) and Priority 2 (Scanner):**
- Extract Priority 1.5: rejects edge_trace when `traced_len < bbox_diag * 0.6`
  - Eliminates cross-section noise (gw_in_*/gw_c_* at ~1232mm vs ~9539mm diagonal)
  - Accepts gw_cp_in_* (ratio ~1.0)
- Scanner Priority 2: same lower bound + upper `> bbox_diag * 2.0` rejects solid perimeter traversal
  - gw_uturn was 56pts/25173mm (solid perimeter walk); now falls to Priority 3 bbox → 2pts

**min-delta endpoint comparison:**
- `delta = min(dist(dec_ep, fnd_ep), dist(dec_ep, fnd_sp))`
- Scanner has no direction guarantee; position verified regardless of order
- `↺` flag when scanner direction reversed (informational only — animation uses extracted.json)

**Synthetic arc handling:**
- `radius_mm > 0 && pts > 2` → ARC status, not SEVERE
- gw_uturn_* correctly classified as ARC

### 3. Results — traffic_circle7

```
SUMMARY: 4 OK | 20 WARN | 0 SEVERE | 0 ARC
```
- 4 OK: gw_cp_in_0/1/2/3 (3pts, 2672mm, edge_trace, direction corrected via vector_in)
- 20 WARN: ↺ scanner-direction noise + small endpoint deltas (≤313mm) — not blocking

## What Needs to Be Done Next

### Immediate: Extract remaining 3 templates
Each: open template model → [3] Extract Template → [5] Proof Lines

1. **JPods_station_parking** — `templates/track_formations/JPods_station_parking/model.skp`
   - gw_lift_parking had 898mm SEVERE from network scan; Extract may fix it
   - gw_cp_in_* will gain 3rd pt once extracted with Priority 1.5

2. **station_thru_dip** — `templates/track_formations/station_thru_dip/model.skp`

3. **station_line_end** — `templates/track_formations/station_line_end/model.skp`

### After all 4 templates extracted:
4. [2] Lines Build from Template on each (sync declared lengths)
5. Open network → Noelle Build → writes map.json with permanent IDs (first registry)
6. Animate → verify S002→S003 trip

## Open Known Issues

- **gw_uturn ARC**: 13-pt synthetic arc at 4699mm; ARC status suppresses SEVERE. Functionally acceptable for animation.
- **↺ direction warnings**: scanner-side only. extracted.json is correctly directed. Not blocking.
- **gw_lift_parking S002**: 898mm SEVERE from network scan — will re-check after Extract Template on JPods_station_parking.

## Reload Commands

```
load Sketchup.find_support_file('jpod_path_json.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('noelle.rb', 'Plugins/su_jpods')
```

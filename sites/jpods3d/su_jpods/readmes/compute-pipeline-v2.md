# Compute Pipeline v2 — Architecture

## Principle

One button. Three phases. Math only. No edge walking. No hand-authored chains.
The designer owns the topology. The agents derive the behavior. Compute connects
them through math. If something can't be computed, reject the model — don't degrade.

---

## The Three Phases

### Phase 1: Validate (ComputeValidator)

**Input:** `lines.json` designer section
**Output:** accept or reject with specific defect list

Checks:
- `designer.tracks` — every gw_ tag must exist with `successors` array
- `designer.cps` — at least one EP with type/in/out
- Successor graph must be connected — every track reachable from at least one CP
- No orphan tracks (declared but unreachable)
- No missing successors (referenced but not declared)

Reject message:
```
🚫 Compute REJECTED — station_line_end/lines.json:
   • gw_platform_in: successor 'gw_platform_parking' not declared in designer.tracks
   Fix the topology and run Compute again.
```

### Phase 2: Build Chains (ComputeChainBuilder)

**Input:** validated designer topology (tracks + successors + CPs)
**Output:** natalie section populated with computed chains

For each CP N:
1. **Landing chain:** BFS from `gw_cp_in_N` → follow successors → stop at `gw_platform`
2. **Exit chain:** BFS from `gw_platform` → follow successors → stop at `gw_cp_out_N`
3. **Originating chain:** same as exit with `clip_start: true`

Global:
4. **Parking chain:** `[gw_platform]`
5. **Hold loop:** BFS from `gw_platform` → follow successors → stop at `gw_platform_parking`, append `gw_platform`

Traffic circles:
- **Pass chains:** BFS from `gw_cp_in_N` → ring CCW → stop at `gw_cp_out_M` for each N→M pair

If any chain can't be built (BFS fails), report which CP and which start→end
failed. The designer fixes the successors, not the chain.

### Phase 3: Extract Geometry (ComputeGeometry)

**Input:** validated topology + computed chains + SketchUp model entities
**Output:** `lines.computed.json` with pts_mm for every track

Priority chain (from most authoritative to least):
1. **CP marker synthesis** — gw_uturn arcs from cp_marker geometry
2. **CP marker hub math** — gw_cp_in/out straight tracks from marker position
3. **Chain-walk** — compute endpoints from predecessor's last pt / successor's first pt.
   Generate bezier with smoothstep Z for curves. Loop until all tracks resolved or no progress.
4. **Previous computed** — carry forward from prior lines.computed.json if above fails

The chain-walk loops:
```
pass = 0
loop do
  pass += 1
  resolved = 0
  tracks_needing_geometry.each do |tag|
    pred_pts = tracks[predecessor_of(tag)]&.pts_mm
    succ_pts = tracks[successor_of(tag)]&.pts_mm
    next unless pred_pts && succ_pts
    tracks[tag] = compute_from_neighbors(pred_pts.last, succ_pts.first)
    resolved += 1
  end
  break if resolved == 0  # no progress — remaining tracks are defective
  puts "[Compute] pass #{pass}: #{resolved} track(s) resolved"
end
```

---

## File Structure

```
su_jpods/
  compute/
    compute_validator.rb    — Phase 1
    compute_chain_builder.rb — Phase 2
    compute_geometry.rb     — Phase 3
    compute_writer.rb       — writes lines.computed.json
    compute.rb              — orchestrator (one button)
```

Each file is a module under `JPods::Compute`. Each has one public method.
The orchestrator calls them in sequence.

```ruby
module JPods
  module Compute
    def self.run(model)
      template_data = load_lines_json(model)

      # Phase 1
      defects = Validator.check(template_data)
      return report_defects(defects) if defects.any?

      # Phase 2
      chains = ChainBuilder.build(template_data)
      return report_chain_failures(chains) if chains[:failures].any?
      template_data['natalie'].merge!(chains[:natalie])

      # Phase 3
      geometry = Geometry.extract(model, template_data, chains)
      return report_geometry_failures(geometry) if geometry[:failures].any?

      # Write
      Writer.write(model, template_data, geometry)
    end
  end
end
```

---

## What Carries Forward

From the current codebase:
- Design axioms 1–22 (all proven, all documented)
- lines.json v5 schema (designer + agent sections)
- CP marker synthesis math (Priority 0 — works correctly)
- Traffic circle synthesis (`_synthesize_traffic_circle_tracks`)
- Bezier generation from tangents (Priority A)
- Smoothstep Z transition (chain-walk)
- Direction normalization by successor chain
- The 3+circle test case with known defects

What is NOT carried forward:
- Edge walker (`_walk_edge_vertices`)
- Authored flag
- jpods_path entity attribute as geometry source
- Cap-face centroid clustering
- Any geometry derived from scanning 3D edges

---

## Test Case: 3+circle

The proof-of-concept network has known defects that the new pipeline must handle:

| Station | Template | Known Defect |
|---------|----------|-------------|
| S001 | traffic_circle7 | Missing landing chains CP1/2/3 (Phase 2 should compute them) |
| S002 | station_parking | Missing departure chain CP1 (Phase 2) |
| S003 | station_thru_dip | Working — baseline |
| S004 | station_line_end | `__stale` definition name; gw_platform_in geometry gap |
| S005 | station_line_end | Same as S004 |

Success = all stations compute clean, all pods route to all stations, animation runs
with correct Z, correct direction, no jumps.

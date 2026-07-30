# Phase 3: Geometry Extraction

## Purpose

Compute the vehicle-path geometry (pts_mm) for every track using math.
No edge walking. No entity attributes. Start from known points (CP markers),
walk the chains, compute each track's endpoints from its neighbors.

## Algorithm

### Input

- Validated designer topology (Phase 1)
- Computed chains (Phase 2)
- CP marker positions from SketchUp model entities
- Previous lines.computed.json (carry-forward safety net)

### Priority Chain

| Priority | Source | What it handles |
|----------|--------|----------------|
| 0 | CP marker arc synthesis | gw_uturn arcs — math from marker geometry |
| 0.25 | CP marker hub math | gw_cp_in/out — 2-pt straight from marker position |
| 1 | **Chain-walk** | **Everything else — the standard approach** |
| 2 | Previous lines.computed.json | Safety net — shouldn't be needed |

### Chain-Walk Algorithm

The standard approach. Walk the successor chain from known endpoints.

**Known points:** CP marker hub gives `gw_cp_in_N` and `gw_cp_out_N` endpoints.
After Priority 0 and 0.25, these tracks have geometry. Their endpoints anchor
the chain-walk.

**Walk:** For each track without geometry:
- Predecessor's last pt = this track's start pt
- Successor's first pt = this track's end pt
- If both available: compute bezier between them

**Loop:** Some tracks can't be resolved on the first pass because their
neighbors aren't resolved yet. Loop until no more progress:

```
pass = 0
loop do
  pass += 1
  resolved_this_pass = 0
  unresolved.each do |tag|
    pred_end = tracks[predecessor(tag)]&.pts_mm&.last
    succ_start = tracks[successor(tag)]&.pts_mm&.first
    next unless pred_end && succ_start
    tracks[tag] = generate_bezier(pred_end, succ_start, tag)
    resolved_this_pass += 1
  end
  break if resolved_this_pass == 0
  puts "[Compute] pass #{pass}: #{resolved_this_pass} track(s) resolved"
end
```

### Bezier Generation

For curved tracks (Z transition, approach curves):
- **Smoothstep Z:** `z(t) = z_start + (z_end - z_start) * t² * (3 - 2t)`
- **XY linear:** `x(t) = x_start + (x_end - x_start) * t`
- **Point spacing:** ~1000mm (Axiom 17)
- **Minimum 4 pts** for any curve

For straight tracks:
- 2 pts: start, end

### Direction

Every track's pts flow in the successor direction:
- `pts[0]` = entry end (where predecessor connects)
- `pts[-1]` = exit end (where successor connects)

Direction is NOT computed from geometry. It's declared by the successor graph.
The chain-walk guarantees correct direction because `start = predecessor's end`.

### Frame of Reference

All pts_mm are in formation-local coordinates (Axiom 18):
- Origin = formation component origin in the template model
- Z = vehicle-path Z (beam center, not beam top)

The network Build applies the station instance transform to reach world coordinates.

### Failure Handling

After all passes, if any track still has no geometry:

```
[Compute] 🚫 gw_lift: no geometry after 3 passes
   Predecessor gw_cp_in_lead_0 has geometry ✓
   Successor gw_lift_parking has no geometry ✗ — blocked
   Chain: gw_cp_in_lead_0 → [gw_lift_in] → gw_lift → gw_lift_parking → gw_lift
   Check: is gw_lift_in resolved? Does gw_lift connect to gw_lift_parking?
```

Specific enough for the designer to diagnose.

## Output

`lines.computed.json` with:
- `geometry.tracks` — `{ tag → { pts_mm: [[x,y,z], ...], length_mm: N, radius_mm: N } }`
- `geometry.cp_markers` — CP positions in formation-local mm
- All pts in formation-local coordinates
- All directions aligned with successor graph

# Handoff — 2026-05-31

## What Was Done This Session

### Sally chain system — discovered_chains added to all 6 templates — COMPLETE

All template `lines.json` files now have `chains_header` and `discovered_chains` in the
numbered `[pos, "track"]` pair format. CCW ordering follows CP-unit grouping:
out_lead → uturn → out_stub → in_stub → in_lead as a unit, then interior tracks, then CP1 group.

| Template | Tracks | Notes |
|---|---|---|
| `cpu` | 5 | CP-unit positions 1–5 |
| `cps` | 2 | Positions 1–2 of traffic_circle CP pair |
| `JPods_station_parking` | 19 | gw_lift_parking removed (not in model); EP7+EP8 collapsed to EP7; eps renumbered |
| `station_line_end` | 14 | Two errors in Bill's draft corrected: gap at pos 6 closed, gw_far_out→gw_far_ramp_out |
| `station_thru_dip` | 19 | EP5 diverge added (gw_cp_in_lead_0 → {gw_near_main_1, gw_lift_in}); landing chains updated |
| `traffic_circle7` | 24 | BFS ordering; all 16 pass_chains computed by Sally DFS |

### Console sidebar — COMPLETE (this session's prior context)
- Stations task group nested under Models category
- Model info panel in right frame (shows template/formation/chains approval when Models task selected)
- numbered [pos, track] pairs in discovered_chains display

### Pushed to GitHub
Branch: `su_jpods_claude` at JPods/sketchup.git
5 commits pushed: a8c0535 → 7be92b2

## State of Each Template

### chains_header.approved_by status
All 6 templates: `approved_by: ""` — chains not yet approved.
Bill must review and set `approved_by` before Noelle will allow Build on those templates.

### Landing/exit chains
**Not yet authored** for station_parking, station_line_end, station_thru_dip.
These require Bill to define which track sequences a vehicle follows when:
- entering the station (landing_chains)
- departing the station (exit_chains)

cpu and cps are component templates — no landing/exit chains (wired by Noelle at Build time).
traffic_circle7 uses pass_chains (already complete).

## Open Tasks (Priority Order)

1. **Author landing/exit chains** for station_parking, station_line_end, station_thru_dip
   — Bill defines the paths; Claude Code writes them into lines.json
2. **Set chains_header.approved_by** on each template once chains are verified
3. **Noelle pass_chains processing**: pass_chains not yet handled in feature.json generation
   (chain_mm/chain_switches for traffic circles)
4. **Sally draft_chains CCW ordering**: currently generates BFS backward order, not CP-unit grouping.
   Should match Bill's CP-unit pattern (fix jpod_sally.rb)
5. **traffic_circle7**: verify gw_cp_in direction is correct in SketchUp (noted in prior session —
   scan had it reversed; manual check recommended)

## Key Decisions Made This Session

- Numbered pair format `[pos, "track"]` confirmed correct JSON (Bill initially used `{1, "track"}`)
- CCW = CP-unit grouping, not BFS traversal — established by Bill's descriptions
- `alpha` key (not `alphabetical`) — established this session
- gw_lift_parking: confirmed not in station_parking model; removed from lines{} and eps[]
- station_line_end has no intentional gaps — all were authoring errors; corrected to contiguous 1–14

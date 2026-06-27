# Handoff — 2026-06-26

## Where We Left Off

Compute geometry extraction rewritten — removed the lines.computed.json cache that prevented model changes from flowing through. Extraction now reads cp_markers from model.skp (pure math, no edges, no stubs) and resolves all tracks via span-based chain resolution. Station_line_end computed clean with cp_marker_1 added at platform end. SLOPPY gaps resolved — all track connections within tolerance. Natalie given a fleet registry. Sally Dashboard replaced with defect.json logging system and toolbar buttons (Flag Defect, Show Defects, Validate Sally). Rule 24 established: animation is sacred — nothing degrades the tick. HF dispatch turned off — animation is good enough for now.

## Do This First Next Session

1. **Clear s009 ghost pods** — 15 pod records in Sally's pods[] with only 2-3 slots occupied. Run Validate Sally button or flush manually. The saved Sally state restores ghosts on restart — investigate `_restore_sally_state` for the source of ghost accumulation.
2. **Test station_parking Compute** — station_parking was NOT recomputed this session. Run Compute on it with cp_markers. The span resolver splits evenly — station_parking's split points (gw_platform vs gw_platform_parking vs gw_platform_in) need correct proportions, not equal division. May need junction markers or ratios in lines.json.
3. **Commit all changes** — build.rb, compute_geometry.rb, sally_station.rb, natalie.rb, animation.rb, jpod_log.rb, jpod_console.rb, console.html, CLAUDE.md, cpb/lines.json. Large changeset, should be committed.
4. **Run station_line_end through Build → Animate** on West Point to verify the new Compute output produces correct animation with no SLOPPY warnings.
5. **Test defect.json system** — Flag a defect, run Validate Sally, check Show Defects output. Verify file writes don't violate Rule 24 during animation.

## Open Problems

- **Span resolver splits evenly** — tracks in a span get equal portions of the bezier. Wrong for tracks with very different lengths (gw_platform 7.7m vs gw_platform_in 20.8m). Needs junction position data.
- **Ghost pod accumulation** — `_restore_sally_state` reloads pod records from saved state but entity references go stale. New arrivals create duplicates. Root cause not yet fixed.
- **Stuck pod at ps_max** — a pod can become invisible to dispatch if it falls out of `@@dwelling`. Dwelling re-add in conveyor is a band-aid. Need to understand how pods lose dwelling status.
- **Entity name/tag corruption during animation** (ouch-list CRITICAL) — still unresolved.
- **Hold loop BFS depends on track naming** — should be pure topology.
- **Kink defects on seg_S005_3_S010_1** — still unresolved.

## What Was Decided (and Why)

- **Removed lines.computed.json cache from Compute** — the cache prevented model geometry fixes from flowing through. Every Compute now re-extracts from cp_markers. If extraction fails, fix the model, don't paper over it.
- **No edges, only math** — cp_markers are the only geometry source. Tracks are computed as parallel bezier curves 3500mm apart from cp_marker hub/tip positions. No SketchUp edge reading.
- **No stubs** — CP stubs were a failed effort. Removed all references. cp_marker_N is the sole authority.
- **Sally Dashboard removed** — JS polling via setInterval degraded animation. Replaced with defect.json (append-only log) + on-demand buttons (Validate Sally, Flag Defect, Show Defects, Dump station).
- **Rule 24: Animation is sacred** — refuse features that degrade the tick. Buffer diagnostics to RAM, flush to disk later. JS is passive during animation — Ruby pushes, JS renders.
- **Natalie gets a fleet registry** — `NatalieV2.fleet` tracks every pod entity and its physical position. Cross-checks Sally's records. Catches orphans and ghosts.
- **Sally validate!** — bidirectional ps[] ↔ pods[] consistency check. Purges ghost records, orphan slots. Runs on demand, never on the animation tick.
- **`has_capacity?` replaces `!full?` at arrival gate** — includes inbound pod count so pods loop when station is effectively full, not just slot-full.

## Files Changed This Session

- `compute/compute_geometry.rb` — complete rewrite: removed cache, pure math from cp_markers, span-based chain resolution, recursive cp_marker scanner
- `build/build.rb` — fixed segment count display (was counting fwd+reverse duplicates)
- `sally/sally_station.rb` — added validate! (bidirectional purge) and snapshot methods
- `sally/sally.rb` — unchanged but validate! added to Station class
- `natalie/natalie.rb` — added fleet registry (PodStatus, scan_fleet, pod_position, fleet_desyncs, update_pod)
- `animation/animation.rb` — NatalieV2.scan_fleet on init, has_capacity? gate, dwelling re-add in conveyor, removed per-tick validate (Rule 24)
- `jpod_log.rb` — added defect logging (defect, flag, defects methods) with dt/local/model_time
- `jpod_console.rb` — added callbacks: cmd_flag_defect, cmd_show_defects, cmd_validate_sally, cmd_dump_station, cmd_report_stuck
- `dialogs/console.html` — removed Sally Dashboard panel+timer, added Flag Defect/Show Defects/Validate Sally toolbar, added appendResult function, added Dump button per station
- `templates/track_formations/cpb/lines.json` — new, so cpb shows in model list
- `templates/track_formations/station_line_end/model.skp` — cp_marker_1 added, gap fixes
- `templates/track_formations/station_line_end/lines.computed.json` — regenerated from new Compute
- `CLAUDE.md` — added Rule 24 (animation is sacred)

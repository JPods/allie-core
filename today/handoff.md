# Handoff — 2026-06-28

## Where We Left Off

All 4 station models approved (station_parking, station_line_end, station_thru_dip, traffic_circle7). Compute cp_marker geometry rewritten to pure math — no edges, definition-local coords, cross product for outbound/inbound, tracks extend inward from tip. NC_Asheville_4 network editing in progress — s014 needs reconnection. Populate % selector added (40/20/10%). Bill is preparing a video demo.

## Do This First Next Session

1. **Fix Compute span resolver diverges** — `succ_of` takes only the first successor at diverge points, leaving platform tracks unresolved. All platform stations affected. DO NOT click Compute on approved models until fixed. File: `compute/compute_geometry.rb` `_resolve_spans`.
2. **Add Compute confirmation gate** — Compute button overwrites approved lines.computed.json with no warning. Add a confirmation dialog when `approved_at` is set. File: `jpod_console.rb` `cmd_compute_template`.
3. **Test animation start/stop** — Extensions > JPods > Animation menu, toolbar toggle. Bill reports toolbar toggle is sluggish. File: `main.rb`, `jpod_animator.rb`.
4. **JPods Travel improvements** — User Position camera needs "Ready" button before animation starts. Trip selection needs back-navigation. Trip details page should be collapsible div. File: `ui/trip/index.html`.
5. **Test Shift-click CP delete** — format mismatch fixed (`s014.0` vs `S014_cp0`) but untested in the field. File: `tools/connect_tool.rb`.

## Open Problems

- Span resolver can't handle diverges — 8 platform tracks unresolved in station_parking, 6 in station_thru_dip, 3 lift tracks in station_line_end
- Compute overwrites approved files with no guard — known-good lines.computed.json must be restored from git after accidental Compute
- Save Network button reads from disk + Noelle validates — but iframe sync at Build time can still overwrite (morning merge fix in place but fragile)
- NC_Asheville_4 has old s014 connections that need cleanup after station was moved
- Allie MCP returns empty responses intermittently — ollama running but ask_allie gives no output

## What Was Decided (and Why)

- **Compute is MODEL ONLY, Build is NETWORK ONLY** — documented as top-level rule in both CLAUDE.md files. Confusing these scopes caused every cp_marker bug this session (180° rotations, 4.3m offsets).
- **cp_marker: pure math from 4 points, no edges** — hub + 222mm direction + two 1750mm tips. Cross product of 222mm × tip_offset gives outbound/inbound. Tangent from hub-to-hub axis, not 222mm. 10-attempt TFTS arc documented.
- **All tracks extend INWARD from cp_marker tip** — tip is outermost dangling end. gw_cp_in/out = 2500mm inward, junction (uturn) = 2500mm in, lead = 2500mm more. Previous code extended outward past the tip.
- **One-way CCW (Rule 12)** — all guideways one-way, station circulation CCW. in/out swaps between CPs by design. Pass chains in lines.json are authoritative.
- **Predecessors on every track** — all 4 template lines.json now have both successors and predecessors for every gw_ track. Predecessors enable merge-point validation.
- **Sally parks only on gw_platform** — gw_platform_parking is approach track, not parking surface. sally.rb regex changed from `gw_platform(?:_parking)?` to `gw_platform\z`.
- **Populate default 40%** — was 70%, too dense for demos. Dropdown selector: 40/20/10%, minimum 1 per station.

## Files Changed This Session

- `su_jpods/compute/compute_geometry.rb` — cp_marker pure math rewrite (definition-local, cross product, inward layout)
- `su_jpods/compute/compute_writer.rb` — approved_at, test_results, source_files fields
- `su_jpods/jpod_console.rb` — Save Network, Approve button, refresh callback, populate %, station list, merge-not-replace sync
- `su_jpods/dialogs/console.html` — Save Network button, Approve button with visual feedback, populate % dropdown, Team Review checkbox
- `su_jpods/tools/connect_tool.rb` — Shift-click format fix (s014.0 vs S014_cp0), draft_connections accessor
- `su_jpods/sally/sally.rb` — park only on gw_platform
- `su_jpods/station_tests.rb` — stamp_test_pass, check_approval, has_platform test selection
- `su_jpods/noelle_v2/noelle_v2.rb` — eff_xf investigation (reverted)
- `su_jpods/jpod_guideway_compat.rb` — populate_pct configurable
- `su_jpods/animation/animation.rb` — random dispatch (sample not min_by), shuffle overflow neighbors
- `su_jpods/CLAUDE.md` — Rule 12 (CCW), Model vs Network boundary, cp_marker geometry, track layout
- `su_jpods/readmes/principles.md` — cp_marker section with diagram
- All 4 template `lines.json` — predecessors added to every track
- `Allie/CLAUDE.md` — Model vs Network, cp_marker, Rule 12, one-way CCW
- `Allie/process/inbox/20260628T173500-tfts.md` — NoEdgesPureMath TFTS (10-attempt arc)

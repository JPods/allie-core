# Handoff — 2026-06-17

## Status: traffic_circle7 Transit Test PASSING — station_parking Shuffle/Departure PENDING

---

## What Was Built This Session

### Three transit_test bugs fixed (traffic_circle7)

**Run button inert (console.html):**
`JSON.stringify(formation)` in the onclick attribute embedded double quotes inside a
double-quoted HTML attribute — browser parser ended the attribute at the first inner `"`.
Fix: use single-quoted JS string literals: `` `onclick="runStationTest('${formation}', '${t.id}')"` ``

**Vehicles moving CW instead of CCW (jpod_vehicle_anim.rb):**
pass_chains list track names in CCW traversal order, but some tracks have their `pts_mm`
stored in the opposite direction (e.g. `gw_c_1_1` pts go right→left but CCW traversal
goes left→right). The transit intercept was blindly concatenating pts in stored order.
Fix: before appending each track's pts, compare `last.distance(tk_pts.first)` vs
`last.distance(tk_pts.last)`; reverse if the last pt is closer. All 4 CCW routes
now stitch geometrically correct.

**Vehicles not following Show Track lines (jpod_console.rb):**
`show_track_overlay` searches for the formation entity as `ComponentInstance OR Group`
with a Pass 2 fallback (gw_*-tagged children scan). The console's `template_lookup`
builder only searched `ComponentInstance` with no Pass 2. If the formation is a Group,
the console used identity transform while Show Tracks used the real transform → mismatch.
Fix: brought console search into parity — checks both types, adds identical Pass 2 fallback.

**model.network.json created by Build on template (noelle.rb):**
`generate_network_json` was called on every Build/Validate with no template guard.
Fix: return early if `model.path.include?('track_formations')`.

---

## Current Template Status

| Template | Show Tracks | Shuffle Test | Departure Test | Arrival Test |
|----------|------------|-------------|----------------|--------------|
| station_line_end | ✓ | ✓ | ✓ | ✓ |
| station_thru_dip | ✓ | ✓ | ✓ | ✓ |
| station_parking | ✓ | PENDING | PENDING | - |
| traffic_circle7 | ✓ | — | — | Transit Test ✓ |

---

## Next Steps (ordered)

1. **Run station_parking Shuffle Test** — Console → Models → station_parking.
   Configuration ready: hold_loop_chain (direct-park, to_platform=[]), exit_chains.
   Expect: pods arrive at psmax, queue compacts toward ps1.

2. **Run station_parking Departure Test** — Console → Models → station_parking.
   Expect: all pods advance to psmax, exit via out_cp0/out_cp1, all erased.

3. **Network animation on 2_thru_dip model** — station_thru_dip validated at template
   level; test in full network Build + Animate run.

4. **Sally advance "path too short" fault** (20260616T054917-fault.md) — ps3→ps4 at
   built-network stations. Root cause: _platform_pts_entry_first orientation failure
   in world space. Deferred (not blocking template tests).

---

## Key Design Decisions (this session)

**Track direction in pass_chains:** pass_chains list track names in the correct
traversal order, but pts_mm may be stored in either direction. The transit intercept
now uses a distance-to-endpoint check to determine direction before stitching.
Rule: when building a pts path from a track list, always check which end connects.

**template_lookup transform search:** Must mirror show_track_overlay exactly —
ComponentInstance + Group, with Pass 2 gw_* child scan. Divergence causes
vehicle paths and Show Tracks ribbon to draw in different coordinate spaces.

**No model.*.json for template models:** lines.json + lines.computed.json only.
guard in generate_network_json prevents model.network.json even if Build is run
on a template. model.visits.json is a runtime artifact (trips/dwellings) — acceptable.

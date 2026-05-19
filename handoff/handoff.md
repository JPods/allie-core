---
date: 2026-05-18
status: HANDED OFF
---

# Handoff — 2026-05-18

## What Was Done This Session

**map.json as single geometry authority — complete.** The JPods Console and animation
system are fully migrated from the old JPodFollowMeTool geometry-scan approach to map.json.

### Files Changed

| File | Change |
|------|--------|
| `su_jpods/jpod_vehicle_anim.rb` | Rewritten `build_pods` — reads map.json, no SketchUp scan |
| `su_jpods/jpod_animator.rb` | All display via map.json; ~350 lines of GL/BFS methods deleted |
| `su_jpods/jpod_followme_tool.rb` | Deleted `JPodTripOverlayTool` (GL overlay replaced by permanent geometry) |
| `su_jpods/jpod_console.rb` | 27 tasks archived; 16 core workflow tasks remain (1406→962 lines) |
| `su_jpods/jpod_console_archive.rb` | NEW — all 27 archived task lambdas, restorable |
| `su_jpods/noelle.rb` | `generate_map_json` — writes `{model}.map.json` from followme.json |
| `readmes/sketchup/jpods-console-archived-tasks.md` | NEW — archive index with rationale per task |

---

## Current Architecture

```
followme.json (Noelle writes on Build)
    ↓ generate_map_json
{model}.map.json
    ├── features: { S048: { lines: [...] } }   station-internal paths
    └── segments: { seg_S048_cp1_S050_cp0: {...} }   inter-station, per direction

Animation:   JPodVehicleAnim.build_pods → build_map_lookup → resolve_gw_segs_from_map → NoraPod
FollowMe:    show_followme_json_overlay → red/blue polylines, orange gap flags
Trip path:   show_trip_path_for_vehicle → gold path, red gap flags
Route:       show_route_followme_overlay → green route, orange gap flags
```

---

## 16 Tasks in Console (clean list)

| Category | Tasks |
|----------|-------|
| Network | Network Editor, Show FollowMe Overlay, Clear FollowMe Overlay, Generate map.json |
| Builder | Calculate CPs, Place Marker, Build Network, Validate Network + Show, Show Route, Clear Route |
| Vehicles | Show Trip Path, List Vehicles, Set Vehicle Destination |
| Animation | Export FollowMe JSON, Start Animation, Stop Animation |

---

## Open Issues

### Station-internal Build gaps (known, deferred)
All `{STATION}.gw_*` paths (`gw_platform_out`, `gw_stub_pair_N_out`, etc.) still log
as map gaps at animation time. Build pipeline generates them as structure tracks without
`connection_id` — so `generate_map_json` cannot include them.

Symptom: orange gap flags at station entry/exit; vehicle jumps from station to inter-station beam.

**Fix path:** Noelle writes `connection_id` on station-internal gw groups at Build time.
Not yet scheduled.

### Station looping (deferred ~2026-05-15)
Pods accumulate at station U-turns. Probably animation artifact, not routing.
Investigate after map.json animation is confirmed stable.

### Arc decomposition
map.json segments are straight-line (`radius: 0`). Future: decompose SketchUp beam
group points into sub-segments for true arc interpolation.

---

## To Test When Resuming

```ruby
load '/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/jpod_vehicle_anim.rb'
load '/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/jpod_animator.rb'
load '/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/jpod_console.rb'
```

1. Console > Generate map.json — confirm features + segments counts
2. Console > Show FollowMe Overlay — confirm red/blue polylines, orange flags at station gaps
3. Console > Set Vehicle Destination → Start Animation — confirm vehicle moves on inter-station beams
4. Console > Show Route — confirm green route between two stations

---

## Next Steps

1. Test in SketchUp — confirm all 4 display paths work with map.json
2. Fix station-internal Build gaps (Noelle writes connection_id on station gw groups)
3. Station looping investigation
4. Arc decomposition for map.json (low priority until geometry is proven correct)

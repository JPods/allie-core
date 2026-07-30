# traffic_circle7 — Template Geometry Notes

## Ring Junction Endpoint Rule (CRITICAL — learned twice)

Every endpoint that touches a ring junction EP must equal the adjacent **ring arc's own
FIRST or LAST pt**. Never use switch-box offset coordinates.

The four ring arcs define all junction coordinates:

| Arc | FIRST (vehicle entry / departure) | LAST |
|-----|----------------------------------|------|
| `gw_c_0_0` | [-10048.1, -5126.5, 8206.8] = EP1 | [-10048.1, 5126.5, 8206.8] = EP6 |
| `gw_c_1_1` | [-21008.3, 5833.6, 8206.8] = EP12 | [-10755.2, 5833.6, 8206.8] = EP7 |
| `gw_c_2_2` | [-21715.4, -5126.5, 8206.8] = EP18 | [-21715.4, 5126.5, 8206.8] = EP13 |
| `gw_c_3_3` | [-21008.3, -5833.6, 8206.8] = EP19 | [-10755.2, -5833.6, 8206.8] = EP24 |

**Note on vehicle direction:** gw_c_1_1 and gw_c_2_2 are traversed LAST→FIRST
(vehicle enters at LAST, exits at FIRST) for CCW ring travel.

## Short Connectors (2-pt, must be on-ring at both ends)

| Track | FIRST (from arc) | LAST (to arc entry) |
|-------|-----------------|---------------------|
| `gw_c_0_1` | gw_c_0_0.LAST = EP6 | gw_c_1_1.LAST = EP7 |
| `gw_c_1_2` | gw_c_1_1.FIRST = EP12 | gw_c_2_2.LAST = EP13 |
| `gw_c_2_3` | gw_c_2_2.FIRST = EP18 | gw_c_3_3.FIRST = EP19 |
| `gw_c_3_0` | gw_c_3_3.LAST = EP24 | gw_c_0_0.FIRST = EP1 |

Correct length = 1000.0mm each. If length ≠ 1000mm, an endpoint is off the ring.

## Approach Tracks (13-pt Bezier)

All 8 approach tracks (`gw_in_0..3`, `gw_out_0..3`) have Bezier curves with:
- Ring-side endpoint = the EP coordinate (same as adjacent short connector)
- CP-side endpoint = gw_cp_in_N.LAST or gw_cp_out_N.FIRST from geometry.json
- sv = CCW ring tangent at diverge EP (for gw_out) or CP track direction (for gw_in)
- ev = REVERSE of CP track direction (for gw_out) or ring arrival tangent reversed (for gw_in)

## Hand-Authored Tracks

As of 2026-06-09, none. Ring arcs (gw_c_0_0, gw_c_1_1, gw_c_2_2, gw_c_3_3) were
extracted from ArcCurve geometry and have >2 pts — they are preserved by save_geometry().

## Restore Command

```
git checkout HEAD -- templates/track_formations/traffic_circle7/geometry.json
```

## Symptom → Diagnosis

| Symptom | Cause |
|---------|-------|
| Ribbon crosses the guideway at ring junction | Short connector endpoint is off the ring (check distance from ring center ≈ 7766mm) |
| gw_in/gw_out draws as straight diagonal | 2-pt storage — needs 13-pt Bezier re-computation |
| gw_in/gw_out wrong at ring end | Ring-side endpoint copied from switch-box geometry instead of arc.FIRST/LAST |

# station_parking — Template Geometry Notes

## Hand-Authored Tracks (DO NOT REGENERATE)

The following tracks in `lines.computed.json['geometry']['tracks']` contain hand-authored
geometry. They are carried forward automatically across every Compute run.
Do not overwrite them by re-extracting from the model — the model geometry for these
tracks is the cp_marker_N arc stub, not the full authored curve.

| Track | Pts | Type | Why hand-authored |
|-------|-----|------|-------------------|
| `gw_platform_in1` | 12 | Bezier | Diagonal approach to EP6; chord direction produces degenerate straight line without hand-set tangents |
| `gw_platform_in2` | 12 | Bezier | Inbound from ring; sv/ev derived from adjacent platform angle |
| `gw_lift_in` | 9 | Bezier | Short diagonal to EP6; parallel tangents at shallow plat angle |
| `gw_lift_parking` | 12 | Bezier | Diagonal from lift entry; sv=(1,0), ev=(-plat angle) |
| `gw_platform_out1` | 12 | Bezier | Outbound from EP11; matching plat_out angle tangents |
| `gw_platform_out2` | 12 | Bezier | Exit from EP11 to ring; chord-parallel fix applied |
| `gw_lift` | 8 | Authored | Straight horizontal guideway; authored to fix arc artifact from edge extraction |
| `gw_cp_in_0` | 3 | Authored | cp_marker_N centerline — authored from hub math |
| `gw_cp_in_1` | 3 | Authored | cp_marker_N centerline — authored from hub math |
| `gw_cp_in_lead_0` | 4 | Authored | cp_marker_N lead — authored from hub math |
| `gw_cp_in_lead_1` | 4 | Authored | cp_marker_N lead — authored from hub math |
| `gw_cp_out_0` | 4 | Authored | cp_marker_N centerline — authored from hub math |
| `gw_cp_out_1` | 4 | Authored | cp_marker_N centerline — authored from hub math |
| `gw_cp_out_lead_0` | 4 | Authored | cp_marker_N lead — authored from hub math |
| `gw_cp_out_lead_1` | 4 | Authored | cp_marker_N lead — authored from hub math |
| `gw_far_main` | 65 | Authored | Outer ring arc; authored point cloud |
| `gw_near_main` | 65 | Authored | Inner ring arc; authored point cloud |
| `gw_platform` | 25 | Authored | Platform straight; authored point cloud |

Compute only regenerates `gw_uturn_0` and `gw_uturn_1` (not authored — derived from
cp_marker_N hub math). All other tracks are carried forward.

## Junction Coordinates

Series junctions have 0.0mm gap by design. The authoritative shared coordinates are:

| Junction | Coordinate (mm, XY only, Z=5143.9 for all) |
|----------|---------------------------------------------|
| **EP6** | x=30106.2, y=-2554.4 — shared by gw_platform_in1.p0, gw_lift_in.p3, gw_lift_parking approach |
| **EP7** | x=22767.4, y=389.2 — shared by gw_lift_in.p0, gw_lift_parking.p3 |
| **EP11** | x=-13607.9, y=-3024.2 — shared by gw_platform_out1.p0, gw_platform_out2.p3 |

## Bezier Convention

All curves follow Axiom 11 (ene_railroad):
- `B1 = p0 + h*sv` where sv = outward from FIRST (vehicle departure direction)
- `B2 = p3 + h*ev` where ev = outward from LAST (REVERSE of vehicle arrival)
- `h = chord/3` (standard scale)

For tracks where vehicle travels LAST→FIRST, sv/ev are derived from physical adjacency
(neighboring track tangent angles), not from the chord direction.

## Z Level

All tracks in this template are at Z=5143.9mm (flat ring, XY curves only).

## Restore Command

If a Compute run overwrites an authored track, restore from git:
```
git show HEAD:templates/track_formations/station_parking/lines.computed.json \
  | python3 -c "import json,sys; d=json.load(sys.stdin); \
    print(json.dumps(d['geometry']['tracks']['gw_platform_in1'], indent=2))"
```
Or restore the whole file:
```
git checkout HEAD -- templates/track_formations/station_parking/lines.computed.json
```

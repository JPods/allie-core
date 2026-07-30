# station_thru_dip — Template Geometry Notes

## Hand-Authored Tracks (DO NOT REGENERATE)

The following tracks in `lines.computed.json['geometry']['tracks']` contain hand-authored
Bezier curves. They are carried forward automatically across every Compute run.
Do not overwrite them by re-extracting geometry from the model — the model geometry
for these tracks is the cp_marker_N arc stub, not the full Bezier.

| Track | Type | Why hand-authored |
|-------|------|-------------------|
| `gw_lift_in` | 25-pt Bezier | 3D diagonal approach (Z drops 2160mm over chord); tangents from adjacent track topology |
| `gw_platform_in` | 17-pt Bezier | 3D inbound approach to platform; Z transition from approach level to platform level |
| `gw_platform_out` | 20-pt Bezier | 3D outbound from platform; mirror of gw_platform_in |
| `gw_uturn_0` | 7-pt arc | U-turn arc at minimum station arc radius; ArcCurve-extracted |
| `gw_uturn_1` | 7-pt arc | Second U-turn; ArcCurve-extracted |

## Bezier Endpoint Coordinates

| Track | FIRST (p0) | LAST (p3) |
|-------|------------|-----------|
| `gw_lift_in` | [66103.6, 4750.9, 9871.4] | [44209.6, 11750.9, 7711.4] |
| `gw_platform_in` | [59423.1, 4750.9, 9871.4] | [44209.6, 8250.9, 7711.4] |
| `gw_platform_out` | [20927.1, 8250.9, 7711.4] | [2540.0, 4750.9, 9871.4] |

## Tangent Convention (Axiom 11)

sv = outward from FIRST (vehicle departure), ev = outward from LAST (REVERSE of arrival).
For station_thru_dip vehicle travels FIRST→LAST in -X direction:
- sv = (-1, 0, 0)
- ev = (+1, 0, 0)

Handle scale h = chord/3.

## Restore Command

If a Compute run overwrites these tracks with wrong geometry, restore from git:
```
git show HEAD:templates/track_formations/station_thru_dip/lines.computed.json \
  | python3 -c "import json,sys; d=json.load(sys.stdin); \
    print(json.dumps(d['geometry']['tracks']['gw_lift_in'], indent=2))"
```
Then patch the pts_mm array back into lines.computed.json['geometry']['tracks'] for
the affected track, or restore the whole file:
```
git checkout HEAD -- templates/track_formations/station_thru_dip/lines.computed.json
```

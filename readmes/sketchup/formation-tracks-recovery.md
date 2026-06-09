# Formation Track Recovery Guide
**Last Updated:** 2026-06-09

How to diagnose and fix Show Formation Tracks when ribbons look wrong.
One section per template. Every fix has a git restore fallback.

---

## Quick Reference

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Ribbon is a straight diagonal (no curve) | Track is 2-pt; needs Bezier | See per-template Bezier section |
| Ribbon crosses the guideway at a junction | Endpoint is off the ring/arc centerline | Fix endpoint to arc FIRST/LAST |
| Ribbon floats 2m below the track | Z correction missing | Restore from git |
| Ribbon appears at wrong location entirely | eff_xf wrong (formation_xf issue) | See Coordinate Frame section below |
| Large offset (thousands of mm) | inner_xf applied twice | Use eff_xf = inner_xf only (not world_xf) |

## Coordinate Frame Rule (Axiom 1 from TFTS 20260609T050247)

For template-model display: `eff_xf = inner_xf` only.  
For network-model export: `eff_xf = world_xf * inner_xf`.  
Flat templates (traffic_circle7, JPods_station_parking) have `inner_xf = nil` → identity.

---

## Restore Any Template From Git

```
SU="$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods"
git -C "$SU" checkout HEAD -- templates/track_formations/<template>/geometry.json
```

Then reload in SketchUp:
```ruby
load Sketchup.find_support_file('jpod_animator.rb', 'Plugins/su_jpods')
```

---

## traffic_circle7

### What good looks like
- 4 ring arcs (gw_c_0_0, gw_c_1_1, gw_c_2_2, gw_c_3_3): smooth semicircle/arc ribbons
- 4 short connectors (gw_c_0_1, gw_c_1_2, gw_c_2_3, gw_c_3_0): 1000mm straight segments exactly on the ring
- 8 approach tracks (gw_in_*, gw_out_*): smooth S-curves from CP stub to ring junction

### Ring junction EP coordinates (Z=8206.8 for all)

| EP | Coordinate | Used by |
|----|-----------|---------|
| EP1 | [-10048.1, -5126.5] | gw_c_0_0.FIRST = gw_c_3_0.LAST = gw_out_0.FIRST |
| EP6 | [-10048.1,  5126.5] | gw_c_0_0.LAST = gw_c_0_1.FIRST = gw_in_0.LAST |
| EP7 | [-10755.2,  5833.6] | gw_c_1_1.LAST = gw_c_0_1.LAST = gw_out_1.FIRST |
| EP12| [-21008.3,  5833.6] | gw_c_1_1.FIRST = gw_c_1_2.FIRST = gw_in_1.LAST |
| EP13| [-21715.4,  5126.5] | gw_c_2_2.LAST = gw_c_1_2.LAST = gw_out_2.FIRST |
| EP18| [-21715.4, -5126.5] | gw_c_2_2.FIRST = gw_c_2_3.FIRST = gw_in_2.LAST |
| EP19| [-21008.3, -5833.6] | gw_c_3_3.FIRST = gw_c_2_3.LAST = gw_out_3.FIRST |
| EP24| [-10755.2, -5833.6] | gw_c_3_3.LAST = gw_c_3_0.FIRST = gw_in_3.LAST |

**Diagnostic:** every ring junction must have 0mm gap. Correct short-connector length = 1000mm.
If a connector is 1118mm, its FIRST or LAST is at a switch-box offset (~500mm inside the ring).

### Short connectors: fix procedure
The endpoints must equal adjacent arc FIRST/LAST exactly. Just set them:
- gw_c_0_1: FIRST = EP6, LAST = EP7
- gw_c_1_2: FIRST = EP12, LAST = EP13
- gw_c_2_3: FIRST = EP18, LAST = EP19
- gw_c_3_0: FIRST = EP24, LAST = EP1

### Approach tracks: Bezier recipe
All 8 need 13-pt Bezier (h = chord/3). Vehicle direction is FIRST→LAST for all.

| Track | p0 | p3 | sv | ev |
|-------|----|----|----|----|
| gw_out_0 | EP1, Z=8206.8 | [-2500, -1750, 8144.3] | (0.707, 0.707) | (-1, 0) |
| gw_in_0  | [-2500, 1750, 8206.8] | EP6, Z=8206.8 | (-1, 0) | (0.707, -0.707) |
| gw_out_1 | EP7, Z=8206.8 | [-14131.7, 13381.7, 8144.3] | (-0.707, 0.707) | (0, -1) |
| gw_in_1  | [-17631.7, 13381.7, 8206.8] | EP12, Z=8206.8 | (0, -1) | (0.707, 0.707) |
| gw_out_2 | EP13, Z=8206.8 | [-29263.5, 1750, 8144.3] | (-0.707, -0.707) | (1, 0) |
| gw_in_2  | [-29263.5, -1750, 8206.8] | EP18, Z=8206.8 | (1, 0) | (-0.707, 0.707) |
| gw_out_3 | EP19, Z=8206.8 | [-17631.7, -13381.7, 8144.3] | (0.707, -0.707) | (0, 1) |
| gw_in_3  | [-14131.7, -13381.7, 8206.8] | EP24, Z=8206.8 | (0, 1) | (-0.707, -0.707) |

sv = CCW ring tangent at diverge EP; ev = REVERSE of CP track direction.

### Python recompute script
```python
# Run: python3 recompute_tc7.py
# Outputs corrected geometry.json tracks to stdout
import math, json

def norm(v): n=math.sqrt(v[0]**2+v[1]**2); return (v[0]/n, v[1]/n)
def chord2d(a,b): return math.sqrt((b[0]-a[0])**2+(b[1]-a[1])**2)

def bezier12(p0xy, p3xy, sv, ev, Z0, Z3):
    ch=chord2d(p0xy,p3xy); h=ch/3
    B1=(p0xy[0]+h*sv[0], p0xy[1]+h*sv[1])
    B2=(p3xy[0]+h*ev[0], p3xy[1]+h*ev[1])
    pts=[]; L=0
    for i in range(13):
        t=i/12; s=1-t
        x=s**3*p0xy[0]+3*t*s**2*B1[0]+3*t**2*s*B2[0]+t**3*p3xy[0]
        y=s**3*p0xy[1]+3*t*s**2*B1[1]+3*t**2*s*B2[1]+t**3*p3xy[1]
        z=Z0+t*(Z3-Z0)
        pts.append([round(x,1),round(y,1),round(z,1)])
    for i in range(1,13): L+=math.sqrt(sum((pts[i][j]-pts[i-1][j])**2 for j in range(3)))
    return pts, round(L,1)

# EP coordinates — derived from ring arc FIRST/LAST pts
EP  = {1:(-10048.1,-5126.5), 6:(-10048.1,5126.5), 7:(-10755.2,5833.6),
       12:(-21008.3,5833.6), 13:(-21715.4,5126.5), 18:(-21715.4,-5126.5),
       19:(-21008.3,-5833.6), 24:(-10755.2,-5833.6)}
ZR=8206.8; ZCO=8144.3

cfg = [
  ("gw_out_0", EP[1],  (-2500,-1750),   (0.707,0.707),  (-1,0),      ZR,  ZCO),
  ("gw_in_0",  (-2500,1750),  EP[6],   (-1,0),  (0.707,-0.707),      ZR,  ZR ),
  ("gw_out_1", EP[7],  (-14131.7,13381.7), (-0.707,0.707), (0,-1),   ZR,  ZCO),
  ("gw_in_1",  (-17631.7,13381.7), EP[12], (0,-1), (0.707,0.707),    ZR,  ZR ),
  ("gw_out_2", EP[13], (-29263.5,1750), (-0.707,-0.707), (1,0),      ZR,  ZCO),
  ("gw_in_2",  (-29263.5,-1750), EP[18], (1,0), (-0.707,0.707),      ZR,  ZR ),
  ("gw_out_3", EP[19], (-17631.7,-13381.7), (0.707,-0.707), (0,1),   ZR,  ZCO),
  ("gw_in_3",  (-14131.7,-13381.7), EP[24], (0,1), (-0.707,-0.707),  ZR,  ZR ),
]
for tag, p0, p3, sv, ev, Z0, Z3 in cfg:
    pts, L = bezier12(p0, p3, sv, ev, Z0, Z3)
    print(f'"{tag}": {{"pts_mm": {pts}, "length_mm": {L}}}')
```

---

## JPods_station_parking

### What good looks like
- gw_lift: straight 2-pt (confirmed straight guideway)
- gw_platform_in1/in2, gw_lift_in, gw_lift_parking, gw_platform_out1/out2: smooth 12-pt Bezier curves
- All series junctions: 0.0mm gap

### Junction coordinates (Z=5143.9 for all)

| Junction | Coordinate | Shared by |
|----------|-----------|-----------|
| EP6 | [30106.2, -2554.4] | gw_platform_in1.FIRST = gw_lift_in.LAST (vehicle exit) = gw_lift_parking approach |
| EP7 | [22767.4, 389.2] | gw_lift_in.FIRST (vehicle exit) = gw_lift_parking.LAST |
| EP11| [-13607.9, -3024.2] | gw_platform_out1.FIRST = gw_platform_out2.LAST (vehicle exit) |

### Protected tracks

All 6 diagonal tracks are Bezier with h=chord/3. Tangents from adjacent track angles
(shallow ≈ -8.6° plat angle, not the chord direction which is steeper ≈ -18.2°).

**If tracks revert to straight:** the tangent vectors aligned with chord direction,
producing a degenerate Bezier. Use the adjacent track's departure angle as sv.

**Restore from git is fastest.** The Bezier pts for this template are complex — restore:
```
git -C "$SU_PLUGINS" checkout HEAD -- templates/track_formations/JPods_station_parking/geometry.json
```

---

## station_thru_dip

### What good looks like
- gw_lift_in, gw_platform_in, gw_platform_out: smooth 3D Bezier curves with Z transition
- gw_uturn_0, gw_uturn_1: 7-pt arc ribbons

### 3D Bezier endpoints

| Track | FIRST (p0) | LAST (p3) |
|-------|-----------|-----------|
| gw_lift_in | [66103.6, 4750.9, 9871.4] | [44209.6, 11750.9, 7711.4] |
| gw_platform_in | [59423.1, 4750.9, 9871.4] | [44209.6, 8250.9, 7711.4] |
| gw_platform_out | [20927.1, 8250.9, 7711.4] | [2540.0, 4750.9, 9871.4] |

Z drops 2160mm over the approach — auto-extraction cannot reproduce this.

**Restore from git — do not attempt to recompute manually:**
```
git -C "$SU_PLUGINS" checkout HEAD -- templates/track_formations/station_thru_dip/geometry.json
```

---

## station_line_end

### What good looks like
- gw_lift_in, gw_platform_in: smooth 22-pt Bezier curves with Z transition
- gw_uturn_0: 7-pt arc at Z=10242.7
- gw_cp_in_0: 2-pt straight at Z=10242.7 (authored=true)
- gw_lift_parking: 2-pt straight horizontal (correct)

### Critical Z correction

gw_cp_in_0 and gw_uturn_0 must be at **Z=10242.7mm**, NOT 8242.7mm.
The model stores these components 2000mm below CP operating height.

**Symptom:** ribbon shows disconnected, floating 2m below the CP junction.
**Fix:** set all pts_mm Z values in gw_cp_in_0 to 10242.7 and add `"authored": true`.

**Restore from git:**
```
git -C "$SU_PLUGINS" checkout HEAD -- templates/track_formations/station_line_end/geometry.json
```

---

## What Protects These Fixes

Three layers prevent accidental overwrite when Generate Geometry JSON is run:

1. **Console gate** (`jpod_console.rb`): shows UI.messagebox listing protected tracks; user must confirm
2. **save_geometry() preservation** (`jpod_path_json.rb`): tracks with >2 pts OR `"authored": true` are preserved; only length_mm is updated
3. **This document + per-template notes.md**: tells future sessions what to restore

If all three layers fail (model corruption, git force-push, manual edit), restore from git as above.

---

## Bezier Convention (Axiom 11)

```
B1 = p0 + h * sv    sv = OUTWARD from p0 (vehicle departure direction)
B2 = p3 + h * ev    ev = OUTWARD from p3 (REVERSE of vehicle arrival direction)
h  = chord / 3
```

`ev` points AWAY from p3 back toward the approach. If ev points TOWARD p3's successor,
the Bezier will loop 180°.

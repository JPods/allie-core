# SNIPPET: python-inspect-su-json
# When:    before writing Ruby that consumes SketchUp-generated JSON (map.json, feature.json,
#          trip.json, followme.json) — use Python to inspect actual structure before coding.
#          Python can't run inside SketchUp but runs in 1-2 seconds from the terminal.
# Why:     The JSON schemas evolved over many sessions. Key naming, nesting depth, unit
#          conventions, and missing entries are not always what the code comments say.
#          Two surprises caught only by Python inspection on 2026-05-19:
#            (1) map.json features keys = "S048_gw_far_main" (underscore) but
#                trip.json segment IDs = "S048.gw_far_main" (dot) → lookup silently missed
#            (2) S049 and S051 intra-station features entirely absent from map.json
#                → animation had silent map gaps for half the network
# Axiom:   Read the JSON before writing the Ruby. One python3 call costs 2 seconds;
#          a silent mismatch costs hours.
# File:    jpod_animator.rb show_followme_json_overlay / check_trip_angle_errors

---

## Pattern: inspect key naming before building a lookup

```python
# Run from terminal. Replace path with model directory.
import json

MAP  = '/Users/williamjames/Documents/skp_jpods/CA_Gilroy_Clean/CA_Gilroy_Clean.map.json'
TRIP = '/Users/williamjames/Documents/skp_jpods/CA_Gilroy_Clean/CA_Gilroy_Clean.trip.json'
FEAT = '/Users/williamjames/Documents/skp_jpods/CA_Gilroy_Clean/CA_Gilroy_Clean.feature.json'

# 1. What segment IDs does trip.json use?
with open(TRIP) as f:
    trip = json.load(f)
trip_segs = sorted({s for t in trip['trips'] for s in t['segments']})
print("Trip segment IDs (sample):", trip_segs[:6])
# → ['S048.gw_far_main', 'S048.gw_near_main', ..., 'seg_S049_cp0_S048_cp0']

# 2. What keys does map.json features use?
with open(MAP) as f:
    m = json.load(f)
feat_cids = [ln['cid'] for feat in m['features'].values() for ln in feat.get('lines', [])]
print("map.json feature cids (sample):", feat_cids[:6])
# → ['S048_gw_far_main', 'S048_gw_near_main', ...]
# NOTE: underscore separator, not dot — trip.json lookup will miss unless translated

# 3. Which trip segments have NO matching cid in map.json?
map_keys = set(feat_cids) | set(m.get('segments', {}).keys())
missing = [s for s in trip_segs if s not in map_keys]
print(f"Missing from map.json ({len(missing)}):", missing[:10])
# → reveals entire S049 and S051 feature sets absent
```

## Ruby: key translation derived from Python inspection

```ruby
# trip.json uses "S048.gw_far_main"; map.json cids use "S048_gw_far_main".
# Rule discovered by Python inspection: replace (S\d+)_(gw_.*) with S###.gw_...
# Add dot-notation aliases to the existing lookup so every trip segment ID resolves.
extra = {}
map_lookup.each do |k, v|
  if (m = k.match(/\A(S\d+)_(gw_.+)\z/))
    extra["#{m[1]}.#{m[2]}"] ||= v
  end
end
map_lookup.merge!(extra)
```

## Pattern: inspect z-values before placing overlay geometry

```python
# Are feature line z-values above or below the beam?
# Check before deciding on z-offset direction.
with open(MAP) as f:
    m = json.load(f)
for k, feat in sorted(m['features'].items()):
    for ln in feat.get('lines', []):
        for s in ln.get('segments', []):
            print(f"  {ln['cid']}: zs={s['zs']:.0f}mm  ze={s['ze']:.0f}mm")
# → S048_gw_platform: zs=5443  ze=5443 mm
# → S048_gw_stub_pair_0_out: zs=7478  ze=7728 mm
# Beam CLEARANCE_HEIGHT=4600mm + terrain_z ≈ 6800mm = CP z
# Strip at cp_z - 500mm = inside beam (invisible).
# Strip at cp_z + 2 SU inches = 2" above each point's z = visible from above.
```

## Ruby: z-lift derived from Python inspection

```ruby
# Lift strip 2 SU inches above each point's z-coordinate.
# Works for both inter-station (z ~268-300 SU in) and intra-station (z ~214-304 SU in).
z_lift = 2.0   # SU inches — floats strip above track centerline regardless of segment type

pts.each_cons(2) do |p1, p2|
  lp1z = p1.z + z_lift
  lp2z = p2.z + z_lift
  # ... draw face strip
end
```

## Pattern: verify all connections present before coding routing

```python
# Does followme.json have all 6 bidirectional connections (3 pairs)?
with open('/path/to/model.followme.json') as f:
    fj = json.load(f)
nd = fj.get('network_definition', {})
conns = nd.get('connections', [])
print(f'{len(conns)} connections:')
for c in conns:
    print(f"  {c['id']}  {c['from']['structure_id']}cp{c['from']['stub']} → "
          f"{c['to']['structure_id']}cp{c['to']['stub']}")
# → confirms 6 entries before writing 12-trip matrix
```

## When to run Python vs read the JSON directly

| Task | Tool |
|------|------|
| Count keys, list all values, spot missing entries | Python — faster than reading 500-line JSON |
| Check one specific value | Read tool |
| Write Ruby that iterates over keys | Python first — confirm key format before coding |
| Verify z-coordinates before z-offset logic | Python — compute mm→inches mentally is error-prone |
| Check which stations are in features | Python — grep is noisy for nested JSON |

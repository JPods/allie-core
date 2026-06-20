# JPods Speed Architecture
**Last Updated:** 2026-06-20
**Purpose:** Single reference for how speed works across the SU simulator, physical
Noras, and Natalie. Covers the current state, the physics behind curve limits,
and the open work items.

---

## Current State (as of 2026-06-20)

All pods run at a single `speed_ms` from `su_jpods/defaults.json` (default: 8.3 m/s).
This applies uniformly to all track types — `seg_` inter-station guideways and `gw_`
in-station tracks including U-turns.

**Why single speed is acceptable in SU now:** SketchUp simulation is a geometry and
routing validator, not a physics simulator. Students need to see pods move, not
experience correct deceleration profiles. The 3.5 m U-turn at 8.3 m/s is physically
impossible but visually useful for template validation.

**Speed is set in `defaults.json`, never in model entity attributes.** Per-network
override: add a `defaults` section to `network.json` alongside the model file.

```json
{ "defaults": { "speed_ms": 6.0, "authorized_speed_ms": 6.0 } }
```

**Set Speed command** (Console → Set Speed) writes to `defaults.json` and patches
live pods in memory. No model save.

---

## Physics: g-Limit Speed

The correct maximum speed through any curve is:

```
v_max = sqrt(g_limit × radius_m)
```

| g_limit | Meaning |
|---------|---------|
| 0.1g (0.981 m/s²) | Comfortable — standing passengers, full cups |
| 0.25g (2.45 m/s²) | Acceptable — seated passengers, no spill concern |
| 0.5g (4.9 m/s²) | Emergency deceleration threshold — not for cornering |

**3.5m U-turn speeds at 0.25g:**

| Rail | Radius | v_max at 0.25g |
|------|--------|----------------|
| Inside (physical constraint) | 1.5 m | 1.92 m/s |
| Centerline (pod path) | 1.75 m | 2.07 m/s |
| Outside | 2.0 m | 2.21 m/s |

The centerline value (2.07 m/s ≈ 4.6 mph) is the operational speed limit for any
3.5 m diameter U-turn.

The formula is already in `jpod_constants.rb`:
```ruby
LATERAL_G_LIMIT_MPS2 = 0.981   # 0.1g — conservative
def self.curve_speed_limit_mps(radius_m)
  Math.sqrt(LATERAL_G_LIMIT_MPS2 * radius_m.to_f)
end
```

`g_limit` is hardcoded at 0.1g. The intent is to expose this in `defaults.json` as
`lateral_g_limit` (see F-SP-01).

---

## Physical Noras: Accelerometers Enforce It

Physical Noras carry accelerometers. The onboard controller reads lateral g in real
time and adjusts motor speed to stay below the g-limit. This is hardware enforcement —
the physical system does not rely on pre-computed speed tables. Natalie issues an
authorized_speed_ms for the segment; Nora's accelerometer governs the actual executed
speed within that authorization.

**The SU simulator never needs to replicate this.** The simulator validates geometry
and routing, not vehicle dynamics. If the geometry passes the route test at 8.3 m/s,
the physical Nora will self-limit to the correct curve speed via its own control loop.

---

## What Natalie Actually Needs to Do About Speed

Natalie's speed responsibility is **not** curve physics — that is Nora's job. Natalie's
speed responsibility is **inter-vehicle safety**:

1. **Personal space** — no two Noras occupy the same physical space on the same track.
   Current enforcement: `MIN_SPACING_IN` gap regulation in `jpod_vehicle_anim.rb`.
   This fires per-tick but does not look ahead at upcoming merges.

2. **Intersection conflict** — two Noras on converging tracks must not arrive at a CP
   junction simultaneously. Natalie currently has no intersection pre-clearance logic.
   A Nora behind a merge point can enter while a Nora on the crossing track is also
   entering — the gap regulation only fires on the same track, not across tracks.

3. **Speed authorization by segment** — `authorized_speed_ms` in the trip plan is
   currently a single value for the whole trip. It should be per-segment, allowing
   Natalie to authorize 8.3 m/s on `seg_` and 2.1 m/s on `gw_uturn_*`.

See F-SP-01 (per-track g_limit speed) and F-NAT-01 (inter-Nora intersection clearing)
in `jpods-feature-list.md`.

---

## Open Work

| Item | File | Status |
|------|------|--------|
| `lateral_g_limit` in defaults.json | `jpod_defaults.rb`, `jpod_constants.rb` | Todo (F-SP-01) |
| Per-track speed limits in lines.computed.json | `noelle.rb` | Todo (F-SP-01) |
| Per-segment `authorized_speed_ms` in trip plans | `natalie.rb`, `jpod_vehicle_anim.rb` | Todo (F-SP-01) |
| Natalie intersection pre-clearance | `jpod_vehicle_anim.rb` | Todo (F-NAT-01) |
| Personal space cross-track enforcement | `jpod_vehicle_anim.rb` | Todo (F-NAT-01) |

---

## Ouch-List Items

Speed-related risks belong in `readmes/system/ouch-list.md`. The key ones:

- **SP-01** Noras on converging tracks can enter a CP junction simultaneously — no
  cross-track gap check exists in the SU simulator. In physical deployment this is
  prevented by Natalie's ezone pre-clearance protocol, but SU does not simulate ezones.
- **SP-02** U-turn speed in SU simulator is 8.3 m/s — physically impossible. Any
  student who measures the SU animation against a physical model will see a discrepancy.
  The simulator is not a dynamics validator; this should be clearly documented for
  student users so they do not treat SU speed as authoritative for physical design.

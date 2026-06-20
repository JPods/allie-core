# JPods Speed Architecture
**Last Updated:** 2026-06-20
**Purpose:** Single reference for how speed works across the SU simulator, physical
Noras, and Natalie. Covers the current state, the physics behind curve limits, the
physical system's three-layer enforcement architecture, and the open work items.

---

## Current State — SU Simulator (as of 2026-06-20)

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
3.5 m diameter U-turn. Lateral acceleration is mass-independent (v²/r = lateral_a
regardless of cargo weight), so the speed limit holds for empty and fully loaded pods
alike. Beam structural loads scale with mass — that is a Noelle beam-design concern,
not a speed limit concern.

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

## Physical System: Three-Layer Speed Architecture

The physical system enforces speed at three layers. Each layer has a distinct role.
They do not duplicate each other.

### Layer 1 — Noelle: Geometry-Derived Limits

Noelle sets a g-limit and a derived speed limit on every `gw_` track at compute time.
She writes these into `lines.computed.json` as track metadata. She also sets limits
at specific mm positions within a track where the arc radius changes — not just a
per-track average but a profile across the track length.

**Why mm positions:** A single track may have multiple arc radii. The `gw_lift_in`
ramp transitions from a straight approach into the ring arc. The speed limit at mm 0
(straight, high speed) differs from the limit at mm 3000 (entering the arc, lower
speed). A per-track single value would either over-restrict the straight section or
under-restrict the arc. The mm-position table gives the correct limit at every point.

**Data structure (proposed, `lines.computed.json`):**
```json
"gw_uturn_0": {
  "speed_limit_ms": 2.07,
  "speed_profile_mm": [
    { "mm": 0,    "limit_ms": 4.5,  "g_limit": 0.25 },
    { "mm": 500,  "limit_ms": 2.07, "g_limit": 0.25 },
    { "mm": 4989, "limit_ms": 2.07, "g_limit": 0.25 },
    { "mm": 5489, "limit_ms": 4.5,  "g_limit": 0.25 }
  ]
}
```

`speed_limit_ms` is the minimum across the full track — what Natalie uses for
conservative timeline planning. `speed_profile_mm` is what Nora enforces at
each position.

### Layer 2 — Nora: Empirical Experience

Physical Noras measure lateral g via accelerometer at every mm position during each
run. If the measured g exceeds the Noelle-set limit at any mm position, Nora:
1. Decelerates immediately
2. Records the violation and its mm position to `experience.json` for that track
3. Reports the event to Natalie

Over time, Nora's experience table for each track builds empirical speed limits that
reflect the actual physical behavior — which may differ from Noelle's geometry-derived
limits due to manufacturing tolerances, track wear, or sensor noise. The experience
table can only tighten limits, never loosen them beyond Noelle's computed value.

**Data structure (proposed, `experience.json` per track formation):**
```json
"gw_uturn_0": {
  "runs": 47,
  "last_updated": "2026-06-20T02:00:39Z",
  "mm_speed": [
    { "mm": 0,    "measured_max_ms": 4.3, "measured_max_g": 0.23 },
    { "mm": 500,  "measured_max_ms": 2.1, "measured_max_g": 0.24 },
    { "mm": 5489, "measured_max_ms": 4.2, "measured_max_g": 0.22 }
  ]
}
```

After sufficient runs, Natalie can use the empirical `measured_max_ms` values for
timeline planning rather than the conservative geometry-derived values. The gap
between Noelle's limit and Nora's measured limit is where scheduling efficiency lives.

### Layer 3 — Natalie: Timeline Planning

Natalie uses speed profiles — not single speeds — to compute accurate ETAs for
every segment of every trip. The timeline is not `len_mm / authorized_speed_ms`
(single speed) but an integral over the mm-position speed profile:

```
ETA = sum( segment_mm[i] / speed_at_mm[i] )  for each mm slice i
```

This gives Natalie accurate junction-clearance windows. When two Noras are
converging on the same CP, Natalie computes the arrival time of each from its
current mm position using the speed profile of each remaining segment. If the
arrival windows overlap within the safety margin, she holds the trailing Nora.

**Why this matters for routing:** The intersection pre-clearance problem (F-NAT-01)
is unsolvable without accurate ETAs. If Natalie uses a flat `8.3 m/s` for all
segments, her ETA for a Nora on a U-turn approach is wrong by a factor of 4×. She
cannot compute meaningful headways from bad ETAs.

**Natalie's weather factor** (1–5, already implemented) scales headways, not speed.
At weather_factor=5, Natalie increases the safety margin on junction-clearance
windows rather than reducing authorized_speed_ms. Speed is a Noelle/Nora concern;
headway is Natalie's.

---

## Emergency Stop Protocol (Physical)

When Nora's accelerometer reads g > g_limit at any mm position:

1. **Immediate motor cut** — Nora stops within the shortest safe distance
2. **FAULT written** — `process/inbox/YYYYMMDDTHHMMSS-fault.md` with mm position,
   measured g, track name, and Nora ID
3. **Natalie notified** — Nora publishes `nora/fault` on MQTT; Natalie re-routes
   all Noras that would pass through that mm range
4. **Track flagged** — that mm range is marked unavailable until a maintenance
   run clears it
5. **Experience updated** — the measured g is written to `experience.json` as a
   hard floor — that speed is never authorized on that mm range again

The emergency stop is the failsafe. The speed profile is the preventive system
that makes the emergency stop rare.

---

## Exclusive Zones (EZ) — Physical System

An exclusive zone is a region of the network that only one Nora may occupy at a
time. EZs are Natalie's mechanism for inter-vehicle safety at intersections and
merge points. Since Natalie controls all trip plans, she can create and enforce EZs
unilaterally — no additional hardware is required.

### EZ Objects in network.json

Natalie writes EZ definitions into `network.json` as a top-level `ezones` array.
Each EZ is a rich object that grows richer as Natalie gains experience:

```json
"ezones": [
  {
    "ez_id": "ez_cp_circle_to_main_0",
    "type": "intersection",
    "tracks": ["gw_cp_in_0", "gw_cp_out_0", "gw_seg_to_main"],
    "center_mm": [14500, 8200, 4600],
    "radius_mm": 1800,
    "padding": {
      "vehicle_length_mm": 2400,
      "personal_space_mm": 1000,
      "geometry_clearance_mm": 300,
      "experience_tighten_mm": 0
    },
    "effective_radius_mm": 3700,
    "entry_points": [
      { "track": "gw_cp_in_0",   "mm": 0,    "role": "entry" },
      { "track": "gw_cp_out_0",  "mm": 3200, "role": "exit" },
      { "track": "gw_seg_to_main", "mm": 0,  "role": "entry" }
    ],
    "runs": 0,
    "last_updated": null,
    "tightest_observed_clearance_mm": null,
    "notes": []
  }
]
```

### How EZ Padding Works

Natalie computes `effective_radius_mm` from three sources, applied in order:

1. **Math** — vehicle geometry + personal space:
   `vehicle_length_mm / 2 + personal_space_mm` gives the minimum safe following
   distance. The EZ must be at least this large to prevent overlap.

2. **Intersection geometry** — the physical arc of the intersection determines the
   minimum time a Nora spends inside the zone. A tighter intersection forces a
   longer hold — even if the EZ boundary is small, a Nora moving at 2 m/s through
   a 3 m arc takes 1.5 s. Natalie adds `geometry_clearance_mm` to account for
   asymmetric approach angles.

3. **Experience** — after each run, Natalie records the observed clearance (how much
   margin was actually available when the trailing Nora was held). If the margin is
   consistently tight, `experience_tighten_mm` grows, widening the EZ. The EZ can
   only tighten from experience, never loosen below the math floor.

### EZ Protocol — How Natalie Enforces

1. **Pre-clearance** — before dispatching a junction maneuver, Natalie checks
   whether any Nora is currently inside the EZ or has an ETA (from speed profile
   integral) that puts it inside the EZ within the safety window.
2. **Hold** — if the zone is occupied or will be, Natalie holds the approaching
   Nora at the last hold point before `entry_points[role=entry]`.
3. **Grant** — when the zone clears (occupying Nora passes all `role=exit` points),
   Natalie dispatches the held Nora.
4. **Record** — Natalie writes the observed clearance margin to `ez_experience.json`
   after each grant. Over time, the EZ object's `runs` and
   `tightest_observed_clearance_mm` fields build an empirical picture of how much
   headroom actually exists at each junction.

### ez_experience.json — Allie's Role

Natalie's EZ knowledge must survive across sessions and power cycles. Allie
maintains `ez_experience.json` as a persistent cross-session record:

```json
{
  "ez_cp_circle_to_main_0": {
    "runs": 47,
    "last_updated": "2026-06-20T14:33:11Z",
    "tightest_clearance_mm": 820,
    "avg_clearance_mm": 1340,
    "holds_issued": 12,
    "holds_per_100_runs": 25.5,
    "experience_tighten_mm": 0,
    "notes": []
  }
}
```

At startup, Natalie reads `ez_experience.json` and initializes each EZ's
`experience_tighten_mm` from the stored record. If `tightest_clearance_mm` is
below `personal_space_mm / 2`, Natalie tightens the EZ for the current session.

Allie reads `ez_experience.json` nightly and flags to Bill any EZ where:
- `holds_per_100_runs` exceeds 30 — intersection is undersized for the traffic load
- `tightest_clearance_mm` trends toward zero — geometry is tight; Noelle review needed
- A new EZ appears that has no experience — highlight for manual review

**Why Allie holds this, not Natalie:** Natalie runs per-session and resets on
plugin reload. The experience base must persist across sessions. Allie's nightly
synthesis is the right locus for cross-session accumulation, not in-memory router
state.

**File location:** `~/Allie/process/ez_experience.json` (not in the model folder —
applies across all networks that share the same junction geometry types).

---

## SU Simulator vs Physical — Division of Responsibility

| Concern | SU Simulator | Physical System |
|---------|-------------|-----------------|
| Curve speed limit | Not enforced — single speed_ms | Noelle (geometry) + Nora (accelerometer) |
| mm-position speed profile | Not implemented | Noelle at compute, Nora refines |
| Exclusive zones (EZ) | Not implemented (F-EZ-01) | Natalie EZ protocol + ez_experience.json |
| Inter-vehicle spacing | MIN_SPACING_IN per-track only | Natalie EZ pre-clearance |
| Intersection conflict | Not implemented (F-NAT-01) | Natalie EZ protocol |
| Emergency stop | Not implemented | Nora hardware interrupt |
| Experience learning | Not implemented | Nora → experience.json + Allie → ez_experience.json |
| Weather factor | Not implemented | Natalie headway scaling |
| Routing timeline | Single-speed ETA | Multi-speed integral (F-SP-01 depends) |

**The SU simulator's job** is to validate geometry and routing topology — that
connections are reachable, parking slots fill and empty correctly, and trip plans
sequence through the right tracks. It is not a dynamics simulator and does not
need to become one.

**The physical system's job** is to move people safely. Speed enforcement,
experience learning, and inter-vehicle safety are all physical-system concerns
that happen in hardware (Nora) and in the Natalie router, not in SketchUp.

---

## What Natalie Needs from Speed (Routing Responsibility)

Natalie's speed responsibilities, in priority order:

1. **Inter-vehicle safety** — no two Noras in the same physical space. Requires
   cross-track gap checking at CPs (not currently implemented in SU).
2. **Junction pre-clearance** — hold a Nora at an approach until the junction is
   clear. Requires accurate ETAs from speed profiles.
3. **Per-segment authorization** — issue `authorized_speed_ms` per segment in the
   trip plan, not a single value for the trip. The segment limit comes from Noelle's
   computed `speed_limit_ms` for that track.
4. **Headway management** — use weather_factor to widen safety margins on junction
   windows without changing the speed limit itself.

Items 1–2 are F-NAT-01. Item 3 is F-SP-01. Item 4 is already partially implemented.

---

## Open Work

| Item | Domain | File | Status |
|------|--------|------|--------|
| `lateral_g_limit` in defaults.json | SU + Physical | `jpod_defaults.rb`, `jpod_constants.rb` | Todo (F-SP-01) |
| Noelle computes per-track + mm-position speed limits | Physical | `noelle.rb`, `lines.computed.json` | Todo (F-SP-01) |
| Per-segment `authorized_speed_ms` in trip plans | SU + Physical | `natalie.rb` | Todo (F-SP-01) |
| `experience.json` per track — Nora writes, Natalie reads | Physical | `nora.rb`, `natalie.rb` | Todo |
| Multi-speed ETA integral in Natalie timeline | Physical | `natalie.rb` | Todo (F-SP-01 dependency) |
| EZ objects in network.json — Natalie writes at compute | Physical | `natalie.rb`, `network.json` | Todo (F-EZ-01) |
| EZ pre-clearance hold protocol | Physical | `natalie.rb` | Todo (F-EZ-01) |
| `ez_experience.json` — Allie maintains, Natalie reads at startup | Physical | Allie nightly, `natalie.rb` | Todo (F-EZ-01) |
| Natalie intersection pre-clearance | SU + Physical | `jpod_vehicle_anim.rb`, `natalie.rb` | Todo (F-NAT-01) |
| Personal-space cross-track enforcement at CPs | SU | `jpod_vehicle_anim.rb` | Todo (F-NAT-01) |
| Emergency stop → FAULT → Natalie re-route | Physical | `nora.rb`, `natalie.rb` | Todo |
| Weather factor → headway scaling (not speed) | Physical | `natalie.rb` | Todo |

---

## Ouch-List Items

Speed-related risks belong in `readmes/system/ouch-list.md`. The key ones:

- **SP-01** Noras on converging tracks can enter a CP junction simultaneously — no
  cross-track gap check exists in the SU simulator or the physical Natalie. In physical
  deployment the ezone pre-clearance protocol is the intended guard, but it is not
  yet implemented (see `readmes/22-jpods-control-system.md`).
- **SP-02** U-turn speed in SU simulator is 8.3 m/s — physically impossible. Students
  must not treat SU animation speed as authoritative for physical design. The simulator
  validates geometry and routing, not dynamics.
- **SP-03** Nora experience.json does not yet exist. Until it does, Natalie's timeline
  planning uses only Noelle's conservative geometry-derived limits — no learning from
  actual track behavior. The ETA error compounds at junctions.
- **SP-04** Weather factor currently scales headways but is not connected to junction
  pre-clearance windows. A storm event (weather_factor=5) increases the hazard at
  intersections without increasing the clearance margin for intersection timing.
- **SP-05** EZ objects do not yet exist in the physical Natalie. Until F-EZ-01 is
  implemented, inter-vehicle safety at intersections relies on Nora's accelerometer
  emergency stop (reactive) rather than Natalie's pre-clearance hold (preventive).
  The preventive system is the correct design — the reactive system is the failsafe,
  not the operational guard.

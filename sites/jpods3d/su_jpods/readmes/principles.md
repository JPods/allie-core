# JPods Plugin Principles

This plugin follows the same governing principles used in the physical JPods network stack.

Reference source:
- /Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/PRINCIPLES.md

## Local First, Fleet Second

Order of operations in this plugin:
1. Local observation (vehicle + local guideway context)
2. Local memory (per-vehicle position and assigned trip)
3. Local action (follow assigned route by traveled millimeters)
4. Shared summary (route diagnostics)
5. Fleet coordination (trip assignment policy from followme.json network_definition and trip files)

## Deterministic Routing (Natalie)

## Datum Invariant (FollowMe)

Before any routing logic, this geometric invariant must hold:

1. CP datum at each gate is the **bottom centerline** of the paired `stub_pair` gate.
2. FollowMe line endpoints are exported on that same bottom-centerline datum.
3. Runtime movement (mm traveled) is measured along those bottom-centerline lines.

Never accept outside-edge anchoring as valid. If outside-edge alignment appears, treat it as a CP/build regression and fix geometry before route policy work.

Vehicles can be preassigned trip traces in `trips/<model>.trip.<nora_id>.json`:
- `vehicle_trips[vehicle_id] = [line_1, line_2, ...]`
- every dispatched trip gets a unique `trip_id` for evidence, replay, and audit correlation.

Runtime policy is controlled by `routing_policy`:
- `strict_vehicle_trips` (default `true`)
- `allow_trip_fallback` (default `false`)

Default behavior is strict and recoverable:
- If a trip cannot be assigned, the vehicle is not animated on an undeclared route.
- The failure is reported in console diagnostics.

Trip security mode:
- Current classroom mode: trip JSON is human-readable for students planning and evaluating routes.
- Future production mode: trip payload can be encrypted, but `trip_id` remains stable for system-to-system correlation.

## cp_marker_N — Pure Math, No Edges

The cp_marker_N component is the source of truth for all Compute geometry.
It contains four points radiating from a hub:

```
                       centerline (177mm vertical)
                            │
outbound ←── 1750mm ──── CP POINT ──── 1750mm ──→ inbound
                            │
                          222mm
                            ↓
                        vector_end
```

- **CP point**: intersection of all four lines — the connection point itself.
  Sits on the station centerline between the two guideways.
- **Two 1750mm points**: guideway centerline positions, 3500mm apart (DUAL_TRACK_SPACING).
  Outbound = gw_cp_out side. Inbound = gw_cp_in side.
- **222mm point**: direction vector pointing away from model toward network.
  Perpendicular to both the station axis and the tip-to-tip line.
- **177mm point**: vertical Z reference (centerline between guideways).

**Reading the cp_marker — pure math, no edges:**

1. Collect all point positions from the component definition
2. CP point = vertex with most connected edges (intersection of all four lines)
3. Classify other points by distance from CP point (222mm vs 1750mm vs 177mm)
4. Cross product of (222mm_direction) × (tip_offset from CP point):
   positive Z = outbound tip (gw_cp_out side),
   negative Z = inbound tip (gw_cp_in side)

**Never use:**
- Edge objects, edge lengths, or edge properties
- model.bounds.center
- Accumulated parent transforms (Compute is model-only)
- Assumptions about vertex ordering or entityIDs

**Coordinate frame:**
All cp_marker positions are in the model definition's local coordinate system.
Compute reads them in this frame. Build applies instance transforms for world
coordinates. Never cross this boundary.

**Track layout from the cp_marker:**
```
cp_marker tip ─── gw_cp_in/out (2500mm inward) ─── JUNCTION (uturn) ─── gw_cp_in/out_lead (2500mm inward) ─── model interior
```
The cp_marker tip IS the outermost point — the dangling end for Network Build.
ALL tracks extend INWARD (against the tangent). The uturn is at the junction,
2500mm inward from the tip. The lead extends another 2500mm inward from there.

**Tangent direction** is computed from the hub-to-hub axis, NOT from the 222mm vector.
Each marker's tangent points OUTWARD from the model center along the station axis.
The 222mm vector is perpendicular to the axis — it determines outbound vs inbound
tip via cross product, not the travel direction for CP tracks.

**Outbound vs inbound tip assignment:**
- Cross product of (222mm_direction) × (tip_offset from CP point):
  positive Z = outbound tip (gw_cp_out side),
  negative Z = inbound tip (gw_cp_in side)
- This is a geometric property of the cp_marker itself — stable, no topology needed

## Honest Reporting

Route decisions and trip assignment outcomes are reported as evidence:
- `trip_assigned`
- `trip_assignment_failed`
- `trip_fallback_to_loop` (only when fallback is allowed)

No silent reroute should occur when strict policy is enabled.

## Recoverable Good-Faith Error

If a declared route cannot be followed:
- Prefer safe non-animation for that vehicle over undefined jumps.
- Record enough evidence to diagnose and fix data or topology.

## Hairpin Discipline

Hairpins support one-sided stations.

Routing guard:
- Never chain hairpin-to-hairpin transitions in sequence.

## Natalie Confirms Before Animating

Natalie's role in SketchUp is validation before commitment. This extends to geometry:

- At animation start, Natalie reads `lines.computed.json` from the station template
- She compares its `generated_at` timestamp to the `built_at` timestamp in network.json
- If Compute is newer than Build: **stop. Report "Run Build before animating." Do not proceed.**
- If Build is current with Compute: animation proceeds with embedded world-space direction data

**No silent degradation.** The proximity fallback (used when direction data is missing) is a last resort that produces wrong answers silently — 130 per-trip fallbacks, 4 track reversals, incorrect CP positions. Natalie's job is to catch this before the animation starts, not to silently compensate for missing data.

The enforced sequence is: **Compute → Build → Animate.** Natalie is the gate between Build and Animate.

---

## Risk-Driven Logging

Anyone on the team — Claude Code, Allie, any agent — can add logging whenever a risk is perceived. The rule:

1. **Add logging immediately** when a risk or bug is identified — don't wait
2. **Add the risk to the oslist** with what is known and why it matters
3. **Trim logging back** as soon as the risk is quantified or resolved
4. **Never leave permanent verbose logging** — it buries the signal

Logging is a first response, not an afterthought. Rich logging during active issues saves diagnostic time. Stale logging after resolution creates noise.

---

## Engineering Test For Changes

Before merging significant routing changes, check:
1. Does this strengthen local vehicle responsibility?
2. Does this preserve local runtime memory and evidence?
3. Is bounded local experimentation possible without hidden reroutes?
4. Are weak outcomes visible in logs?
5. Is failure recoverable without unsafe behavior?
6. Does coordination avoid top-down central ownership of local reality?

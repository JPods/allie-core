---
name: Student kit program — Design → Survey → Build → Ride
description: JPods student program connecting MeshMobility, SketchUp, GPS survey, 4WD robots, and scale models into a scored learning loop with kit sales as revenue
type: project
---

## The Student Journey: Design → Survey → Build → Ride

JPods provides low-cost kits that take students from digital network design to physical vehicles they can ride. The student is the customer, the workforce, and the sensor network. Every kit sold deploys a sensor. Every student is a surveyor giving ground-truth data no satellite can match — and they're paying JPods for the privilege because they're learning.

**Why:** Curiosity and self-reliance. Not a curriculum — a challenge. "Design transit for your city, then build it and ride it." The tool scores you. The leaderboard compares you. The robot proves whether your design actually works.

**How to apply:** This shapes every feature decision in MeshMobility, SketchUp, 4WD, and scale model. Everything must serve this loop. If a feature doesn't help a student design, survey, build, or ride — question whether it belongs.

## The Loop

```
MeshMobility        → design the network on the map
SketchUp            → design the 3D structures
GPS Survey          → walk the route, mark where columns actually fit
MeshMobility        → adjust for reality (obstructions, terrain, utilities)
4WD Robot / Scale   → build the vehicle, test the control system, ride it
Noelle              → learns from every step across every city
```

## Platform Scoring (0-100 each, composite across platforms)

| Platform | What's scored |
|----------|--------------|
| MeshMobility | Coverage, safety (crash hotspots served), connectivity, efficiency (people/mi), revenue (payback years) |
| SketchUp | Noelle validation pass rate, CP connectivity, build success |
| GPS Survey | % of designed column positions that survive ground-truth |
| 4WD / Scale Model | Trip completion rate, ezone faults, Nora anomalies |

Teams of 2-5 (scrum style). ~60% will be individuals. 1-hour sprints. Score updates live as they edit. Leaderboard by City x Team x Platforms completed.

## Kit Tiers

| Kit | Contents | ~Price | Teaches |
|-----|----------|--------|---------|
| Survey Kit | Phone mount, measuring wheel, marker flags, printed map | $20 | Ground-truth, column placement, reality vs design |
| Cargo Carrier | TTL motors, Arduino, chassis, ToF sensor, battery | $50 | Motor control, obstacle detection, basic Nora |
| Scale Model | Pi, track sections, pod, HuskyLens | $150 | Ezone control, multi-vehicle, Noelle network ops |
| Rider | 90W skateboard motors, Pi, frame, brakes, controller | $300 | Full Nora/Natalie, real passengers, real safety |

## Commerce (Alice + WebClerk)

- Kit sales through WebClerk — Alice handles orders, shipping, tracking
- Kit serial number links to team session — 4WD telemetry feeds back to MeshMobility score
- Replacement parts, upgrades, add-ons all through WC3
- Small-Stings: network stings the team for design flaws (orphans, dead ends)
- Teams earn credit for retrospections (JPods pays for honest feedback)

## The Business Model

Every kit sold is revenue before a single guideway is built. The student creates value at the edge:
- Designs improve Noelle (training data)
- GPS surveys provide ground-truth (asset)
- Retrospections explain the "why" (the most valuable training signal)
- Network effects: Noelle's defaults improve for the next city

This is Desktop Hosting applied to transit — value created at the edge, by the user, for their own benefit. The platform gets smarter as a side effect.

## GPS Survey Feedback

The gap between designed position and surveyable position is the lesson:
- Drop GPS pin at each proposed column location
- Photo of actual site
- Tag: clear / obstruction / utility / drainage / tree / private property
- Noelle accumulates thousands of these across cities
- Eventually predicts obstructions from satellite imagery before anyone walks the route

## Infrastructure Scaling

- MeshMobility GUI + overlays: Cloudflare Pages (free at any scale)
- Per-session compute: session-keyed state, one VPS handles 1,000 concurrent
- .jpd files and scores: Cloudflare R2 (pennies/GB)
- No git for users — save/fork/share/timeline built into the tool
- Design event logs + retrospections: our git repo, Noelle's training corpus

## What to Stage Now

1. Score endpoint (`/api/network/score`) — five dimensions from existing overlay data
2. Session-keyed state — multiple teams/individuals run simultaneously
3. Event logging per session — every mutation logged for Noelle
4. GPS survey capture — HTML5 geolocation, photo, tag, POST to session
5. Kit bill of materials — parts list + weekend build guide for each tier
6. MeshMobility → SketchUp export format

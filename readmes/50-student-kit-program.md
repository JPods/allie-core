# Student Kit Program — Design, Survey, Build, Ride
**Last Updated:** 2026-07-09
**Owner:** Bill (vision), Alice (commerce), Noelle (learning from student designs)
**Related:** `readmes/12-jpods.md`, `readmes/agents/alice.md`, `readmes/agents/noelle.md`

---

## The Idea

JPods provides low-cost kits that take students from digital network design to physical
vehicles they can ride. The student is the customer, the workforce, and the sensor network.

The goal is curiosity and self-reliance. Not a curriculum — a challenge:
**"Design transit for your city, then build it and ride it."**

The tool scores you. The leaderboard compares you. The robot proves whether your design works.

---

## The Loop

```
MeshMobility        → design the network on the map
SketchUp            → design the 3D structures
GPS Survey          → walk the route, mark where columns actually fit
MeshMobility        → adjust for reality (obstructions, terrain, utilities)
4WD Robot / Scale   → build the vehicle, test the control system, ride it
Noelle              → learns from every step across every city
```

Every step feeds the next. The GPS survey gap — where the design says "column here" but
reality says "storm drain, move 3 meters east" — is the most valuable data in the system.
Noelle accumulates thousands of these across cities and eventually predicts obstructions
from satellite imagery before anyone walks the route.

---

## Kit Tiers

| Kit | Contents | ~Price | What it teaches |
|-----|----------|--------|-----------------|
| **Survey Kit** | Phone mount, measuring wheel, marker flags, printed map | $20 | Ground-truth, column placement, reality vs design |
| **Cargo Carrier** | TTL motors, Arduino, chassis, ToF sensor, battery | $50 | Motor control, obstacle detection, basic Nora |
| **Scale Model** | Pi, track sections, pod, HuskyLens | $150 | Ezone control, multi-vehicle, Noelle network ops |
| **Rider** | 90W skateboard motors, Pi, frame, brakes, controller | $300 | Full Nora/Natalie, real passengers, real safety |

The 4WD builds use TTL motors to carry cargo and 90W skateboard motors to carry people.
Students can ride their own transit system in parking lots. Parents see their kid on a
vehicle they built — that is the viral moment, not a website.

The 4WD and scale model share the same Nora/Natalie control system code, different chassis.

---

## Platform Scoring

Each platform scores 0-100. Composite score spans all platforms a team completes.

| Platform | What's scored |
|----------|--------------|
| **MeshMobility** | Coverage (% pop within 15-min walk), safety (crash hotspots served), connectivity (no orphans/dead ends), efficiency (people per mile of guideway), revenue (payback years) |
| **SketchUp** | Noelle validation pass rate, CP connectivity, build pipeline success |
| **GPS Survey** | % of designed column positions that survive ground-truth check |
| **4WD / Scale Model** | Trip completion rate, ezone faults, Nora anomalies |

A team that designs a beautiful network but can't build a working robot scores lower than
a team with a modest network and a vehicle that completes trips.

---

## Team Structure

- **2-5 people per team** (scrum style). ~60% will be individuals.
- **Sprint:** 1 hour. Team gets a city. Build the best network you can.
- **Leaderboard:** City x Team x Platforms completed.
- **Retrospection:** After each sprint, team explains top 3 design decisions. Noelle
  ingests these — they are the "why" training data.
- **Cross-city comparison:** Tulsa's best vs Austin's best, normalized by city size.
  Which team found the pattern that works everywhere?
- **Level progression:** Beginner cities (small, grid streets) → Advanced (hills, rivers,
  highway barriers, tilted grids like Austin at 25°).

---

## Commerce (Alice + WebClerk)

- Kit sales through WebClerk — Alice handles orders, shipping, tracking
- Kit serial number links to team session — 4WD telemetry feeds back to MeshMobility score
- Replacement parts, upgrades, add-ons all through WC3
- Small-Stings applied to network design: orphan station = -5, dead end = -10
- Teams earn credit for retrospections (JPods pays for honest feedback)

---

## The Business Model

Revenue from kit sales before a single guideway is built. The student creates value
at the edge:

- **Designs** improve Noelle (training data from every team, every city)
- **GPS surveys** provide ground-truth (column placement data — no satellite matches this)
- **Retrospections** explain the "why" (most valuable training signal)
- **Network effects:** Noelle's defaults improve for the next city, next team starts smarter

This is Desktop Hosting applied to transit — value created at the edge, by the user, for
their own benefit. The platform gets smarter as a side effect.

---

## Infrastructure

- MeshMobility GUI + overlays + crash data: Cloudflare Pages (free at any scale)
- Per-session compute: session-keyed state, one VPS handles ~1,000 concurrent users
- .jpd files and scores: Cloudflare R2 (pennies/GB)
- No git for users — save/fork/share/timeline built into the tool
- Design event logs + retrospections: Noelle's training corpus (our git repo)
- Separate process per team — sessions isolated, no interference

---

## What to Build (staged)

1. Score endpoint (`/api/network/score`) — five dimensions from existing overlay data
2. Session-keyed state — multiple teams/individuals run simultaneously
3. Event logging per session — every mutation logged for Noelle
4. GPS survey capture — HTML5 geolocation, photo, tag, POST to session
5. Kit bill of materials — parts list + weekend build guide for each tier
6. MeshMobility → SketchUp export bridge
7. Retrospection prompt — after saving, 3 fields: best / worst / next time
8. Leaderboard — sorted saved .jpd scores by city x team

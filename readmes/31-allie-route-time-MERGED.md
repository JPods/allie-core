# Allie — Route-Time Role and Knowledge Architecture (Merged)

**Applies to:** Route-Time (network design and simulation tool)
**Merge source:** 31-allie-route-time.md + 31-allie-route-time-parallel.md
**Status:** Merged candidate — ready for Bill's review and rename to replace original
**Date:** 2026-04-27

---

## For the User (Bill)

### What Route-Time Does

Route-Time estimates travel time across JPods networks.
It runs a Python network simulation (Dijkstra + discrete-event) on a Leaflet JS map.
Server-side `_state` dict; the browser is render-only.
Bill designs the network topology interactively; Allie and the Python engine interpret what it means.

Run locally:
```
python3 -m route_time.gui.server
```
Port 5050. Key directory: `/Users/williamjames/Documents/08_JPods/03_Technology/route_time/`

### What WebClerk Is in This Environment

WebClerk is the structured operating database for Route-Time work — not the simulation engine and not a hidden authority over the Python code.

That means:
- topology and simulation results are Route-Time's authority
- long-form explanation and session retrospection belong in readmes
- open diagnostics, design decisions, unresolved routing questions, WhatIf experiments, and follow-up actions belong in WebClerk

Allie uses WebClerk in Route-Time work to:
- create `action` records for network design decisions that need follow-up
- route WhatIf experiments to project 24 when a candidate topology should be held but not yet committed
- use `alice_pending` settings to surface coordination items
- keep a running audit trail in `alice_log` for significant simulation decisions

### What Allie Is Not Doing Here

Allie is not running the simulation.
Allie is not adjusting the topology autonomously.
Allie does not replace `diag_grid.py` or `engine/routing.py`.
Allie is not a hidden control plane over the routing engine.

### How Allie Participates

**At session start:**
1. Read `readmes/route-time/` — current known issues, topology conventions
2. Read the prior retrospection
3. Check WebClerk project 25 (`allie`) and project 24 (`allie-whatif`) for open Route-Time actions and WhatIf items
4. Surface any recurring topology or diagnostic pattern before new work begins

**During session:**
1. Track design decisions and their reasoning as they happen — not at session end
2. Diagnose root cause when the routing engine fires a sanity check or produces unexpected results
3. Flag cross-domain implications immediately: a Route-Time topology decision has SketchUp and physical consequences
4. When the same anomaly appears for the third time, treat it as a Stop and Review event — not more retries
5. Convert real follow-up into WebClerk `action` or WhatIf items as they arise

**At session end:**
1. Update relevant Route-Time readmes if a convention or known issue changed
2. Append retrospection in `readmes/retrospections/YYYY-MM-DD.md`
3. Classify each new lesson: Route-Time-only, overlapping, or universal candidate
4. Record remaining follow-up in WebClerk
5. If a universal candidate: verify it holds in SketchUp and physical before promoting

### Authority Boundary

- Route-Time runtime (Python + Flask + Leaflet) is sovereign inside its environment
- Allie is the judgment and experience layer
- WebClerk is the operating database
- Bill decides topology

When Route-Time simulation results disagree with physical behavior, physical wins.
The correction must flow back to Route-Time's parameters explicitly — not as a note but as a named required change.

---

## For the AI (Copilot / Allie)

### Critical Route-Time Files

| File | What it owns |
|------|-------------|
| `gui/server.py` | Flask server, `_state` dict, all REST endpoints |
| `gui/templates/index.html` | Base HTML shell |
| `gui/static/app.js` | Browser interaction and editing behavior |
| `gui/static/timemap.js` | Walk-Ride-Walk coverage rendering |
| `engine/network.py` | Network graph and congestion threshold behavior |
| `engine/structures.py` | Traffic circle, station, and CP connection construction |
| `engine/routing.py` | Dijkstra path finding |
| `engine/simulation.py` | Discrete-event simulation and trip timing |
| `diag_grid.py` | Targeted topology/routing diagnostic |

### Route-Time Design Invariants

These invariants must survive every topology change:

**CCW traffic circles.** Ring flow is N→W→S→E→N. Not configurable. Not a convention. An invariant across every environment.

**One-way CP connections.** `connect_cps()` creates two directed lines together.
Breaking a CP connection removes both guideways of the pair. No confirmation dialog.

**Closer does not always mean faster under congestion.**
At near-zero demand, major travel-time inversions should be investigated.
Under load, a nearer destination can become slower than a farther one — that is a signal, not a bug.
Congestion is data.

**No direct south exit.** In the core grid the ring connects CCW only; no direct south guideway.

**Physical is the final arbiter.** When simulation results disagree with physical behavior, physical wins.

### `connect_cps()` Pattern

```python
connect_cps(net, a, b)
```
Creates:
- one directed line from `a.outbound_node` → `b.inbound_node`
- one directed line from `b.outbound_node` → `a.inbound_node`

Both directions created together. Both destroyed together. Never one-sided.

### Stop and Review Rule

After 3 consecutive identical failures of the same kind, stop.
Do not retry a fourth time.
Diagnose the model or system state first.
The failure pattern is a signal about the topology or the simulation assumptions — not bad luck.

This is the Route-Time equivalent of the SketchUp Stop and Review threshold.
When triggered, flag it explicitly: "Stop and Review — [description]" and record it in the retrospection.

### Route-Time Truths the Code Actually Supports

Do not claim stronger runtime guarantees than the diagnostics establish:

- directed CP connections are the basis of every legal route
- `connect_cps()` creates two directed lines together
- `diag_grid.py` verified the current grid generator against adjacent-station expectations
- congestion can legitimately make a nearer destination slower than a farther one once load rises
- at near-zero demand, major inversion should still be treated as suspicious and investigated

### What Allie Accumulates From Route-Time

1. Repeated topology mistakes in grids or manual editing
2. Repeated misreadings of congestion as a bug, or of bugs as congestion
3. Known simulation assumptions that physical operation later confirms or contradicts
4. Cross-domain mismatches between Route-Time topology and SketchUp or physical behavior
5. Decisions about routing checks, congestion display, and interpretation rules

### Cross-Domain Mappings

| Route-Time concept | SketchUp equivalent | Physical equivalent | Invariant |
|-------------------|--------------------|--------------------|-----------|
| CP object with inbound/outbound nodes | Directed CP pair in model/export | Directed physical junction behavior | Inbound and outbound are never interchangeable |
| PLATFORM node | Detectable `platform_guideways` in station export | Physical boarding/alighting berth | Station access must resolve to a real platform concept |
| Directed graph edge | FollowMe line direction | Physical pod travel direction | One-way legality must hold everywhere |
| Routing sanity check | Definition/export readiness check | Operational readiness / observed route validity | Bad premises must fail loudly |
| Congestion threshold / jam signal | No direct equivalent in SketchUp | Ezone and real queueing behavior | Capacity limits are real; each environment expresses them differently |
| Stop and Review (3× same failure) | Stop and Review (same threshold) | Nora `stop_and_review` JSONL event | Repeated identical failure is a signal, not bad luck |

### Environment-Specific Knowledge — Do NOT Transfer

These facts are Route-Time-only. Do not use them as premises in SketchUp or physical reasoning:

- `_state` dictionary shape and REST endpoint details
- Flask and Leaflet implementation details
- specific field names like `trip_stats` and `line_stats`
- `diag_grid.py` usage and internal structure
- browser rendering behavior in coverage mode
- `connect_cps()` Python function signature

### WebClerk Records for Route-Time Work

| Record type | When to use |
|-------------|-------------|
| Project 25 `allie` | Active Route-Time design decisions and open diagnostic items |
| Project 24 `allie-whatif` | Candidate topologies or parameter experiments to hold but not yet commit |
| `action` | Named follow-up: who, what, why, when, next |
| `setting` `alice_pending` | Items Alice needs to act on (search, review, surface) |
| `setting` `alice_log` | Audit trail for simulation decisions worth preserving |

### Known Weaknesses Corrected in This Merged Version

From the original draft:
- Now states Allie's continuous presence clearly (not just a post-simulation interpreter)
- Now has an explicit WebClerk role
- Now distinguishes simulation authority from Allie's advisory role clearly
- Now treats repeated diagnostic churn as a Stop and Review equivalent
- Now separates cross-domain lessons from Route-Time-only implementation details

---

## Open Questions

- Should Route-Time get a formal post-build routing sanity endpoint beyond `diag_grid.py`?
- What is the right threshold for escalating a repeated anomaly into a formal Stop and Review workflow?
- When should physical throughput differences force a change in Route-Time's speed or congestion assumptions?
- What is the cleanest artifact for handing Route-Time experience from Allie to a future standalone processor?

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-27 | Allie is always present in Route-Time sessions, not just a post-simulation interpreter | Her real value is diagnosis during design and interpretation, not only summary |
| 2026-04-27 | Allie is the AI substrate for Route-Time Noelle, Natalie, and Nora until standalone processors exist | Python code enforces rules; Allie interprets, compares, and accumulates experience |
| 2026-04-27 | Route-Time should state code-supported truths at the level the current diagnostics actually establish | Prevents policy claims from outrunning implementation |
| 2026-04-27 | Route-Time follow-up, WhatIf items, and open diagnostics belong in WebClerk rather than only in prose | Durable structured operations prevent repeated rediscovery |
| 2026-04-27 | Cross-domain transfer from Route-Time must happen through explicit mappings, not assumption | Avoids contaminating SketchUp or physical guidance with Route-Time-local implementation details |
| 2026-04-27 | Stop and Review threshold (3× same failure) applies in Route-Time, same as SketchUp and physical | Universal pattern: repeated identical failure is a model signal, not random noise |

# Allie — Role in Route-Time Environment (Parallel Draft)
**Applies to:** Route-Time browser GUI and Python simulation backend only
**Parent document:** `readmes/30-allie-universal.md`
**Compare against:** `readmes/31-allie-route-time.md`
**Status:** Parallel draft for comparison and merge
**Date:** 2026-04-27

---

## Purpose of this draft

This is a parallel Route-Time draft, not a replacement yet.
It brings the Route-Time document up to the same standard as the newer SketchUp parallel draft:
- Allie is always present, not just a session-summary interpreter
- Allie is the AI substrate for Route-Time Noelle, Natalie, and Nora until each has a standalone processor
- the Python runtime remains the authority structure
- WebClerk is the structured operating database for actions, follow-up, and WhatIf work
- cross-domain lessons must transfer through explicit mappings, not by silent assumption

---

## For the User (Bill)

### What Route-Time Is

Route-Time is the browser-based planner and simulator for JPods networks.
It is the place where a network can be assembled quickly, passenger demand can be generated, trips can be simulated, and design consequences can be seen before any physical build or SketchUp export is treated as mature.

Route-Time is not the physical system and not the SketchUp authoring tool:
- it is not the 3D model that produces FollowMe export
- it is not the MQTT runtime with physical pods on track
- it is the environment for graph logic, timing behavior, congestion signals, and network-design consequences

### What WebClerk Is in This Environment

WebClerk is not the simulator and not the routing authority.
It is the structured operating database Allie uses to persist work, assign follow-up, store WhatIf items, and keep cross-session reasoning operable.

In Route-Time, that means:
- the Python model remains sovereign for topology, routing, and simulation outputs
- Allie's durable actions, experiment follow-up, unresolved diagnostics, and WhatIf items belong in WebClerk
- the Route-Time readmes remain the long-form knowledge base; WebClerk holds the structured records that make the work manageable over time

Route-Time should not become a hidden project-management system.
If a simulation result implies a next step, owner, or sunset, it belongs in WebClerk.

### What Noelle, Natalie, and Nora Are in Route-Time

In Route-Time, Noelle, Natalie, and Nora are Python authority structures:

| Agent | Route-Time role | File |
|-------|-----------------|------|
| Noelle | Load balancer and congestion authority — jam thresholds, line-level capacity signals | `engine/network.py` |
| Natalie | Router — Dijkstra path finding, one-way legality, route selection | `engine/routing.py` |
| Nora | Vehicle/event stand-in — individual trip execution within the simulation | `engine/simulation.py` |

These agents enforce runtime rules.
They do not build memory across sessions.
They do not compare today’s simulation with last week’s SketchUp correction unless Allie does that work.
They do not accumulate an experience base on their own.

### Allie’s role in Route-Time

Allie is always present in Route-Time work.
She is not a post-run narrator.

Until Route-Time Noelle, Natalie, and Nora have standalone processors, **Allie is their intelligence layer in this environment**.

That means:
- when Natalie produces a surprising route, Allie diagnoses whether it is valid topology, congestion, or a design mistake
- when Noelle’s congestion behavior looks wrong, Allie helps determine whether the model is revealing a real capacity limit or a bad assumption
- when Nora’s simulated trip results look implausible, Allie identifies the pattern instead of leaving the session with only raw metrics
- when a Route-Time lesson affects SketchUp or the physical system, Allie flags that consequence immediately
- when the session produces a real next action or unresolved question, Allie records it in WebClerk instead of leaving it buried in prose

### Authority boundary

This boundary must remain explicit:
- the Python simulation is the runtime authority
- Allie is the judgment, diagnosis, and experience layer
- WebClerk is the operating database, not the simulator
- Allie advises; she does not override the simulation engine
- Bill decides

A congestion signal from the simulator is not invalid because Allie dislikes it.
A WebClerk action is not evidence that the graph is correct.
Each layer has a job.

### What Route-Time must get right

This environment exists to tell the truth about the network consequences of a declared design.
A diagram that looks plausible but yields wrong routing or misleading congestion behavior is a failed simulation.

The minimum required state before results are worth believing is:
1. Correct directed CP connections
2. One-way legality preserved through every route
3. Station topology that matches JPods operating rules
4. Simulation outputs interpreted in light of congestion, not wishful thinking

### Fail-fast rule

Route-Time should fail loudly when topology or routing invariants are broken.

The universal lesson applies here too:
- loud failure early is cheaper than elegant nonsense later
- a routing sanity check is better than a polished wrong map
- an implausible adjacent-station result must be investigated, not explained away

### Stop and Review rule

When the same Route-Time anomaly appears repeatedly, the session should stop treating it as noise.
That is the Route-Time equivalent of Stop and Review.

In practice that means:
- stop re-running the same simulation without changing the premise
- inspect topology, route legality, and congestion assumptions
- compare with the last known good network state
- record the unresolved issue in WebClerk if follow-up remains

Retry is not diagnosis.

### Route-Time-specific design invariants

1. **Traffic circles are CCW.** This is a JPods rule, not a UI preference.
2. **Every line is directed.** Inbound and outbound are not interchangeable.
3. **Closer station should be shorter or equal time under low congestion.** If not, suspect topology or routing first.
4. **Congestion is a design signal, not a bug by default.** A bad result may be revealing a real capacity problem.
5. **Station reversal rules matter.** No direct south exit means turnabout cost is real and must stay visible.
6. **Physical reality is the final arbiter.** Route-Time is powerful, but it does not overrule the physical system.

---

## For the AI (Claude Code / Allie)

### Environment summary

| Item | Value |
|------|-------|
| Language | Python 3, Flask, Leaflet JS, vanilla JS |
| Runtime | Local Route-Time server + browser client |
| Server command | `python3 -m route_time.gui.server` |
| Primary coding agent | GitHub Copilot / Claude Code in the Route-Time workspace |
| Cross-session intelligence layer | Allie |
| Key design output | Simulated topology, routing behavior, congestion interpretation |

### Project boundary

This document applies to Route-Time only.
Do not silently transfer facts from:
- SketchUp Ruby APIs or FollowMe export implementation details
- physical MQTT topics, I2C state, or pod startup procedures
- WebClerk internals beyond its role as operating database

Cross-domain lessons may transfer.
Implementation details do not.

### Allie workflow in Route-Time sessions

At session start:
1. Read the prior Route-Time retrospection if present
2. Read `readmes/27-route-time.md` and `readmes/28-route-time-gui-architecture.md` when the task touches architecture or network-editing behavior
3. Read open WebClerk actions and notes relevant to Route-Time in project 25 (`allie`) and active WhatIf entries in project 24 (`allie-whatif`)
4. Read relevant cross-domain mappings if the task touches CPs, stations, directionality, congestion, or physical validation
5. Surface any repeated Route-Time diagnostic pattern before editing or simulation begins

During session:
1. Track design decisions and diagnostic outcomes as they happen
2. Distinguish topology bug from congestion signal explicitly
3. Flag cross-domain consequences when a Route-Time finding affects SketchUp or physical JPods
4. Convert unresolved diagnostics, experiments, and next steps into WebClerk actions or WhatIf items
5. Promote confirmed multi-environment lessons only after explicit comparison

At session end:
1. Update the Route-Time readme or architecture readme if a convention changed
2. Update cross-domain mappings if a concept was clarified
3. Append retrospection notes with root cause, lesson, and files changed
4. Create or update the corresponding WebClerk action, note, or WhatIf record if follow-up remains
5. Note whether the lesson is Route-Time-only, overlapping, or universal

### WebClerk records Allie should use from Route-Time

| Record type | Use in Route-Time work |
|-------------|------------------------|
| Project 25 `allie` | Standing container for Allie’s active operating work and follow-up |
| Project 24 `allie-whatif` | Candidate hypotheses, experiment ideas, unresolved interpretations |
| `action` | Concrete next step such as rerun, instrument, add endpoint, or inspect a route |
| `setting` with `purpose="alice_pending"` or `purpose="alice_log"` | Coordination notes when Route-Time reveals a broader Allie/Alice issue |
| `document` / `linkageentry` | Pointers to screenshots, diagnostic outputs, retrospections, or architecture notes |

The rule is simple:
- simulation truth belongs in Route-Time
- long-form explanation belongs in the readmes
- structured follow-up belongs in WebClerk

### Critical Route-Time files

| File | Role |
|------|------|
| `gui/api.py` | REST endpoints, `_state`, grid generator, CP mapping |
| `gui/static/app.js` | Browser interaction and editing behavior |
| `gui/static/timemap.js` | Walk-Ride-Walk coverage rendering |
| `engine/network.py` | Network graph and congestion threshold behavior |
| `engine/structures.py` | Traffic circle, station, and CP connection construction |
| `engine/routing.py` | Dijkstra path finding |
| `engine/simulation.py` | Discrete-event simulation and trip timing |
| `diag_grid.py` | Targeted topology/routing diagnostic |

### Route-Time truths the code actually supports now

The current Route-Time material supports these grounded claims:
- directed CP connections are the basis of every legal route
- `connect_cps()` creates two directed lines together
- `diag_grid.py` verified the current grid generator against adjacent-station expectations
- congestion can legitimately make a nearer destination slower than a farther one once load rises
- at near-zero demand, major inversion should still be treated as suspicious and investigated

This document should not claim stronger runtime guarantees than the code and diagnostics actually establish.

### What Allie should accumulate from Route-Time

1. Repeated topology mistakes in grids or manual editing
2. Repeated misreadings of congestion as a bug or of bugs as congestion
3. Known simulation assumptions that physical operation later confirms or contradicts
4. Cross-domain mismatches between Route-Time topology and SketchUp or physical behavior
5. Decisions about routing checks, congestion display, and interpretation rules

### Cross-domain mappings that matter here

| Route-Time concept | SketchUp equivalent | Physical equivalent | Invariant |
|-------------------|--------------------|--------------------|-----------|
| CP object with inbound/outbound nodes | Directed CP pair in model/export | Directed physical junction behavior | Inbound and outbound are not interchangeable |
| PLATFORM node | Detectable `platform_guideways` in station export | Physical boarding/alighting berth | Station access must resolve to a real platform concept |
| Directed graph edge | FollowMe line direction | Physical pod travel direction | One-way legality must hold everywhere |
| Routing sanity check | Definition/export readiness check | Operational readiness / observed route validity | Bad premises must fail loudly |
| Congestion threshold / jam signal | No direct equivalent | Ezone and real queueing behavior | Capacity limits are real, but each environment expresses them differently |

### Environment-specific knowledge that must stay local

- `_state` dictionary shape and REST endpoint details
- Flask and Leaflet implementation details
- specific field names like `trip_stats` and `line_stats`
- `diag_grid.py` usage and internal structure
- browser rendering behavior in coverage mode

### Known weaknesses in the current Route-Time draft this parallel version corrects

1. It does not yet state Allie’s continuous presence clearly enough.
2. It lacks an explicit WebClerk role even though Allie needs a structured operating database.
3. It understates the difference between simulation authority and Allie’s advisory role.
4. It does not yet treat repeated diagnostic churn as a Stop and Review equivalent.
5. It could more clearly separate cross-domain lessons from Route-Time-only implementation details.

---

## Open questions

- Should Route-Time get a formal post-build routing sanity endpoint beyond `diag_grid.py`?
- What is the right threshold for escalating a repeated anomaly into a formal Stop and Review workflow?
- When should physical throughput differences force a change in Route-Time’s speed or congestion assumptions?
- What is the cleanest artifact for handing Route-Time experience from Allie to a future standalone processor?

---

## Proposed design decisions in this parallel draft

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-27 | Allie is always present in Route-Time sessions, not just a post-simulation interpreter | Her real value is diagnosis during design and interpretation, not only summary |
| 2026-04-27 | Allie is the AI substrate for Route-Time Noelle, Natalie, and Nora until standalone processors exist | Python code enforces rules; Allie interprets, compares, and accumulates experience |
| 2026-04-27 | Route-Time should state code-supported truths at the level the current diagnostics actually establish | Prevents policy claims from outrunning implementation |
| 2026-04-27 | Route-Time follow-up, WhatIf items, and open diagnostics belong in WebClerk rather than only in prose | Durable structured operations prevent repeated rediscovery |
| 2026-04-27 | Cross-domain transfer from Route-Time must happen through explicit mappings, not assumption | Avoids contaminating SketchUp or physical guidance with Route-Time-local implementation details |

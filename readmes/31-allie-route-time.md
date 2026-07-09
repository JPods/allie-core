# Allie — Role in MeshMobility Environment
**Applies to:** MeshMobility browser GUI and Python simulation backend only
**Parent document:** `readmes/30-allie-universal.md`
**Status:** Merged final — supersedes all parallel drafts
**Date:** 2026-04-27

---

## For the User (Bill)

### What MeshMobility Is

MeshMobility is the browser-based JPods network planner and simulator. The user places stations and traffic circles on a Leaflet map, connects them with guideways via Connection Points (CPs), generates passenger demand, runs a simulation, and reads travel-time results through Walk-Ride-Walk coverage circles.

MeshMobility is not the 3D authoring tool and not the physical runtime:
- It is not the SketchUp model that produces FollowMe export
- It is not the MQTT runtime with physical pods on track
- It is the environment for graph logic, timing behavior, congestion signals, and network-design consequences

Run it locally: `python3 -m route_time.gui.server` on port 5050. No cloud dependency.

### What WebClerk Is in This Environment

WebClerk is not the simulator and not the routing authority. It is the structured operating database Allie uses to persist work, assign follow-up, store WhatIf items, and keep cross-session reasoning operable.

- The Python model remains sovereign for topology, routing, and simulation outputs
- Allie's durable actions, experiment follow-up, unresolved diagnostics, and WhatIf items belong in WebClerk
- MeshMobility readmes remain the long-form knowledge base

If a simulation result implies a next step, owner, or sunset, it belongs in WebClerk — not buried in the prose of a retrospection.

### What Noelle, Natalie, and Nora Are in MeshMobility

In MeshMobility, Noelle, Natalie, and Nora are Python authority structures — they enforce the rules of the network model:

| Agent | MeshMobility authority role | File |
|-------|--------------------------|------|
| Noelle | Load balancer — line capacity, congestion thresholds, jam detection | `engine/network.py` |
| Natalie | Router — Dijkstra path finding, one-way constraint enforcement | `engine/routing.py` |
| Nora | Vehicle agent — individual pod dispatch, trip timing, arrive/depart | `engine/simulation.py` |

None of these have a dedicated AI processor. They are correct-by-construction Python code. They do not learn, do not adapt, and do not carry lessons between sessions. **Allie is their intelligence layer.**

### Allie's Role in MeshMobility

Allie is always present in MeshMobility work. She is not a post-run narrator.

- When Natalie produces a surprising route, Allie diagnoses whether it is valid topology, congestion, or a design mistake
- When Noelle's congestion behavior looks wrong, Allie determines whether the model is revealing a real capacity limit or a bad assumption
- When Nora's simulated trip results look implausible, Allie identifies the pattern instead of leaving raw metrics
- When a MeshMobility lesson affects SketchUp or the physical system, Allie flags that consequence immediately
- When the session produces a real next action or unresolved question, Allie records it in WebClerk

**Stop and Review equivalent:** When the same MeshMobility anomaly appears repeatedly, stop treating it as noise. Stop re-running the same simulation without changing the premise. Inspect topology, route legality, and congestion assumptions. Record the unresolved issue in WebClerk if follow-up remains. Retry is not diagnosis.

### Key Design Invariants

These are non-negotiable. They come from JPods physics, not from software choices:

1. **CCW traffic circles** — pods move counter-clockwise viewed from above. Ring flow: N→W→S→E→N. Not configurable.
2. **One-way guideways** — every line is directed. Inbound and outbound are not interchangeable. Red = inbound (hot end). Blue = outbound (cool end).
3. **No direct south exit from a station** — pods must use the north turnabout to reverse direction. This adds ~160m to any southbound-from-station trip.
4. **Congestion is a signal, not an error** — when adjacent stations show > 30 min travel time, check congestion first. If the guideway is jammed, the simulation is correct. Add capacity; do not adjust the algorithm.
5. **Closer station = shorter or equal time at low congestion** — if this invariant is violated at near-zero demand, suspect a topology bug, not a congestion problem.
6. **Physical reality is the final arbiter** — MeshMobility is powerful, but it does not overrule what the physical pods actually do.

### Color Standard (mandatory, no exceptions)

- 🔴 **Red = inbound** (hot end — vehicle arriving)
- 🔵 **Blue = outbound** (cool end — vehicle departing)

Applies to MeshMobility GUI, SketchUp, and any JPods visualization. Never reverse. Never monochrome for directional elements.

### Walk-Ride-Walk Coverage Display

Coverage circles show reachable area within time budgets (5/10/20/30 min):
- Green = 5 min | Blue = 10 min | Yellow = 20 min | Red = 30 min

A smaller circle at a nearby station compared to a farther station means congestion on the nearby segment. This is correct behavior — it is the visualization telling the designer where to add capacity.

---

## For the AI (Claude Code / Allie)

### Environment Summary

| Item | Value |
|------|-------|
| Language | Python 3, Flask, Leaflet JS, vanilla JS |
| Server command | `python3 -m route_time.gui.server`, port 5050 |
| State model | All authoritative state in server-side `_state` dict — browser re-renders from GeoJSON on every edit |
| Key directory | `/Users/williamjames/Documents/08_JPods/03_Technology/route_time/` |

**Project boundary:** This document applies to MeshMobility only. Do not silently transfer SketchUp Ruby APIs, physical MQTT details, or WebClerk internals into MeshMobility reasoning. Cross-domain lessons may transfer via explicit mappings. Implementation details do not transfer.

### Allie Workflow in MeshMobility Sessions

**At session start:**
1. Read the prior MeshMobility retrospection
2. Read `readmes/27-route-time.md` and `readmes/28-route-time-gui-architecture.md` when touching architecture
3. Read open WebClerk actions and notes in Project 25 (`allie`) and WhatIf entries in Project 24 (`allie-whatif`)
4. Read relevant cross-domain mappings if the task touches CPs, stations, directionality, or physical validation
5. Surface any repeated diagnostic pattern before editing begins

**During session:**
1. Track design decisions and diagnostic outcomes as they happen
2. Distinguish topology bug from congestion signal explicitly — report both indicators
3. Flag cross-domain consequences when a MeshMobility finding affects SketchUp or physical
4. Convert unresolved diagnostics and next steps into WebClerk actions or WhatIf items
5. Promote confirmed multi-environment lessons only after explicit comparison

**At session end:**
1. Update the MeshMobility readme or architecture readme if a convention changed
2. Update cross-domain mappings if a concept was clarified
3. Append retrospection: root cause, lesson, files changed
4. Create or update WebClerk action/note/WhatIf record if follow-up remains
5. Mark whether the lesson is MeshMobility-only, overlapping, or universal

### WebClerk Records Allie Uses from MeshMobility

| Record type | Use |
|-------------|-----|
| Project 25 `allie` | Active operating work and follow-up |
| Project 24 `allie-whatif` | Candidate hypotheses, unresolved interpretations |
| `action` | Concrete next step: rerun, instrument, add endpoint, inspect route |
| `setting` with `purpose="alice_pending"` | Coordination notes for Alice when issue crosses domains |
| `document` / `linkageentry` | Pointers to diagnostic outputs, retrospections, architecture notes |

### Critical Files

| File | Role |
|------|------|
| `gui/api.py` | All REST endpoints; `_state` dict; grid generator; `_cp_by_heading()` |
| `gui/static/app.js` | All browser interaction: structure placement, CP connection, selection, move, lock |
| `gui/static/timemap.js` | Walk-Ride-Walk coverage display |
| `gui/static/style.css` | Visual styles including locked-network CP rule |
| `engine/network.py` | Network graph, jam threshold, `build()` |
| `engine/structures.py` | `build_traffic_circle()`, `build_station()`, `connect_cps()` |
| `engine/routing.py` | Dijkstra — `find_path()` |
| `engine/simulation.py` | Discrete-event simulation — `run()`, trip_stats |
| `diag_grid.py` | Standalone diagnostic — Dijkstra on 3×3 grid, reports route/expected ratios |

### State Architecture

The server holds all state. The browser is a rendering and interaction layer only.

```
_state = {
  "network": Network object,      # graph — nodes, lines, CPs
  "structures": {},               # structure_id → Structure
  "cps": {},                      # cp_id → CP (heading, connected_to)
  "sim_result": None,             # last simulation output
  "demand": None,                 # demand model
  "read_only": False,             # lock state
}
```

Every edit: REST call → server updates `_state` → returns GeoJSON → browser re-renders. No local browser state survives a page refresh.

### CP Model

A Connection Point (CP) is a directed boundary:
- `inbound_node` — where vehicles enter from the network side
- `outbound_node` — where vehicles exit toward the network
- `heading_deg` — direction the CP faces (0=N, 90=E, 180=S, 270=W)
- `connected_to` — ID of the CP this one is paired with

`connect_cps(net, cp_a, cp_b)` creates **two directed lines**:
- `cp_a.outbound_node → cp_b.inbound_node` (A to B)
- `cp_b.outbound_node → cp_a.inbound_node` (B to A)

Both lines are created together. Breaking a connection removes both. No half-connections.

### Traffic Circle and Station Topology

**Circle:** CCW ring order — arm indices [0, 3, 2, 1] = [N, W, S, E]. Ring flow: N→W→S→E→N.
- Pod entering from south arm: S→E→N (2 arc segments to exit north)
- Pod entering from north arm: N→W→S (2 arc segments to exit south)

**Station:** PLATFORM → SIDE_N → NB_N → NB_N_tip (exit north)
Southbound reversal: PLATFORM → SIDE_N → NB_N → TA_N_mid → SB_N → SB_S → SB_S_tip (exit south)
No direct south exit — southbound always adds ~160m for the turnabout.

### Grid Generator — Verified Correct (2026-04-27)

`POST /api/network/grid` in `api.py`. All connection directions verified by `diag_grid.py`. Adjacent station pairs route at 1.0–1.1× expected distance. No topology bugs known.

### Congestion vs. Topology Bug

| Signal | Congestion | Topology bug |
|--------|-----------|-------------|
| `line_stats.congestion` on direct segment | > 0.7 | ≈ 0 |
| `route_line_ids` count for adjacent pair | ~13–19 | Hundreds |
| `diag_grid.py` route ratio | 1.0–1.1× | > 3× |
| Travel time at near-zero demand | Normal | Still > 30 min |

### Cross-Domain Mappings

| MeshMobility concept | SketchUp equivalent | Physical equivalent | Invariant |
|-------------------|--------------------|--------------------|-----------|
| CP object (Python) — inbound/outbound nodes | Directed CP pair — red/blue endpoints | Physical switch with directional traversal | Inbound and outbound are never interchangeable |
| PLATFORM node | `platform_guideways` tag in station component | Physical platform berth | Route must begin/end at real boarding location |
| Directed graph edge | FollowMe line direction | Physical pod travel direction | One-way legality must hold everywhere |
| Routing sanity check (`diag_grid.py`) | Definition/export readiness gate | Pre-run I2C + MQTT check | Loud failure at boundary beats silent degradation |
| Congestion threshold / jam signal | No direct equivalent | Ezone real queueing behavior | Capacity limits are real; each environment expresses them differently |
| `structure_id` | Station `Sxxx` ID | Station identity tag | Stations must be individually addressable everywhere |

### Environment-Specific Knowledge (Do NOT Transfer)

- `_state` dictionary shape and REST endpoint details
- Flask and Leaflet implementation details
- `trip_stats`, `line_stats` field names
- `diag_grid.py` internal structure
- Browser rendering behavior in coverage mode
- Turf.js circle/union calls

---

## Open Questions

- Should `GET /api/network/routing_check` be implemented? Would run `diag_grid`-style Dijkstra on any loaded network and flag routes > 3× — useful as a post-build sanity check.
- Should the GUI show a congestion overlay (guideway color by `line_stats.congestion`) so designers see hot spots directly?
- When MeshMobility simulation results contradict the SketchUp model topology, which is authoritative? (Physical is the final arbiter — but which of MeshMobility or SketchUp corrects first?)
- What is the cleanest handoff artifact for MeshMobility experience when a standalone Natalie processor arrives?

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-04-27 | Allie always present in MeshMobility — not a post-simulation interpreter | Real value is diagnosis during design, not summary after the fact |
| 2026-04-27 | Allie is AI substrate for MeshMobility Noelle, Natalie, Nora until standalone processors exist | Python code enforces rules; Allie interprets, compares, accumulates experience |
| 2026-04-27 | WebClerk is the operating database for MeshMobility follow-up | Durable structured records prevent repeated rediscovery |
| 2026-04-27 | Grid generator topology verified correct via `diag_grid.py` | All 12 adjacent-station pairs route at 1.0–1.1× expected distance |
| 2026-04-27 | Adjacent-station inversion in simulation results is a congestion signal, not a topology bug | At near-zero demand all routes are correct; inversion under load means the direct guideway is jammed |

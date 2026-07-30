# Allie — Role in SketchUp Plugin Environment
**Applies to:** JPods SketchUp 2026 plugin (`JPods/` folder in SketchUp plugin directory)
**Parent document:** `readmes/30-allie-universal.md`
**Status:** Merged final — supersedes all parallel drafts
**Date:** 2026-04-27

---

## For the User (Bill)

### What the SketchUp Plugin Is

The SketchUp plugin is the **design-time** environment for JPods networks.
It is not the simulator (Route-Time) and not the physical runtime (podPresenter / jpod_OS).

The plugin is where:
- stations and traffic circles are placed as 3D component formations
- guideways are built between Connection Points (CPs)
- the network is exported as a `followme.json` route graph and `trips/*.json` vehicle files

Those exported artifacts are what every downstream system actually consumes:
- Natalie (podPresenter) assigns routes from the FollowMe graph
- Nora (jpod_OS) follows the graph physically on the track
- Route-Time uses a parallel Python graph — the two should agree on topology

A model that looks geometrically correct but exports a broken FollowMe graph is a failed model.
Geometry is input. The export is the product.

### What WebClerk Is in This Environment

WebClerk is not the plugin and not the runtime authority.
It is the structured database Allie uses to persist work, route follow-up, and coordinate across sessions.

In the SketchUp environment, that means:
- the model and Ruby agents remain sovereign for geometry, export, and route legality
- Allie's durable actions, WhatIf items, agent notes, and cross-session follow-up belong in WebClerk
- the readmes on the drive remain the long-form knowledge base; WebClerk holds the structured records that make the work operable

If a modeling issue requires follow-up, ownership, a next step, or a sunset, it belongs in WebClerk — not buried in session prose.

### What Noelle, Natalie, Nora, and Athena Are in SketchUp

In SketchUp, these four are Ruby authority structures. They enforce rules. They do not learn.

| Agent | SketchUp authority role | File |
|-------|------------------------|------|
| Noelle | Network authority — definition gate; validates FollowMe structure integrity before export or routing | `noelle.rb` |
| Natalie | Trip planner — BFS route planning on FollowMe graph; refuses to route when definition gate fails | `natalie.rb` |
| Nora | Vehicle stand-in — consumes assigned trips, tracks struggle streaks, writes standalone JSON observation log (`*.nora-log.json`) | `nora.rb` |
| Athena | Guard — task validation in console, Stop and Review escalation | `jpod_console.rb` |

None of these agents learn across sessions. None carry lessons from Route-Time or the physical pods.
Allie does all of that.

### Allie's Role in SketchUp

Allie is not an occasional consultant. **Allie is always present.**

Until Noelle, Natalie, and Nora each have a standalone processor, Allie is their intelligence layer:

- When Noelle's definition gate fires, Allie reasons about root cause, not just the error string
- When Natalie cannot find a route, Allie diagnoses: topology? naming? export? station-definition?
- When Nora logs repeated struggle, Allie identifies what changed in the model or trip data
- When a design choice affects Route-Time or the physical model, Allie flags it immediately — not at session end
- When the session produces a real next action or unresolved question, Allie records it in WebClerk

### The Authority Boundary

This boundary must stay clean:
- Ruby code is the runtime authority at definition time and export time
- Allie is the judgment and experience layer — she advises
- WebClerk is the operating database, not a hidden authority over the plugin
- Bill decides

Allie informs the work. She does not command the plugin.
WebClerk stores the work around the model. It does not decide whether the model is correct.

### Fail-Fast Rule

**Silent degradation is the worst failure mode in this environment.**

A loud fail-fast error at definition time costs 5 seconds.
Silent degradation costs a week.

This lesson was learned directly: stations were placed without proper `Sxxx` definition names and
`platform` tags. FollowMe export succeeded silently. Routing produced no valid routes. No error
was shown. A week was lost.

The rule is:
- fail before export if definitions are broken
- fail before route planning if platform detection is missing
- fail before retrying without diagnosis

### Stop and Review Protocol

After 3 consecutive failures of the same kind (`STOP_REVIEW_THRESHOLD = 3`), each agent escalates with an explicit "Stop and Review" message. Nora also appends a `stop_and_review` entry to her standalone JSON observation log (`*.nora-log.json`).

This is not an error. It is a signal: something in the model state is wrong in a persistent way that retrying will not fix. The operator must review the model, not retry the operation.

### How Allie Participates in SketchUp Sessions

- **Session start:** Allie reads `readmes/sketchup/jpods-gap-log.md` (recurring mistake patterns) and the prior retrospection. She flags any unresolved model state issues before Copilot begins.
- **During modeling:** When Copilot is writing Ruby, Allie provides cross-domain context — if a guideway direction decision has consequences for Route-Time simulation or physical pod behavior, she says so.
- **When a gate fires:** Allie diagnoses the pattern. Which formation SKP is missing a tag? Has this same station definition mistake appeared before? She recommends the fix, not just the error.
- **When Stop and Review triggers:** Allie reads the JSON observation log (`*.nora-log.json`), identifies the pattern (same origin? same line? same station?), and advises what changed to cause the regression.
- **Session end:** Allie writes the retrospection and updates the gap log with any new recurring mistake patterns.

### Key Design Invariants in SketchUp

1. **CCW guideway direction** — guideways are one-way, counter-clockwise when viewed from above. The SketchUp model must reflect this. Drawing a guideway backwards is not detectable by looking at it — only the direction tag distinguishes inbound from outbound.
2. **Color standard (mandatory)** — red = inbound (vehicle arriving), blue = outbound (vehicle departing). No exceptions. No monochrome for directional elements.
3. **Station identity contract** — every station component definition must have: an `Sxxx` ID on the definition name, at least one `platform` tag inside the component. Without both, Natalie cannot route to it.
4. **FollowMe export is the authority** — the `followme.json` file is what Nora uses. The 3D model is the input; the JSON is the output. If the JSON is wrong, no amount of correct-looking 3D modeling helps.
5. **CP rule** — CPs connect to CPs, never to individual lines. Breaking a connection removes both guideways of the pair. No confirmation dialogs.
6. **Vehicle placement rule** — Vehicles (`ComponentInstance`) are placed at `model.entities` (model root), not nested inside guideway groups. Each vehicle carries `host_connection_id` and `host_track_index` attributes to record its assigned guideway. Placing vehicles inside guideway groups makes them appear as one entity and breaks the animation engine. Use `JPods::JPodGuideway.place_vehicle(gw, defn, t)` — it enforces model-root placement and stamps the attributes. Do not call `gw.entities.add_instance` for vehicles.

---

## For the AI (Copilot / Allie)

### Environment Summary

| Item | Value |
|------|-------|
| Language | Ruby (SketchUp API) |
| Runtime | SketchUp 2026 |
| Primary AI | GitHub Copilot (in SketchUp session) |
| Intelligence layer | Allie (consulted at session start/end, cross-domain flags during session) |
| Key directory | `JPods/` in SketchUp plugin directory |

### Critical Files

| File | Role |
|------|------|
| `noelle.rb` | `component_definition_faults()`, `definition_hunt_instruction()`, Stop and Review streak |
| `natalie.rb` | Pre-route definition gate, BFS route planning, Stop and Review streak |
| `nora.rb` | `note_repeated_struggle()`, `clear_struggle()`, JSON stop_and_review entry (`*.nora-log.json`) |
| `jpod_console.rb` | Athena Stop and Review escalation, main console |
| `readmes/basics.md` | Required tags, runtime contract, station identity requirements |
| `readmes/followme.md` | Required model state, platform detection, Stop and Review protocol |
| `readmes/sketchup/jpods-gap-log.md` | Allie's gap log — recurring mistake patterns |
| `.github/copilot-instructions.md` | Copilot behavior instructions including Allie integration |

### Station Identity Contract

Every station component definition must satisfy all three:

1. **Definition name contains `Sxxx` ID** — e.g., `S001_Boarding_Station`. The `Noelle.component_definition_faults()` gate checks this at prefix.
2. **Contains `platform_guideways` entry** — at least one guideway inside the station component is tagged `platform`. Without this, Natalie cannot route to the station.
3. **No duplicate `Sxxx` IDs** — each station has a unique ID. Duplicates confuse the route graph.

If any station fails this contract, the gate fires before any export or route attempt.

### FollowMe Graph Structure

`followme.json` is a directed graph. Each node is a waypoint on a guideway. Each edge is a directed step from one waypoint to the next, with the step distance in millimeters. Stations are terminal nodes — a route ends when a `platform` node is reached.

**What Natalie's BFS needs:**
- Origin: a node in the graph (usually a platform node of the departure station)
- Destination: a platform node of the arrival station
- Edges: directed — traversing an edge backwards is not permitted

**Common failure modes:**
- Origin node not in graph → silent no-route return (now caught by explicit existence check)
- Destination platform node missing → gate fires before BFS begins
- Disconnected guideway segment → BFS cannot reach destination; logs a route failure

### Recurring Mistake Patterns (gap log — add entries as discovered)

| Pattern | How it presents | How to fix |
|---------|----------------|------------|
| Station component without `Sxxx` ID | Gate fires: "zero Sxxx definitions found" | Rename the component definition in Entity Info |
| Station without platform tag | Gate fires: "station S001 has no platform_guideways" | Add a guideway inside the station, tag it `platform` |
| Guideway drawn in wrong direction | Route goes the long way around; no gate fires | Reverse the guideway direction using the direction tag |
| Disconnected segment after edit | BFS finds no route; no topology error reported | Check the segment endpoints in FollowMe inspector |

### What Allie Accumulates from SketchUp Sessions

Each session, Allie updates:

1. **Gap log** (`readmes/sketchup/jpods-gap-log.md`) — any new recurring mistake pattern
2. **SketchUp-specific memory** — Ruby API behaviors, new gate scenarios, model state patterns
3. **Cross-domain mappings** — if a SketchUp concept clarifies something in Route-Time or physical, write the explicit mapping
4. **Design decisions table** in `noelle.md`, `natalie.md`, `nora.md` — any decision made this session

### Known Cross-Domain Mappings for SketchUp

| SketchUp concept | Route-Time equivalent | Physical equivalent |
|-----------------|----------------------|--------------------|
| `Sxxx` station ID | `structure_id` in network | Station identity tag on physical station hardware |
| `platform_guideways` tag | PLATFORM node in Route-Time network graph | Physical platform surface |
| Colored CP endpoint (red/blue) | CP object with inbound/outbound nodes | Physical switch direction |
| `followme.json` BFS graph | Dijkstra graph in `engine/network.py` | Nora's onboard path map |
| Component definition gate (Noelle) | `diag_grid.py` topology check | Pre-run I2C and MQTT connectivity check |
| Stop and Review at 3 consecutive failures | No equivalent yet | Nora `stop_and_review` JSON entry (`*.nora-log.json`) |

### Environment-Specific Knowledge (do NOT transfer to other environments)

- SketchUp Ruby API calls (`Sketchup.active_model`, `entities`, `component_definitions`)
- `followme.json` format specifics
- FollowMe export sequence
- Copilot instruction format in `.github/copilot-instructions.md`
- Standalone JSON observation log format (Nora's `*.nora-log.json`) — physical only

### Authority Boundary for Copilot

When Copilot is working in the SketchUp session:
- Copilot writes Ruby code and works within the SketchUp model
- Allie provides cross-domain context and cross-session pattern recognition
- Copilot does not modify Allie's readmes or memory files
- Allie does not write SketchUp Ruby code directly
- Bill makes all decisions — both Copilot and Allie advise

---

## Open Questions

- What is the right format for Allie to communicate cross-domain flags to Copilot during a SketchUp session? (Currently: session start/end consultation — mid-session flags require Bill to relay them.)
- Should the gap log be in Allie's readmes or in the SketchUp plugin's readmes? (Currently both — Allie's copy is the authoritative one.)
- When Natalie's BFS finds a valid route but Nora physically cannot complete it (track geometry issue), how does that lesson feed back to the SketchUp model? (Currently: Bill observes and corrects manually.)
- What is the correct test for "the model is ready for FollowMe export"? Current gate checks definitions. Are there additional checks needed for track geometry?

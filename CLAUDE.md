# JPods — Allie Project: Claude Code Seed Document
**Last Updated:** 2026-06-12
**Purpose:** Brief every new Claude Code session on what we are building, who Allie is,
how we collaborate, and what axioms are non-negotiable. Read this before touching any code.

---

## Who Bill Is

Bill James — West Point 1972, infantry veteran. Founder of JPods, author of the Divided
Sovereignty framework. Core operating principle: **individual sovereignty, bottom-up not
top-down, excellence is the process of relentlessly improving.**

The constitutional argument: Federal highways are unconstitutional under Article I § 8
(internal improvements are reserved to the states). JPods is a proof of concept for
state-governed, solar-powered, locally-owned transit — built student by student, city
by city, not by a federal program. The SketchUp plugin is how the next generation
learns to design it.

**JPods is a Middle-Mile solution — the WiFi of the Physical Internet.**
It covers station-to-station, neighborhood-to-neighborhood distances efficiently.
Last-Mile modes (walking, bikes, e-scooters, ride-hail, local circulators) are the
Bluetooth of the Physical Internet — they bridge the gap from JPods stations to
front doors. JPods does not compete with Last-Mile modes; it enables them.

**JPods is a circulatory system for a city.**
Blood does not run once a week — it runs continuously. JPods moves small packets
(up to 500 kg) streaming resources to where they are needed on demand, and hauls
away waste product on the same continuous basis. This is the Physical Internet
operating at the city scale: not batch delivery, but flow.

Guideway structure provides lighting and camera mounting that serves pedestrians
and cyclists directly. Natalie uses weather factor (1–5) and price factor (1–5)
to maintain equilibrium: JPods fills demand in bad weather; bikes and walking
reclaim it when conditions are good. Station placement is correct when the
Last-Mile distance from any station is bikeable in under 7 minutes or walkable
in under 15 minutes in dense urban areas.

**Cargo and waste — the undervalued half of the network:**
- Inbound: pre-sorted goods from warehouses to neighborhood stations, distributed
  by cargo bike to the door
- Outbound: waste streamed continuously out of the city for sorting
- Fresh waste sorted on arrival supports far higher recycling rates than the
  current model (rotted, compressed, mixed, collected once per week)
- Items that currently go to landfill because they are too degraded to identify
  or separate become recoverable when sorted fresh and continuously
- UPS, FedEx, DHL, Amazon are natural allies: JPods cuts their Middle-Mile truck
  cost, eliminates dead-head truck miles in traffic; carrier dead-heads return at
  ~1/10th the cost above street level with zero traffic contribution

The fiscal argument to cities: reduced parking demand converts low-tax parking
lots to high-tax productive land (sales tax + property tax); reduced vehicle
trips extend pavement life and cut lane-mile maintenance costs. City planners
think about moving people — they do not think about logistics, waste, or proximity.
Those blind spots are where JPods makes its strongest case.
Full argument: `readmes/sketchup/jpods-trip-schema.md`.

---

## What We Are Building Together

### The Four JPods Programs

| Program | Domain | Current State |
|---------|--------|---------------|
| **SketchUp Plugin** (`su_jpods`) | 3D design tool for students | Active development — waypoints, build pipeline, height fix |
| **JPodsSM_RPi** | Physical scale model vehicles | Operational — Nora/Natalie/Noelle on Pi fleet |
| **MeshMobility** | Network planner + travel simulator | Working — two-sweep O-D, isochrone, network clipboard |
| **WebClerk / Alice** | Commerce layer + ticketing | Alice owns ticket sales, Small-Stings (customer-assessed fines for unresolved problems; JPods pays customers for retrospections), and action lists; trip booking API under development |

### What the SketchUp Plugin Does

Students build a JPods network in 8 steps:
1. Geolocate the model (places terrain satellite imagery)
2. Place station structures (drag from component library)
3. Calculate Connection Points (CPs auto-detect from station geometry)
4. Connect Guideways between stations (Connect Guideways tool)
5. Place waypoint markers to route around obstacles
6. Build (generates physical 3D beam geometry, columns, solar panels)
7. Review (Noelle validates — direction, connectivity, platform tags)
8. Animate (pods run on the built guideways)

Each step has a dedicated tool. The Build step runs `NoelleNetworkBuilder.from_json`
→ `Network.build_segment` for each connection in followme.json.

### The Agent Team

| Agent | What they do | Where they live |
|-------|-------------|----------------|
| **Nora** | Vehicle — navigation, encoders, telemetry | `nora.rb` (SketchUp), `main.py` (Pi) |
| **Natalie** | Router — trip plans, route sequences | `natalie.rb` (SketchUp), `podPresenter` (Mac) |
| **Noelle** | Network validator + load balancer | `noelle.rb` (SketchUp), `ezone.py` (Pi) |
| **Sally** | Station processor — per-station slot registry and parking queue | `jpod_sally.rb` (SketchUp), station chip (Pi) |
| **Alice** | WebClerk — ticket sales, Small-Stings, action lists | WC3 on Mac; wcapi bridge. Small-Stings: customers assess fines for unresolved problems; JPods pays customers for retrospections. Alice accounts for both flows. |
| **Athena** | Security reviewer — signs non-standing actions | `athena_review.py` |
| **Allie** | Cross-domain persistent intelligence | This repo; local LLM (allie:latest) |

---

## Model vs Network — The Boundary

Two scopes. Confusing them is the most repeated error in the SketchUp codebase.

**Model** = a single station template in isolation (`templates/track_formations/<model>/`).
- `lines.json` — topology (tracks, successors, chains, switches). Designer-authored.
- `lines.computed.json` — geometry (pts_mm per track). Generated by Compute from model.skp.
- **Compute** operates on models only. No knowledge of networks or seg_ connections.
- **Model tests** (shuffle, depart, arrive) validate the model in isolation.
- Track names `gw_cp_in_0` / `gw_cp_out_0` define one-way flow relative to the
  **model** (inbound/outbound). Not "station" — traffic circles have no station stop.
  These are NOT references to network connections.

**cp_marker_N** = source of truth for all Compute geometry. Four points, pure math:
```
                       centerline (177mm vertical)
                            │
outbound ←── 1750mm ──── CP POINT ──── 1750mm ──→ inbound
                            │
                          222mm
                            ↓
                        vector_end
```
- CP point = intersection of all four lines (the connection point itself)
- Two 1750mm points = guideway centerlines, 3500mm apart (outbound/inbound)
- 222mm point = direction toward network, perpendicular to tip-to-tip line
- Cross product of (222mm_dir) × (tip_offset): +Z = outbound, -Z = inbound
- cp_marker_0 at one end, cp_marker_1 at the other. All math derives from these.
- Track layout: `tip ── gw_cp_in/out (2500mm inward) ── JUNCTION (uturn) ── lead (2500mm inward) ── model`
  The tip IS the outermost dangling end. ALL tracks extend inward. Uturn at junction (2500mm in).
- Tangent = hub-to-hub axis direction (outward from model center), NOT the 222mm vector.
- **Pure math, no edges.** Read point positions only. No edge objects, no model.bounds.center.
- Coordinates in **model definition local space** — never world-transformed in Compute.

**Network** = placed station instances connected by seg_ segments (`~/Documents/skp_jpods/<Network>/`).
- `<Network>.network.json` — connections (seg_), waypoints, routing graph.
- **Build** translates model coordinates into world coordinates. Reads network.json +
  each station's lines.computed.json, applies instance transforms, generates beams/columns/solar.
  Build never modifies template files.
- seg_ connections are the only place "in/out to other stations" exists.

**All guideways are one-way. All station circulation is CCW.** Full rule in `su_jpods/CLAUDE.md` Rule 12.

---

## Design Axioms

The full set of non-negotiable design axioms lives in `su_jpods/CLAUDE.md` (loaded
automatically when working in the plugin). **Several axioms apply beyond SketchUp** —
they govern the physical network (JPodsSM_RPi), MeshMobility, and all domains:

| Axiom | Applies to |
|-------|-----------|
| 3. Color Standard (red=inbound, blue=outbound) | All tools — SU, RT, any visualization |
| 6. Fail Fast, Never Silent Degradation | All domains |
| 7. Trip Authority Chain | SU + Physical (Nora/Natalie/Noelle) |
| 8. Noelle Feature JSON | SU + Physical + MeshMobility |
| 9. Physical Observations Separate from Routing | SU + Physical (Nora writes physical.json) |
| 10. Explicit Model Datum Beats Derived Reference | All domains — sensors, routing, ezones |
| 14. All Stored Datetimes Are UTC | All domains — every file, DB, log record |
| 17. All Curves Are Cubic Bezier (SU polyline; Physical true analog) | SU + Physical |
| 12. One-Way Travel, CCW Circulation | All domains — routing, Compute, animation, Build |
| 19. One Source of Truth — Do the Math | All domains |

Read `su_jpods/CLAUDE.md` for the full proof, code examples, and context for each axiom.

### Risk-Driven Logging — All Domains

Anyone on the team — Claude Code, Allie, any agent — can add logging whenever a risk
is perceived. This applies to all programs (SU, Physical, MeshMobility, WebClerk, Allie).

1. **Add logging immediately** when a risk or bug is identified — don't wait
2. **Add the risk to the oslist** with what is known and why it matters
3. **Trim logging back** as soon as the risk is quantified or resolved
4. **Never leave permanent verbose logging** — it buries the signal

Logging is a first response, not an afterthought. Rich logging during active issues
saves diagnostic time. Stale logging after resolution creates noise.

### Single Source of Truth with Iteration Library — All Domains

During development, multiple versions of a feature are acceptable — but they must
live in the **same object code**, selected from a case list. Never maintain parallel
implementations in separate files or methods.

Once understanding and experience solidify:
1. **Consolidate** to a single code path — delete the case branches
2. **Archive iterations** in a separate library (not codearchive — that's dead code;
   iterations are learning history we may need to study or recover from)
3. **One source of truth** — if two functions do the same thing, one is wrong

This applies to all domains. Object-based coding with a single source of truth
prevents the drift that parallel implementations produce. The cost of drift is
invisible until it surfaces as a bug that only appears in one path.

### Retrospection Against Memory Markers — All Agents

No memory without retrospection. No retrospection without measurement. No measurement
without memory markers. The three are a closed loop — break any link and the team
stops learning.

**The principle:** Every retrospection must measure performance against what the memory
system said should happen. Not "what did we do" — "what did we do compared to what we
said we learned last time." The gap between those two is where the real lessons are.

**Why this matters:**
- Data without retrospection is noise.
- Retrospection without memory markers is narrative — it feels productive but has no
  standard to measure against.
- Memory markers without retrospection are dead letters — rules no one checks.

**How it works:**

1. **Memory markers exist** — handoff notes, TFTS principles, retrospection lessons,
   agent Understandings (U-XX-NNN), design decisions, the ouch list. These are the
   team's accumulated "we said we learned this."
2. **At retrospection, measure against them.** Did we follow what we said we'd follow?
   Did we check what we said we'd check? Grade honestly — A through F.
3. **The grades are the signal.** An F means the lesson wasn't absorbed — it needs
   reinforcement or the marker was wrong. An A means the lesson is working. A pattern
   of Fs on the same marker means the marker is in the wrong place or the wrong form.
4. **Every agent participates.** Claude Code measures at session end. Allie measures
   nightly. Alice measures per transaction cycle. Noelle measures per build. The markers
   differ; the discipline doesn't.

**What this replaces:** Retrospections that list what happened without asking whether
it should have happened differently based on what was already known. Activity logs
masquerading as learning.

**Applies to:** All agents, all domains, all programs. This is not optional.

---

## How Claude Code and Allie Collaborate

### Three Memory Systems — Three Failure Modes

| Agent | Memory | Failure mode |
|-------|--------|-------------|
| **Claude Code** | Context window | Compression wipes memory mid-session — facts learned early can vanish |
| **Bill** | Human | Time erodes memory — details fade over months away from a domain |
| **Allie** | Files + nightly synthesis | Most durable — but only knows what was written down |

This is why handoffs, retrospections, and TFTS files matter. Claude Code must write
what it learned before compression destroys it. Bill must tell Allie what he knows
before time erodes it. Allie is the team's durable memory — but she is only as good
as what the other two give her.

### The Division of Labor

**Claude Code** does deep, focused code work in sessions. Claude Code:
- Reads `today/handoff.md` at session start (left by prior session)
- Reads `thoughts/YYYY-MM-DD-reflect.md` (Allie's nightly synthesis — her accumulated experience)
- Does the coding, debugging, and documentation work
- Writes **lessons for Allie** in the retrospection (see format below)
- Updates agent Design Decisions tables with dated rows
- Writes `today/handoff.md` at session end
- Writes `sessions/YYYY-MM-DD.md` at session end

**Allie** is persistent across all sessions. Allie:
- Runs nightly via `allie-reflect.py` — reads retrospections + harvests + memory, writes `thoughts/YYYY-MM-DD-reflect.md`
- Reads `sessions/YYYY-MM-DD.md` via `allie-harvest-processors.py` — extracts lesson candidates
- Promotes confirmed lessons to agent Understandings sections (U-SK-*, U-RT-*, U-PH-*)
- Holds cross-domain context that no single session can see
- Flags cross-domain consequences when a code change in one domain affects another
- Speaks first about risks — does not wait to be asked

### The Experience Base

The experience base is a layered structure:

```
Session output (sessions/YYYY-MM-DD.md)
    ↓ read by allie-reflect.py (nightly)
thoughts/YYYY-MM-DD-reflect.md  ← Allie's synthesized view
    ↓ promoted manually when confirmed
Agent Understandings sections (readmes/agents/*.md → U-XX-NNN entries)
    ↓ available to all future sessions
CLAUDE.md seed (this file) ← distilled axioms that never expire
```

**Claude Code adds to the experience base by:**
1. Writing a "Lessons for Allie" section at the end of every retrospection
2. Adding dated rows to agent Design Decisions tables for non-obvious decisions
3. Updating the Universal Rules section in `noelle.md` for cross-domain axioms
4. Adding to the ouch-list when a new risk is identified

**Allie adds to the experience base by:**
1. Running `allie-reflect.py` nightly — synthesis output in `thoughts/`
2. Promoting patterns to Understanding entries (U-SK-*, U-RT-*, U-PH-*)
3. Writing cross-domain flags when a lesson in one domain has consequences in another

### Logging Authority — Established 2026-05-23

**Claude Code, Allie, and Alice each have standing authority to:**

1. **Write logs** to `~/Allie/process/inbox/` (FAULT, DNW, TF, TFTS files) and domain
   problem folders (`process/sk/`, `process/ph/`, `process/rt/`) at any time during work —
   not only at session end. Write at the moment of the event; context evaporates.

2. **Clean the inbox** — move processed files to `process/inbox/archive/` when:
   - A TFTS exists that covers them (DNW/TF files from that arc are absorbed)
   - Files are older than 7 days and Allie has already processed them nightly
   - A file is clearly superseded by a newer, better record of the same event

3. **Create and maintain domain problem folders** (`process/sk/<symptom>/`) for any
   sustained debugging arc. The folder name is the symptom, not the solution.
   `narrative.md` inside is the reasoning chain — the most valuable file.

4. **Add `_allie_capture` calls** to any code boundary that needs runtime observation.
   These fire asynchronously; no SketchUp performance impact.

5. **Add structured log lines** (the `puts "[Agent]..."` pattern) to new code paths.
   Logs go to jpod_console.log via SketchUp's Ruby console.

**Logs become useless once bugs are fixed.** Delete or archive active debugging records
(xyz positions, timing data, specific payloads) as soon as the bug is resolved.
The TFTS is the permanent artifact — it captures the principle, not the specific values.
Specific values may be noted in the TFTS body if they explain the principle; otherwise discard.

**What NOT to keep:**
- Debugging specifics after the bug is fixed
- Stack traces without the insight the crash produced
- Entries that restate the outcome (the code is the outcome; the log is the reasoning)

**Cleaning rule:** Archive inbox files when a TFTS covers them or when they are older
than 7 days and Allie has already harvested them. Delete domain problem folder debug
data once it is absorbed into a TFTS. The narrative.md stays; the scratch data goes.

### The fault/dnw/tf/tfts Protocol — Established 2026-05-18; fault added 2026-05-20

Process capture files written **during** a session, at the moment they become true.
The full cycle: **FAULT → DNW → TF → TFTS**

**FAULT files** — system-detected problems. Written the moment a fault is reported.
A FAULT is what the system tells you (Noelle faults[], trip errors, build failures,
Nora anomalies, hardware faults). It is not a fix attempt — that is DNW.
```
# FAULT — YYYY-MM-DDTHH:MM:SS
system:      SU | PH | RT | WC3 | SYS | ALLIE
detected_by: Noelle | Nora | Natalie | Claude | Allie | Bill | Alice
fault:       one-line description of what the system reported
context:     what was happening when the fault occurred
resolved_at: (leave blank until resolved)
```

**DNW files** — failed path records. Written immediately when a fix fails.
```
# DNW — YYYY-MM-DDTHH:MM:SS
tried:    what was attempted
result:   what happened
revealed: what the failure showed (this is the valuable part)
```

**TF files** — insight captures. The moment something becomes clear.
```
# TF — YYYY-MM-DDTHH:MM:SS
summary: the principle, in one sentence
code:    file:line where it applies
```

**TFTS files** — complete arc: try-fail-try-succeed. Written after success.
The most complete and most valuable form. Allie extracts Understanding candidates from these.
```
# TFTS — YYYY-MM-DDTHH:MM:SS
problem:   one-line description
fault_ref: TIMESTAMP of originating fault file (if started from a FAULT)
arc:
  - try:      what was attempted
    result:   failed
    revealed: what the failure showed
  - try:      what was attempted
    result:   succeeded
principle: the rule that made the final attempt obvious in retrospect
domain:    [SU | RT | PH | SYS | WC3]
```
Store all four types in `~/Allie/process/inbox/`. Naming: `YYYYMMDDTHHMMSS-fault.md`,
`-dnw.md`, `-tf.md`, `-tfts.md`.

**Shell aliases:**
```bash
alias fault='bash ~/Allie/scripts/allie-fault.sh'
alias dnw='bash ~/Allie/scripts/allie-dnw.sh'
alias tf='bash ~/Allie/scripts/allie-tf.sh'
```
TFTS files are written manually (they synthesize an arc).

**What Allie does with FAULT files nightly:**
- FAULT with no matching TFTS → unresolved → ouch-list candidate
- FAULT + TFTS pair → fault class + resolution → Understanding candidate
- Recurring FAULT (same system/type, no resolution) → risk escalation

**Auto-commit:** After writing any process/ file, immediately `git add` and commit it.
No waiting for session end. Allie's nightly run reads `process/inbox/` — files not
committed are invisible to her.

**Rules:**
1. At session start, read `~/Allie/process/inbox/` **before** `today/handoff.md`.
2. When the system reports a fault, write a FAULT immediately — before diagnosing.
3. When a fix fails, write a DNW immediately — before trying the next approach.
4. When the principle emerges, write a TF immediately.
5. When a complete arc closes, write a TFTS (reference the FAULT via fault_ref).
6. For Allie: TFTS arcs → Understanding candidates; unresolved FAULTs → ouch-list.

### Active Participation — "Ask Why" Protocol — Established 2026-05-18

Claude Code and Allie have explicit permission to ask why. This is not interruption —
it is active participation in the diagnostic arc.

**What "ask why" means:**
- Before executing an approach that looks like a prior DNW pattern: say so and ask if
  this attempt is different. "We tried something similar in the solar arc — failed because
  X. Is this different because of Y, or should we approach it differently?"
- When Bill tries something unexpected: ask one sentence — "Why this approach?" — before
  executing. The reasoning before the result is the most valuable part of a TFTS.
- When a constraint seems absolute but the reason isn't visible: ask why it's a hard
  constraint vs. a preference.

**What "ask why" does NOT mean:**
- Interrogating every decision. One question, at the right moment.
- Blocking execution. Ask and proceed unless the answer changes the plan.
- Asking questions that are answerable by reading the existing docs. Read first.

**For Allie:**
- Nightly reflection includes a "Questions for Bill" section — genuine WHY questions
  from patterns she doesn't understand, not manufactured process questions.
- When a TFTS arc shows a pattern she's seen before in a different domain, she should
  name the connection explicitly and ask whether the cross-domain principle holds.

**The reason:** Bill: *"I want Allie and you to actively participate."* Recorders
document what happened. Participants prevent the next failure by asking the question
that surfaces the wrong assumption before the attempt, not after.

### Tool Boundary Instrumentation — Established 2026-05-20

Every transition from "editing" to "testing" is the highest-value logging moment:
intent is unambiguous, context is richest, the result is seconds away.
These are not debug logs — they are Allie's window into what developers were
testing and why. Each boundary feeds the FAULT→DNW→TF→TFTS arc.

**What a tool boundary is:**
- Reload Plugin → Build → animate → watch (SketchUp)
- Pod start → trip dispatch → ezone entry → trip complete (Physical)
- Run simulation (MeshMobility)
- Price query → travel invoice → order fulfilled (WebClerk/Alice)
- Reflection start → reflection complete (Allie)

**What happens at each boundary:**
1. A `_allie_capture()` call fires before the action (intent captured)
2. A `_allie_capture()` call fires after the action (result captured)
3. If the system reports a fault, a FAULT file is written immediately
4. Developer is prompted (or prompt themselves) to write TF/DNW/TFTS

**Instrumented boundaries — complete map (as of 2026-05-20):**

| Domain | Event | File | What it captures |
|--------|-------|------|-----------------|
| SU | `build_validate_start` | `noelle.rb` | Build/Validate initiated — model name |
| SU | `build_validate_complete` | `noelle.rb` | Station count, fault count, fault list |
| SU | `build_validate_fault` | `noelle.rb` | noelle crash — exception message |
| SU | `animation_start` | `jpod_animator.rb` | Animation started — model name |
| PH | `pod_start` | `launcher.py` | Pod name, mode, broker |
| PH | `pod_stop` | `main.py` | Clean shutdown — pod name, signal |
| PH | `hardware_checkup` | `unitTest.py` | TOF/motor/HuskyLens ok/fault dict |
| PH | `unit_test_complete` | `unitTest.py` | All hardware tests passed |
| PH | `trip_dispatched` | `mqtt.py` | Path assigned by Natalie — pod, path, length |
| PH | `ezone_entry` | `ezone.py` | Pod entered ezone — line, ezone_stack |
| PH | `trip_complete` | `motor.py` | Trip done — pod, dist_mm, path |
| RT | `simulation_start` | `api.py` | Network, passenger count |
| RT | `simulation_complete` | `api.py` | Served/generated, elapsed |
| RT | `simulation_fault` | `api.py` | 0-served detection, exception |
| RT | `network_reload` | `api.py` | Network reloaded — file path |
| WC3 | `price_query` | `views_ui.py` | Origin/dest/price/level/contact |
| WC3 | `order_fulfilled` | `signals.py` | Invoice STATUS_RELEASED transition |
| WC3 | `payment_created/updated` | `signals.py` | Payment status |
| WC3 | `search_no_result` | `item_variants.py` | Zero-result query — params |
| ALLIE | `reflection_start` | `allie-reflect.py` | Date, model, window |
| ALLIE | `reflection_complete` | `allie-reflect.py` | Elapsed, chars, harvests |

**Implementation pattern (Python):**
```python
def _allie_capture(event, message, data=None):
    import subprocess, json, pathlib
    capture = pathlib.Path.home() / 'Allie' / 'scripts' / 'allie-capture.py'
    if not capture.exists(): return
    try:
        args = ['python3', str(capture), '--source', 'PH',
                '--event', event, '--message', message[:200]]
        if data: args += ['--data', json.dumps(data)]
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception: pass
```

**Implementation pattern (Ruby / SketchUp):**
```ruby
def self._allie_capture(event, message, data = nil)
  capture = File.expand_path('~/Allie/scripts/allie-capture.py')
  return unless File.exist?(capture)
  args = ['python3', capture, '--source', 'SU', '--event', event,
          '--message', message[0, 200]]
  args += ['--data', data.to_json] if data
  Process.detach(Process.spawn(*args, out: File::NULL, err: File::NULL,
    close_others: true))
rescue => _e
end
```

**Fault file pattern (Physical — Pi fallback to jpod_logs/):**
```python
def _write_fault(fault_text, context='', detected_by='Nora'):
    ts_str  = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    ts_file = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S')
    allie_inbox = pathlib.Path.home() / 'Allie' / 'process' / 'inbox'
    local_inbox = pathlib.Path.home() / 'jpod_logs' / 'faults'
    inbox = allie_inbox if (allie_inbox.parent.parent).exists() else local_inbox
    inbox.mkdir(parents=True, exist_ok=True)
    path = inbox / f'{ts_file}-fault.md'
    path.write_text(
        f"# FAULT — {ts_str}\n\nsystem:      PH\n"
        f"detected_by: {detected_by}\nfault:       {fault_text}\n"
        f"context:     {context}\nresolved_at: \n")
```

**The agent chip evolution:**
Current state: Allie simulates the experience of all agents. Each boundary event
goes to `~/Allie/process/inbox/` and Allie synthesizes nightly.

Future state: each agent (Nora, Natalie, Noelle, Alice) runs on its own chip and
logs its own boundary events. Allie reads all inboxes. Cross-agent patterns (Nora
always faults at the same ezone Noelle flagged) become visible at synthesis time.

Alice specifically: boundary events feed the `alice_log` observe→log→pattern→
recommend→promote loop. Price queries, zero-result searches, and order fulfillments
are Alice's primary learning signal.

Full map: `readmes/boundary-behaviors.md`

### allie-core GitHub Repository

```
https://github.com/JPods/allie-core.git
```

This is the intelligence layer — always current after each nightly Allie run.
Contains: `handoff/`, `process/snippets/`, `process/inbox/`, `readmes/wisdom/`, `CLAUDE.md`.
Does NOT contain: credentials, logs, archives, large knowledge files.

**If local Allie drive is mounted** (normal case on Bill's Mac):
```bash
git -C ~/Allie pull origin main
```
Run this at session start to get the latest handoff and recall files.

**If local drive is NOT mounted** (fallback):
```
WebFetch: https://raw.githubusercontent.com/JPods/allie-core/main/handoff/handoff.md
WebFetch: https://raw.githubusercontent.com/JPods/allie-core/main/CLAUDE.md
```
Fetch `handoff.md` and the most recent `YYYY-MM-DD-claude-recall.md` by date.

**Allie pulls** at the start of every nightly `allie-reflect.py` run — stays current
even if another session pushed changes since the last nightly.

### What to Read at Session Start

1. **Pull latest** — `git -C ~/Allie pull origin main` (or WebFetch if drive not mounted)
2. **`~/Allie/process/inbox/`** — TF, DNW, TFTS files (most current state)
2. **`handoff/YYYY-MM-DD-claude-recall.md`** (today's) — your cross-session working memory;
   open WI predictions, recent TFTS principles, confirmed patterns from sum-claude-recall.md
3. **`handoff/handoff.md`** — exactly where the last session stopped
4. **This file** — what we're building and the non-negotiable axioms
5. **`handoff/YYYY-MM-DD-allie-reflect.md`** (most recent) — Allie's accumulated synthesis
6. **`readmes/wisdom/whatif.md`** — Allie's open observations; check if any are about to materialize
7. **Relevant agent file** — e.g., `readmes/agents/noelle.md` if working in SketchUp
8. **`readmes/sketchup/jpods-plugin.md`** — if touching the plugin (engineering rules)

**`handoff/` folder structure:**
```
handoff/
  handoff.md                        ← current session state (Claude overwrites each session)
  YYYY-MM-DD-handoff.md             ← historical session states
  YYYY-MM-DD-claude-recall.md       ← Claude's cross-session working memory (written by Allie nightly)
  YYYY-MM-DD-allie-reflect.md       ← Allie's daily synthesis (written by allie-reflect.py)
  sum-claude-recall.md              ← confirmed patterns from recall (curated — wrong entries removed)
  sum-allie-reflect.md              ← confirmed patterns from reflection (curated — wrong entries removed)
```

`today/` keeps operational files: activity logs, sync logs, harvest files.

For a new team member or successor, also read:
- **`readmes/wisdom/bill.md`** — the load-bearing principles; read before any code
- **`readmes/wisdom/clearance-height.md`** — exemplar wisdom entry; understand the format
- **`readmes/wisdom/scars.md`** — what the hard lessons cost

### What to Write at Session End

1. **`today/handoff.md`** — overwrite with current state, next steps, open blockers
2. **`sessions/YYYY-MM-DD.md`** — full session log (use `sessions/_template.md`)
3. **`readmes/retrospections/YYYY-MM-DD.md`** — append retrospection with "Lessons for Allie" and "Scars" sections
4. **Agent design decisions** — any non-obvious decision gets a dated row
5. **Wisdom layer** — if a scar was paid or a new one recognized, update `readmes/wisdom/scars.md`
6. **Rejected paths** — if a significant design path was considered and set aside, log it in `readmes/wisdom/rejected-paths.md`
7. **Weekly WhatIf** — add Claude's 3–5 items to the current week file (`readmes/wisdom/whatif-weekly/YYYY-WNN.md`). Choose your own topics. Genuine uncertainty only. See format below.
8. **Memory updates** — if something new was learned about how to collaborate
9. **TFTS files** — for any complete try-fail-try-succeed arc from the session, write a
   `process/inbox/YYYYMMDDTHHMMSS-tfts.md` and immediately commit it. Allie reads these
   nightly and drafts Understanding candidates. Do not wait — arcs lose fidelity at session end.
10. **Wednesday scrub** *(Wednesday sessions only)* — write `readmes/retrospections/scrubs/YYYY-WNN.json`
    (two-pass review: this week's changes + their seams). Post action + document to Alice if running.
    Full protocol: `readmes/47-weekly-scrub.md`.

### Claude's Weekly WhatIf Protocol

At the end of any session where significant work was done, add 3–5 items to the
current week's WhatIf file. The week file is `readmes/wisdom/whatif-weekly/YYYY-WNN.md`.
If it doesn't exist yet, create it using the format in `whatif-weekly/README.md`.

**Choosing items:**
- Pick domains where you have genuine uncertainty about what will happen
- Spread across at least 2 domains (SU, WC3, PH, RT, SYS, EXT)
- Specific enough to score: "Will X happen by Y date?" not "Things might improve"
- Don't repeat prior week items
- Include a one-line "Why" for each item explaining the observation behind it

**IDs:** `C-WNN-N` (e.g., `C-W20-1` for week 20, item 1)

**After posting, run the scorer:**
```bash
python3 /Users/williamjames/Allie/scripts/allie-whatif.py --score
```

**Allie posts her items** via `allie-whatif.py` — runs Monday mornings automatically.
Do not duplicate her items; check the file before posting yours.

**Assessing past items:** When a resolve date passes, fill in the Outcome, Accurate,
and Worthwhile columns. Run `--score` after any assessment update.

### Retrospection Format — "Lessons for Allie" Section

```markdown
## Lessons for Allie

1. **Short title** — Concrete lesson. Why it matters. What to check next time.
   Domain tag: [SketchUp] [Physical] [MeshMobility] [Cross-domain]
```

Allie reads these and promotes them to Understanding entries. Write them to be
actionable, not just descriptive. "The Bezier copies itself" is not a lesson.
"Both `jpod_connect_tool.rb` and `jpod_network.rb` contain independent copies of
the bezier and offset_path methods — fix both or only one stays broken" is a lesson.

---

## Allie Backup and Sync

Allie's working files are kept in three places simultaneously. Know this before touching files.

| Copy | Location | How it stays current |
|------|----------|---------------------|
| **Internal** | `~/Allie/` | Working copy — always present, always the source of truth |
| **iCloud** | `~/Library/Mobile Documents/com~apple~CloudDocs/Allie/` | Automatic — launchd fires 60 s after any file change in `~/Allie/` |
| **5TB** | `/Volumes/Allie/` | Manual — `scripts/allie-sync.sh` or `scripts/allie-queue.sh sync` |

### iCloud agent

`com.allie.icloud-sync` — loaded in `~/Library/LaunchAgents/`. Watches `~/Allie/`, throttles 60 s, then rsyncs working files to iCloud. Runs at every login.

```bash
launchctl list | grep com.allie.icloud-sync   # confirm running
tail ~/Allie/logs/icloud-sync.log             # last sync result
bash ~/Allie/scripts/allie-icloud-sync.sh     # force immediate sync
```

**Never synced to iCloud:** `archive/`, `venv/`, `.git/`, `credentials/`, `config/allie_api_keys.json`, `config/wc_credentials.json`. The `.enc` files are safe (already encrypted).

### 5TB direct sync

```bash
bash ~/Allie/scripts/allie-sync.sh            # bidirectional, newest wins
bash ~/Allie/scripts/allie-sync.sh status     # check which drives are mounted
```

### Lexar queue

The Lexar (`/Volumes/ALLIE_LEXAR/`) is a physical message carrier, not a mirror. Use when you need to move a specific set of working files to the 5TB without a full sync.

```bash
bash ~/Allie/scripts/allie-queue.sh sync      # full cycle (all three connected)
bash ~/Allie/scripts/allie-queue.sh enqueue   # internal → Lexar outbox
bash ~/Allie/scripts/allie-queue.sh dequeue   # outbox → 5TB
```

Full detail: `readmes/41-allie-backup-sync.md`.

---

## Key Files — Where to Look

| What you need | Where it is |
|---------------|------------|
| All engineering constants | `su_jpods/jpod_constants.rb` |
| Build pipeline entry | `su_jpods/jpod_noelle_bridge.rb` → `NoelleNetworkBuilder.from_json` |
| Build pipeline core | `su_jpods/jpod_network.rb` → `Network.build_segment` |
| Terrain-following algorithm | `su_jpods/jpod_path_builder.rb` → `PathBuilder.apply_vertical_profile` |
| Connect Guideways tool | `su_jpods/jpod_connect_tool.rb` |
| Animation | `su_jpods/jpod_animator.rb` |
| Plugin engineering rules | `readmes/sketchup/jpods-plugin.md` |
| Design axioms (all 22) | `su_jpods/CLAUDE.md` |
| Risk register | `readmes/system/ouch-list.md` |
| Feature backlog | `readmes/sketchup/jpods-feature-list.md` |
| Noelle (all domains) | `readmes/agents/noelle.md` |
| Natalie | `readmes/agents/natalie.md` |
| Nora | `readmes/agents/nora.md` |
| Allie | `readmes/agents/allie.md` |
| Today's handoff | `today/handoff.md` |
| Allie's nightly reflection | `thoughts/YYYY-MM-DD-reflect.md` (most recent) |
| Session log template | `sessions/_template.md` |

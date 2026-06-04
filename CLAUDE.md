# JPods — Allie Project: Claude Code Seed Document
**Last Updated:** 2026-05-20
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
| **Route-Time** | Network planner + travel simulator | Working — two-sweep O-D, isochrone, network clipboard |
| **WebClerk / Alice** | Commerce layer + ticketing | Alice owns pricing; trip booking API under development |

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
| **Alice** | WebClerk — data quality, billing, patterns | WC3 on Mac; wcapi bridge |
| **Athena** | Security reviewer — signs non-standing actions | `athena_review.py` |
| **Allie** | Cross-domain persistent intelligence | This repo; local LLM (allie:latest) |

---

## How Claude Code and Allie Collaborate

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
- Run simulation (Route-Time)
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
   Domain tag: [SketchUp] [Physical] [Route-Time] [Cross-domain]
```

Allie reads these and promotes them to Understanding entries. Write them to be
actionable, not just descriptive. "The Bezier copies itself" is not a lesson.
"Both `jpod_connect_tool.rb` and `jpod_network.rb` contain independent copies of
the bezier and offset_path methods — fix both or only one stays broken" is a lesson.

---

## Non-Negotiable Design Axioms

These have been paid for with real bugs. They are not preferences.

### 1. Edge-Driven — No Calculated Centerlines as Authoritative References

SketchUp's geometry kernel operates on **edges**. FollowMe walks edges. Every position
reference in specs, sensors, metrics, and code anchors to a hard physical edge:
- Beam clearance = terrain surface edge + CLEARANCE_HEIGHT → **bottom face edge of beam**
- CP position = **stub end edge**, not stub midpoint
- Ezone boundary = **entry/exit edge** of the guideway segment
- PathBuilder receives Z=0 on center_pts; `floor_z = terrain + CLEARANCE_HEIGHT` builds from real surface

**Never:** store `bounding_box.center.z` as a beam height. Never pass Bezier midpoint Z
as a desired elevation. Never define a junction by a computed centerpoint.

**The proof:** Guideway-at-8.4m bug. The Bezier spline inherited CP stub heights (~7.5m)
as `desired_z`. PathBuilder's grade corridor allowed the interior to stay at 7.5m even
though anchor_zs was correctly set to 4.6m. Fix: zero center_pts Z before PathBuilder.
The edge-referenced floor_z dominates.

This axiom transfers to physical sensors (TOF, AprilTag), routing (Natalie), and ezone
definitions (Noelle). See full rule in `readmes/sketchup/jpods-plugin.md` Rule 8.

### 2. `Vector3d * Float` is Illegal in SketchUp Ruby

SketchUp's `Geom::Vector3d` has no `coerce` method. `vec * scalar` always raises
`ArgumentError: Cannot convert argument to Geom::Vector3d`. Always expand:

```ruby
# WRONG — crashes:
vec.normalize * 2.5

# RIGHT — always:
n = vec.normalize
Geom::Vector3d.new(n.x * 2.5, n.y * 2.5, n.z * 2.5)
```

**`jpod_connect_tool.rb` and `jpod_network.rb` each have their own copy of the bezier
and offset_path methods.** Fix both, always. One file staying broken looks like a different bug.

### 3. Color Standard — Never Reversed

- **Red = inbound** (hot end — vehicle or flow arriving)
- **Blue = outbound** (cool end — vehicle or flow departing)

Applies in all tools: SketchUp plugin, Route-Time GUI, any future visualizations.
No monochrome for directional elements. This is physics (hot/cool), not style.

### 4. CLEARANCE_HEIGHT = 4.6m — Active Safety Debt

The single source of truth is `jpod_constants.rb`. Guideways are safe at 4.6m.
**JPods vehicles (pods) are exposed to overheight trucks.** Height-sensing and pod
defensive-stop systems are committed but not yet built (CL-01 to CL-07 in ouch-list).

Do not lower below 4.6m. Do not deploy publicly at 4.6m without CL-02 having a
design, owner, and certification path.

### 5. Draw from Live State, Not Stale Instance Variables

When `@@draft_connections` is updated by a drag, the draw method must read from
`@@draft_connections`, not from instance variables set before the drag started.
`@edit_preview_pts` was the culprit that caused live Bezier to not update during drag.

### 6. Fail Fast, Never Silent Degradation

Three examples of silent degradation that cost weeks:
- Stations missing `platform_guideways` → routing ran but produced nonsense
- `msg.length != 7` → Natalie silently dropped every START ping from Nora
- Bezier at old 7.5m Z → guideways built at wrong height with no error

When a check fails, print and abort. When a definition is missing, demand it loudly.

### 7. Trip Authority Chain

Noelle certifies the map → Natalie plans the route → Nora travels it.
Nora does not re-query Noelle at runtime. Redundant validation is noise, not safety.
Stale trip files (wrong `followme_generated_at`) are purged at export, not patched.

### 8. Noelle Feature JSON — Applies to All Environments

Station behaviors (what segment sequences are physically allowed at each station template)
are declared once in `noelle_features.json` in the plugin folder. This is **not a
SketchUp-only concept** — the same behavioral declarations apply to:

- **SketchUp plugin** — TripPlanner reads `{model}.feature.json` to build trip.json
- **Physical scale model** — Nora follows the same segment sequences; the JPodsSM_RPi
  dispatcher must reference feature behaviors when planning routes for physical pods
- **Route-Time** — station capacity, throughput, and pass-through eligibility are
  derived from the same behavioral declarations

**Noelle generates `{model}.feature.json` on every Build and Validate** — never by
user request, never calculated at trip-planning time. It is a resolved reference:
Noelle writes it, everyone else reads it.

**Why this matters for large networks:** A network with 20 stations has hundreds of
possible O-D pairs. Recalculating routing rules at trip-planning time means recalculating
the same physical facts hundreds of times. Feature JSON declares them once. TripPlanner,
Natalie, and Nora look them up. This is how JPods scales.

File locations:
- Plugin authority: `su_jpods/noelle_features.json` (keyed by component definition name)
- Project reference: `{model}.feature.json` (per-template with instances list, generated by Noelle)
- Adding a new station template: add one entry to `noelle_features.json`, re-run Build

### 10. Explicit Model Datum Beats Derived Reference — 2026-05-18

When an explicit, model-author-placed datum exists, use it. Never prefer a derived
reference over an explicit one.

**The proof:** `scan_stub_pair_tips` derived CP tangent direction from cluster centroids
and then from radial distance from the bounding box center (`formation_center`). Both
failed for S050.CP0 because both references can misclassify for asymmetric or unusual
templates. The fix: validate tangent against `cap_pt` (the `dead_cap_end` entity,
explicitly placed by the model author). If the tangent points away from `cap_pt`,
reverse it. No clustering or bounding box geometry needed.

**The hierarchy:**
1. Explicit tagged entity (cap_pt, stub_pair, platform tag) → use directly
2. Hard physical edge endpoint → use directly
3. Radial distance from formation center → use only when 1 and 2 unavailable
4. Cluster centroid projection → last resort, most fragile

**Applies to all domains:** same principle governs Nora's sensor anchor points
(explicit AprilTag position, not estimated midpoint), Natalie's ezone boundaries
(entry/exit edge, not computed centerline), and physical model waypoints (ToF reads
a hard surface, not a calculated reference plane).

**Process note:** Three fix attempts were needed:
- Fix 1 (`avg_outward_tangent` guard): failed — `inward_ref` was also derived wrong
- Fix 2 (radial distance swap): failed — `formation_center` biased for some templates
- Fix 3 (`cap_pt` validation): correct — explicit datum, no derivation

The gap between Fix 2 and Fix 3 is the lesson: ask "what explicit datum exists?" before
reaching for another derived reference.

### 11. Hermite Terminal Tangent is the Curve Velocity — Reverse for Arriving CP — 2026-05-18

In the Hermite-to-Bezier formulation (`bezier_pts_via` in `jpod_connect_tool.rb`),
the tangent at each endpoint is the **curve velocity** at that point — not a handle
direction.

- **FROM endpoint:** velocity is outward (pod departs). Use `from_cp[:tangent]` as-is.
- **TO endpoint:** velocity is inward (pod arrives). Use `to_cp[:tangent].reverse`.

The ene_railroad handle convention in `bezier_pts` / `tangent_curve_pts` is different:
both handles are placed OUTWARD from their respective CPs. The math is equivalent but
the sign convention is opposite. Never mix the two formulations in the same function.

**The proof:** `bezier_pts_via` used the outward TO tangent directly → curve velocity
at the destination was outward → the guideway appeared to loop backwards at the gate.
`bezier_spline_pts` in `jpod_network.rb` already had `.reverse` correctly. The connect
tool preview was wrong; the build was right. Fixed by adding `.reverse` to the TO
endpoint tangent in `bezier_pts_via`.

**Check whenever touching Bezier/Hermite endpoint code:** is this function using the
Hermite convention (velocity = tangent magnitude × direction) or the handle convention
(control point = anchor + tangent × scale)? The two require opposite signs at the TO end.

### 12. Bezier Preview Density Must Be Adaptive — 2026-05-18

Never use a fixed segment count (`BEZIER_SEGS = 20`) for bezier preview curves.
For a 300m connection: 20 segments = 15m each. The preview looked angular and users
reported it as broken.

**Rule:** Use `PREVIEW_SEG_M = 3.0.m` — one point every 3m, minimum 20 segments.
The build code already used `BEZIER_TARGET_SEG_M = 2.0.m`. The preview needs the same
adaptive logic.

**Implementation:** `n = [[(chord / PREVIEW_SEG_M).ceil, BEZIER_SEGS].max, 512].min`

This applies to both `bezier_pts` (no markers) and `bezier_pts_via` (with markers).
When the caller passes an explicit `n:`, that still overrides — but the default is now
adaptive.

**Also applies to the physical model:** if any path preview is drawn for the tabletop
demo, the same principle holds. Fixed segment counts break at scale.

### 13. Non-Station Components Must Not Enter the CP Pipeline — 2026-05-18

`pair_stubs` and `detect_cps_from_stub_pair_tags` are called on every component in the
model that has `gw_stub_pair` tagged entities. The terrain tile (Geolocation Content)
and any other non-station components may also be scanned if they accidentally carry
these tags or if the scan is broader than intended.

**Guard added:** `pair_stubs` now returns `[]` immediately when `all_pts.empty?`
(line 1266 in `jpod_structure_tool.rb`). Previously this caused `ZeroDivisionError`.

**The broader rule:** Every function that aggregates points and divides by count must
guard against the empty case. In SketchUp Ruby, there is no type system to prevent
a scan from encountering geometry the author never intended. Fail fast with `[]` or
`nil` — never divide blindly.

### 14. All Stored Datetimes Are UTC — 2026-05-20

**Rule:** Every datetime written to a file, database, attribute, or log record is UTC,
ISO-8601 format with Z suffix: `YYYY-MM-DDTHH:MM:SSZ`.

**In Ruby (SketchUp):**
```ruby
Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')   # correct
Time.now.strftime('%Y-%m-%dT%H:%M:%S')         # WRONG — local time, no zone marker
```

**In Python (Allie, Pi agents):**
```python
from datetime import datetime, timezone
datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')   # correct
datetime.now().isoformat()                                    # WRONG — local, no zone
```

**Display is a rendering concern.** Any user-facing timestamp converts UTC to local at
render time. The stored record is always UTC.

**If timezone context matters** (physical location of an event — e.g., Nora observing
an anomaly on a Pi in Gilroy vs. a future Pi in another city), store the UTC offset
alongside the UTC datetime:
```json
{ "observed_at": "2026-05-20T18:30:00Z", "utc_offset_minutes": -420 }
```
Never store local time as the primary record. The offset is metadata, not the anchor.

**Why this matters:**
- `expires_at`, `followme_hash`, stale detection — all comparisons require a single
  reference frame. UTC is that frame.
- Multiple machines (Mac, Pi fleet, Alice server) may be in different time zones or
  have misconfigured local clocks. UTC comparisons are immune to this.
- Allie's nightly reflection and Claude Code sessions operate in the same UTC space
  regardless of where the hardware sits.

**Applies to:** Noelle (map.json, feature.json), Nora (physical.json, nora.json),
Natalie (trip assignments), Alice (billing records), Allie (memory, harvest, reflect),
Claude Code (session files, process/inbox).

**Verified clean 2026-05-20** — 9 non-UTC data-field timestamps fixed across:
`noelle.rb`, `jpod_vehicle_runtime.rb`, `jpod_animator.rb`, `jpod_structure_tool.rb`,
`jpod_followme_exporter.rb`, `jpod_network_editor.rb`, `jpod_oversight.rb`.

### 9. Physical Observations Are Separate from Routing Declarations

`{model}.feature.json` is a routing declaration — regenerated by Noelle on every Build
and Validate. It must never contain physical observations.

Physical observations (bumps, trees, obstructions, alignment issues, debris, vibration,
speed anomalies) accumulate from Nora's sensors over every trip. They live in:

**`{model}.physical.json`** — schema `jpods-physical-v1`.

**Why separate:** If physical observations were in feature.json, every Build would erase
them. A bump Nora logged three weeks ago at 34% of a segment would vanish the next time
a student resets the network. The physical world does not reset.

**Who writes what:**
- Noelle writes `feature.json` (routing behaviors — what is allowed)
- Nora writes `physical.json` (physical reality — what was observed)
- Noelle reads both before confirming a route is clear

**Observation structure:**
```json
{
  "seg_S048_cp1_S050_cp0": {
    "observations": [
      { "type": "bump", "location_t": 0.34, "severity": "minor",
        "description": "column joint", "logged_at": "...", "logged_by": "NORA_0001" }
    ]
  },
  "S048.gw_uturn_1": {
    "observations": [
      { "type": "alignment_issue", "location_t": 0.5, "severity": "moderate",
        "description": "yaws right at apex", "logged_at": "...", "logged_by": "NORA_0001" }
    ]
  }
}
```

Line IDs in physical.json match trip.json exactly — both inter-station (`seg_*`) and
intra-station (`STATION_ID.gw_*`). trip.json segment list is the canonical key set.

Severity: `minor` (log, report at review) → `moderate` (warn operator) → `severe`
(block route until operator signs off).

**Not yet implemented.** `anomalies: []` in `nora.json` is the staging area. First step:
populate from IMU/encoder spikes; flush to `physical.json` at trip end.

### 15. Formation Map — Debug Once, Use Many — 2026-05-24

Each station template has one formation map at `su_jpods/formations/{formation}.json`
(schema `jpods-formation-map-v1`). It stores CP positions and tangents in LOCAL
(definition) coordinates.

**BUILD rule:** always use an existing formation map; never overwrite it.
- Map exists → read CP data from it (pre-verified, no re-detection)
- Map missing → generate from `connection_points` attribute + save for future use

**User debug path:** open template model → Console → Workflow → **Generate Formation Map**
(always overwrites — explicit re-verification action).

**Why this matters:** CP detection runs on live model geometry. If a student accidentally
moves a cp instance, the next BUILD would generate wrong CPs for every network using that
template. The formation map breaks this dependency — CPs are verified once, then locked.
Delete `su_jpods/formations/{formation}.json` to force a fresh generation.

**Applies to all environments:** the same formation map is the authority for SketchUp
(stub synthesis), Natalie (trip planning), and Nora (ezone boundaries). If the formation
map says CP0 is at a given position, all three agree. No per-network recalculation.

### 16. Minimum In-Station Arc Diameter = 3.5 m — Hard Physical Limit — Updated 2026-06-04

**Rule:** Every arc-geometry track in a station template (`gw_uturn_*`, `gw_c_*`, and
any future arc `gw_*` track) must have a turning **radius ≥ 1750 mm (diameter ≥ 3.5 m)**.
No arc may be tighter. `gw_uturn_*` arcs are exactly at this limit (chord = 3.5 m,
radius = 1.75 m). Updated 2026-06-04: rule is minimum DIAMETER 3.5 m, not radius 3.5 m.

**Source of truth:** `jpod_constants.rb` → `MIN_STATION_ARC_RADIUS_MM = 1750.0`

**Enforced at three checkpoints:**
1. `_generate_uturn_arc_pts_mm` — prints violation, refuses to silently compensate
2. `populate_from_open_template` — checks ArcCurve radius and chord/2; prints `🚫 FIX MODEL`
3. `proof_lines` — checks extracted.json segment radius; prints `🚫 ARC DIAMETER VIOLATION`

**gw_cp_in_* direction standard — established 2026-06-04:**
Every `gw_cp_in_*` component must contain a 172mm edge on the `vector_in` tag at the
component local origin, pointing in pod travel direction. This is the explicit model datum
(Axiom 10). `populate_from_open_template` and `proof_lines` both warn when it is missing.

**ArcCurve extraction — established 2026-06-04:**
`populate_from_open_template` now checks for SketchUp ArcCurve edges first (Priority 1)
before falling back to bounding-box extraction (Priority 2). ArcCurve gives exact
connected pts, correct radius, and ordered vertex chain — essential for traffic-circle-style
stations where bounding-box extraction gives disconnected endpoints.

**For designers:** if proof reports `ARC DIAMETER VIOLATION`, the arc was drawn too tight.
Move endpoints farther apart or increase the arc radius in the SketchUp model. Minimum
chord for a uturn (semicircle) is 3.5 m (chord = 2r = diameter).

**Full rule:** `readmes/sketchup/jpods-plugin.md` Rule 12.

---

## Current Active State (as of 2026-05-18)

### SketchUp Plugin — What Works

- Connect Guideways tool: CP detection, waypoint placement, live Bezier during drag
- Cursor state machine: hand (hover), 4-arrow (drag), crosshair (placement), pencil (gate)
- Build pipeline: runs without crash; **4 segments confirmed built on CA_Gilroy_Clean 2026-05-18**
- **CP tangent direction: CONFIRMED CORRECT** — cap_pt validation added; explicit gate datum
  overrides cluster/radial derivation; all tangents now reliably outward
- **Bezier preview density: CONFIRMED CORRECT** — PREVIEW_SEG_M=3m adaptive; no more 15m
  coarse segments on long connections
- Clearance height: CLEARANCE_HEIGHT = 4.6m; legacy Z zeroed in markers and center_pts
- **Waypoint marker Z: CONFIRMED CORRECT** — terrain + CLEARANCE_HEIGHT default; user adjusts Z; 1/5/10m reference circles at terrain level; stem from terrain to beam level; `ground_z_at` used for placement to skip existing marker stems
- **CP anchor Z: CONFIRMED CORRECT** — `from_cp[:center].z + BEAM_DEPTH` (non-traffic) or `+ BEAM_DEPTH/2` (traffic circle); confirmed flush connection at S012 and S044 on 2026-05-14

### Change Control — Marker Z and CP Anchor Z

**These two algorithms are confirmed working. Do not change either without a written plan.**

Three CP anchor alternatives were tested on 2026-05-14 and all failed before restoring
the committed code. The documented failures are in `readmes/sketchup/jpods-plugin.md`
Rules 9–10 and `readmes/sketchup/jpods-cp-regression-guard.md`.

Before proposing any change to marker Z or CP anchor Z:
1. State the specific problem being solved
2. Cite the exact code location being changed
3. Describe why the current algorithm fails for that case
4. Describe the proposed algorithm and which failure modes it avoids
5. Get Bill's sign-off before touching code

### SketchUp Plugin — Open Issues

- **Station templates** (F-07): station .skp stubs still at 7.5m stub height — structural
  redesign needed, not code. Logged in feature-list.md.
- **Noelle direction violations**: S013, S044 flagged "missing detectable platform guideways"
  — station model definition issue, not plugin bug.
- **Station looping**: pods accumulate at station U-turns — deferred to ~2026-05-15.

### Physical Scale Model — Current State

Physical pods (Baron-4WD + Romeo BLE + Pi) operational. Startup guide at
`readmes/25-jpods-allie-startup-guide.md`. I2C bus lockup resolved.
Mini-bot tabletop demo paused until ~2026-05-15.

### Route-Time — Current State

Fully working network planner and simulator. See `readmes/27-route-time.md`
and `readmes/28-route-time-gui-architecture.md`.

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
| Risk register | `readmes/system/ouch-list.md` |
| Feature backlog | `readmes/sketchup/jpods-feature-list.md` |
| Noelle (all domains) | `readmes/agents/noelle.md` |
| Natalie | `readmes/agents/natalie.md` |
| Nora | `readmes/agents/nora.md` |
| Allie | `readmes/agents/allie.md` |
| Today's handoff | `today/handoff.md` |
| Allie's nightly reflection | `thoughts/YYYY-MM-DD-reflect.md` (most recent) |
| Session log template | `sessions/_template.md` |

---

## Reload Command (SketchUp Ruby Console)

To reload a changed file without restarting SketchUp:
```
load Sketchup.find_support_file('jpod_network.rb', 'Plugins/su_jpods')
```
Then: Extensions > JPods > Create > Build to test.

**Always use `Sketchup.find_support_file` — never a literal path with spaces.**
The path `Application Support/SketchUp 2026` contains spaces. Markdown code blocks
and backtick formatting introduce extra whitespace at those spaces when rendered,
producing a broken command that most users cannot diagnose. `find_support_file`
has no spaces and works regardless of SketchUp version or user home directory.

Replace the filename to reload other files:
```
load Sketchup.find_support_file('jpod_structure_tool.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_connect_tool.rb', 'Plugins/su_jpods')
load Sketchup.find_support_file('jpod_animator.rb', 'Plugins/su_jpods')
```

Reload only the changed file — SketchUp state persists across reloads,
so a full restart is only needed if constants change.

# Rejected Paths
**Purpose:** Design paths seriously considered and set aside. The temptation is as
important as the decision. A successor who only sees the chosen path does not
understand why it was chosen.

**Format:**
```
## [What was rejected] — [Date]
**The temptation:** why it seemed right
**Why it was set aside:** the actual reason
**What was chosen instead:** the path taken
**The test:** how you would know if the rejection was wrong
```

---

## Staying at 7.5m Clearance — 2026-05-13

**The temptation:** Passive safety. 7.5m clears every standard vehicle by 3m.
No sensors needed. No latency budget. No regulatory certification problem.
The safety model is simple: height is the protection.

**Why it was set aside:** Urban JPods networks cannot practically use 7.5m columns.
The column cost, the visual intrusion, and the permit challenges in tight urban
corridors make 7.5m undeployable at the scale JPods needs to reach. The engineering
is correct at 7.5m but the deployment is wrong.

**What was chosen instead:** 4.6m clearance with a committed (but not yet built)
active safety complement: height sensing, pod defensive stop, response latency budget,
local regulatory certification. The guideways are safe. The pods need cover.

**The test:** If CL-02 (sensor system design) is still Unaddressed when the first
passenger deployment is proposed, the rejection of 7.5m was wrong — not in principle,
but in practice. The active safety system is the price of the rejection. If it is
not built, 4.6m is not safe and the rejection should be revisited.

---

## Calculated Centerline as Position Reference — 2026-05-13

**The temptation:** The centerline between two CP stubs is geometrically clean.
It is equidistant from both guideways. It is what you would draw on paper. For
routing, for animation, for sensors — the center of the track seems like the
natural reference.

**Why it was set aside:** SketchUp's geometry kernel is edge-based. FollowMe walks
edges. When a computed centerline was used as the position reference, FollowMe collapsed
paths, Z values drifted, and animation produced wrong positions. The calculated point
has no corresponding edge in the model — so SketchUp cannot use it as intended.
Physical sensors have the same problem: a TOF aimed at a calculated centerpoint reads
a different distance after any geometry adjustment.

**What was chosen instead:** Edge-driven references everywhere. Beam bottom face edge
for clearance. Stub end edge for CP position. Terrain surface for guideway elevation.

**The test:** If a position reference must be recalculated when beam width or geometry
changes, it is a calculated centerline, not an edge reference. Edge references
self-correct; centerline offsets silently diverge.

---

## Central Controller for Ezone Coordination (Noelle as Central Process) — Pre-2026

**The temptation:** A central Noelle process that coordinates all pods' ezone access
is simpler to reason about, easier to debug, and closer to how most traffic management
systems work. One source of truth. One place to look when something goes wrong.

**Why it was set aside:** The patent's core innovation is no central controller.
A central Noelle process contradicts the distributed design, creates a single point
of failure, and requires a communication layer between pods and the controller that
introduces latency and failure modes. More fundamentally: if Noelle is central, she
is a governor, not a coordinator. Individual sovereignty at the vehicle level requires
that each Nora govern herself.

**What was chosen instead:** Noelle as distributed behavior. Each Nora runs ezone.py.
Emergent coordination IS Noelle. Speed adjustment (zipper merge) replaces stop-and-wait.

**The test:** If two pods can deadlock in an ezone without any central resolution
mechanism, the distributed design is incomplete. But the alternative — central
coordination — trades one failure mode for another (central process crash, network
partition, latency). The distributed design's failure mode (deadlock) is less common
and more recoverable than the central design's failure mode (single point of failure
at scale).

---

## WebClerk/Alice Owning the Route Map — 2026-04-30

**The temptation:** Alice already owns the database. FollowMe.json is a structured
data artifact. Putting the route map in WebClerk makes it queryable, auditable,
versioned, and accessible to the commerce layer without file IO.

**Why it was set aside:** The route map is a runtime artifact for SketchUp and
physical deployment. It must be available without network access, without WebClerk
running, without Alice available. Making it a WebClerk dependency would break
the sovereignty of the SketchUp design tool and the physical deployment. The
principle: no network dependency in the authoring tool.

**What was chosen instead:** FollowMe.json lives next to the .skp file. Alice reads
it; she does not own it. The commerce layer is downstream of the design tool, not upstream.

**The test:** If SketchUp cannot build or animate without a WebClerk connection,
the rejection was wrong. SketchUp must remain self-contained.

---

## Continuous Sync Between SketchUp State and Noelle/Natalie/Nora — 2026-05-09

**The temptation:** Keep SketchUp model state, followme.json, Natalie's route graph,
and Nora's trip files continuously synchronized — any change in one immediately
propagates to all others. No stale state. No export step.

**Why it was set aside:** Continuous sync requires all components to be online and
coherent simultaneously. In practice, students will be mid-edit when they want to
check a route. The model will be incomplete. The sync will produce inconsistent state.
Worse: the export step is a gate — it forces the designer to explicitly commit to
a network state before routing or animation. Removing the gate removes the deliberate
commitment.

**What was chosen instead:** Explicit export gates. FollowMe is exported after Build.
Trip files are generated after export. Stale trip files are purged at export time.
Each gate is a deliberate act, not a background synchronization.

**The test:** If a student can accidentally animate on a stale network definition
without knowing it, the rejection was wrong. The explicit export gate exists to prevent
exactly this failure mode.

---

## Fixing the SketchUp Ruby `*` Operator via Monkey-Patching — 2026-05-13

**The temptation:** Add a `coerce` method to `Geom::Vector3d` via Ruby's open-class
feature. `class Geom::Vector3d; def coerce(other); [self, other]; end; end`. This
would make `vec * 2.5` work everywhere without changing any existing code.

**Why it was set aside:** Monkey-patching SketchUp's core geometry classes is an
invitation to subtle, hard-to-debug failures. Other SketchUp plugins may depend on
the exact current behavior of Vector3d. SketchUp updates may silently conflict with
the patch. The patch would need to be loaded before any code that uses Vector3d,
creating a load-order dependency. The cure is worse than the disease.

**What was chosen instead:** Explicit component expansion everywhere. The rule is
clear, searchable, and self-documenting. Any developer reading `Geom::Vector3d.new(n.x * s, ...)`
understands what is happening. The monkey-patch would hide the constraint.

**The test:** If the component expansion produces significantly more bugs than the
monkey-patch would have introduced, the rejection was wrong. In practice, the explicit
form is more legible and the constraint is now documented in CLAUDE.md.

---

## Accumulating Design Decisions in Git Commit Messages Only — 2026-05-13

**The temptation:** Git commit messages are the natural place for "why" documentation.
They are attached to the code change, versioned, and searchable. No separate documentation
files needed.

**Why it was set aside:** Git history is excellent at "what changed" and "when."
It is poor at "what was considered and rejected," "what this decision expresses as
a principle," and "what it will cost if this decision is wrong." Commit messages
require reading the full history to synthesize a pattern. They are not readable by
Allie's synthesis scripts. They do not survive repository forks or code rewrites.
The wisdom layer is not a replacement for git history — it is a separate artifact
that expresses what git cannot.

**What was chosen instead:** Agent Design Decisions tables for dated decisions;
`readmes/wisdom/` for the scar ledger, rejected paths, and permanent principles.
Git history for "what" and "when." Wisdom layer for "why" and "what it means."

**The test:** If a successor can reconstruct the design reasoning from git history
alone without the wisdom layer, the rejection was wrong. In practice, they cannot —
the rejected paths and the principles are not in any commit message.

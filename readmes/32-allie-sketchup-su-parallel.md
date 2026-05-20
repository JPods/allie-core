# Allie — SketchUp (SU) Parallel Draft
**Applies to:** SketchUp 2026 JPods plugin
**Purpose:** Parallel comparison draft for SU track
**Source set reviewed:** 30-allie-universal.md, 31-allie-route-time.md, 32-allie-sketchup.md, 33-allie-physical.md
**Date:** 2026-04-27

---

## Why this parallel draft exists

This draft is a comparison candidate, not a replacement yet. It tightens SU authority boundaries, clarifies what must be shared with Route-Time and Physical, and removes ambiguity about who does what during a SketchUp session.

---

## Changes Needed (from SU perspective)

### Needed updates in 30-allie-universal.md

1. Add an explicit "evidence packet" requirement at session end.
   - Every environment should publish the same 5 outputs: what changed, what failed, what passed, what is still unknown, what must transfer cross-domain.
2. Clarify "Allie does not rewrite authoritative files directly".
   - Add: unless Bill explicitly instructs and approves a concrete edit scope.
3. Add promotion criteria for universal knowledge.
   - Promote only when verified in all three environments or verified in two plus not contradicted by physical.

### Needed updates in 31-allie-route-time.md

1. Add a required export format for SU handoff.
   - Route-Time needs a stable, machine-readable handoff payload so SU and Physical can compare topology and directionality.
2. Add a stronger distinction between congestion and topology issues in reporting.
   - Require both indicators in reports: congestion metric and route-ratio metric.
3. Add the same session evidence packet fields used in SU and Physical.

### Needed updates in 33-allie-physical.md

1. Add a direct intake contract for SU model intent.
   - Physical should receive a concise route-intent table from SU so failures can be attributed to geometry, control, or sensing.
2. Add a rule for physical contradiction handling.
   - If physical contradicts SU/Route-Time, record exact contradiction and required upstream correction in both documents, same day.
3. Add explicit feedback format for simulation calibration.
   - Physical should emit calibration deltas (timing, queue behavior, blockage frequency) in fixed fields.

### Needed updates in 32-allie-sketchup.md

1. Resolve participation ambiguity.
   - Current wording says Allie is consulted at start/end, but also describes in-session guidance. Define this as:
     - Required: start + end
     - Optional but preferred: in-session checkpoints at decision boundaries.
2. Add SU readiness gate as a checklist artifact.
   - Not just rule checks; produce a signed-ready record before FollowMe export.
3. Make CP direction validation explicit and testable.
   - Include a pre-export direction scan and an exception list.

---

## SU Parallel Copy (Candidate Text)

## For Bill

### What SU is responsible for

SU is the design-authoring environment. It is where topology intent is declared:
- station identity,
- platform identity,
- guideway direction,
- CP boundary orientation,
- export graph integrity.

SU is not the runtime truth. Physical runtime behavior is truth. Route-Time is analytic truth for the modeled assumptions. SU must provide clear intent so those two systems can validate or reject it.

### Agent roles in SU

- Noelle: definition authority and precondition gate.
- Natalie: route-feasibility authority on exported graph.
- Nora: operational behavior observer (via downstream evidence and repeated-failure patterns).
- Athena: escalation authority (Stop and Review discipline).
- Allie: intelligence layer for cross-session and cross-domain pattern recognition.

### Operating rule

Loud failure at definition time beats silent degradation at export/runtime.

If model intent is incomplete, refuse export and emit one corrective message with exact failing objects.

---

## For Copilot and Allie

### SU authority boundaries

- Ruby authority code decides pass/fail.
- Allie advises and records cross-domain implications.
- Copilot edits plugin code and tooling when instructed.
- Bill is final decision authority.

### Required SU readiness gate (must pass before export)

1. Station identity
   - Every station definition has unique Sxxx ID.
2. Platform identity
   - Every station has at least one platform-tagged guideway.
3. Directional integrity
   - Every directional element has unambiguous inbound/outbound assignment.
   - Red=inbound, Blue=outbound.
4. CP pair integrity
   - CP connects only to CP.
   - Disconnect removes both guideways of pair.
5. Graph reachability
   - Every station platform can route to every required destination class under current topology constraints.
6. Exception ledger
   - Any intentional exception is listed with reason, owner, and sunset date.

If any item fails, export is blocked.

### Required SU session evidence packet

At session end, SU publishes this packet:

- Changed definitions: list of touched station/circle/component IDs.
- Gate failures seen: grouped by fault type and count.
- Stop-and-Review events: count, trigger type, resolution status.
- Directional exceptions: list, reason, owner, sunset.
- Cross-domain implications:
  - what Route-Time should verify,
  - what Physical should verify.

This packet is the comparison substrate across your three version streams.

### Cross-domain mapping contract (SU side)

For each concept that leaves SU, include:

1. SU representation
2. Route-Time representation
3. Physical representation
4. invariant that must survive translation
5. implementation details that must not be transferred

Example:

- Concept: CP boundary direction
- SU: colored directional endpoint in component definition
- Route-Time: CP object with inbound/outbound nodes
- Physical: switch behavior with directional traversal constraints
- Invariant: inbound/outbound are not interchangeable
- Do-not-transfer: method names, internal API signatures

---

## Comparison Protocol (SU version)

When comparing SU vs Route-Time vs Physical outputs, use this sequence:

1. Topology intent check
   - Do all three agree on station/CP connectivity?
2. Directionality check
   - Do all three preserve inbound/outbound direction?
3. Reachability check
   - Can required OD pairs complete in all three?
4. Throughput/congestion check
   - Are bottlenecks aligned in location and order-of-magnitude?
5. Contradiction record
   - If mismatch exists, log root candidate and required correction target (SU, Route-Time, or Physical runtime/calibration).

---

## Design decisions in this SU draft

| Date | Decision | Why |
|------|----------|-----|
| 2026-04-27 | SU must emit a session evidence packet | Enables side-by-side comparison without narrative ambiguity |
| 2026-04-27 | SU readiness gate is a blocking checklist artifact | Prevents silent degradation and ambiguous export quality |
| 2026-04-27 | In-session Allie support set to optional checkpoints, not mandatory continuous loop | Preserves workflow speed while keeping high-leverage intervention points |
| 2026-04-27 | Contradictions must declare correction target | Avoids unresolved "someone else should fix it" drift |

---

## Open questions for polish

- Should SU evidence packet be markdown, JSON, or both?
- What is the minimum OD route set for mandatory reachability tests before export?
- Should Stop-and-Review thresholds differ by fault class (identity fault vs routing fault)?
- Do we need a single shared schema for comparison artifacts across SU, Route-Time, and Physical?

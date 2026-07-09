# WhatIf — Allie's Observation Log
**Owner:** Allie — written autonomously when something is noticed that may matter later.
**Purpose:** Seeds, not conclusions. A WhatIf is not a recommendation. It is a flag
that something was observed and should be checked.

**Permission:** Allie writes here without asking. Bill and Claude Code read this at
session start when working in a relevant domain. A WhatIf that becomes a real risk
moves to the ouch-list. One that becomes a design decision moves to the agent files.
One that becomes a principle moves to `bill.md`. The ones that stay here are still seeds.

**Format:**
```
## [WI-NNN] [Domain] — [Date]
**Observed:** what Allie noticed
**Why it might matter:** the consequence if the observation is correct
**Check by:** how you would verify whether it materialized
**Status:** Open / Resolved / Promoted
```

---

## [WI-001] SketchUp — 2026-05-13

**Observed:** Station .skp templates have stubs at 7.5m (the old clearance height).
The code now correctly builds guideways at 4.6m by zeroing desired_z and using
terrain + CLEARANCE_HEIGHT as the anchor. But the structural geometry — the physical
stub that the guideway beam connects to — is still at 7.5m. A student building a
network at 4.6m will see a vertical gap at every station connection.

**Why it might matter:** The gap is not cosmetic. It means the FollowMe path crosses
a discontinuity at the station join. Depending on how SketchUp handles the sweep, this
could produce broken faces, visible gaps in the beam, or animation path errors where
pods "fall" at station joins.

**Check by:** Build a network with stations and inspect the beam-to-stub connection
at each station in a zoomed view. If there is a visible gap or a bent face at the join,
F-07 is a build blocker, not just a visual defect.

**Status:** Open. F-07 logged in `readmes/sketchup/jpods-feature-list.md`.

---

## [WI-002] Physical — 2026-05-13

**Observed:** The clearance height decision (4.6m) was made and documented. The sensor
system (CL-02) does not exist. Bill accepted responsibility explicitly. But: accepted
responsibility is not the same as a design timeline. CL-02 could age indefinitely on
the ouch-list without a specific owner and date.

**Why it might matter:** If the first physical deployment happens at 4.6m without sensors,
the risk is real and unmitigated. The ouch-list says Must Fix. Must Fix without a deadline
and an owner tends to become Deferred.

**Check by:** At the start of any deployment planning session, check CL-02 status.
If it is still Unaddressed and someone is discussing a deployment timeline, flag it
immediately. The deployment timeline and the sensor design timeline must be the same conversation.

**Status:** Open. CL-02 in `readmes/system/ouch-list.md`.

---

## [WI-003] Cross-domain — 2026-05-13

**Observed:** The edge-driven axiom was derived from a SketchUp-specific failure
(FollowMe walking edges, centerline mismatch). It was then generalized to physical
sensors, routing, and ezone boundaries. But the generalization was asserted, not tested.

**Why it might matter:** In physical sensor placement, the equivalent of "edge-driven"
might not be the beam face. It might be a specific point on the beam cross-section
(e.g., the beam bottom centerline is actually the correct reference for clearance
measurement to the ground). If the axiom was over-generalized, applying it rigidly
to physical sensor specs could produce wrong sensor placement.

**Check by:** When the first sensor spec is written for height detection, test whether
"edge-driven" produces the correct reference point. If the sensor needs to measure
to the beam centerline (not the beam face edge) for clearance calculation, the
axiom needs a domain qualifier.

**Status:** Open. Theoretical concern — no specific failure yet.

---

## [WI-004] MeshMobility — 2026-05-13

**Observed:** MeshMobility's simulation uses MIN_HEADWAY_MM for vehicle spacing.
The physical scale model uses GUIDEWAY_SPACING_M (5.0m) as the telemetry-based
minimum gap. These are separate constants in separate codebases. If they diverge,
simulation results will not match physical behavior.

**Why it might matter:** A student designing a network in MeshMobility who then tests
it physically will see different throughput. The simulation will predict a certain
capacity; the physical system will deliver less if the headway constants differ.

**Check by:** Find the headway constant in MeshMobility's Python codebase and compare
to `GUIDEWAY_SPACING_M` in `jpod_constants.rb`. If they differ by more than 10%,
flag as a calibration issue.

**Status:** Open. Not verified since 2026-05-01.

---

## [WI-005] Governance — 2026-05-13

**Observed:** The Noelle distributed design (each Nora runs ezone.py; emergent
coordination IS Noelle) has no governance mechanism for network-wide parameter
changes. NEW-05 ("Articles of Confederation flaw") is on the ouch-list. But there
is no design for how a distributed system ratifies a new parameter simultaneously.

**Why it might matter:** As physical deployments scale beyond a single test track,
there will be a moment when a safety parameter (headway, speed limit) needs to
change across an entire fleet simultaneously. Without a ratification mechanism,
the parameter change is either applied pod-by-pod (inconsistent state during rollout)
or requires a coordinated shutdown (operationally expensive).

**Check by:** When the first multi-pod deployment beyond 4 vehicles is planned,
check whether a parameter change can be applied consistently. If it cannot,
NEW-05 becomes a deployment blocker.

**Status:** Open. NEW-05 in ouch-list. No design exists.

---

## [WI-006] Succession — 2026-05-13

**Observed:** Bill is explicit about mortality and succession. The wisdom layer
was built in response. But the wisdom layer is in the Allie repo, which requires
knowing the repo exists to read it. A successor who inherits only the JPods codebase
(`su_jpods`, `JPodsSM_RPi`, `MeshMobility`) will not find `readmes/wisdom/` unless
they are explicitly directed there.

**Why it might matter:** The knowledge layer (code, comments, README) will travel
with the code. The wisdom layer will not, unless it is deliberately included in
handoffs, forks, or succession packages.

**Check by:** When the first handoff to a new team member or successor happens,
check whether `readmes/wisdom/` is included and whether they are explicitly asked
to read `bill.md` before reading any code.

**Status:** Open. Succession protocol not yet written.

---

## [Space for Allie's future entries]

*Allie adds entries here when she observes something that may matter later.
Each entry is a seed. Seeds that grow become risks, design decisions, or principles.
Seeds that don't grow are still worth planting.*

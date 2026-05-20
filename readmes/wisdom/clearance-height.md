# Clearance Height — 4.6m vs 7.5m
**Date:** 2026-05-13
**Domain:** JPods Engineering / Safety
**Status:** Decision made. Scar not yet paid. Mitigation not yet built.

---

## The Decision

JPods guideways were designed at 7.5m clearance — the AASHTO highway overpass standard.
A standard semi (4.1m) passes under with more than 3m to spare. No active detection needed.
Height alone is the protection.

Bill changed this to 4.6m. The guideways are safe at 4.6m — the beam structure clears
a standard vehicle. But a JPods pod traveling on that beam is within reach of a raised
dump truck bed, a double-stack flatbed load, an overheight vehicle of any kind.

The reason for 4.6m: urban deployment. 7.5m columns are impractical in tight city
corridors. The cost and geometry savings are real. But they come with a changed safety model.

At 7.5m: passive safety. Height is the protection. No sensors required.
At 4.6m: active safety required. Height sensing, pod defensive stop, response latency
budget, sensor placement on the network, regulatory certification — none of these exist yet.

---

## What It Cost

Nothing yet. Which is the most dangerous kind of cost.

The scar has not arrived. Bill made this decision clearly and deliberately — not by
accident, not by ignoring the risk. He said: *"I am accepting responsibility to build
systems to prevent trucks from hitting pods travelling under guideways. The guideways
are safe. The vehicles are exposed."*

The cost will arrive when:
- A pod is struck by an overheight vehicle before sensors exist, OR
- The sensor system is built under time pressure rather than proper design, OR
- A regulator asks for the certification basis and there is none

The lesson is in the gap between the decision date (2026-05-13) and the mitigation
date (unknown). Every day in that gap is borrowed time.

**Risk register:** CL-01 through CL-07 in `readmes/system/ouch-list.md`
CL-02 (no sensor system) is Existential / Must Fix.
CL-04 (response latency budget not yet calculated) is Existential.

---

## What Was Tempted

**Temptation 1: Stay at 7.5m.**
Passive safety is simpler. No sensors to design, no latency budget, no regulatory
certification problem. The cost is tall columns in urban corridors, and the political
difficulty of getting approvals for 7.5m urban structures.

This was set aside because 4.6m is the right engineering answer for urban JPods —
but only if the active safety complement is built. 7.5m without sensors is safe.
4.6m without sensors is not yet safe for passengers.

**Temptation 2: Treat 4.6m as an interim without naming the risk.**
Ship the design tool at 4.6m, document it somewhere, hope the sensor system gets
built before deployment. Do not make the risk explicit. Do not put it on the ouch-list.
Do not say out loud that this is a commitment, not a preference.

Bill rejected this explicitly. He insisted the risk go on the ouch-list. He named
it in the constants file. He said the words: *"I am accepting responsibility."*

That is the harder right. The temptation to soften it was present. He did not take it.

**Temptation 3: Treat sensor design as someone else's problem.**
"We'll hire an engineer for that." "The deployment site will figure it out."
"The regulator will tell us what they need."

The problem with delegating safety design to an unknown future actor is that the
delegation itself becomes the risk. When no one owns CL-02, CL-02 never gets done.
Bill's explicit acceptance of responsibility — written into code comments, into the
ouch-list, into this document — is the attempt to prevent that failure mode.

---

## The Principle

*Active safety cannot be borrowed against. A risk accepted without a named owner,
a design, and a timeline is not accepted — it is deferred, and deferral is not
acceptance.*

Passive safety (height alone, separation alone) requires no ongoing commitment.
Active safety (sensors, defensive stop, response latency) is a system that must
be designed, built, tested, certified, and maintained. These are not equivalent.
Choosing active safety means choosing the obligation, not just the technology.

---

## In Bill's Voice

*"I am accepting responsibility to build systems to prevent trucks from hitting pods
travelling under guideways. The guideways are safe. The vehicles are exposed with
need Allie and Athena clearly aware of this accepted risk."*

*"There are no such protections for pedestrians and cars on roads."*
(His framing: roads provide no active protection from vehicle strikes. JPods at 4.6m
is in that same category until sensors exist. The comparison is honest, not dismissive.)

*"It belongs on the ouch-list because it is a known risk I am choosing."*

---

## Cross-Domain Connection

**Usufruct:** Taking the cost savings of shorter columns without building the sensor
system is extraction without return. The debt is owed to the first passenger who rides
at 4.6m. Until CL-02 has a design and a path to certification, that passenger is
owed something we have not yet paid.

**Constitutional:** Bill's comparison to roads is deliberate. Roads kill 40,000 people
per year in the US. The regulatory framework accepts this because the alternative
(not driving) is politically impossible. JPods is an argument that the alternative
IS possible — but only if JPods does not replicate the same passive-safety-as-sufficient
assumption. If JPods at 4.6m accepts "height is protection" without sensors, it has
made the same category of error it was built to correct.

**Sovereignty:** The sensor system must be locally governed. A centrally mandated
sensor standard (from a Federal agency) that does not match local deployment conditions
is the same failure mode as Federal highway standards that do not match local geography.
The design principle: sensor placement, latency budget, and certification basis must be
worked out by the local operator with the local regulator — not handed down.

---

## WhatIf

- What if a pod is struck before sensors exist — during a demo, during a student
  exercise, during an early deployment? The question is not whether to build sensors —
  it is whether the timeline for building them is honest.

- What if the response latency budget (CL-04) proves the sensor system impossible
  to certify at 4.6m, and the only safe clearance is 5.5m or 6m? The decision to
  go to 4.6m would then require revisiting. The honest answer is: we do not yet know.

- What if the first deployment regulator requires 7.5m, and the station templates
  are already designed for 4.6m? F-07 (update station .skp stubs) is not yet done.
  The structural mismatch would then be a deployment blocker, not just a design debt.

---

## Who Carries This

**Bill James** — accepted responsibility explicitly on 2026-05-13.
**Allie** — holds the cross-domain awareness. Flagged to watch CL-02 status.
**Athena** — security and risk reviewer; CL-04 (latency budget) is hers to flag.
**Whoever designs the first physical deployment** — owns the sensor system design
or must explicitly refuse the 4.6m clearance and revert to 7.5m.

An unowned risk is not a managed risk. The owner must be named at each handoff.

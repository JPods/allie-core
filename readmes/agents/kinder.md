# Kinder — Special Users

**One-liner:** I ensure the system works for passengers who cannot advocate for themselves — children, wheelchair users, non-verbal passengers, and anyone the default design does not see.
**Ouch-list items I own:** K-01 through K-08
**Signing status:** Not applicable (user-experience design agent — no MQTT presence)

---

## Responsibilities

- Unaccompanied minor protocol: accountability, emergency contact, response chain (K-01)
- Wheelchair securement: tie-down spec, emergency stop forces, projectile prevention (K-02)
- Pod interior dimensional spec: wheelchair turn radius, stroller fold requirement (K-04, K-08)
- Child safety: gap sizing for windows and door seams on elevated sections (K-03)
- Sensory accommodation: alert volume and visual intensity for autism spectrum users (K-05)
- Non-verbal emergency signaling (K-06)
- Heat emergency protocol for stranded pod: passengers who cannot self-evacuate in summer heat (K-07 — Existential)

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| — | No decisions recorded yet | Kinder's domain is in the ouch list but detailed design has not started |

---

## Open Questions

- K-07 is Existential: a stranded pod in summer sun becomes a heat emergency in minutes for a child or wheelchair user. What is the maximum stranded time before intervention is required, and what is the automated response?
- K-01: unaccompanied minor protocol — does the pod refuse to dispatch, require a confirmed adult at the destination, or something else?
- K-02: wheelchair securement spec — what g-force does the pod exert in emergency stop, and what tie-down force is required?
- K-05: how do we test sensory accommodation? Who is the test population?
- K-06: non-verbal emergency signal — large button? Gesture? Both?
- Does the pod know it has a special-needs passenger? If so, how is that communicated at boarding without violating passenger privacy (A-06)?

---

## Interfaces

Not applicable — Kinder produces design specifications and test protocols.

---

## Notes to Other Agents

- **Willi:** W-02 (platform gap) and K-04 (wheelchair dimensions inside pod) are the same problem from two angles. Solve together.
- **Nora:** K-07 requires Nora to detect a stranded condition and alert within a defined time window. What sensors does Nora have for interior temperature? None currently.
- **Matilda:** K-02 wheelchair securement forces depend on Matilda's emergency stop deceleration spec. What is the maximum deceleration in an emergency stop?
- **Athena / Allie:** K-01 (unaccompanied minor) and K-06 (non-verbal emergency) both involve passenger data. The sovereignty question — who holds the minor's identity token, and who can Nora alert — must be answered before either protocol is designed.

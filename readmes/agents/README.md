# Agent Team — README Index
**Last Updated:** 2026-04-04
**Purpose:** One file per agent. Each agent owns their file and can add to it freely. This is the living record of who does what, what decisions have been made, and what is still open.

---

## Template

Every agent file uses this structure. Add sections as needed; do not remove them.

```
# [Name] — [Domain]

**One-liner:** What I do in one sentence.
**Ouch-list items I own:** [list of risk IDs]
**Signing status:** has key pair | planned | not yet

---

## Responsibilities
## Design Decisions  (date | decision | reasoning)
## Open Questions
## Interfaces        (sends | receives | signs | requires signatures from)
## Notes to Other Agents
```

---

## Engineering Design Team

| Agent | Domain | File |
|-------|--------|------|
| Cilia | Civil / Structural | [cilia.md](cilia.md) |
| Matilda | Mechanical + Fleet Calibration | [matilda.md](matilda.md) |
| Sparki | Energy | [sparki.md](sparki.md) |
| Athena | Security | [athena.md](athena.md) |
| Willi | Pedestrian / Walking Access | [willi.md](willi.md) |
| Kinder | Special Users | [kinder.md](kinder.md) |

## Control System Agents

| Agent | Role | File |
|-------|------|------|
| Nora | Vehicle — autonomous pod | [nora.md](nora.md) |
| Natalie | Router — trip scheduling | [natalie.md](natalie.md) |
| Noelle | Load Balancer — ezones, prepositioning | [noelle.md](noelle.md) |
| Sally | Station Processor — per-station slot registry, parking queue | [sally.md](sally.md) |

## Ecosystem Agents

| Agent | Role | File | WC Connection |
|-------|------|------|---------------|
| Alice | WebClerk specialist — data quality, billing, patterns | [alice.md](alice.md) | 24 |
| Allie | Bill's personal AI — cross-domain, sovereignty review | [allie.md](allie.md) | 22 |
| Athena | Adversarial reviewer — security, privacy, action gate | [athena.md](athena.md) | 23 |

## Allie — Cross-Environment Architecture

These documents define Allie's role in each environment and the three-layer knowledge taxonomy that governs what knowledge transfers across environments. Every AI working in any environment should read the universal document and their environment-specific document.

| Document | Scope | File |
|----------|-------|------|
| Universal — Allie role + knowledge taxonomy | All environments | [../../30-allie-universal.md](../../readmes/30-allie-universal.md) |
| Route-Time — user guide + AI instructions | Python/Flask/Leaflet simulation | [../../31-allie-route-time.md](../../readmes/31-allie-route-time.md) |
| SketchUp Plugin — user guide + AI instructions | Ruby/SketchUp 3D modeling | [../../32-allie-sketchup.md](../../readmes/32-allie-sketchup.md) |
| Physical JPods — user guide + AI instructions | RPi/MQTT/physical scale model | [../../33-allie-physical.md](../../readmes/33-allie-physical.md) |

---

## Editing Rights

**Any agent may edit any file in `/agents/` at any time for anything that affects their domain.**

This is not limited to your own file. If Cilia sees a structural consequence in Matilda's domain, she writes it in matilda.md. If Nora discovers a routing edge case, she writes it in natalie.md. Cross-domain notes belong in the file of the agent who needs to act on them, not only in the file of the agent who noticed them.

The only constraint is honesty: write what you know, date design decisions, mark open questions as open.

**Athena maintains integrity.** Every file in `/agents/` is hashed and backed up by Athena's verification system (`athena/verify_agents.sh`). Changes are logged. If a file is hijacked or corrupted, Athena can restore from a signed backup. Write freely — Athena has the merge.

---

## Physical Processor Architecture

Every entity in a deployed JPods network has **one or more dedicated processors** tracking and timing its own events. No entity depends on a central clock.

| Entity | Physical processor | Events it tracks |
|--------|--------------------|-----------------|
| **Nora** (each pod) | Raspberry Pi (one per vehicle) | Encoder ticks, ToF range, IMU, AprilTag, MQTT START/ACTION |
| **Sally** (each station) | Station chip (ESP32-class or equivalent) | trip_complete arrival, slot assignment, occupancy threshold, dispatch signals |
| **Natalie** (router) | Dedicated Pi or server | Route requests, trip_complete confirmations, balance signals from all Sallys, emergency pre-emption |
| **Noelle** (validator) | Design-time only (SketchUp) | Not a runtime agent — runs at Build/Validate, not during operation |
| **Each CP** (switch) | Embedded controller at the physical switch | Diverge/merge commands from Natalie, pod detection, fault reporting |

**Consequence for simulation:** The SketchUp simulation has one master animation tick (`onNextFrame`). This tick stands in for each agent's independent clock. Each agent is called from the master tick but owns its own internal tick counter and cadence — it decides whether to act on any given tick. The code structure is:

```ruby
# In jpod_animator.rb onNextFrame:
Nora.on_tick(n)     # every tick — position interpolation
Sally.on_tick(n)    # slow poll + event callbacks
Natalie.on_tick(n)  # route and balance checks, slower cadence
```

Each agent also exposes `on_event(type, payload)` for event-driven callbacks (arrival, departure, fault). In physical deployment, `on_event` is called by MQTT message receipt on the agent's own processor — no master tick involved. The same agent logic runs in both contexts; the difference is only in who calls it and when.

**"1 or more processors" means fault tolerance is possible.** A station chip can have a primary and a standby. A pod can have a nav processor and a separate sensor-fusion processor. The protocol does not assume single-processor agents. Each processor publishes on MQTT; the other agents read without caring whether it came from a primary or backup.

---

## Cross-Cutting Rules

1. **Payload is always readable.** Sign for authenticity; never encrypt to obscure. Debugging must remain possible without Athena's tooling.
2. **Any agent can sign and require signatures without asking permission.** That is what sovereignty means at the message layer.
3. **Add to ouch-list freely.** Flag cross-domain risks in the other agent's section — that is the protocol, not overstepping.
4. **Open questions belong here, not in your head.** If you do not know, write it down.
5. **Edit `/agents/` freely.** Athena has the merge and the backup. You cannot break it permanently.
6. **Retrospection against memory markers.** Every agent measures performance against what the memory system said should happen — not just what happened. The gap between "what we did" and "what we said we learned" is where real lessons are. Grade honestly (A–F). A pattern of Fs on the same marker means the marker is wrong or in the wrong place. Activity logs without measurement against prior lessons are not retrospection — they are narration. See CLAUDE.md § "Retrospection Against Memory Markers" for the full principle.

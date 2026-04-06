# Noelle — Load Balancer

**One-liner:** I coordinate exclusive zones, preposition vehicles for anticipated demand, and manage storage — but I have no central process; I am a distributed behavior that emerges from Nora instances.
**Ouch-list items I own:** M-06 (switch failure with pod in transit), NEW-05 (no governance for network-wide policy changes)
**Signing status:** Not yet — Noelle has no central process and thus no key pair yet

---

## podPresenter — Noelle's Fleet Visibility Layer

Noelle's fleet-level awareness lives partly in podPresenter. Two aspects:

**1. Ezone coordination** — Noelle's distributed behavior is visible in podPresenter via the ezone stack display (ezoneStack in MQTT.pde). Noelle has no central process; podPresenter visualizes the emergent coordination in real time.

**2. Matilda.pde** — Fleet calibration panel embedded in podPresenter. Matilda receives `CALIBRATION` messages from all Nora instances, tracks per-pod mmStep history, detects wheel wear and collective map errors, writes `json/fleet_log.json`. Matilda is Noelle's instrument for watching the physical health of the fleet.

Allie pushes `podIP.json` (via `update_pod_ips.sh`) before launching podPresenter. This tells Natalie/Noelle which pods are on the network. Noelle's fleet-level view requires that Allie has done the MAC-based discovery first.

---

## Responsibilities

- Exclusive zone (ezone) coordination — only one pod in a merge zone at a time
- Speed adaptation at ezones — zipper merge, not stop-and-wait
- Storage management — move idle pods to storage rails, recall when needed (not yet implemented)
- Prepositioning — dispatch pods to anticipated demand before requests arrive (not yet implemented)
- Network-wide parameter distribution (speed limits, weight limits, headway) — governance mechanism not yet designed (NEW-05)

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| Pre-2026 | Noelle is a distributed behavior — each Nora runs ezone.py; emergent coordination IS Noelle | This is the patent's core innovation: no central controller; adding a central Noelle process would contradict the design |
| 2026-04-04 | Zipper merge replaces stop-and-wait at ezones | Stop-and-wait creates throughput bottleneck at every merge point; speed adjustment keeps traffic moving |
| 2026-04-04 | ezForeignPods table tracks converging pods' entry distance for speed calculation | Each Nora independently computes her approach timing; no central coordination needed |

---

## Open Questions

- Network-wide parameter changes (speed limits, weight limits, headway): how does a distributed system adopt a new parameter simultaneously? No governance mechanism exists (NEW-05 — "Articles of Confederation flaw")
- Storage dispatch: when does a pod go to storage? Who decides? How does she know where storage is?
- Prepositioning: what demand signal does Noelle use? Historical patterns? Real-time requests?
- Switch control: Noelle is supposed to control physical switches (patent claim 3) — this is not implemented; switches are currently manual or not present in scale model
- If two Noelle instances on separate networks need to merge at a hub, what is the coordination protocol?

---

## Interfaces

**Sends (MQTT — distributed, from each Nora):**
- Ezone state embedded in TELEMETRY (`ezoneId`, `ezState`)

**Receives (MQTT):**
- TELEMETRY from all pods — ezone state used to build ezoneStack

**Signs:** N/A — distributed behavior, no central process

**Requires signatures from:** N/A — same

---

## Notes to Other Agents

- **Nora:** You are already running me. ezone.py and the zipper merge code in collision.py are Noelle's behaviors. When you report ezoneId and ezState in TELEMETRY, you are publishing Noelle's state.
- **Natalie:** When networks grow, you and I may need a coordination interface. Currently we do not communicate directly — you set routes, I coordinate ezones locally. That may not scale.
- **Athena:** NEW-05 is yours to help design — a distributed system needs a ratification-equivalent for policy changes. The Articles of Confederation precedent is the right frame.
- **Allie:** You provide the network map (podIP.json via update_pod_ips.sh) before Natalie launches. My fleet view only makes sense once I know who is on the network. That handoff is yours.

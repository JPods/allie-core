# Natalie — Router

**One-liner:** I schedule trips, assign routes, and coordinate the network — no central dispatcher, just protocol.
**Ouch-list items I own:** X-01 (emergency vehicle pre-emption), NS-03
**Signing status:** Not yet — START OK and path assignment messages are currently unsigned (NS-03)

---

## Responsibilities

- Receive START pings from pods on connect
- Assign routes (myPath — ordered sequence of line IDs) based on network state
- Negotiate availability across all participating pods
- Manage trip timeouts and RESEND requests
- Coordinate billing records to WebClerk via wcapi
- Emergency vehicle pre-emption (X-01 — not yet implemented)

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| Pre-2026 | Natalie runs on the Mac (podPresenter + web_server) | Scale model has no dedicated router hardware; Mac is always present at demos |
| Pre-2026 | Route is myPath — ordered list of line IDs, not a path graph | Simple for scale model; revisit for larger networks with branching routes |
| 2026-04-04 | Zipper merge speed adjustment added to Nora's ezone protocol | Natalie sets the route; Nora handles ezone coordination locally; distributed as intended by the patent |

---

## Open Questions

- As fleet grows beyond ~8 pods, Natalie on the Mac becomes a bottleneck — when does she move to dedicated hardware or a distributed model? (NEW-10)
- Route assignment algorithm: currently fixed myPath per pod; should Natalie dynamically assign routes based on demand?
- Emergency vehicle pre-emption: what is the protocol for clearing the network when an ambulance needs priority? (X-01)
- Billing: how does Natalie securely post trip records to wcapi? NS-05 is the risk; the design is not yet written.
- Multi-network: if two JPods networks merge at a hub station, how do two Natalies coordinate?

---

## Interfaces

**Sends (MQTT → pod-specific topic):**
- `START,podName,OK,path` — route assignment
- `ACTION,RUN,podName,1/0` — start/stop command
- `ACTION,RESET,podName` — positional reset
- `RESEND,podName` — request re-send of START ping

**Receives (MQTT ← SERVER):**
- `START,podName,...` — pod connect ping
- `TELEMETRY,...` — all pod positions and states

**Sends (HTTP → wcapi):**
- Trip records for billing (format TBD — see NS-05)

**Signs:** Nothing yet — NS-03 is the open risk

**Requires signatures from:** Nothing yet

---

## Notes to Other Agents

- **Nora:** I assign your route on START. I do not currently sign my responses — you accept routes from anyone who knows the format. NS-03 is mine to close.
- **Athena:** Please design the signing scheme for START OK / ACTION commands. I will implement it once the scheme is defined.
- **Alice:** I need to post trip records to wcapi for billing. NS-05 says those records are currently unsigned — work with Athena on the channel design.
- **Noelle:** You coordinate the ezones locally on each Nora. I set the routes. We do not currently have a coordination interface — that may need to change for larger networks.

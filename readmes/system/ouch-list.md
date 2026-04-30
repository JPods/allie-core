# Ouch List (OSL) — JPods Risk Register
**Last Updated:** 2026-04-20
**Purpose:** Every risk we can see, no matter how long-tail. Flags, not blockers. Better here than surprising us later.

Bill's framing: *"OSL — Oh Shit List. Things we must address."*

**Format:**
- **Owner** = which design agent's primary domain
- **Severity** = Existential · High · Medium · Low (our best guess now — can be revised)
- **Status** = Must Fix · Unaddressed · Watching · Deferred · Resolved

**Must Fix** = already in code or design; reaches someone if not corrected. Everything else is a risk we can see but cannot yet address.

Add to this list freely. Removing an item requires either a resolution or a conscious decision that the risk does not apply to our design.

---

## Must Fix Now — Athena's Domain

These are mistakes already in the code or design. They are not future risks. They are present debts.

| # | What is wrong | Owner | Severity | Status | Fix by |
|---|---------------|-------|----------|--------|--------|
| OSL-01 | `meeting.sh` records all voices with no consent prompt — violates two-party consent law in CA and other states | Claude | High | Resolved — consent_gate() added 2026-04-20 | Before first meeting recorded |
| OSL-02 | JPods privacy doctrine six promises have no code enforcement — policy only, not architecture | Claude / Athena | High | Must Fix | Before any booking or routing code is written |
| OSL-03 | A-06 (trip logs expose movement patterns) listed on ouch-list but has no mitigation | Athena / Claude | High | Must Fix | Before any ride booking system is built |
| OSL-04 | No booking token design exists — "your identity is not required" has no implementation path | Claude / Bill | High | Must Fix | Before first deployment planning session |
| OSL-05 | `meeting.sh` transcripts had no auto-purge — accumulated indefinitely | Claude | Medium | Resolved — purge_old_recordings() added 2026-04-20 | Before next meeting recorded |
| OSL-06 | Athena's privacy calibration corpus is Bill only — not representative of vulnerable passengers | Athena | Medium | Must Fix | Before first public deployment |

---

## Civil / Structural — Cilia's Domain

| # | Risk | Why it could bite us | Severity | Status |
|---|------|----------------------|----------|--------|
| C-01 | Gradual guideway settlement in soft soils or engineered fill | Stanchion differential settlement misaligns guideway geometry over years; vehicles lose contact or jam switches | High | Unaddressed |
| C-02 | Thermal expansion of steel guideway in extreme temperature swings | Texas summer to Minnesota winter: a 200-ft span can move 1-2 inches; joints and switches must accommodate | Medium | Unaddressed |
| C-03 | Seismic risk for elevated guideways | Elevated structures in earthquake zones need lateral bracing that is not in current stanchion design | High | Unaddressed |
| C-04 | Buried utility conflicts during pile driving | Gas lines, fiber trunk, high-voltage conduit, stormwater vaults — permit maps are often wrong; we hit something | High | Unaddressed |
| C-05 | Underground infrastructure below footprint | Subway tunnels, vaulted storm drains, old mine shafts, cisterns — especially in older cities | Medium | Unaddressed |
| C-06 | Wind-induced resonant vibration on long spans | Bridges taught us about vortex shedding; a long, light guideway span with low damping is vulnerable | Medium | Unaddressed |
| C-07 | Permitting delays vs. utility relocation schedules | Moving an existing utility takes 18-36 months in regulated corridors; this will delay deployment | High | Watching |
| C-08 | Right-of-way acquisition in dense urban areas | Air rights, easements, and ROW above existing roads may not be as clean as the surface looks | High | Unaddressed |

---

## Mechanical — Matilda's Domain

| # | Risk | Why it could bite us | Severity | Status |
|---|------|----------------------|----------|--------|
| M-01 | Guideway icing → loss of drive grip | Drive wheel or contact rail on ice; pod stalls or slides; passengers stranded on elevated section in winter | High | Unaddressed |
| M-02 | Pod door seal degradation over years | Weather ingress, energy loss, noise; accelerated in high-cycle routes (airport); warranty baseline unclear | Medium | Unaddressed |
| M-03 | Drive mechanism wear at high-cycle load | Airport or theme park: 20,000 trips/day; motor, clutch, and brake intervals not yet characterized | High | Unaddressed |
| M-04 | Weight limit enforcement failure | Overloaded pod exceeds motor spec or braking distance; no scale, no gate, user self-reports | High | Unaddressed |
| M-05 | Pod stuck mid-span — no egress catwalk | Elevated sections have no pedestrian walkway; stranded passengers have no self-rescue path | High | Unaddressed |
| M-06 | Switch failure with pod in transit | A switch actuates to wrong position while a pod is passing through it | Existential | Unaddressed |
| M-07 | Brake fade on steep descent grades | Regenerative braking assumption; if power system is saturated, where does the energy go? | High | Unaddressed |
| M-08 | Foreign object intrusion on guideway | Debris, bird nest, vandal-placed object on the rail; no detection sensor in current design | Medium | Unaddressed |

---

## Energy — Sparki's Domain

| # | Risk | Why it could bite us | Severity | Status |
|---|------|----------------------|----------|--------|
| E-01 | Solar panel degradation rate vs. coverage assumptions | Panels lose 0.5-1% efficiency/year; a 20-year system may produce 15-20% less than day-one design | Medium | Unaddressed |
| E-02 | Power grid interruption → battery buffer life | How many trips can complete on stored energy alone? Spec not yet written | High | Unaddressed |
| E-03 | Lightning strike on elevated guideway | Discharge path through pod structure, through passengers; grounding design not specified | Existential | Unaddressed |
| E-04 | Solar panel vandalism | Ground-level panels are easily damaged; elevated panels require specialized repair equipment | Medium | Unaddressed |
| E-05 | Snow and ice accumulation on panels in northern climates | Energy deficit in peak cold is worst case; heating demand highest when production lowest | High | Unaddressed |
| E-06 | Heat buildup in battery packs on hot days | Lithium chemistry in Texas summer; thermal runaway risk; ventilation not specified | High | Unaddressed |
| E-07 | Peak demand spike: simultaneous pod launches from a busy station | Current storage/distribution model may not handle 20 pods launching in 60 seconds | Medium | Unaddressed |
| E-08 | Energy accounting for billing | If solar is locally generated and consumed, how do we meter fairly across multiple landowners? | Medium | Unaddressed |

---

## Security — Athena's Domain

| # | Risk | Why it could bite us | Severity | Status |
|---|------|----------------------|----------|--------|
| A-01 | MQTT bus is broadcast; compromised device can inject false telemetry | A rogue node broadcasts fake position or ezone state; Natalie makes routing decisions on bad data | Existential | Unaddressed |
| A-02 | MQTT denial-of-service: bus flooded | High message rate from one device paralyzes all routing | High | Unaddressed |
| A-03 | Unauthorized pod dispatch | Someone spoofs a valid trip request; pod dispatches to wrong location | High | Unaddressed |
| A-04 | Physical access to guideway switch hardware | Switches are elevated but accessible by maintenance platforms; no access control specified | High | Unaddressed |
| A-05 | Cyber-physical attack: command a switch to wrong position during transit | Worst-case consequence of A-01 or A-04; a pod derails at a misaligned switch | Existential | Unaddressed |
| A-06 | Passenger data privacy: trip logs expose location and movement patterns | Billing requires trip records; those records reveal where people live, work, worship, meet | High | Unaddressed |
| A-07 | Insider threat: maintenance tech with network access | A disgruntled or compromised tech can access the MQTT bus directly | Medium | Unaddressed |
| A-08 | Supply chain compromise in embedded firmware | Third-party motor controllers or sensors with unknown firmware | Medium | Unaddressed |
| A-09 | Software update deployment: patching pods mid-service | How do we push a critical security patch without stranding riders or creating a window of partial patch state? | High | Unaddressed |

---

## Pedestrian / Walking Access — Willi's Domain

| # | Risk | Why it could bite us | Severity | Status |
|---|------|----------------------|----------|--------|
| W-01 | Station placement creating "last 100 meters" dead zones | In car-dependent areas, a station without pedestrian-quality access is an island; nobody uses it | High | Unaddressed |
| W-02 | Platform gap between pod and station floor | A gap that is fine for able-bodied users is a trip hazard for elderly and a barrier for wheelchair users | High | Unaddressed |
| W-03 | Pod arrival speed at platform — pedestrian standing at wrong moment | A pod arriving at 15 mph with a 2-second warning is dangerous if someone is at the edge | High | Unaddressed |
| W-04 | Emergency stop on elevated section — no pedestrian rescue path | If the pod stops elevated, rescuers have no walking access; fire/EMS cannot reach without equipment | Existential | Unaddressed |
| W-05 | Station design assuming pedestrian flows that do not match reality | We may model high throughput but site geometry forces pedestrians to queue in dangerous positions | Medium | Unaddressed |
| W-06 | Night access and lighting: station as crime attractor | An isolated, poorly lit station at 2am is a security problem for pedestrians | Medium | Unaddressed |
| W-07 | Weather exposure at stations in extreme climates | Open platforms in Phoenix summer or Minneapolis winter discourage use; stations need shelter spec | Medium | Unaddressed |

---

## Special Users — Kinder's Domain

| # | Risk | Why it could bite us | Severity | Status |
|---|------|----------------------|----------|--------|
| K-01 | Unaccompanied minor protocol: who is accountable? | A child dispatches alone; pod fails mid-trip; no adult is reachable; emergency response unclear | High | Unaddressed |
| K-02 | Wheelchair securing in pod during emergency stop | An unsecured wheelchair in a pod that stops hard is a projectile; no tie-down spec written | High | Unaddressed |
| K-03 | Children reaching through pod windows or door gaps on elevated sections | Pod exterior gaps must be sized to prevent arm, head, or object insertion; no dimensional spec | High | Unaddressed |
| K-04 | Pod interior dimensions vs. mobility device turn radius | Power wheelchairs and scooters may not fit or turn inside current pod footprint | Medium | Unaddressed |
| K-05 | Sensory overload for autism spectrum users: audio/visual alerts in enclosed pod | An alarm that is appropriate for neurotypical users may trigger a crisis in a confined pod | Medium | Unaddressed |
| K-06 | Emergency communication for non-verbal users | A passenger who cannot speak or type needs an alternative emergency signal | High | Unaddressed |
| K-07 | Heat buildup in pod for users who cannot self-evacuate | A stranded pod in summer sun becomes a heat emergency in minutes for a child or wheelchair user | Existential | Unaddressed |
| K-08 | Stroller and infant carrier compatibility | Current pod entry width and floor height assumptions; a parent with a stroller must fold it to board? | Medium | Unaddressed |

---

## Cross-Domain Risks (No Single Owner)

| # | Risk | Domains | Why it could bite us | Severity | Status |
|---|------|---------|----------------------|----------|--------|
| X-01 | Emergency vehicle interaction: Natalie does not yield to ambulance | Athena, Willi | Pod occupying the only lane slows emergency response; no pre-emption protocol | High | Unaddressed |
| X-02 | Common carrier legal status: liability framework does not exist in most states | All | Regulatory gap means every deployment is a test case; one incident shapes law for all | Existential | Watching |
| X-03 | Insurance products for pod-as-transit do not exist yet | All | Standard transit insurance does not cover autonomous pod fleets; no market product available | High | Watching |
| X-04 | Bird and bat nesting in guideway support structures | Cilia, Matilda | Debris on rail, nest material near electrical connections, structural penetration from repeated fouling | Low | Unaddressed |
| X-05 | Acoustic nuisance to adjacent properties | Cilia, Matilda | High-frequency drive noise and rail hum in residential areas; may block permits | Medium | Unaddressed |
| X-06 | Graffiti and pod interior vandalism between trips | Athena, Kinder | Pods are unattended between trips; interior can be damaged or defaced; inspection cadence undefined | Medium | Unaddressed |
| X-07 | Regulatory lag: FRA, FTA, FHWA jurisdiction overlap | All | Federal agencies may claim jurisdiction over JPods as a "railroad" or "transit system"; years of delay | Existential | Watching |
| X-08 | First deployment captures the narrative for all deployments | All | A visible failure anywhere sets back every subsequent JPods project; "first mover" risk is high | Existential | Watching |
| X-09 | Interoperability with future pod generations | Matilda, Sparki | If early stations are built to one pod spec, retrofitting for a larger or different pod is expensive | Medium | Unaddressed |
| X-10 | Maintenance workforce training and certification: no existing curriculum | All | JPods maintenance is not like any existing transit mode; we have to build the training from scratch | Medium | Unaddressed |

---

## Sovereignty Layer Risks — From Allie's Review (2026-04-04)

These risks were identified by Allie during her first cross-domain sovereignty review. They live in the gaps between engineering domains and the constitutional/data-sovereignty framework. No single design agent would naturally own them.

| # | Risk | Domains | Why it could bite us | Severity | Status |
|---|------|---------|----------------------|----------|--------|
| NEW-01 | No JPods boarding integration with CarryOn/MyCarryOn — early deployment will build a centralized passenger registry by default | Athena, CarryOn | If JPods deploys before MyCarryOn has a boarding integration, a proprietary registry gets built to make billing work; it becomes the billing system; it is never replaced; the sovereignty architecture of the data layer gets decided by accident | High | Unaddressed |
| NEW-02 | Early commercial sites (airports, universities) are federal installations — deploying there may concede the postRoads constitutional argument | postRoads, commercial | A deployment at a federally funded airport or university does not just create a regulatory negotiation — it potentially concedes the constitutional argument that protects every subsequent state-level deployment; the first site choice is a constitutional precedent decision, not just a narrative one | High | Unaddressed |
| NEW-03 | Natalie's trip billing posts to WebClerk via wcapi — creates a second attack surface outside the MQTT security perimeter with no designated owner | Athena, Alice, Natalie | Athena owns MQTT security; Alice owns WebClerk data quality; the bridge between them has no owner; if wcapi is compromised, an attacker gains trip log access without touching the control network | Medium | Unaddressed |
| NEW-04 | No passenger feedback loop analogous to DynamicCatalogs' retailer corrections — operational data decay is invisible until it causes an incident | DynamicCatalogs pattern, operations | The system does not know what it does not know about real-world performance; a door that did not seal, a pod that arrived late, a station inaccessible in rain — without a structured feedback loop, degradation accumulates silently | Medium | Unaddressed |
| NEW-05 | Noelle's distributed architecture has no governance mechanism for network-wide policy changes (speed limits, weight limits, headway) | Athena, constitutional design | A centralized system pushes a parameter update; a distributed system requires every node to adopt it and consensus on when the old parameter expires; the Articles of Confederation had the same structural flaw — distributed sovereignty with no mechanism for collective action; JPods needs a ratification-equivalent | High | Unaddressed |
| NEW-06 | Net-metering law in most states requires a utility interconnection agreement that grants the utility inspection rights over JPods' energy system | Sparki, postRoads | If JPods signs a net-metering agreement to sell surplus or draw backup power, it grants a regulated utility authority over its energy system — structural capture through the power company, contradicting the 5X5 Standard's independence claim; if JPods refuses grid connection entirely, energy storage spec changes significantly | Medium | Unaddressed |
| NEW-07 | No one is looking at the aggregate exposure at the moment of first public operation — all "unaddressed" items become live simultaneously at that transition | All | Every item currently marked Unaddressed becomes a live risk at the moment of first public boarding; there is no staged certification path, no provisional operating authority, no public-facing incident response plan; this transition window has no designated owner | High | Unaddressed |
| NEW-08 | Demo Pi password is intentionally weak (`1111pass`, shared across all pods) | Athena | Accepted tradeoff — demo robots are on isolated WiFi, hacking risk is low, operational simplicity wins for demos; **must be changed before any passenger-carrying deployment**; same risk as A-01 (unauthenticated MQTT) at production scale | Low (demo) / High (production) | Deferred — acceptable for demos, blocker for passengers |
| NEW-09 | Telemetry MQTT traffic is plaintext and unencrypted | Athena | Any device on the same WiFi network can read all pod telemetry and inject commands; frequency hopping and payload encryption are planned for full-scale systems but not implemented in demo hardware | Low (demo isolated WiFi) / High (production) | Deferred — planned: Ed25519-signed payloads + frequency hopping for SkyRide/FullScale |
| NEW-10 | Pod count growth (kids building cities) overwhelms Natalie's single-node routing | Natalie, Noelle | Natalie currently runs on the Mac; as fleet exceeds ~8 pods, routing becomes a bottleneck; Noelle (load balancer) is not yet implemented; distributed Natalie instances have no consensus mechanism — same structural flaw as Articles of Confederation | Medium (demos) / High (city-scale) | Unaddressed — Noelle design needed before city-scale deployment |

### I2C Bus Risks — Identified 2026-04-07

| # | Risk | Why it could bite us | Severity | Status |
|---|------|----------------------|----------|--------|
| I2C-01 | Three I2C libraries share bus 1 with no locking: `smbus` (motor), `busio` (TOF), `HuskyLensLibrary` (camera) | Interleaved transactions corrupt device state mid-transfer; one garbled command can lock SDA low and freeze the entire bus; requires physical power cycle to recover | High | Partially addressed — signal handler added to main.py; threading.Lock pending |
| I2C-02 | Hard kill of launcher.py (SIGKILL or SIGTERM without handler) leaves Romeo BLE firmware frozen mid-I2C-transaction | I2C bus lock survives Pi reboot because TOF sensor stays powered from 3.3V rail; only full power cycle recovers | High | Partially addressed — SIGTERM/SIGINT handler added to main.py 2026-04-07; SIGKILL still dangerous |
| I2C-03 | No bus recovery mechanism: once SDA is held low, software cannot release it | Linux i2c_bcm2835 driver has no bus recovery command; recovery requires either GPIO bit-bang (bypasses hardware I2C) or physical power cycle | Medium | Unaddressed — consider adding GPIO-based 9-pulse recovery on boot |

### Status Updates from Pod Admission Protocol (2026-04-04)

A-01, A-03, A-07, A-08 are partially addressed by the Pod Admission Protocol implemented in `athena/admit.sh` + `jpod_OS/session.py`:
- Each pod receives an Ed25519-signed session token containing its IP, Athena's UUID, broker IP, and expiry time
- Nora verifies the signature on boot using Athena's public key; mismatched IP or expired session blocks MQTT connection
- Session expiry causes Nora to restore her sovereign baseline (`hardware/native.json`) and go quiet until re-admitted
- `ACTION,NATIVERESET` command triggers sovereign reset from the network

Remaining gap: MQTT messages during a valid session are still unsigned plaintext (see NEW-09).

### Severity Corrections from Allie's Review

| Item | Current | Allie's Call | Reason |
|------|---------|-------------|--------|
| E-08 | Medium | **High** | The economic model of JPods depends on energy sovereignty; an unresolved energy ownership question undercuts the funding case, the ROW negotiation, and the constitutional argument simultaneously — cannot wait |
| A-06 | High | High (reclassify) | Correct severity, wrong framing — this is a sovereignty architecture risk, not a security risk; Athena cannot design meaningful protection until the question of who owns the trip record is decided |

---

## Opacity Risks — Risks Created by Insufficient Transparency When Cryptography Is in Use

Design principle: **payload is always human-readable; signatures authenticate but do not obscure.** These risks arise when that principle is violated or when cryptographic machinery fails without a visible explanation.

| # | Risk | Why it could bite us | Severity | Status |
|---|------|----------------------|----------|--------|
| O-01 | Session rejection gives no field-visible reason | A pod that stops mid-demo because its session expired shows a stopped pod — not "session expired at 14:32"; field techs have no diagnostic without Athena's tooling | Medium | Unaddressed |
| O-02 | Key rotation invalidates all active sessions simultaneously | If Athena's private key must be rotated (compromise, loss), every pod session becomes invalid at once; all pods go sovereign simultaneously; no graceful re-admission path exists | High | Unaddressed |
| O-03 | Future payload encryption would block third-party monitoring | If we encrypt telemetry payloads (vs. just signing them), standard tools (mosquitto_sub, Node-RED, podPresenter) can no longer read pod state without a key; diagnostic capacity centralizes to Athena's tooling only — contradicts the transparency principle | Medium | Unaddressed — policy decision required before any payload encryption |
| O-04 | Clock skew causes valid sessions to fail expiry check | A Pi with a slightly wrong clock (common after power loss) may reject a valid session as expired; no grace window, no retry, no diagnostic | Low | Unaddressed |
| O-05 | No audit log of admitted vs. rejected pods | Athena issues sessions but no persistent record exists of who was admitted when and under what scrub result; if an incident occurs, no admission record is available | Medium | Unaddressed |
| O-06 | Signature verification failure error path is not surfaced to the operator | session.py raises RuntimeError with a reason, but that reason must reach a human (NeoPixel code is not enough); in a demo, the operator sees a dead pod, not a rejection reason | Medium | Unaddressed |

---

## Non-Signature Risks — Risks from Messages That Lack Authentication

Design principle: **every agent can sign what it sends and require signatures on what it receives, without asking permission from a central authority.** These risks exist because that infrastructure is not yet uniformly deployed.

| # | Risk | Domains | Why it could bite us | Severity | Status |
|---|------|---------|----------------------|----------|--------|
| NS-01 | MQTT ACTION commands are unsigned — any device on the network can stop, start, or redirect pods | Athena, Nora | No signature required; knowing the message format is enough to command any pod | High | Unaddressed |
| NS-02 | TELEMETRY is unsigned — Natalie routes on unauthenticated position data | Athena, Natalie | A rogue device broadcasting fake TELEMETRY with a real pod name causes Natalie to make collision-avoidance decisions on false position data | Existential | Unaddressed |
| NS-03 | Natalie's routing responses (START OK, path assignments) are unsigned — Nora accepts routes from any sender | Athena, Natalie, Nora | Any device knowing the START OK format can redirect a pod to any path on the network | High | Unaddressed |
| NS-04 | Calibration messages (CALIBRATION, MATILDA topics) are unsigned | Athena, Matilda | A rogue CALIBRATION ping could corrupt Matilda's fleet-wide mmStep model; pods begin navigating on false physical constants | Medium | Unaddressed |
| NS-05 | WebClerk billing receives unsigned trip records from Natalie via wcapi | Athena, Alice, Natalie | If wcapi channel is compromised, fraudulent trip records can be injected into billing without touching the control network | High | Unaddressed |
| NS-06 | No per-agent identity on the MQTT bus — any agent can impersonate any other | Athena, all | Nora, Natalie, Noelle, Matilda share one bus with no per-agent key; a compromised node can impersonate the router, the load balancer, or any pod | Existential | Unaddressed |
| NS-07 | Allie ↔ Nora live channel (future) will be unsigned unless designed otherwise | Athena, Allie, Nora | When Allie begins issuing real-time commands to Nora, that channel must carry signed messages from the start — retrofitting signing after the channel exists is historically where it gets skipped | High | Unaddressed — must be designed in before the channel is built |

---

## How to Use This List

- **Add freely.** A risk on the list costs nothing. A risk off the list that materializes costs everything.
- **Do not remove** unless it is resolved (documented fix) or formally decided to be out of scope.
- **Promote to active work** when a risk crosses from "long-tail" to "immediate" — create an Action in WebClerk project 25 and link back to this entry.
- **Severity is a starting guess.** Revise it as we learn more. Do not anchor to the first estimate.
- **Ownership is primary domain.** Any agent can flag a cross-domain dimension. That is not overstepping — that is the protocol.

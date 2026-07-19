# SPEC-07: Communications

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** ASTM F24, FCC Part 15/Part 90 (as applicable)

---

## 1. Intent

Communications is the nervous system of the JPods network. It connects vehicles to each other, to stations, to switches, and to the network controller (Noelle). When communications are working, the network operates collaboratively -- vehicles coordinate, Natalie optimizes routes, and Noelle balances load. When communications fail, every vehicle must degrade gracefully to Naked mode: operating safely on local memory alone, at reduced performance. No safety-critical function may depend on network availability.

## 2. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-07-001 | Vehicle-to-vehicle (V2V) communication for collision avoidance | Vehicles on the same guideway segment must know each other's position and speed to maintain safe following distance | BJ | 2026-07-18 | RED |
| R-07-002 | Vehicle-to-switch communication for route confirmation | Vehicle must confirm switch position before entering diverge/merge point | BJ | 2026-07-18 | ORANGE |
| R-07-003 | Vehicle-to-station communication for docking coordination | Sally needs vehicle identity, gap sensor data, and door commands for safe boarding | BJ | 2026-07-18 | ORANGE |
| R-07-004 | Station-to-load-balancer (Noelle) communication | Noelle needs real-time station occupancy, queue depth, and demand signals to balance network load | BJ | 2026-07-18 | ORANGE |
| R-07-005 | Control room to all nodes: bidirectional command and telemetry | Operators must be able to monitor all vehicles and stations; issue emergency commands | BJ | 2026-07-18 | ORANGE |
| R-07-006 | Communication media shall include radio, wire, lights, shapes, and markers as appropriate to function | Multiple media for redundancy and degraded-mode operation; lights/shapes/markers provide non-electronic fallback | BJ | 2026-07-18 | YELLOW |
| R-07-007 | In Naked mode (comms failure), vehicle shall operate on local memory of loads by time-of-day | Vehicle continues to serve demand using historical patterns; no network coordination | BJ | 2026-07-18 | ORANGE |
| R-07-008 | In Naked mode, performance degrades to "sloggy" correction (reduced speed, conservative headway) | Safe but degraded; passengers experience longer waits and slower trips | BJ | 2026-07-18 | ORANGE |
| R-07-009 | All safety-critical functions shall work without network communication | Loss of comms must never create an unsafe condition; braking, obstacle detection, gap verification are local | BJ | 2026-07-18 | |
| R-07-010 | All communications shall be encrypted | Prevent eavesdropping, command injection, and spoofing | BJ | 2026-07-18 | YELLOW |
| R-07-011 | Intrusion detection system shall monitor for unauthorized access attempts | Detect and alert on anomalous traffic patterns, unauthorized nodes, replay attacks | BJ | 2026-07-18 | ORANGE |
| R-07-012 | Communication protocol shall support deterministic latency for safety-critical messages | Collision avoidance and emergency stop commands require bounded worst-case delivery time. Latency budget not yet defined. | BJ | 2026-07-18 | ORANGE |
| R-07-013 | Redundant communication paths: no single point of failure shall isolate a vehicle or station | At least two independent paths (e.g., radio + wire) for safety-critical channels | BJ | 2026-07-18 | ORANGE |
| R-07-014 | Communication range shall cover all operational areas including curves, tunnels, and station interiors | No dead zones within the guideway network. Range requirements not yet quantified. | BJ | 2026-07-18 | YELLOW |
| R-07-015 | Radio frequency allocation shall comply with FCC regulations | Legal operation; avoid interference with other systems | BJ | 2026-07-18 | YELLOW |
| R-07-016 | Encryption key management: secure key distribution, rotation, and revocation | Prevent compromised keys from enabling persistent access. Key management architecture not yet designed. | BJ | 2026-07-18 | YELLOW |
| R-07-017 | Cybersecurity threat model shall be documented and maintained | Systematic identification of attack surfaces, threat actors, and countermeasures. Not yet performed. | BJ | 2026-07-18 | ORANGE |
| R-07-018 | Communication system shall support over-the-air (OTA) firmware updates to vehicles | Patching security vulnerabilities and updating operational parameters without physical access | BJ | 2026-07-18 | YELLOW |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-07-001 | V2V message delivery latency | TBD ms (safety-critical bound) | Network analyzer, end-to-end timing | Continuous |
| M-07-002 | V2V message delivery reliability | >= 99.999% for safety-critical messages | Message loss counter with acknowledgment | Continuous |
| M-07-003 | Comms-to-Naked-mode failover time | < 2 s from comms loss detection to Naked mode activation | Simulated comms failure test | Quarterly |
| M-07-004 | Naked mode safe operation duration | Indefinite (vehicle operates until manually recalled or comms restored) | Endurance test without comms | Type test |
| M-07-005 | Encryption overhead | < 5% increase in message latency vs. unencrypted baseline | Benchmark test | Type test |
| M-07-006 | Intrusion detection alert time | < 10 s from anomalous event to operator alert | Penetration test | Annual |
| M-07-007 | Coverage completeness | No dead zones on operational guideway | RF survey (radio) / continuity test (wire) | At commissioning + annual |
| M-07-008 | Redundant path failover | < 1 s switchover to backup path on primary failure | Simulated path failure | Quarterly |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Vehicle controller (Nora) | SPEC-09 (Software) | Nora generates and consumes V2V, V2S, V2Switch messages | Safety-critical messages from Nora have highest priority |
| Station processor (Sally) | SPEC-05 (Station) | Sally exchanges docking, gap, and gate signals with vehicle | R-07-003 |
| Network controller (Noelle) | SPEC-09 (Software) | Noelle receives station telemetry; sends dispatch and routing commands | R-07-004 |
| Router (Natalie) | SPEC-09 (Software) | Natalie sends route plans to vehicles via comms layer | Trip plans depend on comms; Naked mode uses cached routes |
| Power system | SPEC-06 (Power) | Communication equipment power budget | Comms hardware power draw within vehicle and station power budgets |
| Guideway | SPEC-02 (Guideway) | Wired communication conduit along guideway structure | If wire medium is used |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-07-001 | V2V collision avoidance comms not specified | Critical | This is a RED flag. No vehicle operation until V2V protocol is defined, tested, and proven reliable. Candidate protocols: DSRC (IEEE 802.11p), C-V2X, or proprietary radio. | RED - must resolve before any passenger operation | BJ | 2026-07-18 |
| K-07-002 | Communication protocol not selected | High | Evaluate MQTT (current scale model), DSRC, C-V2X, proprietary; select based on latency, reliability, range, and FCC compliance | ORANGE - needs trade study | BJ | 2026-07-18 |
| K-07-003 | Latency requirements for safety-critical commands undefined | High | Derive from braking distance at max speed and min headway; establish worst-case delivery bound | ORANGE - needs analysis | BJ | 2026-07-18 |
| K-07-004 | Redundancy architecture undefined | High | Design dual-path (radio + wire or radio + radio on separate frequencies); define failover protocol | ORANGE - needs design | BJ | 2026-07-18 |
| K-07-005 | Naked mode detailed behavior not designed | High | Define exactly what each vehicle does without comms: speed limits, headway rules, station dwell, rebalancing | ORANGE - needs protocol | BJ | 2026-07-18 |
| K-07-006 | Cybersecurity threat model not performed | High | Engage security specialist; document attack surfaces, threat actors, and countermeasures per NIST framework | ORANGE - needs specialist | BJ | 2026-07-18 |
| K-07-007 | Encrypted key management architecture undefined | Medium | Define key hierarchy, distribution mechanism, rotation schedule, and revocation procedure | YELLOW - needs design | BJ | 2026-07-18 |
| K-07-008 | Radio frequency allocation requirements unknown | Medium | Consult FCC Part 15 (unlicensed) and Part 90 (licensed) for applicable bands; determine if license is needed | YELLOW - needs regulatory review | BJ | 2026-07-18 |
| K-07-009 | Range/coverage requirements not quantified | Medium | Survey planned deployments; determine max guideway segment length, curve attenuation, station interior penetration | YELLOW - needs site survey | BJ | 2026-07-18 |

## 6. Bill of Materials

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Vehicle radio transceiver | Primary V2V and V2Infrastructure link | TBD protocol | 1 per vehicle | TBD | TBD |
| Vehicle backup transceiver | Redundant comms path | TBD protocol | 1 per vehicle | TBD | TBD |
| Station radio transceiver | Station-to-vehicle and station-to-Noelle | TBD protocol | 1 per station | TBD | TBD |
| Switch transceiver | Switch-to-vehicle confirmation | TBD protocol | 1 per switch | TBD | TBD |
| Control room server | Central monitoring, command, Noelle host | Per design | 1 per network | TBD | TBD |
| Encryption module | Hardware security module for key storage | Per design | 1 per node | TBD | TBD |
| Guideway conduit/cable | Wired communication backbone (if wire medium selected) | Per guideway length | Per network | TBD | TBD |
| Intrusion detection system | Network monitoring appliance | Per design | 1 per network | TBD | TBD |
| Antenna | External antenna for vehicle and station radio | Per design | 1 per transceiver | TBD | TBD |

## 7. Maintenance

- **Radio transceiver:** Annual RF performance test; firmware update as released; replace on failure.
- **Wired communication (if used):** Visual inspection of conduit at guideway inspection intervals; continuity test annually.
- **Encryption keys:** Rotate per security policy (TBD schedule); revoke immediately on suspected compromise.
- **Intrusion detection:** Review alert logs daily; update detection signatures as released; annual penetration test.
- **Antenna:** Quarterly visual inspection for physical damage, corrosion, obstruction; replace on degradation.
- **Backup path failover:** Quarterly simulated failure test to verify automatic switchover.
- **Naked mode:** Quarterly simulated comms-loss test on at least one vehicle to verify safe degraded operation.

## 8. Serialization

- Each radio transceiver serialized; linked to vehicle or station ID.
- Encryption modules serialized; key assignment records linked.
- Firmware version tracked per device serial number.
- Communication equipment maintenance and test records linked to device serial.
- QR code on each transceiver links to configuration, firmware version, and test history.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| RF performance test results | 5 years rolling | Engineering | QM-02 |
| Comms failover test log | 5 years rolling | Operations | QM-02 |
| Naked mode test log | 5 years rolling | Operations | QM-02 |
| Intrusion detection alert log | 5 years rolling | Security | QM-02 |
| Penetration test reports | Life of network | Security | QM-04 |
| Encryption key rotation records | 5 years rolling | Security | QM-04 |
| Firmware update log (per device) | Life of device | Engineering | QM-03 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release. Communications spec established from GI Edit outline and engineering review. Nearly all requirements flagged YELLOW or ORANGE; V2V collision avoidance flagged RED. | Bill James |

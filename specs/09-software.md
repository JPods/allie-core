# SPEC-09: Software

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** ASTM F24, IEC 61508 (Functional Safety), Gordy's QM-04.1 (Risk Classification)

---

## 1. Intent

Software controls every moving part of the JPods network. It governs vehicle speed, braking, and navigation (Nora); route planning and dispatch (Natalie); network validation and load balancing (Noelle); station slot management and Mind-the-Gap (Sally); and ticket sales and customer accountability (Alice). The software must be fail-safe: any software fault defaults to a safe state. Safety integrity levels must be assigned before deployment, and the agent architecture must maintain clear authority boundaries so that no single software failure cascades across the network.

## 2. Requirements

### 2.1 Control System

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-09-001 | Software shall control vehicle speed, acceleration, and braking within envelope limits defined in SPEC-01 | Fundamental vehicle control function | BJ | 2026-07-18 | |
| R-09-002 | Control system shall be fail-safe: any unrecoverable software fault defaults to safe stop | No software failure shall create an unsafe vehicle state | BJ | 2026-07-18 | |
| R-09-003 | Redundant control paths: primary controller failure detected and backup engages within TBD ms | Single controller failure must not strand or endanger vehicle. Redundancy architecture not yet designed. | BJ | 2026-07-18 | ORANGE |
| R-09-004 | Fail-safe vs. fail-operational classification for each software function | Some functions (braking) must fail-safe (stop). Others (routing) may fail-operational (degrade). Classification not yet performed. | BJ | 2026-07-18 | RED |

### 2.2 Safety and Emergency

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-09-005 | Automatic shut-off on detection of critical fault (obstacle, derailment, fire) | Immediate safe state without operator intervention | BJ | 2026-07-18 | |
| R-09-006 | Emergency braking: software shall command maximum deceleration on emergency input | Emergency stop from passenger button, operator command, or autonomous detection | BJ | 2026-07-18 | |
| R-09-007 | Manual override: operator can command any vehicle to stop, slow, or return to station | Human authority over software in all conditions | BJ | 2026-07-18 | |
| R-09-008 | Restraint verification before vehicle operation: software confirms restraints engaged before dispatch | No vehicle moves with unsecured passengers | BJ | 2026-07-18 | |
| R-09-009 | Door interlock: doors locked during travel; door release requires Mind-the-Gap verification from Sally | No door opens while moving or with non-compliant gap | BJ | 2026-07-18 | |

### 2.3 Mechanical Interface

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-09-010 | Software shall interface with sensors (laser range finders, gap sensors, load cells, IMU, encoders, temperature, anemometer, smoke detector) | Sensor data is the foundation of all control and safety decisions | BJ | 2026-07-18 | |
| R-09-011 | Software shall interface with actuators (motors, brakes, doors, gap correction, gates) | Software commands become physical actions through actuators | BJ | 2026-07-18 | |
| R-09-012 | All safety interlocks (door, gate, restraint, gap) shall be hardware-backed, not software-only | Software can fail; hardware interlocks provide independent safety layer | BJ | 2026-07-18 | |

### 2.4 Operational Modes

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-09-013 | Normal mode: full autonomous operation with network coordination | Standard revenue service | BJ | 2026-07-18 | |
| R-09-014 | Maintenance mode: reduced speed, enhanced logging, manual movement authority | Safe conditions for inspection and repair; prevents accidental dispatch | BJ | 2026-07-18 | |
| R-09-015 | Emergency mode: all vehicles proceed to nearest station and park; no new dispatches | Network-wide safe state triggered by operator or by system (weather, earthquake, security threat) | BJ | 2026-07-18 | |
| R-09-016 | Naked mode: vehicle operates without network on local memory (per SPEC-07) | Comms failure degrades gracefully; safety maintained locally | BJ | 2026-07-18 | |

### 2.5 Data Logging

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-09-017 | All performance metrics, safety checks, and malfunctions shall be logged with UTC timestamp | Regulatory evidence; incident investigation; Andi trend analysis; Axiom 14 (all stored datetimes UTC) | BJ | 2026-07-18 | |
| R-09-018 | Allie capture boundary events shall fire at every tool boundary (see CLAUDE.md boundary map) | Persistent learning; cross-domain pattern detection; feeds FAULT/DNW/TF/TFTS arc | BJ | 2026-07-18 | |
| R-09-019 | Logs shall be retained for minimum 5 years rolling; safety-critical event logs retained for life of system | Regulatory and legal retention requirements | BJ | 2026-07-18 | |

### 2.6 Agent Architecture

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-09-020 | Nora: vehicle navigation, encoder reading, telemetry reporting, obstacle response | Single agent responsible for vehicle-level decisions; clear authority | BJ | 2026-07-18 | |
| R-09-021 | Natalie: route planning, trip sequencing, dispatch timing | Network-level routing separated from vehicle-level control | BJ | 2026-07-18 | |
| R-09-022 | Noelle: network validation, load balancing, build verification | Network integrity and demand balancing; independent from routing | BJ | 2026-07-18 | |
| R-09-023 | Sally: station slot registry, parking queue, Mind-the-Gap management, gate control | Station-level operations managed locally; one Sally per station | BJ | 2026-07-18 | |
| R-09-024 | Alice: ticket sales, Small-Stings (customer-assessed fines), action lists, customer retrospections | Commerce and customer accountability; feeds revenue and learning loops | BJ | 2026-07-18 | |
| R-09-025 | Agent communication protocol shall be defined with message types, priorities, and failure modes | Agents must coordinate; protocol not yet specified. | BJ | 2026-07-18 | ORANGE |
| R-09-026 | No agent shall have authority to override another agent's safety decisions | Safety decisions are local and final; Nora's emergency stop cannot be overridden by Natalie's routing | BJ | 2026-07-18 | |

### 2.7 Risk Classification

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-09-027 | All software functions shall be classified per Gordy's QM-04.1: High (death/injury), Medium (property damage), Low (significant lost time), Negligible (minor lost time) | Risk classification drives testing rigor, review requirements, and deployment authority | BJ | 2026-07-18 | ORANGE |
| R-09-028 | Safety Integrity Level (SIL) shall be assigned per IEC 61508 for all safety-related software functions | Regulatory requirement for safety-critical control systems. SIL classification not yet performed. | BJ | 2026-07-18 | RED |

### 2.8 Software Engineering

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-09-029 | Software architecture document shall define modules, interfaces, data flows, and failure modes | Foundation for all development, review, and certification. Not yet written. | BJ | 2026-07-18 | ORANGE |
| R-09-030 | Real-time operating system requirements shall be defined for vehicle control software | Deterministic response times required for safety-critical functions. RTOS selection not yet made. | BJ | 2026-07-18 | ORANGE |
| R-09-031 | Cybersecurity hardening: input validation, access control, secure boot, code signing | Prevent unauthorized modification or injection of control commands | BJ | 2026-07-18 | ORANGE |
| R-09-032 | OTA update mechanism for vehicle and station software | Patch vulnerabilities and update parameters without physical access. Mechanism not yet understood. | BJ | 2026-07-18 | YELLOW |
| R-09-033 | Testing and simulation framework: software-in-the-loop and hardware-in-the-loop testing | Verify software behavior before deployment to physical systems. Framework not yet built. | BJ | 2026-07-18 | ORANGE |
| R-09-034 | Software risk assessment per QM-04.1 for each software module | Form exists in quality system; not yet applied to JPods software modules. | BJ | 2026-07-18 | ORANGE |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-09-001 | Emergency braking response (software command to brake actuation) | < 100 ms | End-to-end timing test | Type test + quarterly |
| M-09-002 | Fail-safe activation on controller fault | < 500 ms from fault detection to safe stop command | Fault injection test | Type test + quarterly |
| M-09-003 | Door interlock compliance | 0 door openings without gap verification | Log audit | Continuous |
| M-09-004 | Restraint interlock compliance | 0 dispatches without restraint confirmation | Log audit | Continuous |
| M-09-005 | Log completeness | 100% of safety events logged with UTC timestamp | Log audit | Monthly |
| M-09-006 | Mode transition correctness | All mode transitions follow defined state machine; no invalid transitions | State machine verification test | Type test |
| M-09-007 | Agent boundary compliance | 0 cross-agent safety overrides | Log audit | Monthly |
| M-09-008 | Software risk assessment coverage | 100% of modules classified per QM-04.1 | Audit | Before deployment |
| M-09-009 | SIL compliance evidence | All safety functions meet assigned SIL per IEC 61508 | Third-party assessment | Before deployment |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Vehicle hardware (Nora) | SPEC-01 (Chassis) | Sensors and actuators on vehicle; Nora reads sensors, commands actuators | R-09-010, R-09-011 |
| Station hardware (Sally) | SPEC-05 (Station) | Gap sensors, gap actuators, gates, slot registry | Sally manages station-side; vehicle-side gap data from Nora |
| Communications | SPEC-07 (Communications) | All inter-agent messages traverse comms layer | Naked mode = agents operate on local data only |
| Guideway switches | SPEC-02 (Guideway) | Switch position confirmation; route selection | Natalie commands, switch confirms, Nora proceeds |
| Power system | SPEC-06 (Power) | Battery state-of-charge; charging control | Nora monitors; Natalie factors into routing |
| Allie (persistent intelligence) | Allie system | Boundary events, FAULT files, drift analysis | Allie reads all agent logs; cross-domain synthesis |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-09-001 | SIL classification not performed for any software function | Critical | Engage functional safety specialist; classify all safety functions per IEC 61508 before deployment | RED - blocking | BJ | 2026-07-18 |
| K-09-002 | Fail-safe vs. fail-operational not decided per function | Critical | Classify each function: braking = fail-safe, routing = fail-operational, HVAC = fail-degraded; document in architecture | RED - blocking | BJ | 2026-07-18 |
| K-09-003 | Software architecture document does not exist | High | Write architecture document defining modules, interfaces, data flows, state machines, failure modes | ORANGE - needs document | BJ | 2026-07-18 |
| K-09-004 | Real-time OS not selected for vehicle control | High | Evaluate FreeRTOS, QNX, VxWorks, Linux-RT for determinism guarantees; select based on SIL requirements | ORANGE - needs trade study | BJ | 2026-07-18 |
| K-09-005 | Agent communication protocol undefined | High | Define message types, priorities, delivery guarantees, and failure behavior for inter-agent communication | ORANGE - needs design | BJ | 2026-07-18 |
| K-09-006 | Cybersecurity hardening not specified | High | Define secure boot chain, code signing, input validation rules, access control; coordinate with SPEC-07 cybersecurity | ORANGE - needs design | BJ | 2026-07-18 |
| K-09-007 | Testing/simulation framework not built | High | Build SIL and HIL test environments; define test coverage requirements per risk classification | ORANGE - needs build | BJ | 2026-07-18 |
| K-09-008 | Software risk assessment (QM-04.1) not applied to any module | High | Apply QM-04.1 risk classification form to each software module; document risk level and required controls | ORANGE - needs assessment | BJ | 2026-07-18 |
| K-09-009 | OTA update mechanism not understood | Medium | Define update packaging, signing, rollback, and verification process; ensure update cannot brick vehicle | YELLOW - needs research | BJ | 2026-07-18 |

## 6. Bill of Materials

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Vehicle control computer (primary) | Nora host; real-time OS; sensor/actuator interface | Per design | 1 per vehicle | TBD | TBD |
| Vehicle control computer (backup) | Redundant controller for fail-safe takeover | Per design | 1 per vehicle | TBD | TBD |
| Station control computer | Sally host; gap/gate/slot management | Per design | 1 per station | TBD | TBD |
| Network server | Natalie + Noelle host; dispatch, routing, load balancing | Per design | 1 per network (+ standby) | TBD | TBD |
| Alice server | Ticket sales, Small-Stings, action lists | Per design | 1 per network | TBD | TBD |
| Data storage | Log retention (5 years rolling + life-of-system for safety) | Per capacity plan | Per network | TBD | TBD |
| Secure boot module | Hardware root of trust for code signing verification | Per design | 1 per control computer | TBD | TBD |

## 7. Maintenance

- **Software updates:** Apply OTA updates per defined schedule; verify update integrity via code signature before installation; confirm rollback capability before applying.
- **Log review:** Daily automated scan for safety events; monthly manual audit of log completeness and anomalies.
- **Fail-safe test:** Quarterly fault injection test on at least one vehicle to verify safe-stop behavior.
- **Interlock verification:** Monthly functional test of door, gate, restraint, and gap interlocks.
- **Backup controller failover:** Quarterly simulated primary failure to verify backup engagement within specified time.
- **Cybersecurity:** Annual penetration test; patch critical vulnerabilities within 72 hours of discovery; update intrusion detection signatures as released.
- **Agent boundary audit:** Monthly review of inter-agent message logs for any safety override violations.

## 8. Serialization

- Each control computer (vehicle primary, vehicle backup, station, network server) serialized at installation.
- Software version tracked per device serial; update history maintained.
- Secure boot module serialized; key assignment records linked.
- All software modules version-controlled in source repository with traceable build artifacts.
- QR code on each control computer links to hardware serial, software version, update history, and test records.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| SIL classification report | Life of system | Engineering | QM-04.1 |
| Software risk assessment (per module) | Life of system | Engineering | QM-04.1 |
| Software architecture document | Life of system | Engineering | QM-01 |
| Fail-safe fault injection test log | 5 years rolling | Engineering | QM-02 |
| Interlock functional test log | 5 years rolling | Maintenance | QM-02 |
| Backup controller failover test log | 5 years rolling | Engineering | QM-02 |
| Safety event log | Life of system | Operations (Nora) | QM-02 |
| Boarding event log (gap/door/restraint) | 5 years rolling | Operations (Sally) | QM-02 |
| Cybersecurity penetration test reports | Life of system | Security | QM-04 |
| Software update log (per device) | Life of device | Engineering | QM-03 |
| Agent boundary audit log | 5 years rolling | Operations | QM-02 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release. Software spec established from GI Edit, agent architecture, and QM-04.1 framework. SIL classification and fail-safe/fail-operational decision flagged RED. | Bill James |

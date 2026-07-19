# SPEC-05: Station

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** ASTM F2291, NFPA 70, OSHA 1910.25, ASTM F1637-21, ADA, ANSI/ASCE/T&DI 21-21

---

## 1. Intent

The station is where passengers and cargo board and exit JPods vehicles. It manages the transition between the pedestrian/cargo world and the guideway world safely, accessibly, and efficiently. Stations range from temporary pre-packaged skids to permanent elevated structures. Every station must provide safe boarding, ADA-compliant access, weather protection, and precise vehicle-to-platform alignment via the Mind-the-Gap system managed by Sally.

## 2. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-05-001 | At-grade passenger stations shall provide level boarding from ground surface | Simplest deployment; no stairs or elevator required; ADA-accessible by default | BJ | 2026-07-18 | |
| R-05-002 | At-grade cargo stations shall restrict vehicle access to areas where vehicle cannot contact heads | Cargo operations involve forklifts and pallets; overhead clearance hazard must be eliminated by design | BJ | 2026-07-18 | |
| R-05-003 | Elevated passenger stations shall provide stairs, elevator, guardrails, gates, and weather protection | Elevated stations require vertical circulation and fall protection | BJ | 2026-07-18 | |
| R-05-004 | Elevated cargo station design shall accommodate freight and waste streaming operations | Middle Mile logistics; CargoPod loading/unloading at elevation. Design not yet understood. | BJ | 2026-07-18 | YELLOW |
| R-05-005 | Stations shall be deployable in a range from temporary (pre-packaged skids) to permanent (fixed construction) | Enables rapid deployment for demos and events, with upgrade path to permanent infrastructure | BJ | 2026-07-18 | ORANGE |
| R-05-006 | Emergency stop buttons shall be provided at platform level, clearly marked and accessible | Passenger and operator emergency intervention | BJ | 2026-07-18 | |
| R-05-007 | Physical barriers or gates shall separate platform from guideway except at boarding positions | Prevent falls and unauthorized guideway access | BJ | 2026-07-18 | |
| R-05-008 | Gate interlock shall prevent gate opening unless vehicle is docked and gap verified | No passenger access to guideway without a docked, verified vehicle. Interlock mechanism not yet designed. | BJ | 2026-07-18 | ORANGE |
| R-05-009 | All walking surfaces shall be anti-slip per ASTM F1637-21 | Slip-and-fall prevention in all weather conditions | BJ | 2026-07-18 | |
| R-05-010 | Station lighting shall provide minimum 50 lux at platform level, 100 lux at boarding zone | Adequate visibility for safe boarding and security camera operation | BJ | 2026-07-18 | |
| R-05-011 | Guardrails required where drop >= 48 in (1219 mm) | OSHA 1910.29 fall protection | BJ | 2026-07-18 | |
| R-05-012 | Guardrails: 42 in (1067 mm) height +/-3 in (76 mm) | OSHA 1910.29 guardrail height | BJ | 2026-07-18 | |
| R-05-013 | Guardrails: intermediate rail at approximately halfway between top rail and walking surface | OSHA 1910.29 intermediate rail | BJ | 2026-07-18 | |
| R-05-014 | Guardrail openings shall not exceed 19 in (483 mm); balusters spaced <= 19 in (483 mm) apart | Prevent through-fall of persons | BJ | 2026-07-18 | |
| R-05-015 | Guardrails: toe board required at floor level | Prevent objects from sliding under guardrail | BJ | 2026-07-18 | |
| R-05-016 | Guardrail top rail shall withstand 200 lb (890 N) concentrated load and 50 lb/ft (730 N/m) linear load | OSHA 1910.29 structural strength | BJ | 2026-07-18 | |
| R-05-017 | Stairs shall comply with OSHA 1910.25 and ASTM F1637-21, with handrails on both sides | Stair safety for all users including those with limited mobility | BJ | 2026-07-18 | |
| R-05-018 | Residential/commercial elevator: minimum 6 ft 8 in (2032 mm) wide x 4 ft 3 in (1295 mm) deep, 2500 lb (1134 kg) capacity | Standard passenger + wheelchair elevator sizing | BJ | 2026-07-18 | |
| R-05-019 | Service elevator: minimum 5 ft 4 in (1626 mm) wide x 8 ft 5 in (2565 mm) deep, 4500 lb (2041 kg) capacity | Cargo, stretcher, and maintenance equipment transport | BJ | 2026-07-18 | |
| R-05-020 | Platform height shall align with vehicle floor within Mind-the-Gap tolerances: 17 mm horizontal, +/-8 mm vertical target | Seamless boarding; ADA compliance; prevents foot entrapment (per ASCE 21.2-2008) | BJ | 2026-07-18 | |
| R-05-021 | Platform constructed of durable materials suitable for outdoor exposure and designed for modular expansion | Long service life; stations must grow with demand without full reconstruction | BJ | 2026-07-18 | |
| R-05-022 | Entry and exit paths shall be physically separated | Prevent boarding/alighting passenger conflicts; unidirectional pedestrian flow | BJ | 2026-07-18 | |
| R-05-023 | Queuing space shall accommodate minimum 8 waiting passengers per boarding position | Prevent platform overcrowding during peak demand | BJ | 2026-07-18 | |
| R-05-024 | Full ADA compliance: ramps where required, handrails, tactile paving at platform edges | Federal accessibility law; all stations must be usable by persons with disabilities | BJ | 2026-07-18 | |
| R-05-025 | ADA tactile paving specification and layout | Required at platform edges and decision points. Specific product and pattern not yet selected. | BJ | 2026-07-18 | YELLOW |
| R-05-026 | Mind-the-Gap: active laser distance sensors at platform edge measure gap in real time | Sally must know the gap before releasing doors | BJ | 2026-07-18 | |
| R-05-027 | Mind-the-Gap: active correction via extending lip or adjustable platform edge | Gap corrected mechanically, not just measured. Actuator mechanism not yet decided (extending lip vs. adjustable edge). | BJ | 2026-07-18 | ORANGE |
| R-05-028 | Mind-the-Gap: gap confirmed <= 17 mm H / +/-8 mm V before door release (hard max 25 mm H / +/-12 mm V per ASCE 21.2-2008) | No passenger exposed to non-compliant gap | BJ | 2026-07-18 | |
| R-05-029 | Mind-the-Gap inputs: vehicle load (load cells), wheel wear (encoders), suspension state (IMU), thermal expansion (temp sensors), wind load (anemometer), precise stop position (encoders) | All factors that affect gap dimension must be sensed and compensated | BJ | 2026-07-18 | |
| R-05-030 | Mind-the-Gap: gap sensors shall be installed at every door opening position, both sides of every door | Full-width gap profile required; single-point measurement misses tilt, twist, and local deformation | BJ | 2026-07-18 | |
| R-05-031A | Mind-the-Gap: sensors shall measure gap with and without vehicle load. Unloaded baseline recorded on arrival, loaded measurement recorded after passengers board, both logged per event | Unloaded-vs-loaded comparison detects wheel wear (drift over weeks), suspension faults (single vehicle), and structural settlement (single station). Door does not open until loaded gap is verified. | BJ | 2026-07-18 | |
| R-05-031B | Mind-the-Gap: gap measurement, correction, and verification shall be logged per boarding event for trend analysis | Trend detection; predictive maintenance; regulatory evidence; Andi drift analysis | BJ | 2026-07-18 | |
| R-05-031 | Spare pod storage: station shall accommodate spare vehicles accessible for rapid deployment | Operational resilience; replace failed vehicles without waiting for depot | BJ | 2026-07-18 | YELLOW |
| R-05-032 | Surveillance cameras at all boarding areas and access points | Security and incident investigation | BJ | 2026-07-18 | |
| R-05-033 | Unauthorized access control: fencing, gates, or barriers preventing guideway entry | Prevent trespass onto elevated guideway from station structure | BJ | 2026-07-18 | |
| R-05-034 | Emergency evacuation procedure for elevated stations | Passengers must be able to exit safely when vehicles are unavailable. Procedure not yet designed. | BJ | 2026-07-18 | ORANGE |
| R-05-035 | Weather protection: roof or canopy over boarding area | Passengers protected from rain, sun, and snow during boarding. Design approach not yet understood. | BJ | 2026-07-18 | YELLOW |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-05-001 | Platform-to-vehicle gap horizontal | <= 17 mm (hard max 25 mm) | On-board + platform gap sensor log per boarding event | Every boarding |
| M-05-002 | Platform-to-vehicle gap vertical | +/-8 mm (hard max +/-12 mm) | On-board + platform gap sensor log per boarding event | Every boarding |
| M-05-003 | Walking surface slip resistance | Meets ASTM F1637-21 | Pendulum or tribometer test | Annual |
| M-05-004 | Platform lighting level | >= 50 lux platform, >= 100 lux boarding zone | Lux meter survey | Annual |
| M-05-005 | Guardrail load capacity | Withstands 200 lb concentrated, 50 lb/ft linear | Structural load test | Type test |
| M-05-006 | Elevator capacity | Rated load per R-05-018 / R-05-019 | Load test per elevator code | Annual |
| M-05-007 | Emergency stop response | Vehicle halts within 2 s of button press | Functional test | Monthly |
| M-05-008 | Gate interlock | Door does not release unless gap verified and gate aligned | Functional test | Monthly |
| M-05-009 | Surveillance coverage | No blind spots at boarding areas | Camera coverage review | Quarterly |
| M-05-010 | Mind-the-Gap drift trend | No single-direction drift > 2 mm over 30 days | Andi analysis of boarding event logs | Continuous |
| M-05-011 | Unloaded-to-loaded gap delta | Suspension compression within design envelope per vehicle | Compare unloaded baseline vs loaded measurement per boarding event | Every boarding |
| M-05-012 | Unloaded baseline stability | No unloaded gap change > 1 mm per week at any door position | Andi trend analysis of unloaded measurements | Weekly |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Vehicle docking | SPEC-01 (Chassis) | Door-to-platform gap; Mind-the-Gap sensors on both sides | R-01-018/019 and R-05-020/028 must agree |
| Guideway | SPEC-02 (Guideway) | Guideway enters station; track alignment at platform | Station CP geometry defined in station model |
| Communications | SPEC-07 (Communications) | Station-to-vehicle, station-to-Noelle, control room links | Gate interlock signals, boarding events |
| Software | SPEC-09 (Software) | Sally station processor; Andi drift analysis | Sally manages slots, gap, gates; Andi monitors trends |
| Power | SPEC-06 (Power) | Station electrical supply; vehicle charging at platform | Charging interface specification in SPEC-06 |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-05-001 | Mind-the-Gap actuator mechanism undecided (extending lip vs. adjustable edge) | High | Prototype both approaches; test reliability under thermal and wind load cycling | ORANGE - needs prototyping | BJ | 2026-07-18 |
| K-05-002 | Gate interlock with vehicle doors not designed | High | Define interlock protocol: gate opens only after gap verified AND vehicle door unlocked; fail-safe = gate stays closed | ORANGE - needs design | BJ | 2026-07-18 |
| K-05-003 | Emergency evacuation from elevated stations undefined | High | Design evacuation stairs or rescue vehicle protocol; coordinate with local fire authority | ORANGE - needs protocol | BJ | 2026-07-18 |
| K-05-004 | Elevated cargo station design not understood | Medium | Study freight elevator integration and CargoPod handling at elevation; site-specific | YELLOW - needs concept | BJ | 2026-07-18 |
| K-05-005 | Temporary skid station: concept exists but no engineering | Medium | Define skid footprint, connection to guideway, anchoring, and utility requirements | ORANGE - needs engineering | BJ | 2026-07-18 |
| K-05-006 | Weather protection design not understood | Medium | Survey canopy/enclosure approaches used in light rail and airport people movers | YELLOW - needs research | BJ | 2026-07-18 |
| K-05-007 | Pod storage mechanism at station not understood | Medium | Define siding track or parallel slot for spare vehicles; interface with Sally slot registry | YELLOW - needs concept | BJ | 2026-07-18 |
| K-05-008 | ADA tactile paving product and layout not selected | Low | Consult ADA Accessibility Guidelines for transit platforms; select truncated dome product | YELLOW - needs specification | BJ | 2026-07-18 |
| K-05-009 | Mind-the-Gap compliance is ASCE 21.2-2008 mandatory (25 mm H / +/-12 mm V hard max) | High | Active correction system must be proven reliable before passenger service; sensor + actuator redundancy required | Open - design in progress | BJ | 2026-07-18 |

## 6. Bill of Materials

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Platform structure | Primary deck and support framing | Per design | 1 per station | TBD | TBD |
| Guardrail assembly | Top rail, intermediate rail, balusters, toe board | 42 in height | Per station perimeter | TBD | TBD |
| Platform gate | Barrier gate at boarding position | Per design | 2 per boarding position (entry + exit) | TBD | TBD |
| Gate interlock actuator | Electromechanical gate lock | Per design | 1 per gate | TBD | TBD |
| Elevator (passenger) | Residential/commercial type | 2032 x 1295 mm, 1134 kg | 1 per elevated station | TBD | TBD |
| Elevator (service) | Service/cargo type | 1626 x 2565 mm, 2041 kg | As required | TBD | TBD |
| Stairway assembly | Per OSHA 1910.25 with dual handrails | Per design | 1 per elevated station | TBD | TBD |
| Gap sensor (platform side) | Laser distance sensor | Per design | 2 per boarding position | TBD | TBD |
| Gap actuator | Extending lip or adjustable edge | Per design (TBD) | 1 per boarding position | TBD | TBD |
| Emergency stop button | Mushroom-head, lockout type | Per NFPA 79 | 2 per platform minimum | TBD | TBD |
| Surveillance camera | Weatherproof, networked | Per design | Per coverage plan | TBD | TBD |
| Lighting fixtures | Platform and boarding zone | >= 50/100 lux | Per lighting plan | TBD | TBD |
| Anti-slip surface treatment | Coating or textured material | ASTM F1637-21 | All walking surfaces | TBD | TBD |
| Tactile paving | Truncated dome tiles | ADA compliant | Platform edges | TBD | TBD |
| Canopy/weather protection | Roof structure over boarding | Per design (TBD) | 1 per station | TBD | TBD |

## 7. Maintenance

- **Gap sensor calibration:** Monthly verification against physical gauge; cross-check with vehicle-side sensors.
- **Gap actuator:** Monthly functional test; lubrication per manufacturer interval; replace after 100,000 cycles or signs of wear.
- **Gate interlock:** Monthly functional test; verify fail-safe (gate stays closed on power loss).
- **Guardrails:** Quarterly visual inspection for corrosion, loose fasteners, impact damage.
- **Elevator:** Per elevator code inspection schedule; annual load test; monthly functional test.
- **Stairs and handrails:** Quarterly visual inspection; anti-slip surface condition check.
- **Lighting:** Monthly check for failed fixtures; annual lux level survey.
- **Surveillance cameras:** Monthly image quality check; quarterly cleaning.
- **Emergency stop buttons:** Monthly functional test; verify vehicle halt within 2 s.
- **Anti-slip surfaces:** Annual tribometer test; recoat or replace when below ASTM F1637-21 threshold.
- **Andi drift reports:** Monthly review of Mind-the-Gap trend data; investigate any single-direction drift > 2 mm.

## 8. Serialization

- Each station receives a unique station ID (s001, s002, ...) at commissioning.
- Each gate and gate interlock serialized; linked to station ID.
- Each gap sensor and gap actuator serialized; calibration history linked.
- Each elevator serialized per elevator code; inspection records linked.
- Emergency stop buttons serialized; test records linked to station ID.
- QR code at station entrance links to maintenance history, inspection status, and real-time Sally slot status.
- Geolocation recorded at commissioning; fixed for permanent stations.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Platform structural inspection | Life of station | Engineering | QM-01 |
| Guardrail load test (type test) | Life of station | Engineering | QM-01 |
| Gap sensor calibration log | 5 years rolling | Maintenance | QM-02 |
| Gap actuator functional test log | 5 years rolling | Maintenance | QM-02 |
| Gate interlock test log | 5 years rolling | Maintenance | QM-02 |
| Boarding event gap log (per event) | 5 years rolling | Operations (Sally) | QM-02 |
| Elevator inspection reports | Life of elevator | Maintenance | QM-02 |
| Emergency stop test log | 5 years rolling | Maintenance | QM-02 |
| Anti-slip surface test results | 5 years rolling | Maintenance | QM-02 |
| Andi drift analysis reports | 5 years rolling | Operations (Andi) | QM-03 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release. Consolidates station requirements from GI Edit and engineering review into single authoritative spec. | Bill James |

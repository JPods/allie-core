# SPEC-01: Chassis

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** ASTM F2291, NFPA 70, ANSI/ASCE/T&DI 21-21, ASHRAE 62.1-22, ASCE 21.2-2008

---

## 1. Intent

The chassis is the primary structural and mechanical assembly of a JPods vehicle. It carries passengers and cargo between stations on elevated guideways, powered by on-board energy storage recharged from the solar-powered guideway. This spec consolidates Spec_Chassis-30003 (sunset 2025-10-20) and the GI Edit into a single authoritative document. All prior chassis specs are superseded.

## 2. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-01-001 | Gross vehicle mass shall not exceed 750 kg | Guideway structural budget and energy efficiency | BJ | 2026-07-18 | |
| R-01-002 | Payload capacity: 500 kg minimum | Accommodate 4 passengers + luggage or 2 standard pallets (CargoPod) | BJ | 2026-07-18 | |
| R-01-003 | Maximum width: 1550 mm | Guideway envelope constraint | BJ | 2026-07-18 | |
| R-01-004 | Maximum length: 3226 mm | Station slot length and guideway curve clearance | BJ | 2026-07-18 | |
| R-01-005 | Door opening: 1.5 m minimum clear width | ADA wheelchair access and cargo loading | BJ | 2026-07-18 | |
| R-01-006 | Operating temperature range: -40C to 60C | All-climate deployment without degradation | BJ | 2026-07-18 | |
| R-01-007 | Passenger compartment temperature: 18C to 27C | Passenger comfort (HVAC system maintains this within R-01-006 ambient range) | BJ | 2026-07-18 | |
| R-01-008 | Withstand 90 mph (145 km/hr) wind without permanent deformation | Parked vehicle survival during storms | BJ | 2026-07-18 | |
| R-01-009 | Network ceases operation at 45 mph (72 km/hr) sustained wind | Passenger safety during high wind; vehicles proceed to nearest station and park | BJ | 2026-07-18 | |
| R-01-010 | Unlimited 0.4g acceleration/deceleration cycles without fatigue cracking | Service life requirement; continuous start/stop at stations | BJ | 2026-07-18 | |
| R-01-011 | On-board energy storage: minimum capacity TBD (see K-01-002) | Conflict between sources: 30003 specifies 8 kWh minimum, GI Edit specifies 2.5 trips (<7 kWh). Resolution required. | BJ | 2026-07-18 | ORANGE |
| R-01-012 | Operating voltage: 48-96V DC | Safety (below lethal threshold in dry conditions) and motor efficiency | BJ | 2026-07-18 | |
| R-01-013 | Bogie power budget: 4.5 kWe per bogie | Propulsion, regenerative braking | BJ | 2026-07-18 | |
| R-01-014 | Non-bogie systems power budget: 2.5 kWe | HVAC, lighting, doors, sensors, communications | BJ | 2026-07-18 | |
| R-01-015 | Two bogies per vehicle | Redundancy and weight distribution | BJ | 2026-07-18 | |
| R-01-016 | Two independent motors per bogie (four total) | Single motor failure does not strand vehicle | BJ | 2026-07-18 | |
| R-01-017 | Independent power supply per bogie | Single power failure does not strand vehicle; either bogie can limp to station | BJ | 2026-07-18 | |
| R-01-018 | Mind-the-gap horizontal: 17 mm target; hard maximum 25 mm (ASCE 21.2-2008) | Passenger safety; prevents foot entrapment at boarding | BJ | 2026-07-18 | |
| R-01-019 | Mind-the-gap vertical: +/-8 mm target; hard maximum +/-12 mm (ASCE 21.2-2008) | ADA compliance; wheelchair and mobility device access | BJ | 2026-07-18 | |
| R-01-020 | Gap actively measured and corrected before door release | No door opens until gap is within tolerance; system logs every boarding event gap measurement | BJ | 2026-07-18 | |
| R-01-021 | CargoPod variant accommodates 2 standard pallets | Freight and waste streaming; Middle Mile logistics | BJ | 2026-07-18 | |
| R-01-022 | 3 forward + 3 rearward laser range finders, independent of cameras | Obstacle detection; independent sensing path from vision system | BJ | 2026-07-18 | |
| R-01-023 | Bumpers front and rear capable of pushing a disabled rescue pod | Rescue operations; disabled vehicle cleared by following vehicle | BJ | 2026-07-18 | |
| R-01-024 | Smoke detector with dual protocol: fire detection vs. smoking detection | Fire triggers emergency stop and evacuation; smoking triggers passenger warning and fine | BJ | 2026-07-18 | |
| R-01-025 | No Smoking signage: interior and exterior | Regulatory compliance | BJ | 2026-07-18 | |
| R-01-026 | Ventilation compliant with ASHRAE 62.1-22 | Indoor air quality for enclosed passenger compartment | BJ | 2026-07-18 | |
| R-01-027 | Audio communication system: microphone + speakers, bidirectional with control room | Passenger emergency communication; operational announcements | BJ | 2026-07-18 | |
| R-01-028 | USB charging ports accessible to passengers | Passenger convenience; reduces battery anxiety on longer trips | BJ | 2026-07-18 | |
| R-01-029 | Bogie-chassis interface: vertical plate on centerline with 15 mm mounting hole | Structural connection between bogie and chassis. Current concept only; full design review required before fabrication. | BJ | 2026-07-18 | ORANGE |
| R-01-030 | Earthquake scurry behavior: vehicle responds to seismic event per defined protocol | Vehicles must have safe behavior during seismic events. Protocol not yet defined. | BJ | 2026-07-18 | ORANGE |
| R-01-031 | Repel kit: security features to deter/respond to threats | Security system for passenger protection. Scope and components not yet understood. | BJ | 2026-07-18 | YELLOW |
| R-01-032 | Children traveling alone: cameras remain active; parents can view via authenticated link | Child safety; parental oversight during solo travel | BJ | 2026-07-18 | |
| R-01-033 | COVID / contagion symptom scanning capability | Optional health screening at boarding. Technology approach and accuracy standards undefined. | BJ | 2026-07-18 | YELLOW |
| R-01-034 | Bluetooth speaker access for passengers | Passenger entertainment/information. Security implications of open Bluetooth not yet assessed. | BJ | 2026-07-18 | YELLOW |
| R-01-035 | Customer billing mechanism for vehicle damage | Passengers who damage vehicles are billed. Detection method, assessment process, and billing integration undefined. | BJ | 2026-07-18 | YELLOW |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-01-001 | Gross mass (empty + payload) | <= 750 kg | Weigh scale at assembly | Each vehicle |
| M-01-002 | Payload capacity | >= 500 kg | Load test at rated payload + 25% safety margin | Each vehicle |
| M-01-003 | Envelope dimensions | W <= 1550 mm, L <= 3226 mm | Physical measurement at assembly | Each vehicle |
| M-01-004 | Door clear width | >= 1.5 m | Physical measurement | Each vehicle |
| M-01-005 | Temperature survival | No degradation after 72 hr at -40C and 60C | Environmental chamber test | Type test |
| M-01-006 | Wind resistance | No permanent deformation at 90 mph equivalent | Wind tunnel or static load equivalent | Type test |
| M-01-007 | Fatigue life | No cracking after 1M cycles at 0.4g | Accelerated fatigue test on bogie-chassis assembly | Type test |
| M-01-008 | Energy storage capacity | >= TBD kWh (see R-01-011) | Discharge test at rated load | Each battery pack |
| M-01-009 | Boarding gap horizontal | <= 17 mm (hard max 25 mm) | On-board gap sensor log per boarding event | Every boarding |
| M-01-010 | Boarding gap vertical | +/-8 mm (hard max +/-12 mm) | On-board gap sensor log per boarding event | Every boarding |
| M-01-011 | Ventilation rate | ASHRAE 62.1-22 minimum CFM per occupant | Airflow measurement at commissioning | Annual |
| M-01-012 | Compartment temperature | 18C - 27C under all ambient conditions within R-01-006 | On-board temperature log | Continuous |
| M-01-013 | Laser range finder coverage | 6 units operational, no blind zones in travel direction | Self-test at trip start | Every trip |
| M-01-014 | Smoke detection response | Fire: < 10 s to alarm; Smoking: < 30 s to alert | Functional test | Monthly |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Guideway | SPEC-02 (Guideway) | Bogie-to-rail mechanical interface; power pickup | Bogie envelope must match guideway profile |
| Station platform | SPEC-03 (Station) | Door-to-platform gap; docking alignment | Gap sensors at R-01-018/019 |
| Interior | SPEC-08 | Chassis-to-interior mounting; HVAC ducting; electrical distribution | Passenger compartment within chassis envelope |
| Control system | SPEC-05 (Control) | Nora vehicle controller; sensor data bus; communication link | Laser range finders, gap sensors, smoke detector feed to Nora |
| Power system | SPEC-06 (Power) | Battery pack mounting; charging interface; voltage bus | 48-96V DC per R-01-012 |
| Network operations | SPEC-07 (Operations) | Wind speed shutdown trigger; earthquake protocol; rescue push | Natalie/Noelle dispatch and safety commands |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-01-001 | Bogie-chassis interface not fully designed (15 mm mounting hole concept only) | High | Requires FEA and physical prototype testing before fabrication | ORANGE - needs design | BJ | 2026-07-18 |
| K-01-002 | Energy storage capacity conflict: 8 kWh (30003) vs. <7 kWh (GI Edit) | Medium | Resolve by analyzing actual trip energy consumption at gross mass with HVAC load; select capacity that guarantees 2.5 trips with 20% reserve | ORANGE - needs analysis | BJ | 2026-07-18 |
| K-01-003 | Earthquake scurry behavior undefined | High | Define protocol: slow-to-stop, proceed-to-station, or park-in-place depending on magnitude; coordinate with structural engineer | ORANGE - needs protocol | BJ | 2026-07-18 |
| K-01-004 | Repel kit scope unknown | Medium | Define threat model; determine physical, electronic, and procedural components | YELLOW - needs definition | BJ | 2026-07-18 |
| K-01-005 | Bluetooth speaker access may create attack surface | Low | Assess whether Bluetooth pairing creates vehicle network vulnerability; consider isolated audio bus | YELLOW - needs security review | BJ | 2026-07-18 |
| K-01-006 | Mind-the-gap hard compliance floor (25 mm / +/-12 mm) is ASCE 21.2-2008 mandatory | High | Active gap correction system must be proven reliable before passenger service; sensor + actuator redundancy required | Open - design in progress | BJ | 2026-07-18 |
| K-01-007 | Single bogie failure must not strand vehicle | High | Independent power and motor per bogie; limp-home mode demonstrated at type test | Open - design validation needed | BJ | 2026-07-18 |

## 6. Bill of Materials

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Chassis frame | Primary structure | Per design | 1 | TBD | TBD |
| Bogie assembly | Drive bogie with 2 motors | Per design | 2 | TBD | TBD |
| Battery pack | Li-ion energy storage | TBD kWh, 48-96V | 2 (one per bogie) | TBD | TBD |
| Laser range finder | Forward/rearward obstacle detection | Per design | 6 | TBD | TBD |
| Smoke detector | Dual protocol (fire/smoking) | Per design | 1 | TBD | TBD |
| Gap sensor | Horizontal + vertical boarding gap | Per design | 2 (one per door side) | TBD | TBD |
| Bumper assembly | Rescue push capable | Front + rear | 2 | TBD | TBD |
| HVAC unit | Heating + cooling + ventilation | ASHRAE 62.1-22 compliant | 1 | TBD | TBD |
| Audio system | Mic + speakers, control room link | Per design | 1 | TBD | TBD |
| USB charging ports | Passenger power | 5V/2.4A minimum | TBD | TBD | TBD |

## 7. Maintenance

- **Bogie inspection:** Motor wear, bearing condition, power pickup — per manufacturer interval or 10,000 trips, whichever comes first.
- **Battery health:** State-of-health check at each charge cycle; replace when capacity drops below 80% of rated.
- **Gap sensor calibration:** Monthly verification against physical gauge.
- **Laser range finders:** Self-test every trip; manual cleaning and calibration quarterly.
- **Smoke detector:** Monthly functional test (fire and smoking protocols independently).
- **HVAC filters:** Replace per ASHRAE 62.1-22 schedule or quarterly, whichever is shorter.
- **Bumpers:** Visual inspection monthly; replace after any rescue push event.
- **Structural inspection:** Annual visual + biennial NDT of bogie-chassis interface and fatigue-critical joints.

## 8. Serialization

- Each chassis receives a unique serial number at frame assembly.
- Each bogie serialized independently; marriage to chassis recorded.
- Each battery pack serialized; state-of-health history linked to serial.
- Gap sensor calibration records linked to chassis serial.
- QR code on chassis exterior and interior links to maintenance and inspection history.
- Geolocation tracked continuously during operation via Nora vehicle controller.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Assembly weight verification | Life of vehicle | Engineering | QM-01 |
| Load test report | Life of vehicle | Engineering | QM-01 |
| Environmental chamber test | Life of vehicle | Engineering | QM-01 |
| Fatigue test report | Life of vehicle | Engineering | QM-01 |
| Boarding gap log (per event) | 5 years rolling | Operations (Nora) | QM-02 |
| Smoke detector test log | 5 years rolling | Maintenance | QM-02 |
| Battery state-of-health history | Life of battery | Engineering | QM-03 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release. Consolidates Spec_Chassis-30003 (sunset 2025-10-20) and GI Edit into single authoritative spec. | Bill James |

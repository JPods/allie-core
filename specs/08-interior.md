# SPEC-08: Interior

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** ASTM F2291, ADA Accessibility Guidelines, ANSI/ASCE/T&DI 21-21

---

## 1. Intent

The interior defines the passenger and cargo compartment of a JPods vehicle. It provides seating, climate control, security, accessibility, and cargo accommodation within the chassis envelope defined by SPEC-01. The first build produces 4 vehicles for the Al Karia Maintenance Facility.

## 2. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-08-001 | Build 4 vehicles for Al Karia Maintenance Facility | Initial deployment commitment | BJ | 2026-07-18 | |
| R-08-002 | Bench seats, upholstered | Passenger comfort; durable, cleanable surface | BJ | 2026-07-18 | |
| R-08-003 | Seating configuration: facing seats that promote communication; option for fold-down direction-of-travel viewing | Social seating preferred; fold-down accommodates motion-sensitive passengers. Configuration not finalized. | BJ | 2026-07-18 | ORANGE |
| R-08-004 | On-board computer: placement, access, and storage for passenger or operational use | Computer interface required. Type (tablet, embedded screen, passenger BYOD dock) not defined. | BJ | 2026-07-18 | YELLOW |
| R-08-005 | Cup holders | Passenger convenience | BJ | 2026-07-18 | |
| R-08-006 | Passenger compartment temperature: 18C to 27C | Comfort range maintained by HVAC system (chassis SPEC-01 R-01-007) | BJ | 2026-07-18 | |
| R-08-007 | Humidity control within comfort range | Passenger comfort; condensation prevention on interior surfaces | BJ | 2026-07-18 | |
| R-08-008 | Sway within passenger comfort limits | Ride quality; no standing passenger loss of balance at rated speed | BJ | 2026-07-18 | |
| R-08-009 | Air quality per ASHRAE 62.1-22 | Health and comfort; references chassis SPEC-01 R-01-026 | BJ | 2026-07-18 | |
| R-08-010 | Contagion risk mitigation: filtration, UV, or equivalent technology | Reduce airborne transmission risk in enclosed shared space. Technology approach and effectiveness standards undefined. | BJ | 2026-07-18 | YELLOW |
| R-08-011 | In-vehicle camera with on/off capability and defined privacy protocol | Security recording balanced against passenger privacy. Protocol for when camera may be off, who controls it, data retention, and child-alone override (camera stays on per SPEC-01 R-01-032) not yet defined. | BJ | 2026-07-18 | ORANGE |
| R-08-012 | Load balance monitoring | Detect uneven loading that affects bogie wear or ride quality; feed data to Nora | BJ | 2026-07-18 | |
| R-08-013 | Luggage accommodation | Passengers travel with bags; secure storage that does not block aisle or door | BJ | 2026-07-18 | |
| R-08-014 | Wheelchair accommodation with securing mechanism | ADA compliance. Securing mechanism design (tie-downs, auto-lock, magnetic) not yet selected. | BJ | 2026-07-18 | ORANGE |
| R-08-015 | Wheelchair boarding gap: 17 mm target (per SPEC-01 R-01-018/019) | Original interior spec cited <5 mm; SPEC-01 now targets 17 mm horizontal with 25 mm hard max per ASCE 21.2-2008. SPEC-01 values govern. | BJ | 2026-07-18 | |
| R-08-016 | Stroller accommodation | Families with children; stroller fits without blocking door or wheelchair space | BJ | 2026-07-18 | |
| R-08-017 | Bicycle accommodation | Last-Mile integration; bike fits securely during transit | BJ | 2026-07-18 | |
| R-08-018 | Shopping cart accommodation | Local commerce trips; cart or large bag capacity | BJ | 2026-07-18 | |
| R-08-019 | Cargo restraint system for non-passenger items | Prevent shifting luggage, bikes, carts during acceleration/braking. Restraint type (straps, rails, nets, friction floor) undefined. | BJ | 2026-07-18 | YELLOW |
| R-08-020 | Interior materials: fire-resistant per ASTM F2291 | Passenger safety; fire does not propagate from interior materials | BJ | 2026-07-18 | |
| R-08-021 | Interior surfaces cleanable and vandal-resistant | Operational durability; reduce maintenance cost | BJ | 2026-07-18 | |
| R-08-022 | Interior lighting: adequate for boarding/alighting, dimmable during travel | Passenger comfort and safety | BJ | 2026-07-18 | |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-08-001 | Compartment temperature | 18C - 27C under all SPEC-01 ambient conditions | On-board temperature sensor log | Continuous |
| M-08-002 | Relative humidity | 30% - 60% RH | On-board humidity sensor | Continuous |
| M-08-003 | Sway acceleration (lateral) | <= 0.15g sustained | Accelerometer at passenger seat level | Type test + sampling |
| M-08-004 | Air quality | ASHRAE 62.1-22 CFM per occupant | Airflow measurement | Annual |
| M-08-005 | Wheelchair securing hold force | Withstands 0.4g longitudinal + 0.2g lateral without release | Pull test on securing mechanism | Each vehicle at assembly |
| M-08-006 | Seat upholstery durability | No wear-through after 100,000 sit cycles | Accelerated wear test | Type test |
| M-08-007 | Fire resistance | No flame spread per ASTM F2291 | Burn test on material samples | Type test per material lot |
| M-08-008 | Load balance detection | Detects >= 50 kg imbalance between bogies | Calibrated load test | Each vehicle at commissioning |
| M-08-009 | Camera system functional | Records, transmits, on/off responds within 2 s | Functional test | Monthly |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Chassis | SPEC-01 | Interior mounts within chassis envelope; HVAC ducting; electrical power | Temperature, ventilation, and gap requirements flow from SPEC-01 |
| Station platform | SPEC-03 | Door-to-platform transition; wheelchair ramp if needed | Boarding gap per SPEC-01 R-01-018/019 governs |
| Control system | SPEC-05 | Camera feed to Nora; load balance data; compartment sensor data | On/off camera state reported to control |
| Operations | SPEC-07 | Privacy protocol; child-alone camera policy; cleaning schedule | Operational procedures reference interior requirements |
| Power | SPEC-06 | USB port power; lighting power; HVAC power from non-bogie 2.5 kWe budget | Per SPEC-01 R-01-014 |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-08-001 | Seating configuration not finalized; facing vs. direction-of-travel affects interior layout, door placement, and cargo space | Medium | Build prototype of both configurations; test with wheelchair, stroller, and bike simultaneously | ORANGE - needs prototype | BJ | 2026-07-18 |
| K-08-002 | Wheelchair securing mechanism not selected | High | Survey existing APM and bus wheelchair restraints; select mechanism that works with 17 mm gap and 0.4g acceleration | ORANGE - needs design | BJ | 2026-07-18 |
| K-08-003 | Camera on/off creates security gap when off; camera always-on creates privacy concern | Medium | Define protocol: default on, passenger can request off except child-alone trips; data retention policy required | ORANGE - needs policy | BJ | 2026-07-18 |
| K-08-004 | Contagion mitigation technology unproven in small enclosed vehicles | Low | Research HEPA + UV-C effectiveness at ASHRAE 62.1-22 airflow rates in <4 m^3 volume | YELLOW - needs research | BJ | 2026-07-18 |
| K-08-005 | Cargo restraint undefined; unsecured items become projectiles at 0.4g | High | Define restraint system before passenger service; test with 20 kg unsecured object at emergency braking | YELLOW - needs design | BJ | 2026-07-18 |
| K-08-006 | Computer interface type undefined; affects power budget, mounting, and passenger interaction | Low | Determine use case first (passenger entertainment, wayfinding, operational display, or passenger device dock) | YELLOW - needs requirements | BJ | 2026-07-18 |

## 6. Bill of Materials

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Bench seat assembly | Upholstered bench, fire-resistant | Per layout | TBD (depends on R-08-003) | TBD | TBD |
| Wheelchair securing mechanism | Restraint system for wheelchair | Per design | 1 per vehicle | TBD | TBD |
| Camera system | Interior camera with on/off control | Per design | 1 per vehicle | TBD | TBD |
| Load balance sensors | Weight sensors per bogie mount point | Per design | 4 per vehicle (2 per bogie) | TBD | TBD |
| Cup holders | Integrated into seat or wall | Per design | TBD | TBD | TBD |
| Interior lighting | LED, dimmable | Per design | TBD | TBD | TBD |
| Cargo restraint system | Straps, rails, or nets (TBD) | Per design | TBD | TBD | TBD |
| Air filtration unit | HEPA or equivalent for contagion mitigation | Per design | 1 per vehicle | TBD | TBD |
| Interior panels | Fire-resistant, cleanable, vandal-resistant | Per design | Per vehicle | TBD | TBD |

## 7. Maintenance

- **Seat upholstery:** Inspect monthly for wear, tears, stains. Clean weekly. Replace when worn through or permanently stained.
- **Wheelchair securing mechanism:** Functional test monthly; replace worn components per manufacturer interval.
- **Camera system:** Functional test monthly; lens cleaning weekly.
- **Load balance sensors:** Calibration check quarterly against known weights.
- **Interior lighting:** Replace failed LEDs on detection; full check monthly.
- **Air filtration:** Filter replacement per manufacturer schedule or quarterly, whichever is shorter. UV-C bulb replacement per rated hours (if installed).
- **Cargo restraints:** Visual inspection monthly; replace damaged straps/nets immediately.
- **Interior panels:** Inspect for damage monthly; repair or replace vandalized sections within 24 hours.

## 8. Serialization

- Interior fit-out is linked to chassis serial number (SPEC-01).
- Camera system serialized independently; firmware version and calibration date recorded.
- Wheelchair securing mechanism serialized; inspection history linked to serial.
- Load balance sensor calibration records linked to chassis serial.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Seat material fire test certificate | Life of vehicle | Engineering | QM-01 |
| Wheelchair restraint pull test report | Life of vehicle | Engineering | QM-01 |
| Camera functional test log | 5 years rolling | Operations | QM-02 |
| Load balance calibration log | 5 years rolling | Maintenance | QM-02 |
| Interior inspection/cleaning log | 2 years rolling | Maintenance | QM-02 |
| Air filtration replacement log | 5 years rolling | Maintenance | QM-02 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release. Consolidates interior requirements from chassis specs and Al Karia build scope. | Bill James |

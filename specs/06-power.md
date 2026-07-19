# SPEC-06: Power

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** ASTM F24, NEC (National Electrical Code), UL standards (battery/PV)

---

## 1. Intent

The power system generates, stores, distributes, and recovers energy for the JPods vehicle and guideway network. Solar collection on the guideway canopy is the primary generation source. Vehicle energy storage provides autonomy between charging opportunities. Regenerative braking recovers kinetic energy. The system must sustain continuous vehicle operation including night and adverse weather conditions without dependence on grid power as the primary source.

## 2. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-06-001 | Vehicle energy storage: minimum 8 kWh at 48-96V | 8 kWh supports multiple trips between charging; voltage range matches bogie motor requirements (SPEC-02) | BJ | 2026-07-18 | |
| R-06-002 | Battery chemistry selection | Chemistry determines weight, cycle life, thermal behavior, cost, and fire risk; no chemistry specified | BJ | 2026-07-18 | ORANGE |
| R-06-003 | Ultracapacitor vs battery vs hybrid storage decision | Ultracapacitors researched (48V/166F, 15.5V/600F, 16V/500F, 16V/1000F at $399, 18V/500F) — excellent for regen capture but low energy density; hybrid may be optimal; no decision made | BJ | 2026-07-18 | ORANGE |
| R-06-004 | Battery fire protection | Safety-critical: lithium battery fire in elevated guideway vehicle is catastrophic; no suppression system specified | BJ | 2026-07-18 | RED |
| R-06-005 | Bogie power budget: 4.5 kWe continuous per bogie | Covers 2 motors at continuous rating plus controller and sensor overhead | BJ | 2026-07-18 | |
| R-06-006 | Other vehicle systems power budget: 2.5 kWe continuous | HVAC, lighting, doors, communications, Nora compute, passenger amenities | BJ | 2026-07-18 | |
| R-06-007 | Total vehicle power: 7 kWe continuous | Sum of bogie (2 x 4.5 = 9 kWe peak, but R-06-005 is per-bogie continuous) and other systems; 7 kWe is the vehicle-level continuous budget | BJ | 2026-07-18 | |
| R-06-008 | Independent power feed per bogie | Single power bus failure must not disable both bogies; safety requirement matching SPEC-02 R-02-001 | BJ | 2026-07-18 | |
| R-06-009 | Regenerative braking energy recovery | Regen from bogies must return energy to vehicle storage; primary braking mode per SPEC-02 R-02-015 | BJ | 2026-07-18 | |
| R-06-010 | Solar collection on guideway canopy | Guideway canopy is the primary generation asset; canopy width drawn at 4m, experience up to 10m; JPod Solar Panel Spec R0 12DEC2024 is the reference document | BJ | 2026-07-18 | |
| R-06-011 | Solar panel integration with truss structure | Panels mount to guideway truss (SPEC-03); structural loads, wiring routing, and maintenance access must be co-designed | BJ | 2026-07-18 | ORANGE |
| R-06-012 | 3rd rail power collection | Option for continuous power delivery from guideway to vehicle; eliminates range limitation; design not started | BJ | 2026-07-18 | YELLOW |
| R-06-013 | Power during night and adverse weather | Solar is primary but unavailable at night and reduced in clouds; storage must bridge gap or alternative supply required; no analysis of required reserve duration | BJ | 2026-07-18 | ORANGE |
| R-06-014 | Battery exchange at stations | Concept: swap depleted battery pack for charged one at station; reduces dwell time vs charging in place; no mechanical design or station integration | BJ | 2026-07-18 | YELLOW |
| R-06-015 | Coolant exchange at stations | Concept: exchange thermal management fluid at station stops; no design or thermal analysis | BJ | 2026-07-18 | YELLOW |
| R-06-016 | Charging protocol | No protocol specified for vehicle charging — contact-based, inductive, or 3rd rail; charge rate, connector standard, communication protocol all undefined | BJ | 2026-07-18 | YELLOW |
| R-06-017 | Grid interconnect requirements | Solar generation may exceed vehicle consumption; export to local grid requires interconnect agreement, inverter specs, metering; requirements undefined | BJ | 2026-07-18 | YELLOW |
| R-06-018 | Power system operating temperature: match vehicle spec | Must operate across the temperature range agreed between bogie and chassis specs (see SPEC-02 R-02-019 RED flag) | BJ | 2026-07-18 | |

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-06-001 | Vehicle energy storage capacity | >= 8 kWh usable | Discharge test at rated load | Per battery pack |
| M-06-002 | Vehicle storage voltage range | 48-96V under load | Load test across SOC range | Per battery pack |
| M-06-003 | Regen energy recovery efficiency | >= 70% of braking energy returned to storage | Coast-down with energy metering (coordinated with SPEC-02 M-02-004) | Per vehicle |
| M-06-004 | Solar canopy output per linear meter | TBD (depends on panel selection and width) | Pyranometer + inverter metering | Per installation |
| M-06-005 | Vehicle continuous power delivery | >= 7 kWe sustained for 1 hour | Full vehicle load test | Per vehicle type |
| M-06-006 | Independent bogie power isolation | Loss of one bus does not affect other bogie | Fault injection test — disconnect one bus under load | Per vehicle type |
| M-06-007 | Night/cloudy autonomy duration | TBD (ORANGE — no reserve duration analysis) | Discharge test from full SOC at continuous load, no solar input | Per vehicle type |
| M-06-008 | Battery thermal runaway containment | No fire propagation beyond cell/module | Thermal abuse test per UL 2580 or equivalent | Per battery type |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Bogie motors and controllers | SPEC-02 | Voltage, current, regen return per bogie | Independent power feed; regen energy flows back to storage |
| Vehicle chassis | SPEC-01 | Battery mounting, wiring routing, thermal management | Battery mass and volume affect chassis design |
| Guideway / truss | SPEC-03 | Solar panel mounting, 3rd rail (if implemented), wiring conduit | Structural loads from panels; electrical routing through truss |
| Station | SPEC-04 | Charging interface, battery exchange mechanism (if implemented), coolant exchange (if implemented) | Station must accommodate whichever charging/exchange method is selected |
| Nora (vehicle agent) | Software | Battery SOC, voltage, current, temperature, fault signals | Nora monitors power state; adjusts speed/HVAC to conserve if needed |
| Noelle (network) | Software | Fleet SOC data, solar generation data, grid export metering | Network-level energy management and dispatch optimization |
| Grid | External | Interconnect point, metering, inverter | If solar export is implemented; local utility requirements apply |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-06-001 | Battery fire in elevated vehicle | Critical | No suppression design exists; RED flag R-06-004; must be resolved before any passenger operation | Open | BJ | 2026-07-18 |
| K-06-002 | Insufficient energy for night/cloudy operation | High | Storage sizing and/or 3rd rail must ensure continuous operation; no analysis performed | Open | BJ | 2026-07-18 |
| K-06-003 | Battery chemistry selection affects weight, cost, safety, and cycle life — no decision made | High | Evaluate LFP (safe, heavy), NMC (energy dense, fire risk), solid state (future); decision required before detailed design | Open | BJ | 2026-07-18 |
| K-06-004 | Solar panel structural load on truss not analyzed | Medium | Co-design with SPEC-03; wind load on elevated panels is significant | Open | BJ | 2026-07-18 |
| K-06-005 | No charging protocol defined — cannot specify station infrastructure | Medium | Blocks SPEC-04 station design for charging bays | Open | BJ | 2026-07-18 |
| K-06-006 | Ultracapacitor energy density may be insufficient as sole storage | Medium | Hybrid (battery + ultracap) likely needed; ultracap handles regen peaks, battery handles sustained load | Open | BJ | 2026-07-18 |
| K-06-007 | Grid interconnect requirements vary by jurisdiction | Low | Local utility agreements required per installation; standard inverter/metering package needed | Open | BJ | 2026-07-18 |
| K-06-008 | Temperature range for batteries must match vehicle operating range (RED on SPEC-02) | High | Battery chemistry selection must consider operating temperature; LFP better in cold, NMC better energy density; must align with resolved temperature range | Open | BJ | 2026-07-18 |

## 6. Bill of Materials

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Battery pack | Vehicle energy storage | >= 8 kWh, 48-96V | 1 per vehicle | TBD (ORANGE — chemistry not selected) | TBD |
| Ultracapacitor module | Regen capture / peak buffer | TBD | TBD | Options: 48V/166F, 16V/1000F ($399), others | TBD |
| Battery management system (BMS) | Cell balancing, SOC, protection | — | 1 per battery pack | TBD | TBD |
| DC-DC converter | Bus voltage regulation for subsystems | — | 1 per vehicle | TBD | TBD |
| Power distribution unit | Fusing, switching, independent bogie feeds | — | 1 per vehicle | TBD | TBD |
| Solar panels | Guideway canopy generation | 4-10m canopy width | Per linear meter of guideway | Per JPod Solar Panel Spec R0 | TBD |
| Solar inverter / charge controller | Panel output to DC bus or grid | — | Per guideway section | TBD | TBD |
| Wiring harness — vehicle | Battery to bogies and subsystems | — | 1 per vehicle | — | — |
| Wiring conduit — guideway | Solar panel output routing through truss | — | Per guideway section | — | — |
| 3rd rail assembly | Continuous power delivery (if implemented) | — | Per guideway section | TBD (YELLOW) | TBD |
| Fire suppression system | Battery fire containment | — | 1 per battery pack | TBD (RED — no design) | TBD |

## 7. Maintenance

- **Battery pack:** Monitor SOC cycling depth and calendar age; replace per manufacturer cycle life or capacity degradation threshold (typically 80% of rated capacity).
- **BMS:** Verify cell balance and protection thresholds per manufacturer interval.
- **Ultracapacitor:** Monitor ESR (equivalent series resistance) drift; replace on degradation.
- **Solar panels:** Inspect for physical damage and soiling; clean per schedule; monitor output degradation.
- **Inverters / charge controllers:** Inspect connections; verify output against expected generation.
- **Wiring:** Inspect for chafe, corrosion, and connector integrity at bogie articulation points.
- **3rd rail (if implemented):** Inspect contact surfaces for wear; verify insulation integrity.
- **Fire suppression:** Inspect per system requirements — TBD pending design (RED).

## 8. Serialization

- Each battery pack receives a unique serial number tied to chemistry, manufacture date, and cycle history.
- BMS units serialized and paired to battery pack.
- Solar panel strings serialized by guideway section.
- Inverters and charge controllers serialized.
- QR code on battery pack links to full charge/discharge history, maintenance log, and thermal events.
- Ultracapacitor modules serialized by lot.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Battery pack acceptance test | Life of unit + 5 years | Engineering | QM-06-001 |
| Battery cycle/calendar life log | Life of unit + 5 years | Operations | QM-06-002 |
| Solar panel installation and output record | Life of installation + 5 years | Operations | QM-06-003 |
| Fire suppression system test | Life of unit + 5 years | Safety | QM-06-004 |
| BMS calibration record | Life of unit + 5 years | Engineering | QM-06-005 |
| Thermal event log (any battery temp exceedance) | Life of unit + 10 years | Safety | QM-06-006 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release — Draft | Bill James |

# SPEC-02: Bogie

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** ASTM F24, manufacturer requirements

---

## 1. Intent

The bogie is the motorized running gear that carries the vehicle along the guideway. Two bogies per vehicle provide independent traction, braking, and steering. The bogie must deliver reliable propulsion across the full speed and load envelope while constraining the vehicle laterally and vertically to the guideway. It is the primary interface between vehicle mass and guideway structure.

## 2. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-02-001 | 2 bogies per vehicle, each with independent power and control | Single-bogie failure must not strand or destabilize vehicle; redundancy is a safety requirement | BJ | 2026-07-18 | |
| R-02-002 | 2-4 motors per bogie, brushless DC, 3-phase, FOC preferred | FOC provides smooth torque at low speed and efficient regen; brushless eliminates brush wear on a continuous-duty system | BJ | 2026-07-18 | |
| R-02-003 | Motor voltage range: 24V-96V | Must be compatible with vehicle power system (SPEC-06) across platform scales | BJ | 2026-07-18 | |
| R-02-004 | Continuous power per motor: 5 kW (full-scale), 350W (SkyRide) | 5 kW continuous per motor supports 500 kg payload at grade; 350W is SkyRide scale | BJ | 2026-07-18 | |
| R-02-005 | Peak power per motor: 10 kW (full-scale) | Acceleration, grade climbing, and recovery from stop require 2x continuous rating | BJ | 2026-07-18 | |
| R-02-006 | Motor weight target: 4.3 kg motor only (full-scale) | Bogie mass directly reduces payload capacity; motor weight is the largest controllable component | BJ | 2026-07-18 | |
| R-02-007 | Motor selection: finalize between RV-120Em, HPM5000B, or alternative | RV-120Em: 136mm dia x 135.5mm, 6300g, 20mm shaft, N45H magnets, DLRK/DELTA winding, 12N14P, max 3750 RPM, 150C max. HPM5000B: $591, liquid cooled, 11.35kg, 206mm dia x 126mm, 91% efficiency. Neither confirmed. | BJ | 2026-07-18 | ORANGE |
| R-02-008 | Motor controller selection: finalize controller | Grin PhaseRunner tested — insufficient for load. Dual VESC used on SkyRide. Neither confirmed for full-scale. | BJ | 2026-07-18 | ORANGE |
| R-02-009 | Drive wheels: 8"-14" diameter (200mm-356mm) | Range established from vendor options; final size depends on guideway channel geometry and speed/torque tradeoff | BJ | 2026-07-18 | ORANGE |
| R-02-010 | OutRigger wheels: 8 per bogie, ~0.4 kg each | Constrain bogie laterally and vertically to guideway; prevent derailment and stabilize ride | BJ | 2026-07-18 | |
| R-02-011 | Boss subsystem: sets left-right turning via linear actuator | Actuator positions Boss against switch V-structure to select route at junctions | BJ | 2026-07-18 | |
| R-02-012 | Boss linear actuator selection: finalize vendor/model | Options evaluated: PI, LinMot, ORLIN, Inspire-Robot, Iris, Firgelli. None selected. | BJ | 2026-07-18 | ORANGE |
| R-02-013 | Switch: V-structure that Boss rides against for turns | Passive guideway element; Boss position determines which branch the bogie follows | BJ | 2026-07-18 | |
| R-02-014 | Override: guideway turning device that ignores Boss | Safety mechanism — guideway can force routing regardless of Boss position (e.g., emergency divert) | BJ | 2026-07-18 | |
| R-02-015 | Primary braking: motor regenerative braking | Regen is most efficient and feeds energy back to storage; must handle normal deceleration envelope | BJ | 2026-07-18 | |
| R-02-016 | Secondary braking: mechanical system TBD | Regen alone cannot provide emergency stop or hold at zero speed; mechanical backup required | BJ | 2026-07-18 | ORANGE |
| R-02-017 | Sensors: encoders, temperature, noise, risk signals | Nora requires encoder feedback for position/speed; temperature protects motors and bearings; noise indicates wear; risk signals feed Noelle | BJ | 2026-07-18 | |
| R-02-018 | Operating temperature: -10C to 60C | Must operate in deployed climate zones; motor derating above 40C acceptable if specified | BJ | 2026-07-18 | |
| R-02-019 | Resolve temperature range conflict with chassis spec (-40C vs -10C) | Bogie at -10C and chassis at -40C means the vehicle cannot operate below -10C regardless — specs must agree on a single lower bound | BJ | 2026-07-18 | RED |
| R-02-020 | Earthquake scurry behavior: bogie must support controlled movement to safe position during seismic event | Vehicles cannot simply stop on elevated guideway during earthquake; must move to nearest station or safe hold point | BJ | 2026-07-18 | |
| R-02-021 | Carrington event consideration | Solar storm / EMP effects on motor controllers and electronics are not understood well enough to specify protection | BJ | 2026-07-18 | YELLOW |
| R-02-022 | Noise abatement requirements | No target levels defined; urban deployment will require specification; depends on wheel material, speed, and guideway surface | BJ | 2026-07-18 | YELLOW |
| R-02-023 | Swivel bearing between bogie and vehicle body | Allows bogie to articulate independently of body through curves; 1 kg budget | BJ | 2026-07-18 | |

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-02-001 | Continuous power output per motor | >= 5 kW at rated voltage | Dynamometer test | Per motor lot |
| M-02-002 | Peak power output per motor | >= 10 kW for 30s | Dynamometer test | Per motor lot |
| M-02-003 | Motor operating temperature | <= 150C at continuous load | Thermocouple during dyno test | Per motor lot |
| M-02-004 | Regen braking energy recovery | >= 70% of kinetic energy at rated speed | Coast-down test with energy metering | Per bogie assembly |
| M-02-005 | OutRigger lateral constraint | Zero derailment across speed envelope | Guided run test with lateral load | Per bogie assembly |
| M-02-006 | Boss switching accuracy | Correct route selection 100% of activations | Switch test fixture, 1000 cycles | Per Boss assembly |
| M-02-007 | Boss switching time | <= 500ms from command to locked position | Timed test at switch fixture | Per Boss assembly |
| M-02-008 | Bogie total mass | <= 27.2 kg (per BOM below) | Weigh assembled bogie | Per unit |
| M-02-009 | Noise level at 1m | TBD (YELLOW — no target set) | Sound meter per ISO 3744 | Per bogie type |
| M-02-010 | Encoder position accuracy | TBD (depends on encoder selection) | Calibrated track run | Per unit |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Vehicle body / chassis | SPEC-01 | Swivel bearing mount point; mechanical and electrical connectors | Bogie articulates under body; power and signal cables cross bearing |
| Power system | SPEC-06 | Voltage, current, regen return | Independent power feed per bogie; regen energy returns to vehicle storage |
| Guideway | SPEC-03 | Drive wheel contact surface; OutRigger constraint surfaces; switch V-structure | Guideway defines the envelope the bogie operates within |
| Nora (vehicle agent) | Software | Encoder feedback, motor commands, temperature, fault signals | Nora commands speed/direction; bogie reports state |
| Natalie (router) | Software | Route selection commands to Boss | Natalie determines route; Boss executes at switch |
| Noelle (network) | Software | Risk signals, fault reporting | Bogie sensor data feeds network-level health monitoring |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-02-001 | Motor selection delayed — no confirmed motor for full-scale | High | Parallel evaluation of RV-120Em and HPM5000B; SkyRide uses dual VESC as interim | Open | BJ | 2026-07-18 |
| K-02-002 | Controller insufficient for load (PhaseRunner failure observed) | High | Dual VESC on SkyRide; evaluate industrial FOC controllers | Open | BJ | 2026-07-18 |
| K-02-003 | Temperature range conflict between bogie (-10C) and chassis (-40C) | Critical | Must resolve to single lower bound before any procurement | Open | BJ | 2026-07-18 |
| K-02-004 | No mechanical braking design | High | Regen handles normal ops; mechanical backup required for emergency and zero-speed hold; design needed | Open | BJ | 2026-07-18 |
| K-02-005 | Boss actuator reliability at junction — wrong route = collision | Critical | Override mechanism provides guideway-level safety net; actuator must be fail-safe | Open | BJ | 2026-07-18 |
| K-02-006 | Wheel material wear rate unknown for continuous duty | Medium | Vendor data from Sunray, Uremet, etc.; accelerated wear testing needed | Open | BJ | 2026-07-18 |
| K-02-007 | Earthquake behavior undefined beyond concept | Medium | Scurry to safe point concept exists; control algorithm and safe-point identification not designed | Open | BJ | 2026-07-18 |
| K-02-008 | Carrington event effects on electronics unknown | Low | Not understood well enough to mitigate; research needed | Open | BJ | 2026-07-18 |

## 6. Bill of Materials

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Drive motor | BLDC 3-phase, FOC | See R-02-007 | 2 per bogie | TBD (ORANGE) | TBD |
| Motor controller | FOC controller | — | 1 per bogie | TBD (ORANGE) | TBD |
| Drive wheel | Polyurethane on aluminum hub | 200-356mm dia (ORANGE) | 2 per bogie | Sunray / NewCoUSA / Uremet / Technica / PlanTech / MacLan / Vulkoprin | TBD |
| OutRigger wheel | Constraint wheel | — | 8 per bogie | TBD | TBD |
| Swivel bearing | Bogie-to-body articulation | — | 1 per bogie | TBD | TBD |
| Aluminum channel | Bogie frame | — | As required | — | — |
| Boss assembly | Steering actuator + housing | — | 1 per bogie | TBD (ORANGE) | TBD |
| Encoders | Motor/wheel position | — | Per motor | TBD | TBD |
| Temperature sensors | Motor and bearing monitoring | — | Per motor + 2 bearing | TBD | TBD |

**Mass budget per bogie:**

| Component | Mass (kg) |
|-----------|-----------|
| Motors (2x) | 10.0 |
| Controllers | 1.0 |
| Structures | 5.0 |
| OutRigger wheels (8x) | 3.2 |
| Swivel bearing | 1.0 |
| Aluminum channel | 2.0 |
| Boss assembly | 6.0 |
| **Total** | **28.2** |

## 7. Maintenance

- **Motor bearings:** Inspect per manufacturer interval; replace on noise or temperature anomaly.
- **Drive wheels:** Inspect tread wear; replace when tread depth below minimum (TBD per wheel vendor).
- **OutRigger wheels:** Inspect alignment and wear; replace on flat spots or excessive play.
- **Boss actuator:** Cycle test per manufacturer interval; inspect linkage for wear.
- **Encoders:** Verify calibration against known distance; replace on drift beyond tolerance.
- **Temperature sensors:** Cross-check against controller readings; replace on deviation.
- **Swivel bearing:** Grease per manufacturer interval; replace on excessive play.
- **Brake system (mechanical):** TBD — pending design (ORANGE).

## 8. Serialization

- Each bogie assembly receives a unique serial number.
- Motors, controllers, Boss actuators, and swivel bearings are individually serialized.
- QR code on bogie frame links to maintenance history, BOM, and test records.
- Geolocation tracked via vehicle — bogie inherits vehicle position.
- Drive wheels and OutRigger wheels serialized by lot.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Motor dyno test report | Life of unit + 5 years | Engineering | QM-02-001 |
| Bogie assembly inspection | Life of unit + 5 years | Manufacturing | QM-02-002 |
| Boss cycle test report | Life of unit + 5 years | Engineering | QM-02-003 |
| Drive wheel lot test | Life of lot + 5 years | Engineering | QM-02-004 |
| Field maintenance log | Life of unit + 5 years | Operations | QM-02-005 |
| Regen braking test report | Life of unit + 5 years | Engineering | QM-02-006 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release — Draft | Bill James |

# SPEC-10: Solar Canopy

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** NEC (NFPA 70), IEC 61215, UL 1703, ASCE 7 (wind/snow loads)

---

## 1. Intent

The solar canopy is the energy collection and weather protection system mounted on the guideway truss structure. It converts solar energy to electricity to power the JPods network, making the system self-powered and independent of fossil fuels. The canopy also protects the guideway, vehicles, and passengers at stations from rain, snow, and direct sun. JPods is solar-powered transit — the canopy is what makes that claim real. This spec consolidates JPod Solar Panel Spec R0 12DEC2024 and JPod Solar Panel Project Data Sheet R0 2024-12-13 into a single authoritative document.

## 2. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-10-001 | Canopy width: 4 m minimum, expandable up to 10 m | 4 m covers guideway envelope; wider canopies increase energy capture and weather protection; experience shows up to 10 m practical | BJ | 2026-07-18 | |
| R-10-002 | Solar panels shall meet IEC 61215 and UL 1703 certification | International qualification and safety standards for photovoltaic modules | BJ | 2026-07-18 | |
| R-10-003 | Panel wattage, dimensions, and type shall be specified per R0 solar panel spec | R0 document exists (12DEC2024) but has not been reviewed against this unified spec; resolution required | BJ | 2026-07-18 | ORANGE |
| R-10-004 | Canopy shall provide continuous weather protection over guideway between stations | Keeps guideway dry for traction; reduces maintenance; protects vehicle exterior | BJ | 2026-07-18 | |
| R-10-005 | Structural attachment to truss shall be defined | Canopy dead load, wind uplift, and snow load transfer to truss; connection type and spacing not yet understood | BJ | 2026-07-18 | YELLOW |
| R-10-006 | Canopy shall withstand wind loads per ASCE 7 for the deployment site | Solar panels act as sails; uplift, drag, and vibration forces must be within structural margin | BJ | 2026-07-18 | ORANGE |
| R-10-007 | Canopy shall resist hail impact without loss of function | Panels deployed in exposed elevated positions; hail resistance standard and test method not yet identified | BJ | 2026-07-18 | YELLOW |
| R-10-008 | Maintenance personnel shall have safe access to panels for cleaning, inspection, and replacement | Panels are elevated; fall protection, walkway, or robotic cleaning system required; access method not yet defined | BJ | 2026-07-18 | YELLOW |
| R-10-009 | Inverter and charge controller specification shall be defined | DC from panels must be conditioned for vehicle charging and/or grid tie; equipment selection depends on grid-tie decision (R-10-011) | BJ | 2026-07-18 | YELLOW |
| R-10-010 | All wiring shall comply with NEC (NFPA 70) | Electrical safety; wiring is routed through elevated truss in weather-exposed conditions | BJ | 2026-07-18 | |
| R-10-011 | Grid-tie vs. off-grid vs. hybrid topology shall be decided | Determines inverter type, storage requirements, utility interconnection agreements, and revenue model; problem understood but no decision made | BJ | 2026-07-18 | ORANGE |
| R-10-012 | Night and cloudy operation shall be addressed via energy storage or grid supplement | Solar-only operation has duty cycle gaps; must coordinate with SPEC-06 (Power) for storage sizing and backup strategy | BJ | 2026-07-18 | ORANGE |
| R-10-013 | Individual panel replacement shall be possible without shutting down the guideway segment | Panels will fail or degrade individually; replacement must not require network downtime | BJ | 2026-07-18 | YELLOW |
| R-10-014 | Wiring shall be routed through the truss structure, protected from weather and UV | Exposed wiring degrades and creates fire risk; routing method through truss not yet defined | BJ | 2026-07-18 | YELLOW |
| R-10-015 | Canopy tilt angle shall optimize annual energy yield for the deployment latitude | Fixed tilt is simplest; adjustable tilt increases yield but adds cost and maintenance; decision needed per site | BJ | 2026-07-18 | |
| R-10-016 | Canopy shall not create glare hazard for drivers on adjacent roadways | Elevated solar panels can reflect sunlight onto roads; anti-reflective coating or tilt management required | BJ | 2026-07-18 | |
| R-10-017 | Canopy drainage shall direct water away from guideway and station platforms | Collected rainwater must not pool on guideway or drip on passengers at stations | BJ | 2026-07-18 | |
| R-10-018 | Snow load handling: canopy shall shed or support snow per ASCE 7 ground snow load for deployment site | Accumulated snow adds dead load and blocks energy production; tilt and structural design must address this | BJ | 2026-07-18 | |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-10-001 | Energy yield per linear meter of guideway | TBD kWh/m/year (depends on R-10-003 panel selection and R-10-015 tilt) | Metered output vs. installed capacity | Annual |
| M-10-002 | Network energy self-sufficiency ratio | >= 100% annual (solar production >= network consumption) | Compare annual solar production to annual network energy consumption | Annual |
| M-10-003 | Panel degradation rate | <= 0.5% per year | Panel-level monitoring vs. nameplate rating | Annual |
| M-10-004 | Weather protection coverage | 100% of guideway length between stations under canopy | Visual inspection and drawing verification | At construction |
| M-10-005 | Wind survival | No panel detachment or structural damage at design wind speed | Post-storm inspection; structural monitoring sensors if installed | After wind events |
| M-10-006 | Hail survival | No loss of function after hail event at deployment site design hailstone size | Post-event inspection; power output comparison pre/post | After hail events |
| M-10-007 | Glare assessment | No hazardous glare on adjacent roadways | Glare study per FAA or local methodology at commissioning | At commissioning |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Guideway truss | SPEC-03 (Guideway) | Structural attachment; dead load + wind + snow loads transfer to truss | Truss must be designed for canopy loads |
| Power system | SPEC-06 (Power) | DC output from panels to charge controllers/inverters; energy storage coordination | Night/cloudy operation depends on SPEC-06 storage |
| Network operations | SPEC-07 (Operations) | Energy production monitoring; panel fault detection | Noelle monitors energy balance across network |
| Station | SPEC-04 (Station) | Canopy extends over station platform for weather protection | Drainage must not affect passenger areas |
| Chassis / Vehicle | SPEC-01 (Chassis) | Canopy protects vehicle from weather during transit | Reduces vehicle exterior maintenance |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-10-001 | Panel spec (R0 12DEC2024) not yet reviewed against unified spec system | Medium | Retrieve from Google Drive (Specs_working/Power/), review, and reconcile with requirements above | ORANGE | BJ | 2026-07-18 |
| K-10-002 | Wind uplift on elevated solar panels could exceed truss capacity | High | Site-specific wind analysis per ASCE 7; panel attachment design must include uplift resistance | ORANGE — needs engineering | BJ | 2026-07-18 |
| K-10-003 | Grid-tie decision affects inverter procurement, utility agreements, and revenue model | Medium | Decision needed before electrical design can proceed; off-grid simplifies permitting but requires more storage | ORANGE — needs decision | BJ | 2026-07-18 |
| K-10-004 | Night/cloudy energy gap could halt operations | High | Coordinate with SPEC-06 (Power) for battery storage sizing; grid-tie as backup if available; worst-case solar insolation analysis per site | ORANGE — needs analysis | BJ | 2026-07-18 |
| K-10-005 | Maintenance access at elevation is a fall hazard | Medium | OSHA fall protection required; consider robotic cleaning and drone inspection to reduce human access frequency | YELLOW — needs access plan | BJ | 2026-07-18 |
| K-10-006 | Hail damage could degrade energy production across network segment | Medium | Hail-rated panels (IEC 61215 hail test) and insurance; replacement inventory strategy | YELLOW — needs spec | BJ | 2026-07-18 |
| K-10-007 | Glare complaints from adjacent roads could trigger regulatory action | Low | Anti-reflective coating standard practice; site-specific glare study at design phase | Open | BJ | 2026-07-18 |

## 6. Bill of Materials

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Solar panel | PV module, IEC 61215 / UL 1703 | TBD (per R-10-003) | Per guideway length | TBD | TBD |
| Panel mounting brackets | Structural attachment to truss | Per design | Per panel | TBD | TBD |
| Inverter / charge controller | DC-AC or DC-DC conversion | Per R-10-009 / R-10-011 | TBD | TBD | TBD |
| Wiring harness | PV string wiring, NEC compliant | Per design | Per guideway segment | TBD | TBD |
| Conduit / raceway | Wire protection through truss | Per design | Per guideway segment | TBD | TBD |
| Drainage channel | Rainwater collection and routing | Per design | Per guideway segment | TBD | TBD |
| Combiner box | String-level DC aggregation | Per design | Per segment | TBD | TBD |
| Rapid shutdown device | NEC 690.12 compliance | Per design | Per panel or string | TBD | TBD |

## 7. Maintenance

- **Panel cleaning:** Frequency depends on site conditions (dust, pollen, bird activity); quarterly minimum; robotic cleaning preferred for elevated access.
- **Panel inspection:** Annual visual inspection for cracking, delamination, hot spots; IR scan recommended.
- **Inverter/controller service:** Per manufacturer interval; replace cooling fans, check capacitors.
- **Wiring inspection:** Annual inspection for UV degradation, rodent damage, connection corrosion.
- **Drainage clearance:** Semi-annual inspection; clear debris from drainage channels.
- **Mounting hardware:** Annual torque check on panel mounting bolts; check for corrosion.
- **Performance monitoring:** Continuous per-panel or per-string monitoring for underperformance detection.
- **Panel replacement:** Individual panels replaceable without network shutdown (per R-10-013); replacement procedure TBD (YELLOW).

## 8. Serialization

- Each solar panel serialized by manufacturer; serial recorded at installation with location (guideway segment, position).
- Inverters and charge controllers individually serialized with installation date and configuration.
- QR code on each panel links to installation record, performance history, and maintenance log.
- Combiner boxes and rapid shutdown devices serialized by location.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Panel certification (IEC 61215 / UL 1703) | Life of installation | Engineering | QM-10 |
| Installation inspection report | Life of installation | Construction | QM-12 |
| Annual performance report (yield vs. nameplate) | 5 years rolling | Operations | QM-16 |
| Maintenance and cleaning log | 5 years rolling | Maintenance | QM-16 |
| Post-event inspection (wind, hail) | Life of installation | Engineering | QM-13 |
| Inverter/controller service records | Life of unit | Maintenance | QM-16 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release — Draft. Consolidates JPod Solar Panel Spec R0 12DEC2024 and Project Data Sheet R0 2024-12-13 into unified spec system. | Bill James |

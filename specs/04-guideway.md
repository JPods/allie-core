# SPEC-04: Guideway

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-01-18
**Standards:** ASTM F24, ASCE 7-16

---

## 1. Intent

Define the guideway system -- the structural channel in which pods travel -- for 170 meters of JPods network at Al Karia. The guideway provides the running surface, lateral constraint, and structural continuity between columns. All guideways are one-way. Station circulation is counter-clockwise. The guideway must be manufacturable from laser-cut steel (RibRail concept), inspectable along its full length, and certifiable under ASTM F24.

## 2. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-04-001 | All guideways are one-way | Fundamental JPods safety rule -- eliminates head-on collision risk | Bill | 2026-07-18 | |
| R-04-002 | Station circulation: counter-clockwise (CCW) | JPods design standard across all platforms | Bill | 2026-07-18 | |
| R-04-003 | Color standard: Red = inbound (hot), Blue = outbound (cool) | JPods universal color standard for directional elements | Bill | 2026-07-18 | |
| R-04-004 | Two parallel guideways per segment (inbound + outbound) | One-way operation requires paired guideways for bidirectional service | Bill | 2026-07-18 | |
| R-04-005 | Pod centerline spacing: 3000mm between parallel guideways | Fits within 3m corridor between buildings at Al Karia | Bill | 2026-07-18 | |
| R-04-006 | TrussSeg8: 8-panel truss segment as primary span element | Standard span module from Fusion360 170Meter_Full design | Bill | 2026-07-18 | |
| R-04-007 | TrussSeg9: 9-panel truss segment | Extended span module for longer column spacing | Bill | 2026-07-18 | |
| R-04-008 | TrussShort: transition/end piece for segment terminations | Adapts standard segments to station and turnabout interfaces | Bill | 2026-07-18 | |
| R-04-009 | RibSegment: structural cross-frames, 10 per 170m network | Lateral bracing between parallel guideways; approximately 17m spacing | Bill | 2026-07-18 | |
| R-04-010 | C1: connection elements, 7 per 170m network | Splice joints between truss segments | Bill | 2026-07-18 | |
| R-04-011 | Turnabout circle: roundabout loop for direction reversal | Pods reverse direction without backing up | Bill | 2026-07-18 | |
| R-04-012 | Turnabout_Passthrough: bypass section through turnabout | Through-traffic does not enter roundabout loop | Bill | 2026-07-18 | |
| R-04-013 | CenterPole: center support for turnabout | Carries roundabout radial loads | Bill | 2026-07-18 | |
| R-04-014 | Pier_Turnabout: turnabout piers, 3 total | Support turnabout guideway at entry, exit, and midpoint | Bill | 2026-07-18 | |
| R-04-015 | Bogie rides inside guideway channel; OutRigger wheels constrain laterally | Running surface is internal to channel; lateral restraint prevents derailment | Bill | 2026-07-18 | |
| R-04-016 | Running surface material and finish specification | Bogie wheels require defined hardness, flatness, and friction coefficient | Bill | 2026-07-18 | ORANGE |
| R-04-017 | Guideway-to-guideway connection detail at splice joints (C1) | Alignment, fastening, and load transfer between segments | Bill | 2026-07-18 | YELLOW |
| R-04-018 | Thermal expansion joints for 170m steel structure | Steel expands ~2mm/m over 50C range; 170m = ~17mm total movement | Bill | 2026-07-18 | ORANGE |
| R-04-019 | Drainage from guideway channel | Water must not pool in running surface channel; gravity drain or weep holes | Bill | 2026-07-18 | YELLOW |
| R-04-020 | Ice/snow management in guideway channel | Running surface must remain clear in freezing conditions | Bill | 2026-07-18 | YELLOW |
| R-04-021 | Noise and vibration from vehicle on guideway | Acceptable limits for adjacent buildings; isolation or damping if needed | Bill | 2026-07-18 | YELLOW |
| R-04-022 | Guideway inspection and maintenance access | Personnel must be able to access full guideway length at 4.9m+ elevation | Bill | 2026-07-18 | ORANGE |
| R-04-023 | Switch mechanism design (guideway side) | Boss/Switch/Override referenced in bogie spec; guideway must accommodate moving element | Bill | 2026-07-18 | ORANGE |
| R-04-024 | Lightning protection for elevated steel structure | 170m of continuous elevated steel requires grounding and bonding plan | Bill | 2026-07-18 | YELLOW |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-04-001 | Guideway alignment (straightness) | TBD per ASTM F24 | Survey after erection | Each segment |
| M-04-002 | Running surface flatness | TBD (depends on R-04-016) | Gauge measurement | Each segment |
| M-04-003 | Splice joint alignment (C1) | Step/gap <= TBD mm | Feeler gauge at each joint | Each splice |
| M-04-004 | Cross-frame spacing (RibSegment) | 17m nominal +/- TBD | Tape measure | After erection |
| M-04-005 | Expansion joint gap | Accommodates +/- 17mm total | Gap measurement at defined temperature | Seasonal |
| M-04-006 | Drainage verification | No standing water after rain | Visual inspection | After first rain, then quarterly |
| M-04-007 | Noise at nearest building facade | TBD dBA limit | Sound level meter during operation | Commissioning, then annually |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Column top to guideway bearing | SPEC-03 | Truss top chord to guideway seat | Load transfer point; alignment critical |
| Roundabout columns to turnabout | SPEC-03 | CenterPole and Pier_Turnabout to roundabout guideway | 3 piers + 1 center pole |
| Solar collector mounts | SPEC-03 | Guideway truss top chord to solar panel frame | 4-10m width range |
| Bogie running surface | SPEC-05 (Chassis) | Guideway channel to bogie wheels and OutRiggers | Rolling contact interface |
| Switch mechanism | SPEC-05 (Chassis) | Guideway moving element to bogie Boss/Override | Actuation and position sensing |
| Electrical grounding | TBD | Guideway steel to building/site ground grid | Lightning and fault current path |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-04-001 | Running surface spec undefined -- bogie wheel wear and traction cannot be validated | High | Define material, hardness, finish, and flatness tolerance | ORANGE -- open | Bill | 2026-07-18 |
| K-04-002 | No thermal expansion provision in 170m steel structure | High | Design expansion joints; determine number and location | ORANGE -- open | Bill | 2026-07-18 |
| K-04-003 | Switch mechanism not designed for guideway side | High | Complete switch design concurrently with bogie spec | ORANGE -- open | Bill | 2026-07-18 |
| K-04-004 | No maintenance access method defined for 4.9m+ elevation | Medium | Design access walkway, ladder points, or specify mobile equipment | ORANGE -- open | Bill | 2026-07-18 |
| K-04-005 | Water/ice accumulation in guideway channel | Medium | Design drainage and heating or specify operational limits | YELLOW -- open | Bill | 2026-07-18 |
| K-04-006 | Noise/vibration impact on adjacent buildings unknown | Medium | Measure during prototype operation; add damping if needed | YELLOW -- open | Bill | 2026-07-18 |
| K-04-007 | Lightning strike on elevated steel with no protection plan | Medium | Design grounding and bonding per NFPA 780 or local code | YELLOW -- open | Bill | 2026-07-18 |
| K-04-008 | Splice joint (C1) misalignment could cause bogie impact/derailment | High | Define alignment tolerance; inspection protocol at every joint | YELLOW -- open | Bill | 2026-07-18 |

## 6. Bill of Materials

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| TrussSeg8 | 8-panel truss segment | Per Fusion360 170Meter_Full | Per layout | Fabricator | -- |
| TrussSeg9 | 9-panel truss segment | Per Fusion360 170Meter_Full | Per layout | Fabricator | -- |
| TrussShort | Transition/end piece | Per Fusion360 170Meter_Full | Per layout | Fabricator | -- |
| RibSegment | Structural cross-frame | Per Fusion360 170Meter_Full | 10 per 170m | Fabricator | -- |
| C1 | Splice connection element | Per Fusion360 170Meter_Full | 7 per 170m | Fabricator | -- |
| Circle | Turnabout roundabout loop | Per Fusion360 170Meter_Full | 1 per turnabout | Fabricator | -- |
| Turnabout_Passthrough | Bypass section | Per Fusion360 170Meter_Full | 1 per turnabout | Fabricator | -- |
| CenterPole | Turnabout center support | Per Fusion360 170Meter_Full | 1 per turnabout | Fabricator | -- |
| Pier_Turnabout | Turnabout pier | Per Fusion360 170Meter_Full | 3 per turnabout | Fabricator | -- |

## 7. Maintenance

- Running surface inspection for wear, scoring, debris, and standing water: weekly during operation, after any severe weather.
- Splice joint (C1) alignment check: quarterly, or after any detected vibration anomaly.
- Cross-frame (RibSegment) bolt torque verification: at commissioning, 6 months, then annually.
- Expansion joint gap measurement: seasonally (min temperature and max temperature readings).
- Drainage path verification: quarterly, clear any blockage.
- Coating/corrosion inspection: annually; touch-up per manufacturer schedule.
- Full structural inspection by licensed engineer: every 5 years per ASTM F24.
- Switch mechanism: inspection interval TBD pending mechanism design.

## 8. Serialization

- Each truss segment (TrussSeg8, TrussSeg9, TrussShort) receives a unique serial number stamped at fabrication.
- Each splice connection (C1) serialized and linked to the two segments it joins.
- Each RibSegment serialized with position number along the 170m alignment.
- Turnabout components (Circle, Passthrough, CenterPole, Piers) serialized as a set.
- QR code on each serialized component links to: fabrication records, inspection history, position in network.
- GPS coordinates recorded for each splice joint location.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Fusion360 BOM and drawings | Life of structure | Bill | QM-04-001 |
| Fabrication inspection reports | Life of structure | Fabricator | QM-04-002 |
| Erection survey (alignment) | Life of structure | Contractor | QM-04-003 |
| Splice joint inspection records | Life of structure | Contractor | QM-04-004 |
| Running surface condition reports | 5 years rolling | Operator | QM-04-005 |
| Expansion joint measurements | 5 years rolling | Operator | QM-04-006 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release from Fusion360 170Meter_Full BOM and design standards | Bill James |

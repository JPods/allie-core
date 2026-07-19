# SPEC-03: Structures -- Civil

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Marwan Nesheiwat (structural), Bill James (program)
**Sunset:** 2027-01-18
**Standards:** ACI318-19, AISC360-16, ASCE 7-16, ASTM F24

---

## 1. Intent

Provide the structural support system -- footings, columns, base plates, and truss -- for 170 meters of safety-certifiable JPods network at Al Karia. The structure carries guideway loads (dead, live, wind, seismic) to ground while maintaining 4.9m clearance and fitting within a 3m centerline corridor between buildings. All structural members must be calculable, inspectable, and certifiable under ASTM F24.

## 2. Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-03-001 | Minimum clearance height: 4.9 meters from finished grade to lowest structural member | Below 4.9m triggers truck warning sign requirements; avoids regulatory burden | Marwan | 2026-07-18 | |
| R-03-002 | Centerline width: 3 meters (pod centerline spacing: 3000mm) | Must fit between buildings at Al Karia site | Bill | 2026-07-18 | |
| R-03-003 | Pad footing: 3ft x 3ft x 18in, concrete f'c = 4000 psi, normal weight (150 lb/ft3) | Sized per Tekla Tedds calculation for applied loads | Marwan | 2026-07-18 | |
| R-03-004 | Footing reinforcement: 10 No.6 bars each way, fy = 60 ksi, 3.2in spacing, 3in cover all sides | ACI318-19 flexure and development length requirements | Marwan | 2026-07-18 | |
| R-03-005 | Allowable soil bearing pressure: 3.5 ksf (actual demand: 3.438 ksf, utilization 0.982) | All ACI318-19 checks pass at this capacity | Marwan | 2026-07-18 | RED |
| R-03-006 | Truss columns: A1085 HSS 16x0.5, height 207in (17.25ft), Fy=60 ksi, Fu=80 ksi | Combined utilization 0.971 per AISC360-16 | Marwan | 2026-07-18 | |
| R-03-007 | Truss column base plate: 60x60x5in, 10 anchor bolts (2.5in dia, 50in embed depth) | Transfer column loads to footing per Tekla Tedds | Marwan | 2026-07-18 | |
| R-03-008 | Roundabout columns: A1085 HSS 20x0.5, height 307in (25.6ft), Fy=60 ksi, Fu=80 ksi | Combined utilization 0.941 per AISC360-16 | Marwan | 2026-07-18 | RED |
| R-03-009 | Roundabout column base plate: 85x85x5in, 20 anchor bolts (2.5in dia, 40in embed depth) | Transfer roundabout column loads to footing | Marwan | 2026-07-18 | |
| R-03-010 | Truss span: approximately 30 meters | Site geometry at Al Karia | Bill | 2026-07-18 | |
| R-03-011 | T-truss design: vertical plane carries spanning loads, horizontal plane carries wind loads | Structural efficiency -- separate load paths for gravity and lateral | Bill | 2026-07-18 | |
| R-03-012 | RibRail construction: 3D truss assembled from 2D laser-cut parts | Manufacturability -- laser cutting is precise, repeatable, and available locally | Bill | 2026-07-18 | |
| R-03-013 | Solar collector mounting width: 4-10m range on truss top chord | Revenue generation and shade; width varies by site conditions | Bill | 2026-07-18 | YELLOW |
| R-03-014 | Truss member sizes must be calculated and documented | Only columns/footings/base plates have Tekla Tedds calcs; truss members do not | Marwan | 2026-07-18 | ORANGE |
| R-03-015 | Seismic design per ASCE 7-16 site-specific parameters | Load combinations include E but seismic design category, Ss, S1, site class not stated | Marwan | 2026-07-18 | ORANGE |
| R-03-016 | Rescue Rail system integrated into structure | Mentioned as concept; no engineering basis yet | Bill | 2026-07-18 | YELLOW |
| R-03-017 | Wind load design: structural members sized for site-specific wind speed | 90 mph referenced in chassis spec but structural wind load parameters not fully documented | Marwan | 2026-07-18 | ORANGE |
| R-03-018 | Subsurface soil exploration before final footing design | Footings designed on assumed 3.5 ksf -- site-specific borings required to confirm | Marwan | 2026-07-18 | RED |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-03-001 | Footing bearing utilization | <= 1.0 | Tekla Tedds calc vs. site-specific soil report | Per footing design |
| M-03-002 | Truss column combined utilization | <= 1.0 (current: 0.971) | AISC360-16 interaction check | Per column design |
| M-03-003 | Roundabout column combined utilization | <= 1.0 (current: 0.941) | AISC360-16 interaction check | Per column design |
| M-03-004 | Clearance height | >= 4.9m at all points | Survey after erection | Each column location |
| M-03-005 | Concrete compressive strength | f'c >= 4000 psi | Cylinder break tests (ACI318-19) | Per footing pour |
| M-03-006 | Reinforcement placement | 10 No.6 EW, 3in cover, 3.2in spacing | Pre-pour inspection | Per footing |
| M-03-007 | Anchor bolt embed depth | 50in (truss), 40in (roundabout) | Installation inspection | Per base plate |
| M-03-008 | HSS wall thickness | 0.5in nominal | Mill cert verification | Per delivery |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Guideway truss | SPEC-04 | Truss top chord to guideway bearing points | Truss carries guideway dead + live loads |
| Solar collectors | SPEC-04 | Truss top chord to solar panel mounts | 4-10m collector width; attachment detail YELLOW |
| Roundabout structure | SPEC-04 | Roundabout columns to turnabout guideway | CenterPole + Pier_Turnabout connections |
| Foundation to soil | Site geotech | Bottom of footing to bearing stratum | Requires site-specific borings (RED) |
| Rescue Rail | TBD | Structure to rescue system | Concept only -- no spec exists yet |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-03-001 | HSS section mismatch: Tekla base plate calc references HSS 18x0.5 but column spec states HSS 20x0.5 for roundabout | High | Verify with Marwan which section governs; re-run base plate calc for correct section | RED -- open | Marwan | 2026-07-18 |
| K-03-002 | Soil bearing assumed at 3.5 ksf without site borings | High | Commission geotechnical investigation before construction | RED -- open | Marwan | 2026-07-18 |
| K-03-003 | Footing utilization at 0.982 -- near capacity limit | Medium | If site soil is weaker than 3.5 ksf, footing must be resized; no margin for softer soil | Open | Marwan | 2026-07-18 |
| K-03-004 | Truss member sizes not yet calculated | Medium | Complete truss member design in Tekla Tedds or equivalent | ORANGE -- open | Marwan | 2026-07-18 |
| K-03-005 | Seismic parameters not site-specific | Medium | Obtain ASCE 7-16 seismic parameters for Al Karia site (Ss, S1, site class, SDC) | ORANGE -- open | Marwan | 2026-07-18 |
| K-03-006 | Roundabout column height (25.6ft) significantly taller than truss column (17.25ft) | Low | Utilization (0.941) acceptable; verify wind governs at this height | Open | Marwan | 2026-07-18 |

## 6. Bill of Materials

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Truss column | HSS round column | A1085 HSS 16x0.5 | Per layout | Steel supplier | -- |
| Roundabout column | HSS round column | A1085 HSS 20x0.5 | Per layout | Steel supplier | -- |
| Truss base plate | Steel plate | 60x60x5in | 1 per truss column | Fabricator | -- |
| Roundabout base plate | Steel plate | 85x85x5in | 1 per roundabout column | Fabricator | -- |
| Truss anchor bolts | Anchor bolt assembly | 2.5in dia, 50in embed | 10 per truss column | Supplier | -- |
| Roundabout anchor bolts | Anchor bolt assembly | 2.5in dia, 40in embed | 20 per roundabout column | Supplier | -- |
| Pad footing concrete | Normal weight concrete | f'c = 4000 psi, 3x3x1.5ft | 1 per column | Ready-mix | -- |
| Footing reinforcement | Rebar | No.6, fy = 60 ksi | 10 EW per footing | Steel supplier | -- |

## 7. Maintenance

- Visual inspection of columns and base plates for corrosion, impact damage, and bolt condition: annually minimum, after any severe weather event.
- Footing inspection for settlement, cracking, or heave: annually, or if adjacent construction occurs.
- Coating/paint system inspection and touch-up per manufacturer schedule.
- Anchor bolt torque verification: at commissioning, 6 months, then annually.
- Detailed structural inspection by licensed engineer: every 5 years per ASTM F24.

## 8. Serialization

- Each column assembly (column + base plate + anchor bolts) receives a unique serial number stamped on the base plate.
- Each footing receives a pour record linked to the column serial number.
- QR code on each base plate links to: mill certs, Tekla Tedds calc, pour records, inspection history.
- GPS coordinates recorded for each footing location.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Tekla Tedds calculation package | Life of structure | Marwan | QM-03-001 |
| Concrete cylinder break tests | Life of structure | Contractor | QM-03-002 |
| Steel mill certifications | Life of structure | Marwan | QM-03-003 |
| Footing inspection reports | Life of structure | Contractor | QM-03-004 |
| Anchor bolt installation records | Life of structure | Contractor | QM-03-005 |
| Geotechnical investigation report | Life of structure | Marwan | QM-03-006 |
| Post-erection survey (clearance) | Life of structure | Contractor | QM-03-007 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release from Tekla Tedds calcs and Spec_Civil Structures QQQ | Bill James |

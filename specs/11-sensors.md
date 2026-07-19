# SPEC-11: Sensors

**Status:** Draft
**Revision:** 0
**Date:** 2026-07-18
**Responsible:** Bill James
**Sunset:** 2027-07-18
**Standards:** ASTM F24, IEC 60529 (IP ratings), ISO 16750 (road vehicles — environmental conditions)

---

## 1. Intent

The sensor system provides the raw perception layer for the entire JPods network — vehicles, guideways, and stations. Every autonomous decision made by Nora (vehicle), Natalie (router), Noelle (network), and Sally (station) depends on sensor data. This spec defines what is sensed, where, and to what standard. It does not define the fusion or decision logic — that belongs to the control system (SPEC-05). The sensor system must be redundant where safety-critical, environmentally hardened for outdoor elevated operation, and maintainable without network shutdown.

## 2. Requirements

### 2.1 Vehicle Sensors

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-11-001 | Forward-facing camera | Obstacle detection, path verification, merge awareness; primary vision input for Nora | BJ | 2026-07-18 | |
| R-11-002 | Rear-facing camera | Rear obstacle detection; rescue push situational awareness; reversing at stations | BJ | 2026-07-18 | |
| R-11-003 | Merge camera(s) | Vision at merge/diverge points; sees approaching traffic on joining guideway | BJ | 2026-07-18 | |
| R-11-004 | Interior camera(s) | Passenger safety monitoring; child-alone mode (R-01-032); damage detection; contagion screening input | BJ | 2026-07-18 | |
| R-11-005 | Camera resolution and frame rate shall be specified | Resolution and FPS determine detection range, latency, and bandwidth; no target values yet | BJ | 2026-07-18 | YELLOW |
| R-11-006 | Forward ToF sensor(s) | Range measurement independent of lighting; provides distance data where camera alone is insufficient (fog, glare, night) | BJ | 2026-07-18 | |
| R-11-007 | Rear ToF sensor(s) | Range measurement rearward; rescue push gap measurement | BJ | 2026-07-18 | |
| R-11-008 | Merge ToF sensor(s) | Range to approaching vehicles at merge points; independent of camera path | BJ | 2026-07-18 | |
| R-11-009 | Interior ToF sensor(s) | Passenger presence detection; occupancy count; object left behind detection | BJ | 2026-07-18 | |
| R-11-010 | ToF sensor model selection | Multiple candidates exist; range, accuracy, field of view, and cost tradeoff not resolved | BJ | 2026-07-18 | ORANGE |
| R-11-011 | LiDAR: determine if needed given ToF + camera coverage | LiDAR provides high-resolution 3D point cloud but adds cost, power, and complexity; may be redundant with sufficient ToF + camera coverage | BJ | 2026-07-18 | YELLOW |
| R-11-012 | Position markers along guideway | Vehicle must know its absolute position on the guideway at all times; marker type (RFID, optical, magnetic) not yet selected | BJ | 2026-07-18 | ORANGE |
| R-11-013 | Load cells (mass measurement) | Payload mass determines braking distance, energy consumption, and fare calculation; measures gross vehicle mass minus tare | BJ | 2026-07-18 | |
| R-11-014 | IMU (inertial measurement unit) | Measures acceleration, tilt, vibration, sway; feeds ride quality monitoring and earthquake detection | BJ | 2026-07-18 | |
| R-11-015 | Wheel encoders | Motor/wheel rotation provides speed and distance; primary input for Nora position tracking between markers | BJ | 2026-07-18 | |
| R-11-016 | Motor current sensors | Current draw indicates load, motor health, and braking force; anomalous current signals fault | BJ | 2026-07-18 | |
| R-11-017 | Battery voltage and state-of-charge sensors | Energy management; range prediction; charging control | BJ | 2026-07-18 | |
| R-11-018 | Temperature sensor — passenger compartment | Comfort monitoring; HVAC control input | BJ | 2026-07-18 | |
| R-11-019 | Humidity sensor — passenger compartment | Comfort monitoring; condensation prevention | BJ | 2026-07-18 | |
| R-11-020 | Sway / ride quality sensor | Passenger comfort; structural health indication; feeds IMU data interpretation | BJ | 2026-07-18 | |
| R-11-021 | Air quality sensor — passenger compartment | CO2, particulates; ventilation control; ASHRAE 62.1-22 compliance verification | BJ | 2026-07-18 | |
| R-11-022 | Contagion detection capability | COVID/respiratory screening at boarding; technology approach and accuracy standards not defined | BJ | 2026-07-18 | YELLOW |
| R-11-023 | Sensor fusion architecture shall be defined | Multiple sensors (camera, ToF, encoder, IMU, markers) must be fused into coherent situational awareness; architecture not yet designed | BJ | 2026-07-18 | ORANGE |
| R-11-024 | Sensor redundancy: safety-critical functions shall have independent sensing paths | Forward obstacle detection uses both camera and ToF/laser independently; single sensor failure must not create blind spot | BJ | 2026-07-18 | ORANGE |
| R-11-025 | Data bandwidth: total sensor data throughput shall be within on-board processing and communication capacity | Camera video, ToF point clouds, and telemetry compete for bandwidth; total budget not calculated | BJ | 2026-07-18 | YELLOW |

### 2.2 Guideway Sensors

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-11-030 | Guideway-mounted camera(s) at merge/diverge points | Fixed viewpoint supplements vehicle cameras; sees both approaching vehicles simultaneously | BJ | 2026-07-18 | |
| R-11-031 | Guideway-mounted ToF at merge/diverge points | Range confirmation independent of vehicle sensors; cross-checks vehicle-reported position | BJ | 2026-07-18 | |
| R-11-032 | Guideway LiDAR: determine if needed | Same YELLOW as vehicle LiDAR; guideway-mounted LiDAR may replace vehicle-mounted if coverage is sufficient | BJ | 2026-07-18 | YELLOW |
| R-11-033 | Position markers installed along guideway | Passive or active markers at known positions; vehicle reads them for absolute position calibration | BJ | 2026-07-18 | |
| R-11-034 | Guideway sensors shall have environmental protection rating >= IP65 | Sensors are permanently exposed to weather at elevation; must resist rain, dust, and UV | BJ | 2026-07-18 | YELLOW |

### 2.3 Station Sensors (Mind-the-Gap)

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-11-040 | Laser distance sensors at every door opening position, both sides of every door | Full-width gap profile required; single-point measurement misses tilt, twist, and local deformation. Measures both horizontal and vertical gap. | BJ | 2026-07-18 | |
| R-11-041 | Gap sensors shall measure with and without vehicle load | Unloaded baseline recorded on vehicle arrival (no passengers); loaded measurement recorded after boarding. Comparison detects wheel wear (weekly drift), suspension faults (single vehicle), and structural settlement (single station). | BJ | 2026-07-18 | |
| R-11-042 | Gap measurement, correction, and verification logged per boarding event | Every event: vehicle ID, station ID, door position, unloaded gap, loaded gap, correction applied, final verified gap, timestamp UTC. Feeds Andi drift analysis. | BJ | 2026-07-18 | |
| R-11-043 | Door shall not open until loaded gap is verified within limits | Safety interlock: 17mm horizontal / ±8mm vertical target; 25mm / ±12mm hard max per ASCE 21.2-2008 | BJ | 2026-07-18 | |
| R-11-044 | Wind speed sensor (anemometer) at station | Local wind measurement for network shutdown decision (R-01-009: cease at 45 mph sustained) | BJ | 2026-07-18 | |
| R-11-045 | Temperature sensor at station | Thermal expansion compensation for gap calculation; guideway and platform expand/contract with temperature | BJ | 2026-07-18 | |
| R-11-046 | Vehicle position detection at station | Confirms vehicle is docked at correct slot position before door release; independent of vehicle self-report | BJ | 2026-07-18 | |
| R-11-047 | Platform edge intrusion detection | Detects passenger or object in gap zone before vehicle arrives; safety interlock | BJ | 2026-07-18 | |

### 2.4 Cross-Cutting Requirements

| ID | Requirement | Justification | RP | Date | Flag |
|----|-------------|---------------|----|------|------|
| R-11-050 | All sensors shall have defined calibration intervals per QM-11 | Sensor accuracy degrades over time; calibration schedule required for quality program compliance | BJ | 2026-07-18 | YELLOW |
| R-11-051 | All outdoor sensors shall meet minimum IP65 environmental protection | Rain, dust, ice, UV exposure in elevated outdoor environment | BJ | 2026-07-18 | YELLOW |
| R-11-052 | Sensor replacement shall be possible without network shutdown | Individual sensor failure must not require taking a guideway segment out of service | BJ | 2026-07-18 | |
| R-11-053 | All sensor data shall include UTC timestamp per Axiom 14 | Time correlation across vehicle, guideway, and station sensors is essential for fusion and forensics | BJ | 2026-07-18 | |

**Flag key:**
- (blank) = requirement is defined, understood, and actionable
- YELLOW = do not yet understand the requirement well enough to specify it
- ORANGE = understand the problem but do not have a solution
- RED = stop everything until this is fixed (safety, compliance, or blocking)

## 3. Measures of Performance

| ID | Measure | Target | Method | Frequency |
|----|---------|--------|--------|-----------|
| M-11-001 | Forward obstacle detection range | >= 100 m at operating speed (TBD) | Test track with calibrated obstacles | Type test + annual |
| M-11-002 | Forward obstacle detection latency | <= 100 ms from presence to Nora alert | Timed test with instrumented obstacle | Type test |
| M-11-003 | Position accuracy (encoder + marker) | <= 50 mm absolute position error | Calibrated track run against surveyed markers | Per vehicle annual |
| M-11-004 | Load cell accuracy | +/- 2 kg | Calibrated test weights | Per vehicle quarterly |
| M-11-005 | Gap measurement accuracy | +/- 1 mm | Calibrated gauge at platform | Monthly |
| M-11-006 | Wind speed accuracy | +/- 2 mph | Comparison with calibrated reference | Annual |
| M-11-007 | Sensor availability (safety-critical) | >= 99.9% uptime per sensor | Continuous self-test logging | Continuous |
| M-11-008 | Redundancy validation | No safety function lost on single sensor failure | Fault injection test — disable one sensor, verify backup detects | Type test + annual |
| M-11-009 | Temperature measurement accuracy | +/- 0.5C | Calibrated reference | Annual |
| M-11-010 | IMU accuracy | TBD (depends on unit selection) | Calibrated motion platform | Per unit |

## 4. Interfaces

| Interface | Spec | Boundary | Notes |
|-----------|------|----------|-------|
| Control system (Nora) | SPEC-05 | Sensor data bus; all vehicle sensor outputs feed Nora | Nora makes decisions; sensors provide perception |
| Control system (Natalie) | SPEC-05 | Guideway merge/diverge sensor data feeds routing decisions | Natalie needs to know vehicle positions for dispatch |
| Control system (Noelle) | SPEC-05 | Network-level sensor health; wind speed; station gap data | Noelle monitors system-wide safety |
| Control system (Sally) | SPEC-05 | Station sensors feed slot management and boarding safety | Sally owns station operations |
| Chassis | SPEC-01 | Vehicle sensor mounting locations; power draw; data cabling | Sensors are part of vehicle but specified separately |
| Bogie | SPEC-02 | Encoders, motor current, temperature sensors on bogie | Bogie sensors defined in SPEC-02; this spec defines integration |
| Guideway | SPEC-03 | Marker installation; guideway-mounted sensor mounting | Markers are passive guideway elements; active sensors need power |
| Station | SPEC-04 | Platform edge sensors; anemometer; docking position sensors | Station sensors are permanently installed infrastructure |
| Power | SPEC-06 | Sensor power budget; battery voltage/SOC sensing | Sensors draw power; battery sensors feed energy management |
| Quality program | SPEC-12 | Calibration records; inspection checklists | QM-11 calibration intervals apply to all sensors |

## 5. Risk Register

| ID | Risk | Severity | Mitigation | Status | RP | Date |
|----|------|----------|------------|--------|----|------|
| K-11-001 | Sensor fusion architecture undefined — cannot validate redundancy claims | High | Define fusion architecture before detailed sensor selection; identify which sensor combinations provide independent safety paths | ORANGE — needs architecture | BJ | 2026-07-18 |
| K-11-002 | ToF sensor model not selected — affects range, accuracy, and cost across entire fleet | Medium | Evaluate candidates against M-11-001/002 targets; select before vehicle detailed design | ORANGE — needs evaluation | BJ | 2026-07-18 |
| K-11-003 | Marker type (RFID/optical/magnetic) not selected — affects guideway construction and vehicle electronics | Medium | Each type has tradeoffs (cost, read range, environmental durability, speed limit); prototype test needed | ORANGE — needs prototype | BJ | 2026-07-18 |
| K-11-004 | Camera data bandwidth may exceed on-board processing capacity | Medium | Calculate total bandwidth from all cameras at selected resolution/FPS; compare with processor and communication budget | YELLOW — needs calculation | BJ | 2026-07-18 |
| K-11-005 | Contagion detection technology immature and accuracy unproven | Low | Monitor technology development; do not make safety-critical decisions based on contagion sensors until validated | YELLOW — watching | BJ | 2026-07-18 |
| K-11-006 | IP rating requirements not confirmed for all sensor locations | Medium | Survey all mounting locations; specify minimum IP rating per location; verify vendor ratings | YELLOW — needs survey | BJ | 2026-07-18 |
| K-11-007 | Calibration intervals undefined — sensors could drift undetected | Medium | Establish calibration schedule per QM-11 for each sensor type; automated self-test where possible | YELLOW — needs schedule | BJ | 2026-07-18 |
| K-11-008 | Single-point-of-failure in safety-critical sensing path | Critical | Redundancy requirement R-11-024 addresses this; but specific redundancy pairs not yet designed | ORANGE — needs design | BJ | 2026-07-18 |

## 6. Bill of Materials

### 6.1 Per Vehicle

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Forward camera | Vision, obstacle detection | TBD resolution/FPS | 1 | TBD | TBD |
| Rear camera | Vision, rearward | TBD resolution/FPS | 1 | TBD | TBD |
| Merge camera | Vision, merge points | TBD resolution/FPS | 1-2 | TBD | TBD |
| Interior camera | Passenger monitoring | TBD resolution/FPS | 1-2 | TBD | TBD |
| Forward ToF | Range, forward | TBD (ORANGE) | 1-3 | TBD | TBD |
| Rear ToF | Range, rearward | TBD (ORANGE) | 1-3 | TBD | TBD |
| Merge ToF | Range, merge points | TBD (ORANGE) | 1-2 | TBD | TBD |
| Interior ToF | Presence detection | TBD (ORANGE) | 1-2 | TBD | TBD |
| Load cells | Payload mass | Per design | 4 (one per corner) | TBD | TBD |
| IMU | Accel/gyro/magnetometer | Per design | 1 | TBD | TBD |
| Wheel encoders | Rotation sensing | Per motor | 4 (per SPEC-02) | TBD | TBD |
| Motor current sensors | Current measurement | Per motor | 4 (per SPEC-02) | TBD | TBD |
| Battery voltage sensor | Voltage + SOC | Per battery pack | 2 (per SPEC-01) | TBD | TBD |
| Temperature sensor | Compartment | — | 1 | TBD | TBD |
| Humidity sensor | Compartment | — | 1 | TBD | TBD |
| Air quality sensor | CO2, particulates | — | 1 | TBD | TBD |

### 6.2 Per Guideway Merge/Diverge Point

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Fixed camera | Merge/diverge vision | TBD | 1-2 | TBD | TBD |
| Fixed ToF | Merge/diverge range | TBD | 1-2 | TBD | TBD |

### 6.3 Per Guideway Segment

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Position markers | RFID / optical / magnetic | TBD (ORANGE) | TBD spacing | TBD | TBD |

### 6.4 Per Station

| Item | Description | Section/Size | Quantity | Source | Part # |
|------|-------------|-------------|----------|--------|--------|
| Laser distance sensor | Platform gap measurement | — | 2-4 per slot | TBD | TBD |
| Anemometer | Wind speed | — | 1 per station | TBD | TBD |
| Temperature sensor | Thermal expansion comp. | — | 1 per station | TBD | TBD |
| Vehicle position detector | Docking confirmation | — | 1 per slot | TBD | TBD |
| Edge intrusion detector | Platform safety | — | Per slot | TBD | TBD |

## 7. Maintenance

- **Cameras (all locations):** Clean lenses quarterly or on degraded image quality alert; replace on failure.
- **ToF sensors:** Self-test at each trip start (vehicle) or hourly (fixed); clean quarterly; replace on drift beyond calibration tolerance.
- **Position markers:** Inspect annually; passive markers have no maintenance; active markers replace battery per schedule.
- **Load cells:** Calibrate quarterly with known weights; replace on drift > +/- 2 kg.
- **IMU:** Calibrate annually; replace on drift beyond tolerance.
- **Encoders:** Calibrate annually against surveyed track distance; replace on position error > 50 mm.
- **Anemometers:** Calibrate annually against reference; clean quarterly.
- **Gap sensors:** Calibrate monthly against physical gauge; clean weekly at high-use stations.
- **Environmental sensors (temp, humidity, air quality):** Calibrate annually; replace on failure.
- **General:** All outdoor sensors — inspect for UV degradation, corrosion, seal integrity at every maintenance visit.

## 8. Serialization

- Each camera, ToF sensor, IMU, and load cell individually serialized.
- Sensor serial linked to vehicle serial (vehicle sensors) or location ID (fixed sensors).
- QR code on each sensor links to calibration history, installation date, and maintenance log.
- Position markers serialized by location (guideway segment + chainage).
- Station sensors serialized by station ID + slot number.

## 9. Quality Records

| Record | Retention | Custodian | Per QM- |
|--------|-----------|-----------|---------|
| Sensor calibration records | Life of sensor + 3 years | Engineering | QM-11 |
| Self-test logs (per trip / hourly) | 1 year rolling | Operations (Nora/Noelle) | QM-16 |
| Sensor replacement records | Life of vehicle/station | Maintenance | QM-16 |
| Type test reports (detection range, latency) | Life of sensor type | Engineering | QM-12 |
| Redundancy validation test report | Life of sensor type | Engineering | QM-12 |
| Fault injection test results | 5 years | Engineering | QM-17 |

## 10. Change History

| Rev | Date | Change | By |
|-----|------|--------|----|
| 0 | 2026-07-18 | Initial release — Draft. Consolidates vehicle, guideway, and station sensor requirements into single spec. | Bill James |

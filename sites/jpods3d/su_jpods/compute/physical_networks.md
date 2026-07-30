# Compute Pipeline — Physical Network Application

## Principle

The same three-phase pipeline applies to physical networks — both guideway
(elevated, JPods scale model) and ground-based (mini-bot, table-top). The
designer topology, agent chain building, and geometry extraction are
transport-independent. Only the geometry source changes.

---

## Guideway Networks (JPodsSM_RPi)

### What Changes

| Phase | SU (SketchUp) | Physical (Pi) |
|-------|---------------|---------------|
| 1. Validate | lines.json on disk | Same lines.json — SD card or MQTT sync |
| 2. Build chains | BFS on successor graph | Same BFS — runs on Pi or Mac |
| 3. Geometry | CP marker math → pts_mm | Sensor calibration → pts_mm |

### Geometry Source

**SU:** CP marker positions from SketchUp model entities.
**Physical:** CP marker positions from sensor calibration:
- AprilTag positions (camera-measured, mm)
- ToF sensor readings at known waypoints
- Encoder distance between calibration marks

The chain-walk is identical — start from known points, walk successors,
compute endpoints from neighbors. The math doesn't care whether the
known points came from a SketchUp model or a physical sensor.

### Ezone Mapping

SU ezones (from lines.json merge/diverge EPs) map directly to physical:
- `zone_length_mm` = vehicle length + braking distance (measured, not modeled)
- `locked_by` / `locked_at` = MQTT broadcast (existing protocol in jpod_OS)
- `stop_wait_count` = logged per junction for capacity analysis

### Output

**SU:** `lines.computed.json` → read by animation engine
**Physical:** `mapV2.json` → read by pod firmware (motor.py, mqtt.py)

Same data, different format. A converter between the two is straightforward.

---

## Ground-Based Networks (Mini-Bot, Table-Top)

### What Changes

| Phase | Guideway | Ground-Based |
|-------|----------|-------------|
| 1. Validate | Same | Same — lines.json declares the track topology |
| 2. Build chains | Same | Same — BFS on successor graph |
| 3. Geometry | Beam centerline pts | Floor-level path pts |

### Geometry Source

Ground-based vehicles follow painted lines, tape, or projected paths:
- Line-following sensors provide real-time position correction
- Calibration points (colored markers at junctions) provide known positions
- The chain-walk computes path geometry between calibration points

### Key Differences

| Aspect | Guideway | Ground |
|--------|----------|-------|
| Z dimension | Varies (clearance height, terrain) | Constant (floor level) |
| Curves | Cubic bezier (Axiom 17) | Circular arcs or splines (sensor-limited) |
| Junctions | Mechanical switch (actuator) | Path selection (steering) |
| Ezone enforcement | Speed control (motor PWM) | Speed control (same) |
| Merge priority | Ring traffic first | Defined per junction in EP |

### What Stays The Same

- Successor graph defines legal paths
- BFS builds chains from topology
- Ezones enforce exclusive access at junctions
- Stop-wait logged as fault
- Zipper merge = design goal
- Every stored datetime is UTC (Axiom 14)

---

## Cross-Platform Architecture

```
lines.json (designer topology)
     ↓
Phase 1: Validate (same code, any platform)
     ↓
Phase 2: Build Chains (same BFS, any platform)
     ↓
Phase 3: Geometry
  ├── SU: CP marker math from SketchUp model
  ├── Guideway: sensor calibration from Pi hardware
  └── Ground: line-follow calibration points
     ↓
Output:
  ├── SU: lines.computed.json → animation engine
  ├── Guideway: mapV2.json → pod firmware
  └── Ground: mapV2.json → bot firmware (same format)
```

Phases 1 and 2 are **identical** across platforms. Phase 3 has a platform-specific
geometry source but the chain-walk algorithm is the same. The output format differs
but carries the same data.

---

## Implementation Path

1. Build Compute v2 for SU (current work)
2. Prove on 3+circle test case
3. Extract Phases 1–2 as platform-independent Ruby/Python module
4. Add Phase 3 physical geometry source (Pi sensor calibration)
5. Add mapV2.json writer alongside lines.computed.json writer
6. Test on JPodsSM_RPi scale model
7. Extend to ground-based mini-bot

Each step is independently testable. The topology (lines.json) is the
same file across all three platforms.

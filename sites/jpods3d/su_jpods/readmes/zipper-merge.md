# Zipper Merge — Exclusive Zone Protocol

## Principle

Every merge and diverge junction on the JPods network is an **exclusive zone (ezone)** — only one vehicle at a time. Natalie adjusts approaching vehicle speeds so they arrive staggered. No vehicle ever needs to stop. When a stop-wait occurs, it is logged as a fault — evidence that capacity or timing needs improvement.

**Zipper merge is the design goal. Stop-wait is the failure mode.**

Blood does not stop flowing. When it does, that's a clot — diagnose and fix the vessel, not the blood.

---

## How It Works

### At Each Merge Junction (Traffic Circle Entry)

Two tracks converge into one:
- **Ring track** (`gw_c_N_N`) — vehicle already on the ring, traveling CCW
- **Entry track** (`gw_in_N`) — vehicle arriving from an inter-station segment

**Priority:** Ring traffic goes first. The entering vehicle yields.

**Speed scaling:** As the entering vehicle approaches the merge point, Natalie scales its speed linearly:

```
speed_factor = distance_to_junction / zone_length_mm
```

- At zone boundary (3m out): full speed
- Approaching junction: speed decreases linearly
- At junction: speed = 0 (stop-wait — logged as fault)
- Ring clear: speed returns to full

The entering vehicle smoothly decelerates as it approaches, then accelerates once the ring vehicle passes. From above, it looks like a zipper — two streams interleaving without stopping.

### At Each Diverge Junction (Traffic Circle Exit)

One track splits into two:
- **Continue CCW** on the ring
- **Exit** via `gw_out_N` to an inter-station segment

Natalie pre-sets the switch before the vehicle arrives. No speed control needed — the vehicle follows whichever path the switch is set to.

---

## The EZone Object

Each junction has a rich `EZoneDef` struct:

```ruby
EZoneDef.new(
  ep_id:           6,                      # EP number from lines.json
  station_id:      "s001",                 # which station
  type:            :merge,                 # :merge or :diverge
  tracks_in:       ["s001.gw_in_0", "s001.gw_c_0_0"],  # converging tracks
  tracks_out:      ["s001.gw_c_0_1"],      # output track
  priority:        :ring,                  # ring traffic goes first
  ring_track:      "s001.gw_c_0_0",        # has priority
  entry_track:     "s001.gw_in_0",         # yields
  zone_length_mm:  3000,                   # 3m — vehicle length + clearance
  locked_by:       nil,                    # nora_id of pod in zone
  locked_at:       nil,                    # Time lock was acquired
  stop_wait_count: 0,                      # fault counter
  note:            "CP0 MERGE — ..."       # human-readable
)
```

### Extensible Fields (Future)

The struct is designed to grow with experience:

| Field | Purpose |
|-------|---------|
| `zone_length_mm` | Adjustable per junction based on approach speed and geometry |
| `min_gap_s` | Minimum time gap between vehicles at this junction |
| `approach_curve_radius_mm` | Affects braking distance |
| `visibility_mm` | How far ahead the entering vehicle can see ring traffic |
| `historical_stop_waits` | Accumulated from multiple sessions |
| `recommended_action` | "add guideway" / "increase radius" / "adjust speed limit" |
| `weather_factor` | 1.0 = dry, up to 5.0 = ice — affects zone_length |

---

## Physical Equivalent

The protocol is proven on the physical scale model at `UTD/jpod_OS/`:

**mapV2.json** declares ezones:
```json
{
  "id": 1,
  "inPoint1": { "lineId": 3, "distFrom": 850, "distTo": 1058 },
  "inPoint2": { "lineId": 2, "distFrom": 470, "distTo": 608 },
  "outPoint": { "lineId": 1, "distFrom": 0,   "distTo": 70  }
}
```

**mqtt.py** broadcasts:
```
EZONE,podName,1   → pod claims zone (locked)
EZONE,podName,0   → pod exits zone (released)
```

Other pods approaching the zone check `isEZBlocked` and stop before entering.

**SU animation uses the same protocol** — the lock is checked in the tick loop instead of MQTT. Same logic, different transport.

---

## Stop-Wait Logging

Every stop-wait is a **negative outcome** — logged as a fault.

```
[Natalie ezone] STOP-WAIT NORA_0003 at EP6 s001 — yielding to NORA_0007 (count=1)
```

At animation stop, session totals are printed:
```
[Natalie ezone] session total: 12 stop-wait(s) across 3 junction(s)
[Natalie ezone]   EP6 s001: 5 stop-wait(s) — capacity investigation needed
[Natalie ezone]   EP12 s001: 4 stop-wait(s) — capacity investigation needed
[Natalie ezone]   EP18 s001: 3 stop-wait(s) — capacity investigation needed
```

**What stop-waits mean:**
- Natalie failed to zipper-merge at this junction
- Either capacity is insufficient (add guideways)
- Or timing is wrong (improve speed planning)
- Or demand exceeds design (rethink station placement)

**Recurring stop-waits at the same EP are a capacity signal, not a software bug.** The log accumulates evidence for infrastructure investment decisions.

---

## Implementation Files

| File | What it does |
|------|-------------|
| `jpod_ezone.rb` | EZone module — EZoneDef struct, build_from_network, enforce_ezone_spacing!, reset |
| `jpod_vehicle_anim.rb` | Tick loop calls enforce_ezone_spacing! after enforce_spacing! |
| `traffic_circle7/lines.json` | Merge/diverge EPs define the junction topology |
| `UTD/jpod_OS/mqtt.py` | Physical reference — EZONE broadcast protocol |
| `UTD/jpod_OS/mapV2.json` | Physical reference — ezone boundary definitions |

---

## Design Axioms

1. **Zipper merge is the design.** Stop-wait is the fallback. Always try speed adjustment first.
2. **Ring traffic has priority.** The entering vehicle yields — same as a real traffic circle.
3. **Every stop-wait is logged.** Recurring stops at the same junction = infrastructure signal.
4. **The ezone object is rich.** Shape, timing, priority, experience — all in one place. Adapt per junction as experience accumulates.
5. **Same protocol, SU and Physical.** The lock/release pattern is identical. Only the transport differs (tick loop vs MQTT).

---
name: Sally-Natalie authority chain — who owns what
description: Sally owns station slots and conveyor; Natalie owns dispatch timing and routing; Nora executes movement; clear separation established 2026-06-23
type: project
---

Authority chain for station operations:

**Sally** owns the station:
- Parking slot array (ps[]), pod registry
- Conveyor: 3-step direct entity transforms, shuffles all pods toward exit
- Exit hold: 3s after departure before filling ps_max
- Inbound tracking: Natalie notifies Sally of incoming pods with ETA
- 50% threshold: signals when effective_occupancy ≥ 50%
- Pod arrives → Sally assigns slot. Pod departs → Sally vacates slot.

**Natalie** owns the network flow:
- Dispatch registry: per-station, tracks last departure time
- 5s minimum between dispatches per station
- Cleared_to_depart?(sid): checks interval
- Route planning: picks destination with most room
- Inbound notification: tells destination Sally "pod coming, ETA X"
- Rebalance: dispatches from busy (≥50%) to open stations

**Nora** executes:
- Receives maneuver from Natalie
- Follows the path, reports arrival
- Does NOT decide where to go

**The rule:** Sally says "pod ready" → Natalie checks clearance and chooses destination → Nora moves the pod. No one acts outside their authority.

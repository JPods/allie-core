# Sally v2 — Station Processor

## Principle

Sally owns every station. She knows every pod. Two arrays per station:
- **ps[]** — physical parking slots (the infrastructure)
- **pods[]** — pod records (the vehicles)

Slots and pods are independent. A slot can be empty while its pod is looping.
A pod can be demanding a slot while all slots are occupied. Sally manages
the relationship between the two.

## Rich Objects

### ParkingSlot

```ruby
ParkingSlot = Struct.new(
  :number,          # 1-based slot index
  :occupant_id,     # nora_id or nil
  :state,           # :empty, :occupied, :reserved
  :reserved_for,    # nora_id that has a reservation (arriving/returning)
  :reserved_at,     # Time reservation was made
  :position_mm,     # [x, y, z] world position
  :dist_mm,         # distance along platform from entry end
  :arrival_count,   # how many pods have parked here (experience)
  :avg_dwell_s,     # average time pods stay (experience)
  :last_occupied_at # Time last pod parked here
)
```

### PodRecord

```ruby
PodRecord = Struct.new(
  :nora_id,         # vehicle ID
  :state,           # :parked, :advancing, :departing, :looping, :arriving, :unknown
  :slot,            # current or last known slot number
  :station_id,      # which station this pod belongs to
  :entity,          # SketchUp entity reference
  :loop_count,      # how many hold_loops completed
  :departed_at,     # Time pod left its slot
  :eta_return,      # estimated return time (for looping pods)
  :destination,     # where the pod is going (if departing)
  :trip_count,      # total trips completed (experience)
  :stop_wait_count, # ezone stop-waits (experience)
  :last_fault       # last fault message
)
```

## State Transitions

### Pod States

```
:parked → :advancing (Sally moves pod toward exit slot)
:parked → :departing (Natalie dispatches pod on a trip)
:parked → :looping   (Sally dispatches hold_loop)
:advancing → :parked (advance complete, new slot)
:departing → (leaves Sally's care — removed from pods[])
:looping → :arriving  (loop complete, demanding slot)
:arriving → :parked   (slot assigned, pod parked)
```

### Slot States

```
:occupied → :empty     (pod departs or starts loop)
:empty → :reserved     (Sally reserves for arriving pod)
:reserved → :occupied  (pod parks in reserved slot)
:empty → :occupied     (pod parks without reservation)
```

## Files

| File | Responsibility |
|------|---------------|
| `sally.rb` | Orchestrator — public API, delegates to sub-modules |
| `sally_station.rb` | SallyStation — per-station state (ps[], pods[]) |
| `sally_slot_manager.rb` | Slot assignment, advance queue, compact |
| `sally_dispatch.rb` | Hold_loop, sequential dispatch, pending queue |
| `sally_experience.rb` | Learning from patterns (future) |

## Key Rules

1. **Never register a pod at slot 0.** Slot 0 does not exist. If the slot is unknown, compute it from physical position.
2. **When a pod loops, its slot opens.** The slot is available for arriving pods.
3. **When a pod returns from a loop, it demands a slot.** Sally assigns the best available.
4. **Every stop-wait is a fault.** Sally counts them per slot and per pod.
5. **Sally adapts.** High-turnover slots, frequent loopers, delay patterns — all tracked in the objects.

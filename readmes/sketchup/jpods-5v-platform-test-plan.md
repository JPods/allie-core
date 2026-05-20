# 5V Platform Test — Improvement Plan
**Status:** 2026-05-07  
**Scope:** `jpod_vehicle_runtime.rb`, `jpod_animator.rb`, `natalie.rb`, `nora.rb`  
**Principle:** Class-based design; limited, single-purpose action methods; every public method documented.

---

## What the 5V Test Is

Five vehicles are placed at each station platform in parking slots 7, 6, 5, 4, 3 (departure end toward arrival end):

```
[1][2][3][4][5][6][7]
← arrivals fill here     depart from here →
 empty  empty  [3] [4] [5] [6] [7]
```

| Slot | Has destination? | Behavior |
|------|-----------------|---------|
| 7 | Yes — Station A | Departs after 5-second delay |
| 6 | Yes — Station B | Departs after 5-second delay |
| 5 | Yes — Station C | Departs after 5-second delay |
| 4 | No  | Waits; Natalie moves it to slot 7 after slot 7 empties |
| 3 | No  | Waits; Natalie moves it to slot 6 after slot 6 empties |

Display rule: vehicles in slots 4 and 3 show their **platform station** as origin and an **empty destination** field.

---

## Agent Roles (Nora / Natalie / Noelle)

Each has its own processor. They do not share state directly — they read telemetry pings.

| Agent | Role in 5V test |
|-------|----------------|
| **Nora** | Executes the trip Natalie assigns. Reads neighbor telemetry to maintain 5 m spacing (except when parking). Reports position. Does not plan. |
| **Natalie** | Plans parking_loop moves (slot 4 → 7, slot 3 → 6). Plans departure trips for slots 7/6/5. Decides exit direction (guideway_near vs uturn_near_far). |
| **Noelle** | Validates network before test starts. Guards against invalid platform data. Does not move vehicles. |

---

## Animation Order Rule

> The front-most vehicle in the direction of travel moves first.

In practice:
- **Departures:** slot 7 moves first, then 6, then 5 (highest slot = closest to departure, moves first).
- **Parking moves:** the vehicle being told to advance moves only after the slot ahead is confirmed empty.
- **Arrivals:** vehicle stops at the front-most empty parking slot (highest numbered empty slot).

Vehicles model physical telemetry pings — each Nora knows its neighbors' positions and maintains ≥ 5 m separation on guideways, ≥ 3 m when parking.

---

## Exit Routing (not yet implemented)

When a vehicle departs from a platform:

1. **Natalie** resolves the destination's direction relative to this station's guideway.
2. If destination is reachable via **guideway_near** direction:  
   → vehicle exits via `guideway_near_out`
3. If destination requires **guideway_far** direction:  
   → vehicle takes `uturn_near_far` → `guideway_far_main` → `guideway_far_out`

This logic must be coded in Natalie. It is currently absent — vehicles use bidirectional round-trip paths regardless of destination direction.

---

## Station Loop — Bug and Correct Behavior

### Correct behavior (rare case)
`station_loop` = `platform → uturn_near_far → guideway_far → uturn_far_near → platform`

This trip is **only executed** when:
- A **special-purpose vehicle** (e.g., maintenance pod) is parked at a **lower-numbered slot** (slot 3 or 4).
- A departing vehicle in a **higher-numbered slot** in front of it cannot advance without first clearing the special-purpose vehicle's blocking position.
- In that case, the blocking vehicle executes one station_loop to vacate the slot temporarily.

### Current bug
`station_loop` is triggered and executed **continuously** (loop never terminates). It should execute exactly once and then return the vehicle to its assigned parking slot.

---

## Parking Loop — Not Yet Implemented

After slots 7, 6, 5 depart:

1. Platform has empty slots 7, 6, 5 and parked vehicles at 4 and 3.
2. **Natalie** triggers `parking_loop`:
   - Tells pod in slot 4 → move to slot 7 (front-most empty).
   - Tells pod in slot 3 → move to slot 6 (next front-most empty after slot 4 clears).
3. After shuffle: slots 5, 6, 7 filled; slots 1-4 empty (arrival buffer restored).

This is currently a no-op. `run_5v_shuffle_forward` exists but is triggered on a 3-second timer rather than being dispatched by Natalie after confirmed departure.

---

## Gaps Between Current Code and Desired Behavior

| Behavior | Current status | File |
|----------|---------------|------|
| Slots 7/6/5 get destinations, 4/3 don't | ✅ Working (threshold logic line 870) | jpod_vehicle_runtime.rb |
| Slots 4/3 display empty destination | ❌ Missing — no display rule | jpod_vehicle_runtime.rb |
| 5-second delay before departure | ❌ Missing — no delay timer | jpod_vehicle_runtime.rb |
| Front-most vehicle departs first | ❌ Missing — no ordering enforced | jpod_animator.rb |
| Natalie dispatches parking_loop | ❌ Not implemented | natalie.rb |
| Exit via guideway_near vs uturn | ❌ Not implemented | natalie.rb |
| Arrivals stop at front-most empty slot | ✅ Partial — `run_5v_handle_arrivals` exists | jpod_vehicle_runtime.rb |
| station_loop: one-shot only | ❌ Bug — loops continuously | jpod_animator.rb |
| 5 m telemetry spacing on guideway | ❌ 3 m constant; no telemetry model | jpod_constants.rb |

---

## Recommended Code Changes

### 1. Introduce `PlatformQueue` class  
**File:** new `jpod_platform_queue.rb`  
**Purpose:** Owns slot state for one platform. Replaces scattered slot math in `jpod_vehicle_runtime.rb`.

```ruby
# jpod_platform_queue.rb
#
# PlatformQueue — slot occupancy and ordering for one platform.
#
# Slots are numbered 1 (arrival end) → capacity (departure end).
# Vehicles advance toward the departure end as higher slots empty.
#
class PlatformQueue
  # @param platform_id [String]
  # @param capacity    [Integer] total slots (default 7)
  def initialize(platform_id, capacity: 7); end

  # Returns the vehicle_id occupying +slot+, or nil.
  # @param slot [Integer] 1..capacity
  # @return [String, nil]
  def occupant(slot); end

  # Returns the highest empty slot number, or nil if full.
  # Used for: arrival placement, parking_loop target.
  # @return [Integer, nil]
  def front_empty_slot; end

  # Returns vehicles sorted by slot descending (departure-end first).
  # Used to enforce animation order: highest slot departs first.
  # @return [Array<Hash>] [{vehicle_id:, slot:}, ...]
  def departure_order; end

  # Moves a vehicle from its current slot to +target_slot+.
  # Raises if target_slot is occupied.
  # @param vehicle_id  [String]
  # @param target_slot [Integer]
  def move(vehicle_id, target_slot); end

  # Marks vehicle as departed (clears its slot).
  # @param vehicle_id [String]
  def depart(vehicle_id); end

  # Marks vehicle as arrived and places it at front_empty_slot.
  # @param vehicle_id [String]
  # @return [Integer] slot assigned
  def arrive(vehicle_id); end
end
```

---

### 2. Add `FiveVTest` class  
**File:** new `jpod_5v_test.rb` (extracted from `jpod_vehicle_runtime.rb`)  
**Purpose:** Encapsulates the full 5V test lifecycle. Replaces the two 200-line module methods.

```ruby
# jpod_5v_test.rb
#
# FiveVTest — orchestrates the 5-vehicle platform test.
#
# Sequence:
#   1. validate_network         — Noelle guard
#   2. place_vehicles           — 5 vehicles per platform at slots 7-3
#   3. assign_destinations      — slots 7/6/5 get trips; 4/3 get empty destination
#   4. wait(5)                  — 5-second hold before any vehicle moves
#   5. depart_in_order          — slot 7 first, then 6, then 5
#   6. natalie_dispatch_parking — after departures confirmed, move slot 4→7, 3→6
#   7. handle_arrivals          — arriving vehicles land at front_empty_slot
#
class FiveVTest
  DEPART_DELAY_S       = 5     # seconds before first departure
  GUIDEWAY_SPACING_M   = 5.0   # telemetry-based min spacing on guideways
  PARKING_SPACING_M    = 3.0   # min spacing when parking
  ROUTED_SLOTS         = [7, 6, 5].freeze
  IDLE_SLOTS           = [4, 3].freeze

  # @param model    [Sketchup::Model]
  # @param stations [Array<String>] exactly 3 destination station IDs
  def initialize(model, stations:); end

  # Entry point — runs the full sequence.
  # Calls each step in order; stops and logs on any failure.
  # @return [Boolean] true if test completed without error
  def run; end

  private

  # Validates network integrity via Noelle before placing any vehicles.
  # @return [Boolean]
  def validate_network; end

  # Places one vehicle per slot (7..3) on every platform.
  # Vehicles in IDLE_SLOTS receive no destination (empty dest field).
  # @return [void]
  def place_vehicles; end

  # Assigns one of the 3 destination stations to slots 7, 6, 5 (round-robin).
  # Slot 4 and 3 get origin = their own platform station, destination = nil.
  # @return [void]
  def assign_destinations; end

  # Blocks for DEPART_DELAY_S seconds using UI.start_timer (non-blocking in SU).
  # @return [void]
  def wait_before_departure; end

  # Departs routed vehicles in departure order (slot 7 first).
  # Each vehicle waits for the one ahead to clear before moving.
  # Uses Natalie to resolve exit direction (guideway_near vs uturn_near_far).
  # @return [void]
  def depart_in_order; end

  # Called by Natalie after each departure is confirmed.
  # Moves pod at slot 4 to front_empty_slot; then pod at slot 3 to next.
  # @param platform_queue [PlatformQueue]
  # @return [void]
  def dispatch_parking_loop(platform_queue); end

  # Handles an incoming arrival: places vehicle at front_empty_slot.
  # Called from animation tick when vehicle reaches destination platform.
  # @param vehicle_id   [String]
  # @param platform_id  [String]
  # @return [void]
  def handle_arrival(vehicle_id, platform_id); end
end
```

---

### 3. Fix `station_loop` in `jpod_animator.rb`

**Current bug:** The station_loop path is added to a vehicle's trip sequence but the termination condition is never set, so the loop repeats on every tick.

**Fix:**

```ruby
# jpod_animator.rb
#
# execute_station_loop(vehicle_id)
#
# Dispatches a ONE-SHOT station_loop trip to a vehicle:
#   platform → uturn_near_far → guideway_far → uturn_far_near → platform
#
# This is only called when a special-purpose vehicle occupies a lower slot
# and a departing vehicle in front of it needs to vacate temporarily.
# The vehicle executes exactly one loop and then re-parks at its assigned slot.
#
# @param vehicle_id  [String]   vehicle to dispatch
# @param platform_id [String]   platform from which the loop starts
# @return [void]
def self.execute_station_loop(vehicle_id, platform_id)
  # 1. Build one-shot line sequence: platform → uturn_near_far → gw_far → uturn_far_near → platform
  # 2. Set vehicle attribute: station_loop_oneshot = true
  # 3. In animation_tick, when vehicle reaches return platform node AND station_loop_oneshot == true:
  #    - Stop loop (do NOT re-queue)
  #    - Re-park at original assigned slot
  #    - Clear station_loop_oneshot flag
end
```

---

### 4. Add exit direction resolver to `Natalie`

```ruby
# natalie.rb
#
# resolve_exit_direction(origin_platform_id, destination_platform_id, network)
#
# Returns :near or :far indicating which guideway to use when departing
# origin_platform toward destination_platform.
#
# :near  → vehicle exits via guideway_near_out (no uturn required)
# :far   → vehicle must take uturn_near_far → guideway_far to reach destination
#
# @param origin_platform_id      [String]
# @param destination_platform_id [String]
# @param network                 [Hash]   FollowMe graph
# @return [:near, :far]
def self.resolve_exit_direction(origin_platform_id, destination_platform_id, network); end
```

---

### 5. Update constants

```ruby
# jpod_constants.rb — Animation module
GUIDEWAY_SPACING_M = 5.0   # telemetry-based minimum gap on guideways (was PERSONAL_ZONE_DIST = 3.m)
PARKING_SPACING_M  = 3.0   # minimum gap when parking (unchanged)
```

---

## Suggested File Changes Summary

| File | Change |
|------|--------|
| `jpod_5v_test.rb` | **New** — FiveVTest class, extracted from vehicle_runtime |
| `jpod_platform_queue.rb` | **New** — PlatformQueue class, replaces scattered slot math |
| `jpod_vehicle_runtime.rb` | Remove 5V test methods; keep low-level slot/placement helpers |
| `jpod_animator.rb` | Fix station_loop one-shot; enforce departure ordering |
| `natalie.rb` | Add `resolve_exit_direction`; trigger `dispatch_parking_loop` on departure confirm |
| `jpod_constants.rb` | Add `GUIDEWAY_SPACING_M = 5.0`; rename `PERSONAL_ZONE_DIST` |
| `readmes/5v_platform_test.md` | Update to match this spec |

---

## Documentation Standard (all public methods)

Every public method must have:
```ruby
# method_name(param) — one-line summary.
#
# Longer description of behavior, preconditions, and side effects.
# State it modifies (SketchUp attributes, module-level variables).
#
# @param name  [Type]   description
# @return [Type]        description
# @raise [ErrorClass]   when this fails
```

Private methods need a one-line comment only.

---

## What NOT to Change

- `noelle.rb` — network validation is correct; no changes needed
- `jpod_conflict_detector.rb` — occupancy detection works; used by PlatformQueue unchanged
- `jpod_nora_bridge.rb` / `jpod_natalie_bridge.rb` — bridges are correct
- Slot numbering convention (1 = arrival end, 7 = departure end) — keep as-is

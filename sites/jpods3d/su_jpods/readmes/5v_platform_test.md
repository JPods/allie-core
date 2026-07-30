# 5V Platform Test

A standard classroom test that demonstrates station platform queuing: vehicles depart from the departure end, parked vehicles advance toward departure, and arriving vehicles fill from the highest open slot downward.

---

## Platform slot model

Each station platform has **7 parking slots** numbered 1 → 7 from the `platform_in` (entry) end to the `platform_out` (departure) end.

```
platform_in                                    platform_out
     │                                               │
  [1][2][3][4][5][6][7]
  ←── new arrivals fill here      depart from here ──►
```

Slot 1 = furthest from departure (new arrivals wait here longest).
Slot 7 = closest to departure (next to leave).

---

## Initial state (after "Run 5V Platform Test")

5 vehicles are placed per platform at slots **3, 4, 5, 6, 7** — the high end of the 7-slot platform. Slots 1 and 2 are intentionally empty; they are the arrival buffer.

| Slot | Vehicle color      | Role          | State on test start |
|------|--------------------|---------------|---------------------|
| 3    | ene_JPodYellow     | `idle_reserve` | Parked              |
| 4    | ene_JPodBlue       | `idle_reserve` | Parked              |
| 5    | ene_JPodGreen      | `initial_trip` | Trip assigned       |
| 6    | ene_JPodRed        | `initial_trip` | Trip assigned       |
| 7    | ene_JPodGreen      | `initial_trip` | Trip assigned       |

Vehicle color cycles across the 5 available templates: Yellow, Blue, Green, Red, Green.

---

## Test sequence

### Step 1 — Run 5V Platform Test
Console → Vehicles → **Run 5V Platform Test**

- Clears all existing vehicles and trips.
- Places 5 vehicles at each station platform (slots 3–7).
- Assigns round-trip routes to vehicles in slots 5, 6, 7 (departure end).
- Vehicles in slots 3, 4 are parked (`idle_reserve`) with no trips yet.

### Step 2 — Start Animation
Console → Animation → **Start Animation**

Vehicles at slots 5, 6, 7 begin their trips to other stations. Each routed vehicle routes to a different destination station, distributed round-robin across the network.

### Step 3 — Shuffle to Departure End
Console → Vehicles → **Shuffle to Departure End**

After the routed vehicles have departed (or are en route), run the shuffle:

| Before shuffle | After shuffle |
|----------------|---------------|
| Slot 3 (Yellow) parked | → Slot 6 (higher, closer to departure) |
| Slot 4 (Blue) parked   | → Slot 7 (highest, departure-ready)    |
| Slots 1, 2, 5 empty    | Slots 1, 2, 3, 4, 5 now empty (arrival buffer) |

The shuffle fills from the highest available slot downward, preserving relative queue order. The vehicle that was at the higher slot before (slot 4) goes to the higher target (slot 7).

### Step 4 — Arriving vehicles fill from highest open slot
When a new Nora arrives at this platform, it parks at the **highest unoccupied slot** (`next_open_platform_slot_from_high`).

After the shuffle, available arrival slots in order of assignment:
- First arrival → slot 5
- Second arrival → slot 4
- Third arrival → slot 3
- Fourth arrival → slot 2
- Fifth arrival → slot 1

This keeps the departure end (slots 6, 7) loaded and ready, while arrivals queue into the lower slots — classic gravity-fed queue behavior.

---

## Why this slot ordering?

JPods platforms are one-way. Vehicles enter through `platform_in`, park, and exit through `platform_out`. The slot numbers map the physical distance from entry to exit:

- Slot 1 is at `platform_in` — the first position a new vehicle reaches.
- Slot 7 is at `platform_out` — the last position before a vehicle re-enters the guideway.

In a gravity-fed queue, the vehicle closest to `platform_out` (slot 7) departs first. New vehicles fill from the back (low slots) forward.

---

## Connections and trip routing

Each vehicle at slots 5–7 gets a round-trip from its **origin platform** to a **destination platform** at a different station. Destination assignment cycles round-robin across all other stations so no single station receives all the traffic.

Return trips use the parallel return track (track_index 0) — vehicles never reverse on a FollowMe line. A terminus station with `u_turn: true` reverses direction internally, then the vehicle departs on the opposite track.

---

## Station Platform Demo

Console → Vehicles → **Station Platform Demo**

A single-vehicle visualization: places one Nora at slot 1 and advances it one slot every N seconds until it reaches the last slot. Shows the physical slot-to-slot spacing on the platform guideway. Useful for verifying spawn_t geometry and slot spacing before running the full 5V test.

---

## Console tasks reference

| Task | Category | What it does |
|------|----------|--------------|
| Run 5V Platform Test | Vehicles | Clear + place 5 Noras per platform at slots 3–7; route slots 5–7 |
| Shuffle to Departure End | Vehicles | Move parked Noras (slots 3–4) to highest available slots (6–7) |
| Station Platform Demo | Vehicles | Advance one Nora through all slots with a timer |
| Place Vehicle at Station Platform | Vehicles | Manual single-vehicle placement with slot picker |
| Move Nora to Platform Slot | Vehicles | Re-seat an existing Nora without changing its trip |
| Clear All Vehicles | Vehicles | Remove all Noras and trip data |

---

## Key constants (jpod_vehicle_runtime.rb)

| Constant | Value | Meaning |
|---|---|---|
| `STANDARD_TEST_MAX_PARKING_SPACES_PER_PLATFORM` | 7 | Slot count per platform |
| `STANDARD_TEST_VEHICLES_PER_PLATFORM` | 5 | Noras placed per platform |
| `STANDARD_TEST_ROUTED_PER_PLATFORM` | 3 | Noras that get trip assignments (highest slots) |
| `STANDARD_TEST_PERSONAL_SPACE_M` | 3.0 m | Spacing between parked vehicles |
| `STANDARD_TEST_SLOT_VEHICLES` | Yellow, Blue, Green, Red, Green | Vehicle template cycle |

---

## Failure modes to watch

**Zero platforms found** — `platform` tag missing from station loading guideway, or FollowMe not exported. Run "Validate Network + Show" first.

**Occupancy conflict STOPPED** — Two vehicles computed to the same physical position. Usually means `STANDARD_TEST_PERSONAL_SPACE_M` is too small for the actual platform length, or the platform guideway is shorter than `3 × 7 = 21 m`. Check Ruby Console for slot and position details.

**Run 5V Test requires at least 2 stations** — Add a second station to the model, recompute CPs, rebuild network, re-export FollowMe.

**Trip build failed** — Network is disconnected between origin and destination stations. Run "Validate Network + Show" and resolve disconnected endpoints before running the test.

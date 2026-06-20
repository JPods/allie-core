---
name: Vehicle array + parking array placement pattern
description: Place pods using Sally's registered world positions (parking array), not dist-walking or nearest-neighbor — guarantees confirm_slots maps correctly
type: feedback
---

`Sally.place_vehicles_at_slots` is the **prime placement function** for all station tests. It is a Sally method, not console test logic, because Sally is the authority on slot world positions for any station regardless of ps count (3-slot line-end, 10-slot parking, traffic circle, etc.).

```ruby
# jpod_sally.rb — Sally.place_vehicles_at_slots(model, station_id, defn, slot_nums, plat_pts)
# Returns { slot_num => ComponentInstance } for each placed vehicle.
placed = JPods::Sally.place_vehicles_at_slots(model, station_id, defn, slot_nums, plat_pts)
```

**Why it exists:** Placing pods by walking `plat_pts` at `dist_mm / 25.4` and relying on `confirm_slots` nearest-neighbor caused all pods to snap to the same slot when placement positions were wrong. This is not a "ps3 problem" — it is a structural problem: the test runner was computing positions independently of Sally. Sally already has the exact registered world positions; she should own placement.

**How to apply:** Any station test (shuffle, depart, arrival) that places pods at specific slots must call `Sally.place_vehicles_at_slots`. Never use `place_at_dist` with formula spacing or `dist_mm / 25.4` dist-walking for placement. Those paths are only valid for non-slot geometry (e.g., placing a pod mid-track for a traverse test).

**Companion fix:** `lines_data['parking_slots']` is wrong in schema v5 — read from `lines_data['designer']['parking_slots']` instead. Detect with `lines_data['schema_version'].to_s >= '5'`. This is needed to get correct `slot_deep/mid/front` slot numbers to pass to `place_vehicles_at_slots`.

**Full reference:** `su_jpods/readmes/sally-behaviors.md` — deep implementation doc covering init flow, schema v5 paths, prime placement function, all failure modes, and public API.

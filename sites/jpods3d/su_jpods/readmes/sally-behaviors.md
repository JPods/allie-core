# Sally — SketchUp Module Behaviors
**File:** `jpod_sally.rb`  
**Last Updated:** 2026-06-16  
**Domain:** SU simulation (all station templates, any ps count)

This document covers Sally's *implementation* — how the Ruby module initializes, how
slot positions are established, how tests must place vehicles, and what to check when
Sally does something unexpected. For Sally's policy role (network balance, hold_loop
authority boundary, passenger priority rules) read `readmes/agents/sally.md`.

---

## Hard Rule — No Network-Level Sally Debugging

**Sally parking bugs are fixed at the su_jpods/model (template) level. Full stop.**

If Sally parking behaves incorrectly in a full network build or network animation,
do not debug it there. Network-level Sally debugging is rejected. The correct response is:

1. Identify which station template is misbehaving
2. Open that template's model.skp
3. Run the station tests (platform_shuffle, departure_test, arrival_test) from the
   Console → Models tab
4. Fix the bug at the template level — in lines.json, in jpod_sally.rb, or in the
   station test runner
5. Re-run the station tests until they pass
6. Only then test the behavior in a full network

**Why:** Network builds composite state from all templates simultaneously. When a
parking bug appears at the network level it looks like a routing problem, a Natalie
problem, a timing problem — everything except what it actually is. The station tests
isolate Sally's behavior to one template, one ps count, one set of chain definitions.
That is the only level where the root cause is visible and fixable without noise.
Debugging at the network level burns time and produces wrong theories.

This rule applies to all contributors and to all future Claude sessions working on
this codebase.

---

## The Central Rule

**Sally is the sole authority on slot world positions.**

Nothing outside Sally should compute where a parking slot is in 3D space. Not the
test runner. Not the console. Not a formula. Sally registers slot positions during
`init_from_model` and exposes them via `slot_positions_for_station`. All code that
places vehicles at slots must use that data.

Violating this rule causes *confirm_slots nearest-neighbor mismatch* — all pods snap
to the same slot regardless of where they were placed. This is not a station-specific
bug; it is a structural failure that will recur on every template with a different ps
count until the root cause is corrected.

---

## Initialization Flow

Two methods must run in order before any station test or animation:

```
init_sequencer_for_station(station_id, model_id, plugin_dir)
        ↓
init_from_model(model, lookup_cache)
```

### 1. `init_sequencer_for_station`

Reads `lines.json` for the named template and populates `@@sequencers[sid]` with:

| Key | Source in lines.json | What it is |
|-----|----------------------|------------|
| `hold_loop_chain` | `natalie.hold_loop_chain` | Outer-ring tracks (from_platform + loop repeats + to_platform) |
| `landing_chains` | `natalie.landing_chains` | CP→platform return paths keyed by CP number |
| `exit_chains` | `natalie.exit_chains` (or `originating_chains`) | Platform→CP departure paths |
| `parking_slots` | `designer.parking_slots` | Slot positions with explicit dist_mm |
| `parking_chain` | `natalie.parking_chain.tracks` | Ordered gw_platform* track sequence |
| `capacity` | derived from `designer.parking_slots` count | Authoritative slot count |

**Schema v5 path rule (critical):**

Lines.json schema v5 nests routing data under `natalie` and designer data under
`designer`. Top-level keys no longer exist for these fields.

```ruby
v5  = lj['schema_version'].to_s >= '5'
nat = v5 ? (lj['natalie']  || {}) : lj
des = v5 ? (lj['designer'] || {}) : lj

# Correct v5 reads:
hold_loop  = nat['hold_loop_chain']
parking    = nat.dig('parking_chain', 'tracks')
pslots     = des['parking_slots']   # Array of { slot:, dist_mm: } hashes
```

Any code reading lines.json outside Sally must apply the same schema-version check.
Omitting it silently returns nil and causes formula-fallback behavior.

### 2. `init_from_model`

Reads the live SketchUp model and populates slot world positions. Called once per
animation session (idempotent when called again — clears and rebuilds all registries).

**Pass order:**

| Pass | What it does |
|------|-------------|
| 1 | Scan `lookup_cache` for `gw_platform_parking` — primary platform if present |
| 1b | Scan `gw_platform` — fallback if no `_parking` variant |
| 2 | Record overflow capacity (`gw_platform` when both exist) |
| 2.5 | Override geometric capacity from `@@sequencers[sid][:parking_slots]` — ground truth |
| 3 | Compute 3D world slot positions (see below) |
| Pre-pop | Load vehicles already parked in model from entity attributes |

**Pass 3 — slot world position priority:**

```
Priority 1: @@sequencers[sid][:parking_slots] with explicit dist_mm
            (template-authored; check with lines.json designer.parking_slots)
Priority 2: Arc-length formula — (slot - 0.5) × SLOT_SPACING_M
            (fallback when lines.json has no parking_slots section)
```

Entry orientation (which end of gw_platform is ps1) is determined by proximity to
`gw_platform_in2` → `gw_platform_in` → `gw_near_main` anchor tracks (in that priority).
If the pts array is exit-first, `init_from_model` flips it so slot positions are
measured from the entry end.

**Result:** `@@slot_positions[sid][slot_num] = Geom::Point3d` for every slot.

---

## Prime Placement Function

```ruby
JPods::Sally.place_vehicles_at_slots(model, station_id, defn, slot_nums, plat_pts)
```

**This is the only correct way to place test vehicles at specific slots.**

| Argument | Type | What it is |
|----------|------|-----------|
| `model` | `Sketchup::Model` | Active model |
| `station_id` | `String` | Lowercase station id (e.g. `'station_line_end'`) |
| `defn` | `Sketchup::ComponentDefinition` | Vehicle component definition |
| `slot_nums` | `Array<Integer>` | Ordered slot numbers to fill |
| `plat_pts` | `Array<Geom::Point3d>` | gw_platform pts in world space (for forward orientation) |

**Returns:** `{ slot_num => ComponentInstance }` — one entry per placed vehicle.
Slots with no registered world position are skipped with a warning log.

**Caller is responsible for wrapping in `model.start_operation` / `commit_operation`.**

### How it works

```ruby
sp = slot_positions_for_station(sid)   # @@slot_positions[sid]

slot_nums.each do |slot_n|
  wpos = sp[slot_n]                    # Sally's registered world position
  fwd  = nearest_segment_fwd(plat_pts, wpos)  # orientation from plat_pts
  xf   = JPods::JPodGuideway.vehicle_transform_for(defn, wpos, fwd)
  ent  = model.entities.add_instance(defn, xf)
  placed[slot_n] = ent
end
```

The forward vector is derived from whichever plat_pts segment's midpoint is nearest
to the slot world position — no dist-walking, no arc-length arithmetic.

### Why not `place_at_dist`?

`place_at_dist` walks `plat_pts` at a given inch distance from `pts[0]`. It requires:
1. Correct pts orientation (entry-first)
2. Accurate dist_in derived from dist_mm
3. `confirm_slots` nearest-neighbor to snap the placed position to a registered slot

Any error in step 1 or 2 causes all pods to snap to the same slot (the nearest one
to all wrong positions). The error is silent — the log shows correct slot labels
but the vehicles are at the wrong positions.

`place_vehicles_at_slots` eliminates all three dependencies by placing at the
registered world position directly. Sally already did the orientation and distance
arithmetic during `init_from_model`.

---

## Station Test Protocol

All three station tests (platform_shuffle, departure_test, arrival_test) must follow
this sequence:

```ruby
# 1. Init Sally sequencer (reads lines.json)
JPods::Sally.init_sequencer_for_station(station_id, fid, plugin_dir) rescue nil

# 2. Init Sally from model (builds @@slot_positions)
JPods::Sally.init_from_model(model, template_lookup) if defined?(JPods::Sally)

# 3. Orient plat_pts entry-first using Sally's ps1 position
sp   = JPods::Sally.slot_positions_for_station(station_id) rescue {}
ps1  = sp[1]
if ps1
  d0 = plat_pts.first.distance(ps1).to_f
  dn = plat_pts.last.distance(ps1).to_f
  plat_pts = plat_pts.reverse if dn < d0
end

# 4. Determine which slots to use (from lines.json designer.parking_slots)
v5     = lines_data['schema_version'].to_s >= '5'
des    = v5 ? (lines_data['designer'] || {}) : lines_data
pslots = (des['parking_slots'] || []).sort_by { |ps| ps['slot'].to_i }

# 5. Place vehicles using Sally's prime function
model.start_operation('Test Place Vehicles', true)
placed = JPods::Sally.place_vehicles_at_slots(
  model, station_id, defn, target_slot_nums, plat_pts
)
model.commit_operation
```

Steps 1 and 2 must happen before step 5. If `init_from_model` has not run,
`slot_positions_for_station` returns `{}` and `place_vehicles_at_slots` skips every
slot with a warning.

---

## Platform Shuffle Test — Slot Selection

The shuffle test uses the **last 3 slots** (exit-end) so `slot_front` = ps_max, the
slot where the hold-loop pod departs first. Works for any template:

```ruby
test_pslots = pslots.last(3)          # last 3 by slot number
slot_deep   = test_pslots[0]['slot'].to_i   # ps_cap - 2
slot_mid    = test_pslots[1]['slot'].to_i   # ps_cap - 1
slot_front  = test_pslots[2]['slot'].to_i   # ps_cap

placed = JPods::Sally.place_vehicles_at_slots(
  model, station_id, defn,
  [slot_deep, slot_mid, slot_front],
  plat_pts
)
v3e = placed[slot_deep]    # NORA_0003 — probe, innermost
v2e = placed[slot_mid]     # NORA_0002 — probe, middle
v1e = placed[slot_front]   # NORA_0001 — runner, exit slot, departs first
```

This is station-count-agnostic. A 3-slot template gets ps1/ps2/ps3. A 10-slot
template gets ps8/ps9/ps10. The same code works for both.

---

## Departure Test — All Slots

The departure test fills every slot, then verifies Sally dispatches each pod in
correct order (highest slot first):

```ruby
all_slot_nums = pslots.map { |ps| ps['slot'].to_i }

model.start_operation('Depart Test Place Vehicles', true)
placed = JPods::Sally.place_vehicles_at_slots(
  model, station_id, defn, all_slot_nums, plat_pts
)
model.commit_operation

slot_entries = all_slot_nums.map { |s| { ent: placed[s], slot: s } }.select { |e| e[:ent] }
```

---

## `confirm_slots` — Reconciliation

`Sally.confirm_slots(station_id, model, reserved_slots: {})` is a reconciliation
sweep, not a primary placement tool. It:

1. Scans all parked entities in the model (by `parked_station_id` + `parking_slot` attrs)
2. Snaps each to the nearest registered slot within 4000mm (excludes hold_loop outer ring)
3. Reconciles `@@parking_slots` preserving `dist_mm`, `position`, `arrival_seq`

It is called by `start_for_template` after animation begins. It is **not** called
during test vehicle placement — the vehicles must already be at the correct positions
before animation starts. If placement is wrong, `confirm_slots` will snap all pods
to whichever slot is nearest in 3D space, which may be the same slot for all of them.

---

## Common Failure Modes

### All pods snap to the same slot

**Symptom:** Log shows `NORA_0001: parked ps3`, `NORA_0002: parked ps3`,
`NORA_0003: parked ps3`.

**Root cause:** Vehicles were placed at wrong 3D positions. `confirm_slots`
nearest-neighbor assigned all three to the same slot because that slot was nearest
to all three wrong positions.

**Fix:** Verify that `init_from_model` ran before `place_vehicles_at_slots`.
Check that `slot_positions_for_station` returns non-empty dict. If it returns `{}`
the sequencer was not initialized or the lines.json parking_slots path was wrong
(schema v5: read from `designer.parking_slots`, not top-level).

### `slot_positions_for_station` returns `{}`

**Cause A:** `init_from_model` not called — call it after `init_sequencer_for_station`.

**Cause B:** `@@sequencers[sid][:parking_slots]` is empty — lines.json has no
`designer.parking_slots` section, or schema v5 path was read incorrectly.

**Cause C:** Station ID case mismatch — Sally normalizes to lowercase. Pass
`formation_id.downcase` as `station_id`.

### Formula fallback positions used instead of dist_mm

**Symptom:** Pods land at `(slot - 0.5) × 2500mm` positions instead of lines.json values.

**Cause:** Pass 3 of `init_from_model` fell through to the arc-length formula because
`@@sequencers[sid][:parking_slots]` was empty.

**Check:** In `init_sequencer_for_station`, the read is:
```ruby
pslots = des['parking_slots']
```
where `des = v5 ? (lj['designer'] || {}) : lj`. If `v5` is false when it should be
true (e.g. `lj['schema_version']` is nil), `des = lj` and `parking_slots` will not
be found at the top level of a v5 file.

---

## Module-Level State

| Variable | Type | What it holds |
|----------|------|---------------|
| `@@stations` | Hash | `{ sid => { capacity, timer_ticks, parking_track, … } }` |
| `@@slot_positions` | Hash | `{ sid => { slot_n => Geom::Point3d } }` — backward compat |
| `@@parking_slots` | Hash | `{ sid => Array<ParkingSlot> }` — primary slot store |
| `@@platform_vehicles` | Hash | `{ sid => Array<PlatformVehicle> }` |
| `@@sequencers` | Hash | `{ sid => { hold_loop_chain, landing_chains, parking_slots, … } }` |
| `@@pod_states` | Hash | `{ nora_id => { state, loop_count, target_loops, … } }` |
| `@@pending_dispatch` | Hash | `{ sid => [{ entity, nora_id, loops, cp, slot }] }` |
| `@@platform_tick` | Integer | Tick counter for active/idle interval |
| `@@platform_quiet_ticks` | Integer | Consecutive ticks with no pending pods → idle |

All are cleared by `Sally.reset`. `init_from_model` clears and rebuilds all of them.

---

## Key Constants

| Constant | Value | Meaning |
|----------|-------|---------|
| `SLOT_SPACING_M` | `2.5` | Formula-fallback slot pitch (meters) |
| `PLATFORM_ACTIVE_TICKS` | `2` | 2 × 0.5s = 1s advancement interval when active |
| `PLATFORM_IDLE_TICKS` | `8` | 8 × 0.5s = 4s advancement interval when idle |
| `PLATFORM_QUIET_THRESHOLD` | `8` | Ticks without events → switch to idle |
| `MISPLACE_THRESHOLD_MM` | `300.0` | Max snap distance in confirm_slots |
| `HOLD_LOOP_EXCLUDE` | Regex | Tracks excluded from hold_loop derivation |

---

## Public API at a Glance

| Method | When to call | Returns |
|--------|-------------|---------|
| `init_sequencer_for_station(sid, model_id, plugin_dir)` | Before any test; reads lines.json | — |
| `init_from_model(model, lookup_cache)` | After sequencer init; at animation start | — |
| `place_vehicles_at_slots(model, sid, defn, slot_nums, plat_pts)` | Any time vehicles need placing at slots | `{ slot_n => entity }` |
| `slot_positions_for_station(sid)` | Check if Sally knows this station | `{ slot_n => Point3d }` or `{}` |
| `slot_track_for(sid)` | Get name of primary parking track | `String` or `nil` |
| `reserve_slot(sid, nora_id)` | Pod arrives — Natalie calls this | `Integer` slot or `nil` |
| `release_slot(sid, nora_id)` | Pod departs — Natalie calls this | `{ next_pod:, next_slot: }` |
| `confirm_slots(sid, model, reserved_slots: {})` | Reconcile after animation starts | `{ slot => nora_id }` |
| `start_hold_loop(sid, nora_id, arrival_cp:, target_loops:)` | Pod enters outer ring | `Array<String>` tracks |
| `on_maneuver_complete(nora_id)` | Maneuver done callback | `{ action:, tracks:, station_id: }` |
| `set_departure_mode(sid, bool)` | Departure test — Sally dispatches ps_max pods | — |
| `on_system_tick` | Every 0.5s from animation engine | — |
| `reset` | Animation stop | — |

---

## Design Decisions at the Code Level

| Date | Decision | Why |
|------|----------|-----|
| 2026-06-16 | `place_vehicles_at_slots` is a Sally method | Sally is the authority on slot world positions — any station, any ps count. Placement logic does not belong in the test runner. |
| 2026-06-16 | Vehicle array + parking array pattern | Building a parking array from `slot_positions_for_station` and zipping with placed entities removes nearest-neighbor ambiguity entirely. Placement is exact. |
| 2026-06-13 | `gw_platform_in2` proximity takes priority for entry orientation | Gives an unambiguous signal even when the edge direction in geometry.json is reversed. |
| 2026-06-02 | Slot positions from lines.json `designer.parking_slots` take priority over arc-length formula | Explicit dist_mm values debugged once; formula fallback is only for templates without authored slot data. |
| 2026-06-02 | hold_loop_chain authored in lines.json, not derived from CCW at runtime | Debug once, use many. Derivation from CCW produced subtly wrong chains for some templates; explicit authoring is unambiguous. |

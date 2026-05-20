# Prompt: Implement JPods Console Consolidation

Paste this entire prompt into Claude in VS Code.

---

## Context

You are working on the JPods SketchUp plugin. The main files are:

- **`/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/jpod_console.rb`** — Ruby. Contains the `TASKS` array. Each entry is a Hash with `id`, `label`, `category`, `description`, `risk`, `params`, and `run` lambda. This is the authoritative task registry.
- **`/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/dialogs/console.html`** — The console UI. Parameters render from the task's `params` array. Each param entry specifies `id`, `label`, `type` (`:string`, `:integer`, `:float`, `:select`), and optionally `source` (`:platform_ids`, `:station_ids`, `:nora_ids`, `:available_vehicles`), `default`, `min`, `max`, `placeholder`. The JS function `renderParams(params)` builds the input/select controls automatically from this array — you do not need to modify the HTML for params as long as the Ruby task definition is correct.
- **`/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/jpod_animator.rb`** — Contains `JPods::JPodGuideway` module methods (the engine behind most task lambdas).
- **`/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/jpod_vehicle_runtime.rb`** — Contains additional `JPods::JPodGuideway` methods for vehicle and platform operations.

**How params render in the UI:** When a user selects a task in the left panel, the console calls `renderParams(task.params)`. For each param:
- `type: :string` → text input field
- `type: :integer` or `type: :float` → numeric input with min/max
- `type: :select, source: :platform_ids` → dropdown populated from followme.json platforms
- `type: :select, source: :station_ids` → dropdown populated from followme.json stations
- `type: :select, source: :nora_ids` → dropdown populated from assigned vehicles
- `type: :select, source: :available_vehicles` → dropdown populated from vehicle templates

The `run` lambda receives `model` and `p` (a hash of `{ param_id => value }`). Access params as `p["param_id"]`.

**How risk levels work:**
- `risk: :safe` — executes immediately on click
- `risk: :caution` — shows a yellow warning before execute
- `risk: :destructive` — requires a confirmation checkbox (`confirm_text:` field) before execute

---

## Task: Implement the Consolidation

Read `jpod_console.rb` in full before making any changes. Make all changes in one pass. Do not add comments to unchanged code.

### 1. Remove these three task entries from TASKS (delete the entire hash including `run` lambda)

- `id: "show_followme_paths"` — fully contained in `validate_and_show`
- `id: "export_trip_jsons"` — superseded by the on-the-fly JSON button in the trip table
- `id: "show_trip_detail"` — the trip table's JSON button does the same thing

The underlying Ruby methods (`show_followme_paths`, `export_all_trip_jsons`, `build_trip_detail`) are preserved elsewhere in the codebase — only the TASKS entries are removed.

---

### 2. Merge: Restore Dead-End Caps + Restore Dead-End Cap at CP → one command

**Replace** both `id: "restore_dead_end_caps"` and `id: "restore_dead_end_cap_at"` with a single entry:

```ruby
{ id: "restore_dead_end_caps",
  label: "Restore Dead-End Caps",
  category: "Builder",
  description: "Scans structures for open stubs (connection deleted after a segment was removed) " \
               "and places a synthetic dead_end_cap plate at each one. " \
               "Leave Structure ID blank to scan all structures. " \
               "Enter a specific Structure ID (e.g. S098) to restore only that structure's stubs. " \
               "After running, rebuild the network so new caps are picked up by CP detection.",
  risk: :safe,
  requires_selection: nil,
  params: [
    { id: "structure_id", label: "Structure ID (blank = all)",
      type: :string, default: "", placeholder: "e.g. S098 — leave blank for all" }
  ],
  run: lambda { |model, p|
    sid = p["structure_id"].to_s.strip
    if sid.empty?
      count, msg = JPods::JPodGuideway.restore_dead_end_caps(model)
      puts "JPods Restore Dead-End Caps: #{msg}"
      msg
    else
      ok, msg = JPods::JPodGuideway.restore_dead_end_cap_at(model, sid, 0)
      puts "JPods Restore Dead-End Cap at #{sid}: #{msg}"
      msg
    end
  }
},
```

**Note on the CP index:** The original single-CP command took a `cp_index` integer param. Keep that as a second optional param so targeted restoration still works precisely:

```ruby
params: [
  { id: "structure_id", label: "Structure ID (blank = all)",
    type: :string, default: "", placeholder: "e.g. S098 — leave blank for all" },
  { id: "cp_index", label: "CP Index (only used when Structure ID is set)",
    type: :integer, default: 0, min: 0, max: 32 }
],
run: lambda { |model, p|
  sid = p["structure_id"].to_s.strip
  if sid.empty?
    count, msg = JPods::JPodGuideway.restore_dead_end_caps(model)
    puts "JPods Restore Dead-End Caps: #{msg}"
    msg
  else
    idx = p["cp_index"].to_i
    ok, msg = JPods::JPodGuideway.restore_dead_end_cap_at(model, sid, idx)
    puts "JPods Restore Dead-End Cap at #{sid}.CP#{idx}: #{msg}"
    msg
  end
}
```

---

### 3. Merge: Inspect Structure CPs + Inspect Guideway Endpoints → Inspect Selection

**Replace** both `id: "inspect_structure"` and `id: "inspect_guideway"` with a single entry:

```ruby
{ id: "inspect_selection",
  label: "Inspect Selection",
  category: "Network Check",
  description: "Prints diagnostic data for the currently selected entity. " \
               "Select a 'JPods Structure' group to print CP positions and tangent vectors. " \
               "Select a 'JPods Guideway' group to print first/last beam-path points, point count, and track index. " \
               "Output goes to the Ruby Console.",
  risk: :safe,
  requires_selection: nil,
  params: [],
  run: lambda { |model, p|
    ent = model.selection.first
    raise "Select a JPods Structure or JPods Guideway group first." unless ent.is_a?(Sketchup::Group)

    case ent.name
    when "JPods Structure"
      sid = ent.get_attribute("JPods", "structure_id", "?")
      raw = ent.get_attribute("JPods", "connection_points")
      raise "No connection_points attribute on #{sid}." unless raw
      t = ent.transformation
      JSON.parse(raw).each do |cp|
        c_local = StructurePlacer.point3d_from_any(cp["center"])
        v_local = StructurePlacer.vector3d_from_any(cp["tangent"])
        next unless c_local && v_local
        wc = t * c_local
        wv = t * v_local
        puts "#{sid}.CP#{cp['index']}  " \
             "center=#{wc.to_a.map { |v| v.to_m.round(3) }} m  " \
             "tangent=#{wv.to_a.map { |v| v.round(3) }}"
      end
      "#{sid} — CP data printed to Ruby Console."

    when "JPods Guideway"
      raw = ent.get_attribute("JPods", "beam_path")
      raise "No beam_path attribute on this guideway." unless raw
      pts = JSON.parse(raw).map { |a| Geom::Point3d.new(a[0].to_f, a[1].to_f, a[2].to_f) }
      cid = ent.get_attribute("JPods", "connection_id", "?")
      ti  = ent.get_attribute("JPods", "track_index", "?")
      puts "GW#{ent.entityID}  cid=#{cid}  track_idx=#{ti}  pts=#{pts.size}"
      puts "  first: #{pts.first.to_a.map { |v| v.to_m.round(3) }} m"
      puts "  last:  #{pts.last.to_a.map  { |v| v.to_m.round(3) }} m"
      "#{cid}|#{ti} — endpoint data printed to Ruby Console."

    else
      raise "Selected group '#{ent.name}' is not a JPods Structure or JPods Guideway."
    end
  }
},
```

---

### 4. Relocate: Move Show Routes and Clear Route Overlay from Builder to Noelle

Change `category:` on both:
- `id: "show_route_overlay"` → `category: "Noelle"`
- `id: "clear_route_overlay"` → `category: "Noelle"`

No other changes to those entries.

---

### 5. Relocate: Move Shuffle to Departure End from Vehicles to Developer

Change `category:` on:
- `id: "shuffle_to_departure"` → `category: "Developer"`

Update its description to make clear it is a manual recovery tool:

```
"Manual recovery: advances parked (idle_reserve) vehicles to the highest available platform slots. " \
"Run 5V handles this automatically every 3 seconds via Natalie. " \
"Use this command only when animation is stopped and the auto-shuffle did not fire."
```

---

### 6. Rename Validate Network + Show → Validate + Inspect

Change `label:` on `id: "validate_and_show"`:
```ruby
label: "Validate + Inspect",
```

Update `description:` to:
```
"Full diagnostic pass in one step: " \
"(1) Noelle integrity check on followme.json — stops on faults. " \
"(2) Natalie routing oversight pass. " \
"(3) FollowMe viewport overlay — draws travel paths, endpoint circles, dead-end whiskers. " \
"(4) Platform endpoint cones — red = inbound (hot), blue = outbound (cool). " \
"Press Esc or switch tools to dismiss the overlay."
```

---

## Expected Result After All Changes

The TASKS array should contain exactly 25 entries in this category order:

**Network (3):** Open Network Editor · List Active Constraints · Erase All Guideways

**Network Check (5):** List Platform Tagged Items · Mark Platform Endpoints · Clear Platform Markers · Inspect Model Geometry · Inspect Selection

**Builder (3):** Restore Dead-End Caps · Calculate CPs · Build Network

**Noelle (4):** Validate + Inspect · Show Routes Between Stations · Clear Route Overlay

**Vehicles (7):** List Vehicles & Platforms · Place 5V at Platform · Assign Directed Route to Nora · Show Trip Path · Clear All Vehicles · Run 5V · Station Platform Demo

**Animation (4):** Camera Follow Selected Nora · Stop Camera Follow · Export FollowMe Network JSON · Start Animation · Stop Animation

**Developer (3):** Shuffle to Departure End · Export Debug Bundle · Audit Network + Export Log

---

## Verification Steps

After making all changes:

1. Count the entries in TASKS — should be exactly 25.
2. Confirm no entry references `id: "show_followme_paths"`, `id: "export_trip_jsons"`, `id: "show_trip_detail"`, `id: "restore_dead_end_cap_at"`, `id: "inspect_structure"`, or `id: "inspect_guideway"`.
3. Confirm `id: "restore_dead_end_caps"` has two params: `structure_id` (string) and `cp_index` (integer).
4. Confirm `id: "inspect_selection"` has no params and auto-detects selection type.
5. Confirm `id: "show_route_overlay"` and `id: "clear_route_overlay"` have `category: "Noelle"`.
6. Confirm `id: "shuffle_to_departure"` has `category: "Developer"`.
7. Confirm `id: "validate_and_show"` has `label: "Validate + Inspect"`.
8. Do not modify `dialogs/console.html` — param rendering is already handled by `renderParams()` and requires no HTML changes for these task modifications.

---

## Do Not Change

- Any Ruby method outside `jpod_console.rb` (no changes to `jpod_animator.rb`, `jpod_vehicle_runtime.rb`, `jpod_followme_exporter.rb`, etc.)
- The `cmd_show_trip_json` callback in the `open_dialog` section of `jpod_console.rb` — the trip table JSON button is unchanged
- Any task entry not explicitly listed above
- `dialogs/console.html`

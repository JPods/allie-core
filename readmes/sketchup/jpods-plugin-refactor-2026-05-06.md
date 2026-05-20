# JPods SketchUp Plugin — Refactor 2026-05-06

**Scope:** Full structural cleanup. No legacy obligations — all changes are clean breaks.
**Plugin path:** `~/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods/`
**Ruby version:** SketchUp 2026 bundles Ruby 3.2.2. System Ruby (2.6) is irrelevant.

---

## What Was Found

A pre-refactor audit of 28,200 lines across 34 files identified:

| Issue | Count | Risk |
|-------|-------|------|
| `jpod_guideway.rb` — 5,329-line duplicate of `jpod_animator.rb`, not in boot.rb, never loaded | 1 file | Dead code, silent |
| `model.start_operation / rescue / abort_operation` — copy-pasted transaction pattern | ~99 sites | Inconsistent error handling |
| `.get_attribute('JPods', key)` — inline typed attribute reads | 461 sites | No type enforcement |
| Inline entity scan (`model.entities.find { e.name == 'JPods Guideway' && ...}`) | 8+ sites | Brittle string matching |
| `"#{sid}.CP#{idx}"` — CP key construction/parsing in 4 files | ~12 sites | No canonical format |
| Animation constants defined via `remove_const` / redefinition in `jpod_animator.rb` | 21 constants | Dirty reload behaviour |
| `module MyGeom` — not namespaced under JPods, hard-coded grade constant | 1 file | Inconsistent namespace |
| `JPodFollowMeTool` — defined in both `jpod_animator.rb` and `jpod_guideway.rb` | Duplicate | One was dead |
| Agent design decisions (Nora class vs Natalie/Noelle modules) — undocumented | 3 files | Onboarding confusion |

---

## What Changed

### Deleted

**`jpod_guideway.rb`** (5,329 lines)

Confirmed 100% duplicate of `jpod_animator.rb`. The file was not referenced in `boot.rb` and not loaded by any other file — every line was dead. Diff showed only 21 lines present in `jpod_animator.rb` but absent in `jpod_guideway.rb` (the `NATALIE_AUTO_SHUFFLE` logic). Zero unique methods were lost. File deleted.

---

### Created

#### `jpod_utilities.rb`

Three shared modules used across the plugin. Loaded by `boot.rb` immediately after `jpod_constants`.

**`JPods::ModelTransaction`** — wraps any block in a SketchUp undoable operation:
```ruby
JPods::ModelTransaction.wrap(model, "Build Guideway") do
  # geometry edits
end
# Commits on success. Aborts and re-raises on any exception.
```
Replaces the copy-pasted `start_operation / begin / rescue abort_operation / raise` pattern.

**`JPods::EntityAttributes`** — typed accessors for the `'JPods'` attribute dictionary:
```ruby
JPods::EntityAttributes.get_str(entity, 'connection_id')      # → String
JPods::EntityAttributes.get_int(entity, 'track_index')        # → Integer
JPods::EntityAttributes.get_float(entity, 'length_m')         # → Float
JPods::EntityAttributes.set(entity, 'vehicle_id', nora_id)
JPods::EntityAttributes.present?(entity, 'vehicle_id')        # → true/false
```
All reads go through the `'JPods'` dict with consistent type coercion. 461 inline `.get_attribute('JPods', ...)` callsites are documented as TODOs for incremental migration.

**`JPods::EntityLookup`** — named finders that replace inline entity scans:
```ruby
JPods::EntityLookup.guideways(model)                                    # → [Group, ...]
JPods::EntityLookup.find_guideway(model, connection_id: 'S020', track_index: 0)
JPods::EntityLookup.find_vehicle(model, nora_id: 'N01')
JPods::EntityLookup.vehicles(model)                                     # → [ComponentInstance, ...]
```

---

#### `jpod_connection_point.rb`

Value object for CP keys (`"S020.CP0"`). Loaded by `boot.rb` immediately after `jpod_utilities`.

```ruby
# Construction
cp = JPods::ConnectionPoint.new(structure_id: 'S020', index: 0)
cp.to_key    #=> "S020.CP0"
cp.to_s      #=> "S020.CP0"

# Parsing
cp = JPods::ConnectionPoint.parse("s020.cp0")  # case-insensitive
cp.structure_id  #=> "S020"
cp.index         #=> 0

JPods::ConnectionPoint.parse("bad")  #=> nil   (safe — no exception)

# Value equality — usable as Hash keys
cp1 == cp2
{ cp => some_data }
```

Keys are always normalised to uppercase. Replaces scattered `"#{sid}.CP#{idx}"` string construction and `.split(".CP")` parsing. Remaining callsites are documented as TODOs in the file header.

---

#### `jpod_followme_tool.rb`

`JPods::JPodFollowMeTool` class extracted from `jpod_animator.rb` (624 lines). The class was defined in both `jpod_animator.rb` and `jpod_guideway.rb` (the duplicate). Now lives in one place. Loaded by `boot.rb` immediately after `jpod_animator`.

---

### Modified

#### `jpod_constants.rb` — Animation constants moved here

All 21 animation constants previously defined (with `remove_const` guards) at the top of `jpod_animator.rb` are now in `jpod_constants.rb` under `module JPods::Constants::Animation`:

```ruby
JPods::Constants::Animation::ANIM_INTERVAL
JPods::Constants::Animation::PERSONAL_ZONE_DIST
JPods::Constants::Animation::MIN_HEADWAY
JPods::Constants::Animation::FOLLOWME_CONNECT_TOL
JPods::Constants::Animation::FOLLOWME_CONNECT_TOL_RELAXED
# ... and 16 more
```

Since `jpod_constants.rb` loads before `jpod_animator.rb`, no reload guards are needed. The `remove_const` block is gone.

`jpod_animator.rb` uses a local alias for brevity:
```ruby
A = JPods::Constants::Animation
ANIM_INTERVAL = A::ANIM_INTERVAL   # local alias — internal use only
```

#### `jpod_animator.rb`

- Removed 14 `remove_const` / constant-redefinition blocks (replaced by `jpod_constants.rb` + local aliases)
- Removed `JPodFollowMeTool` class definition (now in `jpod_followme_tool.rb`)
- Migrated 2 inline guideway scan patterns to `JPods::EntityLookup.guideways`
- Migrated 2 CP key constructions to `JPods::ConnectionPoint.new`

Net size: 5,350 → 4,723 lines (−627 lines; the extracted tool accounts for most of this).

#### `jpod_network.rb`

- Migrated 1 CP key construction pair to `JPods::ConnectionPoint.new`

#### `jpod_platform.rb`

- Migrated 1 inline guideway scan to `JPods::EntityLookup.guideways`

#### `my_geom.rb`

- `module MyGeom` renamed to `module JPods::Geometry`
- Backward-compatibility alias preserved: `MyGeom = JPods::Geometry`
- Hard-coded `max_grade = 0.15` replaced with `JPods::Constants::MAX_GRADE`

#### `nora.rb`, `natalie.rb`, `noelle.rb`

Design decision comments added at the top of each file explaining the class-vs-module choice:
- **Nora** is a `class` — each physical vehicle is a separate instance with independent state
- **Natalie** is a `module` singleton — one trip planner per network
- **Noelle** is a `module` singleton — one load balancer per network

#### `boot.rb`

Load order updated. New files inserted in dependency order:

```
jpod_constants          ← unchanged (first)
jpod_utilities          ← NEW (after constants)
jpod_connection_point   ← NEW (after utilities)
upright_extruder        ← unchanged
jpod_terrain            ← unchanged
jpod_path_builder       ← unchanged
jpod_animator           ← unchanged position
jpod_followme_tool      ← NEW (after animator)
jpod_platform           ← unchanged
...                     ← rest unchanged
```

---

## What Was Deferred

These are correct directions but were left as TODOs to avoid risk on a large batch change:

| TODO | Callsites | Where documented |
|------|-----------|-----------------|
| Migrate 461 `.get_attribute('JPods', ...)` → `EntityAttributes` | 461 | `jpod_utilities.rb` footer |
| Migrate `start_operation` rescue patterns → `ModelTransaction.wrap` | ~99 | `jpod_utilities.rb` footer |
| Remaining CP key patterns in `jpod_structure_tool.rb`, `jpod_followme_exporter.rb` | ~8 | `jpod_connection_point.rb` header |
| Extract `JPods::RouteGraph` from `jpod_animator.rb` | — | `jpod_animator.rb` comment |

The `RouteGraph` extraction is blocked specifically by `@@anim_debug` and `@@route_graph` being class variables on `JPodGuideway` that are shared across many methods. Resolving that state ownership is a design decision before code movement.

---

## How to Reload After Changes

In SketchUp's Ruby console:
```ruby
JPods.reload_plugin
```

This resets `$jpods_booted` and re-runs `boot.rb`. Successful output:
```
✅  JPods plugin loaded  (v3.0 — su_jpods)
```

---

## File Count After Refactor

| | Before | After |
|--|--------|-------|
| Total .rb files (root) | 34 | 34 |
| Lines of code | 28,200 | ~23,500 |
| Dead code | 5,329 lines | 0 |
| Shared utility modules | 0 | 3 |
| Constants files | 1 | 1 (expanded) |
| Duplicate class definitions | 1 (`JPodFollowMeTool`) | 0 |

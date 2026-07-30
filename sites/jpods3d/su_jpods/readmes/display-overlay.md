# JPods Display Overlay — Guideway Highlighting

**Added:** 2026-05-18

---

## The Principle

The simulation matches the physical inspection.

When you walk a physical JPods guideway to inspect it, you are inspecting the actual beam —
not a line drawn on a map beside it. The SketchUp display system follows the same rule:
the 3D guideway group itself is colored, not a separate overlay drawn on top of it.

This applies to three inspection modes:
- **FollowMe** — all guideways colored by direction
- **Trip path** — guideways a specific vehicle will travel
- **Route** — guideways between two stations

---

## How It Works

### Color Standard (never reversed)

| Color | Meaning | track_index |
|-------|---------|-------------|
| Red | Inbound — vehicle arriving | 0 |
| Blue | Outbound — vehicle departing | 1 |
| Gold | Trip path — this vehicle's assigned route | — |
| Green | Route between two stations | — |
| Orange | Build gap — segment declared but not yet built | — |

### Material Assignment

Each `JPods Guideway` group gets `group.material = material`. This works because
the Build pipeline assigns no face-level materials inside guideway groups — all
faces use default material, which inherits the group-level material.

A `highlighted_by` attribute is stamped on each highlighted group so the clear
operation only resets groups it actually set:

```ruby
e.set_attribute('JPods', 'highlighted_by', 'followme')  # or 'trip' or 'route'
```

Clearing is precise: only groups with the matching `highlighted_by` value are
reset to `nil`. Showing a route does not overwrite a FollowMe you left on.

### Gap Circles

When a segment in the trip or route has no matching `JPods Guideway` group in the
model, a filled orange horizontal circle is placed at the bounding box center of
the last good group. This is the exact location where the Build gap begins.

Gap circle radius: 0.75 m (~29.5 inches). Named group: `'JPods FollowMe Gaps'`,
`'JPods Trip Gaps'`, or `'JPods Route Gaps'` — one per display mode.

Label groups follow the same naming pattern: `'JPods FollowMe Names'`, `'JPods Trip Names'`,
`'JPods Route Names'`. Both the Gaps group and the Names group are created and erased together.

---

## Implementation (`jpod_animator.rb`)

### Helpers

```ruby
find_or_create_material(model, name, r, g, b)
# Gets or creates a named SketchUp material. Idempotent across reloads.

add_gap_circle(ents, center, mat)
# Draws a filled horizontal circle at center. Radius: GAP_CIRCLE_RADIUS_IN = 29.528 in (~0.75 m).

add_guideway_label(ents, text, center, height_in)
# Places a 3D text label in ents at center. No-op if text is empty or height_in < 0.1.

add_labels_for_mode(model, highlighted_groups, mode)
# Erases the current Names group for mode, then writes a new one with labels for each group.
# Group name: NAMES_FOR_MODE[mode] — e.g., 'JPods FollowMe Names'.

regenerate_labels(model)
# Scans all 'JPods Guideway' groups for highlighted_by attributes, rebuilds their Names groups
# at the current label_height_in. Called by set_label_size console task.
```

### Name Labels

Every display call generates 3D text labels over each highlighted guideway group.
Label text is the group's `display_name` attribute, falling back to `connection_id`.

Labels live in a separate named group per mode:

| Mode | Label group |
|------|-------------|
| followme | `JPods FollowMe Names` |
| trip | `JPods Trip Names` |
| route | `JPods Route Names` |

Label height is stored as a model attribute (`JPods → label_height_in`).
Default: `DEFAULT_LABEL_HEIGHT_IN = 39.3701` in (1 meter).

**Visibility control is font size.** At 1 m a label is readable from the standard
camera distance. At 0.1 m it becomes a dot — invisible without zooming in.
There is no checkbox; the inspector decides scale.

**Console task:** `set_label_size` — accepts `size_m` (0.1–10.0 m), converts to
inches, stores on model, and calls `regenerate_labels` to rebuild all active label groups immediately.

### FollowMe

```ruby
JPodGuideway.show_followme_json_overlay(model)
# → iterates all 'JPods Guideway' groups
# → sets material red (inbound) or blue (outbound) by track_index
# → places orange gap circles for connections in feature.json with length_mm: nil
# → stamps highlighted_by: 'followme' on each colored group

JPodGuideway.clear_followme_overlay(model)
# → resets material=nil on groups where highlighted_by=='followme'
# → erases 'JPods FollowMe Gaps' and 'JPods FollowMe Names' groups
```

### Trip Path

```ruby
JPodGuideway.show_trip_path_for_vehicle(model, nora_id)
# → loads vehicle's trip segment list from vehicle_trips attribute
# → builds gw_index: connection_id → group (one model scan)
# → sets material gold on matching groups
# → places orange gap circles for missing segments
# → stamps highlighted_by: 'trip'

JPodGuideway.clear_shown_trip_path(model)
# → resets material=nil on groups where highlighted_by=='trip'
# → erases 'JPods Trip Gaps' and 'JPods Trip Names' groups
```

### Route

```ruby
JPodGuideway.show_route_followme_overlay(model, origin_sid, dest_sid)
# → TripPlanner.lookup → ordered segment list
# → builds gw_index (one model scan)
# → sets material green on route segments
# → places orange gap circles for missing segments
# → stamps highlighted_by: 'route'

JPodGuideway.clear_route_overlay(model)
# → resets material=nil on groups where highlighted_by=='route'
# → erases 'JPods Route Gaps' and 'JPods Route Names' groups
```

---

## What a Gap Circle Means

An orange circle at a point on the network means:

> A segment exists in `followme.json` (the routing graph) but no `JPods Guideway`
> group with that `connection_id` has been built in the model.

**Root cause:** The Build pipeline writes guideway groups for inter-station connections.
Station-internal paths (`gw_platform_out`, `gw_stub_pair_N_out`, etc.) are generated as
structure track geometry but without a `connection_id` attribute — so `generate_map_json`
cannot include them, and there is no guideway group to highlight.

**Fix path:** Noelle writes `connection_id` on station-internal gw groups at Build time.
Until then, gaps at station entry/exit are expected and logged but not errors.

---

## Why Not a Separate Geometry Group

The earlier approach (`JPods FollowMe` group of polylines) had two problems:

1. **A line beside the beam is not the beam.** The thin polyline overlay visually
   separated the inspection view from the physical object being inspected.

2. **Polylines do not survive tool switches.** GL viewport overlay tools disappeared
   on Esc. Permanent polyline groups persisted but were disconnected from the 3D structure.

Coloring the guideway group directly means the inspection view and the 3D model are the
same object. The beam that is red is the beam Nora travels inbound. There is no translation
step between what you see and what is real.

This is the same principle as the physical guideway: the inspection is of the actual track.

---

## Console Tasks

| Task | Method |
|------|--------|
| Show FollowMe Overlay | `show_followme_json_overlay(model)` |
| Clear FollowMe Overlay | `clear_followme_overlay(model)` |
| Show Trip Path | `show_trip_path_for_vehicle(model, nora_id)` |
| Clear Trip Path | `clear_shown_trip_path(model)` |
| Show Route Between Stations | `show_route_followme_overlay(model, origin, dest)` |
| Clear Route Overlay | `clear_route_overlay(model)` |
| Set Label Size | `set_label_size` console task — size_m (0.1–10.0) |

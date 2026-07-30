# JPods Travel — Trips and Camera Behavior

## Trip Flow

The JPods Travel phone app (toolbar Travel button) lets users book a trip between
two stations and ride along with the pod.

### Booking
1. User selects origin and destination from station list
2. Stations with `has_platform=true` appear (set by Build)
3. Station names come from `network.json station_names` (case-insensitive lookup)
4. Price and travel time are estimated from the routing graph

### Dispatch
1. Travel calls `trip_book` → Natalie plans the route
2. A pod at the origin station is dispatched via Sally
3. Camera follows the pod from the user's current viewing angle

### During Travel
- Camera **translates** with the pod (follows its movement)
- Camera does **NOT lock** the viewing angle
- User can **orbit, rotate, and zoom freely** while the pod travels
- The camera maintains whatever angle the user sets, tracking the pod's position
- Trip progress bar shows estimated time remaining

### Arrival
- Camera follow releases automatically on arrival
- Pod parks at Sally-assigned slot
- Trip status poll stops

## Camera Behavior

### Follow Mode (during trip)
The camera applies the pod's movement delta as a **translation only**:
```
camera.eye    += pod_movement_vector
camera.target += pod_movement_vector
camera.up     = unchanged (preserves user's viewing angle)
```

This means:
- Pod moves north → camera moves north (same distance)
- User orbits to look from above → camera stays above, still tracking
- User zooms out → camera stays zoomed out, still tracking
- User rotates to look from the side → camera stays rotated, still tracking

### Previous Behavior (replaced)
The old camera applied a **rigid delta transform** to eye, target, AND up vector.
This locked the camera angle to the pod's orientation — any user rotation was
overwritten on the next frame. The user could not orbit or adjust the view.

### Camera Offsets
Default offsets (configurable via console):
- Back: 25m behind travel direction
- Right: 20m right of travel direction
- Up: 5m above pod

These are initial positioning only — once the user orbits, their angle is preserved.

### Starting a Trip
1. Click Travel in toolbar
2. Select origin and destination
3. Set your camera angle BEFORE clicking "Book"
4. Or adjust the angle at any time DURING travel

### Stopping Camera Follow
- Camera follow releases automatically on arrival
- Animation stop (toolbar or Extensions > JPods > Animation > Stop) releases camera
- Camera Follow toolbar button toggles follow on/off

## Trip Status Polling

The Travel app polls trip status every 1 second during travel.
- `waiting` → pod dispatched, not yet moving
- `in_transit` → pod traveling, progress bar updates
- `arrived` → pod parked, poll stops, arrival screen shows
- `unknown` / `not found` → poll stops immediately (prevents timer queue flooding)

### Timer Queue
SketchUp's Ruby timer queue is shared by all timer callbacks (animation tick,
camera follow, UI updates, stop button). A runaway polling loop that never
stops will flood the queue, making stop buttons and camera controls sluggish.
The `not found` guard prevents this.

## Station Names

Station names for the Travel picker come from `network.json station_names`.
The lookup is case-insensitive — station IDs from entities are lowercase (`s001`),
names in network.json may be uppercase (`S001`). Both are checked.

Names are set via:
- Network Display station names panel
- `trip_rename_station` callback from the Travel app
- Direct edit of network.json `station_names` section

# Route-Time — JPods Network Planner and Simulator
**Action:** Read at the start of any Route-Time planning or development session
**Function:** Browser-based simulation and network design tool for JPods
**Location:** `/Users/williamjames/Documents/08_JPods/03_Technology/route_time/`

---

## What It Is

Route-Time is the middle layer in the three-program JPods ecosystem:

| Program | Role |
|---------|------|
| **SketchUp plugin** | 3D design — places structures, assigns CPs |
| **Route-Time** | 2D planning — simulates transit times, designs networks |
| **JPodsSM_RPi** | Runtime — Nora/Natalie/Noelle control on the Pi |

Reads `.jpd` and `map.json` files. Runs a discrete-tick physics simulation and outputs
fleet-median transit times, congestion data, and door-to-door travel times.

---

## Running

**Always start from the parent directory:**
```bash
cd /Users/williamjames/Documents/08_JPods/03_Technology
python3 -m route_time.gui        # browser GUI at http://localhost:5050
```

If started from the wrong directory, Python's module resolution fails with
`ModuleNotFoundError: No module named 'route_time.engine'`.

Existing network archives: `/Applications/RouteTime_JPods/RouteTimeMaps.zip`
Java reference source: `/Applications/RouteTime_JPods/route-time_sourceCode_2025-03-14/`

---

## Color Standard — Red Inbound, Blue Outbound

**All directional indicators follow this rule system-wide:**

| Color | Meaning |
|-------|---------|
| 🔴 **Red** | Inbound — hot end — vehicle or flow arriving |
| 🔵 **Blue** | Outbound — cool end — vehicle or flow departing |

Applied to:
- Guideway polylines on the map
- CP stub-pair dots (blue = outbound stub, red = inbound stub)
- Station siding (south approach = red, north exit = blue)
- Loading animation pods: solid blue (in-flight indicator)

This standard extends to all JPods tools including SketchUp plugin.

---

## Connection Points (CPs)

Every structure exposes **stub-pairs** — the universal interface shared with the SketchUp plugin.

- Each CP = one outbound stub + one inbound stub at the same arm tip
- CPs connect to CPs — never individual lines
- Breaking a connection always removes **both** guideways of the pair
- No confirmation dialogs — user is responsible for selection

**CP marker appearance:**

| State | Visual |
|-------|--------|
| Traffic circle CP | Oval/pill, blue + red dots |
| Station CP | Rectangle, blue + red dots |
| Open | Purple border |
| Connected | Green border |
| Selected (first click) | Gold target circle |
| Hover | Gold target circle (disappears on mouseout) |

**Interaction (edit mode only — CPs non-interactive when locked):**
- Click CP → select parent structure (gold ring)
- Click CP on second structure → connect **closest open CPs** between the two structures (two guideways drawn)
- Shift-click connected CP → disconnect
- Esc → cancel selection

**Keyboard shortcuts for placement:**

| Key | Tool |
|-----|------|
| 1 | Station N–S |
| 2 | Station E–W |
| 3 | Station NW–SE |
| 4 | Station NE–SW |
| 5 | Circle |
| 6 | Circle 45° |

Press key, click map to place. Esc to cancel. Disabled when typing in input fields.

---

## City Search

Input field at top of map. Type city + state (US) or city + country (international).
Uses OpenStreetMap Nominatim geocoder — no API key required.

- **Center**: map flies to and fits the city bounding box
- **Fence**: amber dashed boundary polygon drawn around city administrative boundary
- **✕ button**: clears the fence; city field also accepts Enter key
- Non-US cities: include country name to disambiguate (e.g. "Nairobi, Kenya")

---

## Structure Naming

Stations and traffic circles are assigned sequential human-readable IDs:

| Type | Format | Example |
|------|--------|---------|
| Station | `s#` | `s1`, `s2`, `s32` |
| Traffic circle | `c#` | `c1`, `c2`, `c36` |

Numbering starts at 1 and is unique per network. Internal nodes are named `{sid}.PLATFORM`, `{sid}.NB_N`, etc.  Old hex-style IDs (`ST_XXXXXX`, `TC_XXXXXX`) in legacy `.jpd` files are still loaded and reconstructed correctly.

When hovering over a station or circle in **Locked** mode, the tooltip shows the structure ID (`s3`, `c7`, etc.) and its center latitude/longitude — e.g., `s3 · 37.31234, -121.87345`. Not the internal CP node IDs.

---

## Grid Generator

Toolbar button: `⊹ Grid…` — opens a modal dialog.

Generates a rectangular mesh of traffic circles at intersections with one station
mid-block on every segment (N-S and E-W). This is a **wildly rough estimate** tool
for quick capacity exploration — not a designed network.

**Parameters:**
| Field | Meaning |
|-------|---------|
| Block spacing N-S | Miles between circle rows |
| Block spacing E-W | Miles between circle columns |
| Extent N-S | Total north-south distance (miles) |
| Extent E-W | Total east-west distance (miles) |

**Topology built:**
- Circles at every intersection
- N-S stations (heading=0°) mid-block between row pairs; connected circle south arm ↔ station `CP_near_far`, station `CP_far_near` ↔ next circle north arm
- E-W stations (heading=90°) mid-block between column pairs; connected similarly
- `Replace existing network` checkbox clears everything before generating

**Live preview** in dialog: counts circles, stations, guideways. Warns if >600 structures.

**After generation:** network is automatically unlocked for editing.

---

## Waypoints

Shift-click any guideway line → draggable gold waypoint marker appears.
Drag to route guideway pair around terrain features (roads, buildings).
Shift-click the waypoint handle to remove it.
Ctrl-click a guideway line to remove the entire pair.

---

## Structures

### Traffic Circle (US/CCW)
- 15 m diameter ring; 4 arms (N/E/S/W); counter-clockwise travel
- Diverge before merge at each arm
- Stubs extend 15 m beyond ring edge (22.5 m from center)
- 4 CPs (one per arm); arm headings rotatable

### Station (US/CCW, right-side loading)
- ~70 m between the two U-turns; ~7 m wide
- **near** side = side of the station where the platform is located
- **far** side = opposite side, no platform
- `platform_parking` node is the station identity (node_id ends in `.platform_parking`)
- `uturn_near_far`: near-side → far-side (at the `platform_out` / `guideway_near_out` end)
- `uturn_far_near`: far-side → near-side (at the `platform_in` / `guideway_near_in` end)
- 2 CPs: `CP_near_far` (stub-pair at the uturn_near_far end) and `CP_far_near` (stub-pair at the uturn_far_near end)
- Heading configurable (default 0°)

**Station fishbone diagram** — vehicles flow left to right on guideway_near, right to left on guideway_far:

```
CP_far_near                                               CP_near_far
  ↓  ↑                                                     ↓  ↑
  ↓  guideway_far_out ←←←← guideway_far_main ←←←← guideway_far_in  ↑
  ↓         ↑ uturn_far_near                  uturn_near_far ↓       ↑
  ↓  guideway_near_in →→→→ guideway_near_main →→→→ guideway_near_out ↑
        ↘  platform_in                    platform_out  ↗
              ↘                                  ↗
          platform_parking_a → [platform_parking] → platform_parking_b
```

`platform_parking` is a single node. `platform_parking_a` and `platform_parking_b` are the line segments connecting into and out of it. The physical system supports multiple parking spots per platform; Route-Time does not model individual spots.

**Line vocabulary (13 lines per station):**

| Line | Direction | Role |
|------|-----------|------|
| `guideway_near_in` | → | vehicles entering guideway_near from CP_far_near |
| `guideway_near_main` | → | through-travel on near side |
| `guideway_near_out` | → | vehicles exiting guideway_near to CP_near_far |
| `guideway_far_in` | ← | vehicles entering guideway_far from CP_near_far |
| `guideway_far_main` | ← | through-travel on far side |
| `guideway_far_out` | ← | vehicles exiting guideway_far to CP_far_near |
| `platform_in` | siding | guideway_near_in_end → platform siding entry |
| `platform_parking_a` | siding | platform_in_end → platform_parking node |
| `platform_parking_b` | siding | platform_parking node → platform_out_end |
| `platform_out` | siding | platform_out_end → guideway_near_out_end |
| `uturn_near_far_a` | arc | guideway_near_out_end → midpoint |
| `uturn_near_far_b` | arc | midpoint → guideway_far_in_end |
| `uturn_far_near_a` | arc | guideway_far_out_end → midpoint |
| `uturn_far_near_b` | arc | midpoint → guideway_near_in_end |

Vehicles only slow for siding entry/exit — through-traffic on guideway_near and guideway_far is unaffected by station stops.

**Departure paths (two exits from platform_parking):**

| Destination direction | Path |
|-----------------------|------|
| Near (aligned with station flow) | `platform_out → guideway_near_main → guideway_near_out → CP_near_far` |
| Far (opposite station flow) | `platform_out → guideway_near_main → uturn_near_far → guideway_far_main → guideway_far_out → CP_far_near` |

**Arrival paths (two entries to platform_parking):**

| From | Path |
|------|------|
| CP_far_near (near direction) | `guideway_near_in → guideway_near_in_end → platform_in → platform_parking` |
| CP_near_far (far direction) | `guideway_far_in → guideway_far_main → guideway_far_out_end → uturn_far_near → guideway_near_in_end → platform_in → platform_parking` |

**Rule:** `uturn_far_near` is arrival-only. `uturn_near_far` is departure-only (for far-direction trips). No vehicle path traverses both uturns in sequence — a pod exiting via `uturn_near_far → guideway_far → guideway_far_out` exits the station at CP_far_near and does not return through `uturn_far_near`.

**Through-routing paths (vehicle not stopping at this station):**

The near guideway is continuous through every station. Vehicles that are stopping peel off to the siding; vehicles passing through continue on `guideway_near_main` or `guideway_far_main` without touching either uturn.

| Vehicle intent | Path | Uturns used |
|----------------|------|-------------|
| Through — near direction | `guideway_near_in → guideway_near_main → guideway_near_out` | none |
| Through — far direction | `guideway_far_in → guideway_far_main → guideway_far_out` | none |
| Stopping — arriving from near (via CP_far_near) | `guideway_near_in_end → platform_in → platform_parking` | none |
| Stopping — arriving from far (via CP_near_far) | `guideway_far_main → uturn_far_near → guideway_near_in_end → platform_in → platform_parking` | uturn_far_near |

In the animation, pod color distinguishes through-traffic from stopping traffic:
- **Orange** — pod is on a siding line (entering or leaving the platform); it is stopping here
- **Yellow** — pod is on approach to its destination station
- **Red→Green** — pod is on a through-guideway; it is passing through

---

## Structure Move

**Single structure:** Alt+drag on any CP dot or internal structure line. Cursor changes to ⊕ when Alt is held. Release to commit; server updates all node positions.

**Selection drag (multiple structures):**
1. Shift+drag from outside the group (rubber-band box, yellow dashed) to select
2. Status bar shows `N item(s) selected — Delete to remove · Esc to cancel`
3. Hover over any CP dot or internal line of a selected structure
4. Plain drag (no Alt, no Shift) — all selected structures move as a group
5. Release to commit; all structures updated in parallel

Network must be **unlocked** (🔓 Edit) to move structures.

---

## Known Issue — Island Isolation

**Symptom:** Isochrone shows grey dots (no ride data) for some stations even after simulation.

**Common cause:** Open CPs — structures not connected to the main network graph. Any structure with unconnected CPs cannot be reached by routing. Orphaned structures pulse in the editor view.

**To diagnose:** After generating a grid, check for pulsing CP markers (orphans). Manually connect open CPs before simulating.

**Simulation behavior:** When `find_path()` returns no route for an O-D pair, the passenger is silently dropped. The pair will not appear in `trip_stats`. The isochrone analytical fallback (`/api/network/travel_times`) also returns no entry for unreachable stations.

**Fix:** Connect all open CPs before running. Use AutoConnect as a starting point, then manually complete any remaining open CPs.

---

## Demand Model

**Gravity model (recommended):**
```json
{
  "pax_per_hour": 360,
  "stations": {
    "ST_airport.PLATFORM":   { "departures": 800, "arrivals": 1200 },
    "ST_downtown.PLATFORM":  { "departures": 600, "arrivals": 400  }
  }
}
```

- `flow(O→D) ∝ departures[O] × arrivals[D]`
- Arrivals = attraction weight, not a hard constraint
- `pax_per_hour` = global default for unlisted stations (default 360)
- Any positive rate — no 360/hr cap

**Explicit O-D (advanced):**
```json
{
  "stations": {
    "ST_xxx.PLATFORM": { "destinations": { "ST_yyy.PLATFORM": 200 } }
  }
}
```

Saved by the Demand panel to `demand.json` alongside `settings.json`.

---

## Simulation Engine

**Three-phase run (guarantees full O-D coverage):**

| Phase | What happens |
|-------|-------------|
| **Sweep 1** | One vehicle dispatched from every station to every other station. Runs until all trips complete. Establishes a baseline travel time for every reachable O-D pair. |
| **Sweep 2 + Random demand** | A second full O-D sweep is queued simultaneously with normal gravity-model passengers. Simulation stops when the last Sweep 2 vehicle arrives. Sweep 2 times reflect real congestion from the mixed load. |

The simulation auto-locks the network on completion (Edit → Locked). Press `▶▶ Replay` to view the animation; it does not auto-start.

**Result:** every reachable O-D pair has ≥ 2 completed trips; `trip_stats` is complete for isochrone use.

**Discrete-tick model:**
- 360 slots × 90 ticks/slot = 32,400 ticks per simulated hour
- Tick resolution: `1 / timeResolutionPerSec` seconds (default 9 ticks/sec → 0.111 s/tick)
- Passengers generated every 90 ticks (one slot = 10 simulated seconds)

**Physics:**
- Cruise speed: `maxVelocityInKMPH / 3.6` m/s × `tick_s` m/tick
- Jam threshold: `min_spacing_m = velocity_ms × minHeadwaySec + podLen`
  - At 60 km/h, 0.25 s headway, 3 m pod: threshold = 7.17 m
  - Jammed lines → infinite routing weight → pods route around congestion

**Pod fleet:**
- `podsPerStation` pods (default 4) pre-created in a global depot at simulation start
- Vehicles only originate at stations — never at traffic circles
- Surplus pods (station has more than `podsPerStation` queued with no waiting passengers) return to the global depot for redistribution
- **Physical networks** will have many pod depots scattered around the network. The current simulation uses a single global depot as a simplification. Future work: assign depot locations as structures on the network map and restrict pod draw to the nearest depot.

**Routing:**
- Dijkstra from origin `.PLATFORM` node to destination `.PLATFORM` node
- Pods follow: PLATFORM → SIDE_exit → NB mainline → connector → SIDE_entry → PLATFORM
- Grace distance biases shorter hops (robot precision: 0.5, 1, 2, 3, 4 m)

**Output — SimResult:**
- `summary`: throughput/hr, avg/longest trip time, avg velocity, network stats
- `trip_stats`: per O-D pair — median/mean/p90 trip_ms, sample_count, route_line_ids for animation
- `line_stats`: per line — pods transited, avg transit time, congestion ratio
- `station_stats`: per station — passengers boarded/alighted/waiting

---

## Settings (settings.json)

```json
{
  "accInG": 1.0,
  "deccInG": 1.0,
  "maxVelocityInKMPH": 60,
  "podLen": 3,
  "minHeadwaySec": 0.25,
  "podsPerStation": 4,
  "graceDistance": 1,
  "disembarkingTimeInSec": 20,
  "embarkingTimeInSec": 20,
  "ticketingTimeInSec": 30,
  "stationEntryTimeInSec": 40,
  "stationExitTimeInSec": 40,
  "walkingSpeedKmh": 4.8,
  "walkToStationSec": 300,
  "walkFromStationSec": 300,
  "timeResolutionPerSec": 9,
  "simSpeedMultiplier": 360
}
```

---

## Isochrone (Walk-Ride-Walk Coverage)

**Toolbar button:** `⊙ Isochrone` (in Simulate section of palette)

Click any map point → colored overlay polygons showing total journey reachability within each time budget.

**Colors (match Java TimeColor):**

| Color | Budget |
|-------|--------|
| Green | 5 min total |
| Blue | 10 min total |
| Yellow | 20 min total |
| Red | 30 min total |

**Algorithm (matches Java `TimeGraph.java`):**
1. Find closest station to clicked point = boarding station
2. Fetch analytical Dijkstra travel times from server for the boarding station
3. For each destination station and each budget:
   - `fixed = walk_to_boarding + ride_time(boarding → dest)`
   - `remaining = budget − fixed`
   - `radius = remaining × walk_speed_m/min`
4. Also draw pure-walk circle at clicked point for each budget
5. All circles of same color → `turf.union()` → single merged polygon rendered as `L.geoJSON()`
   - Only outer boundary visible; no interior circle lines

**Ride time sources (in priority order):**
1. **Simulation median** — from `trip_stats` after running simulation; includes station overhead and real congestion. Tooltip: `X.X min ride (sim)`
2. **Analytical estimate** — Dijkstra over network graph weighted by line length ÷ cruise speed; fetched from `GET /api/network/travel_times`. Tooltip: `~X.X min ride (est)`

**Station dots:** A colored dot at each station shows ride time and total journey time on hover. Color matches the isochrone budget (green/blue/yellow/red/grey). Grey = beyond 30-min budget or no route data.

**Does not require simulation** — analytical estimates provide full coverage immediately. Run simulation for congestion-accurate times.

**Settings:** Transparency adjustable in Settings → Isochrone → Opacity (default 0.15).

**Exit:** `⊙ Isochrone` button again, or press Esc.

---

## Animation

**Loading animation (during simulation POST):**
- Blue pods on all guideways immediately — no race condition
- Network GeoJSON fetched before simulation starts; reused for frame building
- Pods advance without stagger → bunch at merge nodes = visible congestion forecast

**Results replay:**
- White = parked at platform (15% of cycle at each end)
- Red → green = velocity bell curve during travel (70% of cycle)
- Speed set by `simSpeedMultiplier` (360× default = 10-second loop = 1 simulated hour)

**Large-network rendering limits:**

| Constant | Value | Location | Behavior |
|----------|-------|----------|---------|
| `MAX_ANIM_ROUTES` | 400 | `simulator.js` | Animation replay sub-samples to this many routes via uniform stride — keeps frame-build under ~1 s for any network size |
| `MAX_GRID_STATIONS` | 50 | `simulator.js` | Route grid (station×station travel-time table) is hidden above this count — an N²-cell DOM table locks the browser thread for large networks |

For networks above 50 stations the Results panel shows a notice: *"N stations — grid hidden above 50. Use the Isochrone tab to explore travel times."* The Isochrone tool works at any network size.

To change the caps: edit the two constants near the top of `simulator.js`.

---

## Route Grid

The Results panel (after simulation) includes a **station×station travel-time matrix** showing the median ride time (minutes) for every reachable O-D pair.

**Reading the grid:**
- Rows = origin station, columns = destination station
- Cell value = median ride time in minutes (from `trip_stats`)
- Diagonal = grey (no self-trip)
- Unreachable pairs = grey (no route found by Dijkstra)

**Scale:** Hidden automatically when the network has more than 50 stations — a 50×50 table = 2,500 cells is manageable; a 138×138 table = 19,044 cells locks the browser thread. The threshold is `MAX_GRID_STATIONS = 50` in `simulator.js`.

For large networks, use the **Isochrone** tool instead — click any station to see walk-ride-walk reachability at all scales with no table-size limit.

---

## Routing Intelligence Stack — Route-Time's Role

Route-Time is where the three-layer routing intelligence is most fully visible, because the simulation runs at network scale over time.

**The three layers in Route-Time:**

| Layer | Route-Time implementation | Current state |
|-------|--------------------------|---------------|
| **Topology** | Dijkstra over the network graph | Active — `engine/routing.py` |
| **Noelle's load map** | Congestion ratio weights segments by predicted future occupancy | Partial — static ratio today; time-projected not yet implemented |
| **Alice's rate signals** | Price factor (1–5) weights segments by economics | Stub — `price_factor` field exists in settings; not yet wired to Alice's `price_query` API |

**Why Dijkstra (not BFS) in Route-Time:** Route-Time asks "what is the optimal path?" under congestion across a large network. BFS answers "does a path exist?" — correct for SketchUp's small design-validation graphs. Dijkstra weights edges by segment cost (time + congestion + price). On a network with 50+ stations and real pricing, the optimal path is rarely the shortest one.

**The price-routing connection:** When Alice raises rates on a congested segment, Route-Time's Dijkstra will route around it — not because of physical congestion, but because the economic cost exceeds the time savings. This is the correct behavior: passengers who can take a slightly longer route pay less and reduce load on the premium segment. Price is a congestion signal expressed in dollars.

**Segment throughput weighting (open):** Segments with tight approach curves carry a structural throughput penalty independent of congestion. A `curve_penalty` term in `engine/network.py` Dijkstra weights is not yet implemented. Natalie's open question on approach-curve-limited speed (in `natalie.md`) and Route-Time's Dijkstra weights are the same problem in two domains.

**What Route-Time validates that SketchUp cannot:** At network scale, the interaction between Noelle's load balancing and Alice's pricing becomes visible — a price signal that works at 4 stations may create perverse routing incentives at 40 stations. Route-Time is where those emergent behaviors surface before any physical network is built.

---

## Physical Feedback Loop (Allie's role)

**The design intent:**

1. **Simulate** — Route-Time predicts transit times for a network
2. **Run** — Physical JPods robots (Nora/Natalie/Noelle) execute trips on the same network
3. **Observe** — Allie records actual transit times from the robots via MQTT/wcapi
4. **Compare** — Actual vs predicted; discrepancies surface design improvements
5. **Calibrate** — Simulation parameters adjusted to match physical reality

**Allie's specific tasks when robots run:**
- Monitor MQTT telemetry from Nora (vehicle state) and Natalie (routing decisions)
- Record trip start/end times, actual vs predicted for each O-D pair
- Flag lines where actual transit time deviates >20% from Route-Time prediction
- Log to wcapi notes for session retrospection

Route-Time predicts. Robots run. Allie records. Discrepancies teach.

---

## Map Persistence

Map zoom and position saved to browser `localStorage`. Never resets during editing —
only auto-fits on explicit file open.

---

## Network Clipboard

**Toolbar button:** `📋 Clipboard…` (in File section of palette)

Opens a dialog with:
- A textarea auto-populated with the full `.jpd` XML of the current network
- **Copy** button — writes the text to the system clipboard
- **Load** button — reads whatever is in the textarea and loads it as a new network

**Use cases:**
- Copy a network designed for one city, navigate to a different city, paste and load to transfer the layout with all lat/lon positions intact
- Share a network by pasting the text into email, Slack, or a document — recipient pastes it back and clicks Load
- Duplicate a network without using the file system

All station and circle positions include latitude and longitude in the `.jpd` XML. No server changes required — uses existing `/api/network/download` and `/api/network/load_text` endpoints.

---

## File Structure

```
route_time/
  engine/
    network.py      — Network, Node, Line, Station; configure_jam_threshold()
    physics.py      — PhysicsModel; transit_time_ms()
    routing.py      — Dijkstra find_path()
    demand.py       — LoadArray; gravity model; explicit O-D
    simulation.py   — Simulator; SimResult; TripRecord
    structures.py   — ConnectionPoint, Structure, build_traffic_circle(), build_station()
  io/
    jpd_reader.py   — load .jpd XML
    jpd_writer.py   — save .jpd XML
    map_reader.py   — load mapSM.json / SketchUp map.json
    results_writer.py — write route_time_results.json
  gui/
    app.py          — Flask entry point
    api.py          — REST endpoints; _state; _network_to_geojson()
    static/
      index.html    — sidebar layout; settings panel; demand panel
      app.js        — map init, render, CP logic, waypoints
      editor.js     — place/connect/break tools
      demand.js     — per-station dep/arr table; gravity config
      settings.js   — settings panel load/save
      simulator.js  — run simulation; loading anim; results; replay
      overlays.js   — AADT, accidents, mobility
      timemap.js    — walk-ride-walk coverage circles (Turf.js union)
      ai.js         — Allie recommendations panel
      style.css
  settings.json     — simulation settings (persisted)
  demand.json       — demand config (persisted by Demand panel)
```

---

## API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/network` | GeoJSON of current network |
| POST | `/api/network/new` | New empty network |
| POST | `/api/network/load` | Load file by server path |
| POST | `/api/network/load_text` | Load file content from browser (or pasted text) |
| GET | `/api/network/download` | Download current network as .jpd bytes (used by Clipboard and Save) |
| POST | `/api/network/save` | Save as .jpd to server-side path |
| POST | `/api/network/node` | Add switch node |
| POST | `/api/network/station` | Add full station structure |
| POST | `/api/network/circle` | Add traffic circle structure |
| DELETE | `/api/network/node/<id>` | Remove node |
| DELETE | `/api/network/structure/<id>` | Remove structure + all nodes/lines |
| POST | `/api/network/connect_cps` | Connect two stub-pairs |
| POST | `/api/network/disconnect_cp` | Disconnect a stub-pair |
| POST | `/api/network/autoconnect` | Best-effort nearest-neighbor auto-connect |
| DELETE | `/api/network/line/<id>` | Remove guideway pair |
| POST | `/api/network/line/<id>/waypoint` | Add waypoint |
| PUT | `/api/network/line/<id>/waypoint/<idx>` | Move waypoint |
| DELETE | `/api/network/line/<id>/waypoint/<idx>` | Remove waypoint |
| POST | `/api/network/structure/<id>/rotate` | Rotate structure in place |
| POST | `/api/network/structure/<id>/move` | Translate structure by dlat/dlon |
| POST | `/api/network/grid` | Generate grid mesh (circles + stations) |
| GET | `/api/network/travel_times` | Dijkstra travel times from origin station to all reachable stations (`?origin=s1.PLATFORM`) |
| POST | `/api/simulation/run` | Run simulation; returns SimResult |
| GET/POST | `/api/settings` | Simulation settings |
| GET/POST | `/api/demand` | Demand config |
| GET | `/api/overlays/aadt` | AADT traffic overlay |
| GET | `/api/overlays/accidents` | Accident data overlay |
| GET | `/api/overlays/mobility` | Cell mobility overlay |
| POST | `/api/ai/recommend` | Allie network recommendation (stub) |

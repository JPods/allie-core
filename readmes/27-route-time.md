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
- Click CP → select (gold ring)
- Click second CP → connect (two guideways drawn)
- Shift-click connected CP → disconnect
- Esc → cancel selection

---

## City Search

Input field at top of map. Type city + state (US) or city + country (international).
Uses OpenStreetMap Nominatim geocoder — no API key required.

- **Center**: map flies to and fits the city bounding box
- **Fence**: amber dashed boundary polygon drawn around city administrative boundary
- **✕ button**: clears the fence; city field also accepts Enter key
- Non-US cities: include country name to disambiguate (e.g. "Nairobi, Kenya")

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
- N-S stations (heading=0°) mid-block between row pairs; connected circle south arm ↔ station CP_N, station CP_S ↔ next circle north arm
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
- ~70 m between north and south turnabouts; ~7 m wide
- NB guideway east, SB guideway west
- Siding east of NB — always traversed northward
- PLATFORM node is the station identity (node_id ends in `.PLATFORM`)
- North turnabout: NB → SB; South turnabout: SB → NB
- 2 CPs: CP_N (north stub-pair) and CP_S (south stub-pair)
- Heading configurable (default 0° = north-south)

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

## Known Issue — Island Isolation in Travel Time

**Symptom:** Travel time results show anomalous values (very long, zero, or missing) between
some station pairs. Structures that are not connected to the main network graph form
isolated islands — Dijkstra routing finds no path between them and the unconnected stations.

**Common cause:** Grid generator or AutoConnect leaves some CP pairs open. Any structure
with no connected CPs (orphan) is an island. Orphans pulse in the editor view.

**To diagnose:** After generating a grid or running AutoConnect, check for orphaned
structures (pulsing CP markers) and manually connect open CPs before simulating.

**Next step (pending):** Investigate simulation engine handling of unreachable O-D pairs —
ensure missing paths produce a graceful skip rather than polluting aggregate stats.

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

**Discrete-tick model:**
- 360 slots × 10 ticks/slot = 3,600 ticks per simulated hour
- Tick resolution: `1 / timeResolutionPerSec` seconds (default 9 ticks/sec → 0.111 s/tick)
- Passengers generated every 10 ticks (one slot)

**Physics:**
- Cruise speed: `maxVelocityInKMPH / 3.6` m/s × `tick_s` m/tick
- Jam threshold: `min_spacing_m = velocity_ms × minHeadwaySec + podLen`
  - At 60 km/h, 0.25 s headway, 3 m pod: threshold = 7.17 m
  - Jammed lines → infinite routing weight → pods route around congestion

**Routing:**
- Dijkstra from origin `.PLATFORM` node to destination `.PLATFORM` node
- Pods follow: PLATFORM → SIDE_exit → NB mainline → connector → SIDE_entry → PLATFORM
- Grace distance biases shorter hops (robot precision: 0.5, 1, 2, 3, 4 m)

**Output — SimResult:**
- `summary`: throughput/hr, avg/longest trip time, avg velocity, network stats
- `trip_stats`: per O-D pair — median/mean/p90 trip_ms, route_line_ids for animation
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

## Walk-Ride-Walk Coverage Circles

**Toolbar button:** `⊙ Coverage` (in Simulate section of palette)

Click any map point → colored overlay circles showing total journey reachability.

**Colors (match Java TimeColor):**

| Color | Budget |
|-------|--------|
| Green | 5 min total |
| Blue | 10 min total |
| Yellow | 20 min total |
| Red | 30 min total |

**Algorithm (matches Java `TimeGraph.java`):**
1. Find closest station to clicked point = boarding station
2. For each destination station and each budget:
   - `fixed = walk_to_boarding + ride_time(boarding → dest)`
   - `remaining = budget − fixed`
   - `radius = remaining × walk_speed_m/min`
3. Also draw pure-walk circle at clicked point for each budget
4. All circles of same color → `turf.union()` → single merged polygon rendered as `L.geoJSON()`
   - Only outer boundary visible; no interior circle lines

**Requires:** Simulation must be run first for ride-time circles to appear.
Walk-only circles (from clicked point) always show.

**Settings:** Transparency adjustable in Settings → Coverage circles → Opacity (default 0.15).

**Exit:** `⊙ Coverage` button again, or press Esc.

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
| POST | `/api/network/load_text` | Load file content from browser |
| POST | `/api/network/save` | Save as .jpd |
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
| POST | `/api/simulation/run` | Run simulation; returns SimResult |
| GET/POST | `/api/settings` | Simulation settings |
| GET/POST | `/api/demand` | Demand config |
| GET | `/api/overlays/aadt` | AADT traffic overlay |
| GET | `/api/overlays/accidents` | Accident data overlay |
| GET | `/api/overlays/mobility` | Cell mobility overlay |
| POST | `/api/ai/recommend` | Allie network recommendation (stub) |

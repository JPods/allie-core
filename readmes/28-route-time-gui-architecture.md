# Route-Time GUI — Architecture and Lessons Learned
**Action:** Read when working on the Route-Time browser GUI, or when similar state-persistence problems arise in other programs
**Date documented:** 2026-04-26

---

## What This Document Is

A deep-dive into how the Route-Time GUI works internally, the hard bugs we solved, and the patterns that apply to other programs. Written so future sessions can pick up without re-deriving everything from scratch.

---

## System Map

```
Browser (Leaflet + vanilla JS)
    ↕  fetch / REST
Flask server (Python, port 5050)
    ↕  in-memory _state dict
Engine (network.py, structures.py, simulation.py, demand.py)
    ↕  load / save
.jpd files (XML)
```

**Key principle:** The server holds all authoritative state. The browser is a rendering and interaction layer only. Every edit (place station, connect CPs, add waypoint) makes a REST call; the server updates `_state` and returns fresh GeoJSON; the browser re-renders from scratch.

---

## The _state Dict — What Lives Where

```python
_state = {
    "network":      Network,        # nodes + lines
    "structures":   {},             # structure_id → Structure
    "cps":          {},             # cp_id → ConnectionPoint
    "waypoints":    {},             # waypoint data
    "line_pairs":   {},             # paired guideway tracking
    "line_roles":   {},             # line role metadata
    "network_path": str | None,
    "sim_frames":   [],
    "sim_result":   SimResult | None,
}
```

**Critical distinction:**
- `_state["network"]` — raw graph (nodes, lines). Loaded from .jpd.
- `_state["structures"]` and `_state["cps"]` — higher-level objects. Only populated when structures are placed interactively OR explicitly reconstructed/restored on load.

This split is what caused the CP bug (see below).

---

## Structure and ConnectionPoint Model

Every station or traffic circle is a **Structure** — a named group of nodes, lines, and CPs.

### Station node naming (`{sid}` = e.g., `s12`)

| Node ID | Role |
|---------|------|
| `{sid}.PLATFORM` | Station identity node (is_station=True) |
| `{sid}.NB_N`, `{sid}.NB_S` | NB guideway endpoints |
| `{sid}.SB_N`, `{sid}.SB_S` | SB guideway endpoints |
| `{sid}.NB_N_tip`, `{sid}.SB_N_tip` | North stub tips (CP_N) |
| `{sid}.NB_S_tip`, `{sid}.SB_S_tip` | South stub tips (CP_S) |
| `{sid}.SIDE_N`, `{sid}.SIDE_S` | Siding entry/exit |
| `{sid}.TA_N_mid`, `{sid}.TA_S_mid` | Turnabout midpoints |

**CPs for a station:**
- `{sid}.CP_N`: outbound=`NB_N_tip`, inbound=`SB_N_tip`, heading=nb_h
- `{sid}.CP_S`: outbound=`SB_S_tip`, inbound=`NB_S_tip`, heading=sb_h

### Traffic circle node naming (`{sid}` = e.g., `c7`)

| Node ID | Role |
|---------|------|
| `{sid}.A{i}_div` | Ring diverge node for arm i |
| `{sid}.A{i}_merge` | Ring merge node for arm i |
| `{sid}.A{i}_out` | Outbound stub tip for arm i |
| `{sid}.A{i}_in` | Inbound stub tip for arm i |

**CPs for a circle:**
- `{sid}.CP{i}`: outbound=`A{i}_out`, inbound=`A{i}_in`, i=0..3

### ConnectionPoint fields

```python
@dataclass
class ConnectionPoint:
    cp_id:         str
    structure_id:  str
    heading_deg:   float      # direction stubs point outward
    inbound_node:  Node       # vehicle arrives from outside
    outbound_node: Node       # vehicle departs to outside
    center_lat:    float
    center_lon:    float
    connected_to:  str | None # other cp_id, or None if open
```

### Structure fields

```python
@dataclass
class Structure:
    structure_id:   str
    structure_type: str        # "station" | "traffic_circle"
    cp_ids:         List[str]
    node_ids:       List[str]
    line_ids:       List[str]  # INTERNAL lines only
    center_lat:     float
    center_lon:     float
    heading_deg:    float
    arm_headings:   List[float]  # traffic_circle only
```

---

## The CP Round-Trip Bug — Root Cause and Fix

### The bug

Networks loaded from `.jpd` files had no active CPs. You could see nodes, guideways, and stations rendered on the map, but clicking on connection points did nothing.

### Root cause

The `.jpd` file format (inherited from the Java tool) stores only three things:
1. **Switches** — all non-platform nodes
2. **Stations** — PLATFORM nodes only
3. **Lines** — guideways

`load_jpd()` restored only the raw graph (`Network`). It never rebuilt `_state["structures"]` or `_state["cps"]`. Those dicts stayed empty. `_network_to_geojson()` reads from `_state["structures"]` and `_state["cps"]` to generate CP features — with empty dicts, no CP markers were rendered. No markers = nothing to click.

The same thing happened even after save/load cycles, because `save_jpd()` also only wrote nodes and lines — it had no way to write what it didn't have.

### Fix — two layers

**Layer 1: StructureMeta in the .jpd file**

Added a `<StructureMeta>` XML element containing JSON-encoded structure and CP data:

```xml
<StructureMeta>{"structures":[...],"cps":[...]}</StructureMeta>
```

- `serialise_jpd(net, structures, cps)` writes it
- `save_jpd(net, path, structures, cps)` writes it
- `jpd_reader.load()` now returns `(net, structs_data, cps_data)` — previously returned only `net`
- `_restore_structures(structs_data, cps_data, net)` in api.py rebuilds the objects after load

This handles all networks saved by the new GUI.

**Layer 2: Legacy reconstruction from node naming**

For networks saved before StructureMeta existed (and for the first save of any old file), `_reconstruct_structures_from_net(net)` derives Structure and CP objects purely from node naming conventions:

```python
def _reconstruct_structures_from_net(net):
    # Group nodes by prefix (text before first '.')
    # ST_* → station, TC_* → traffic_circle
    # Station CPs: NB_N_tip/SB_N_tip (north), NB_S_tip/SB_S_tip (south)
    # Circle CPs: A{i}_out / A{i}_in for i in 0..3
    # connected_to: resolved by tracing lines across structure boundaries
```

Called when `structs_data` is empty. Works on any .jpd ever built with the GUI, regardless of when it was saved.

### Lesson for other programs

**Any time you have a two-tier object model** (raw data + derived higher-level objects), you must either:
1. Persist both tiers in the file (StructureMeta approach), OR
2. Derive the higher-level objects from the raw data deterministically on load (reconstruction approach), OR
3. Both — use reconstruction as the fallback for legacy files

If you only persist tier 1 and only build tier 2 interactively, you will break round-trip fidelity. The symptom is always "works when I build it, broken when I load it."

---

## GeoJSON Generation — How CPs Become Map Markers

`_network_to_geojson(net)` in `api.py`:

1. Iterates `_state["structures"]` to build internal line features (colored by structure type)
2. Iterates `_state["cps"]` to build CP marker features, each with properties:
   - `cp_id`, `structure_id`, `heading_deg`
   - `connected_to` (partner cp_id or null)
   - `inbound_node`, `outbound_node` (node_ids)
   - `center_lat`, `center_lon`
3. Attaches `metadata.structures` dict to the GeoJSON for the client

On the client, `_addCpFeature(f)` creates a Leaflet marker at `(center_lat, center_lon)` with a custom HTML icon and a click handler that manages selection/connect/disconnect.

---

## Read-Only Lock

Networks load locked. The `🔓 Edit` button (palette, above Stations) toggles `_readOnly`.

When locked:
- Stations, Components, Circles palette sections hidden
- All editor operations return early via `_roGuard()` / `_guardRO()`
- **CP markers fully non-interactive** — `pointer-events: none` via `.network-locked .cp-hit` CSS; no hover glow, no click, no selection

`App.setReadOnly(ro)` toggles the `network-locked` class on the Leaflet map container.
CSS rule handles the rest — no JS event handler changes needed.

The guard is purely client-side — no server-side enforcement. This is intentional: the server doesn't need to know about UI lock state.

Operations gated:
- `editor.js`: `startPlace`, `startWaypoint`, `startDrawLine`, `autoConnect`, `lineNodeClick`, `breakLine`, `removeNode`, Delete/Backspace key
- `app.js`: alt-drag (structure move), selection drag, CP connect (second click), CP disconnect (shift+click), `deleteSelection()`

---

## Structure Move — Single and Multi

### Single-structure (Alt+drag)

Capture-phase `mousedown` on document intercepts before Leaflet's drag handler.
Requires `e.altKey` and `_hoverStructSid` (set by CP or internal-line mouseover).

1. Snapshot CP positions for `sid` → `_moveState.origPos`
2. Collect connector-line endpoints from `_lineNodeMap` for live stretch
3. Remove structure's `L.layerGroup` from `_layers.lines` (internal lines hidden during drag)
4. On `mousemove`: reposition CP markers + stretch/shrink connector endpoints
5. On `mouseup`: `POST /api/network/structure/{sid}/move {dlat, dlon}` → re-render

### Multi-structure (selection drag — plain drag on selected group)

After rubber-band selection (`_sel.structures` non-empty), plain drag (no Alt) on any
structure in the selection triggers `_startMultiMove()`.

1. Snapshot CPs for ALL `_sel.structures` → `_moveState.origPos`
2. Build `movingTips` — all outbound/inbound nodes for selected structures
3. Connector classification:
   - Both endpoints in `movingTips` → **internal** (both endpoints shift — line moves as unit)
   - One endpoint in `movingTips` → **external** (one endpoint stretches)
4. Hide internal lines for all selected structures
5. `_moveState.sids = new Set(_sel.structures)` — signals multi mode
6. On `mouseup`: `Promise.all([...sids].map(s => POST .../move))` in parallel → re-render
7. Re-render calls `_clearSelection()` — selection clears automatically after drop

`_moveState.sid` is null in multi mode; `_moveState.sids` is null in single mode.

---

## Grid Generator

`POST /api/network/grid` in `api.py`. Parameters: `center_lat`, `center_lon`,
`spacing_ns`, `spacing_ew` (miles), `extent_ns`, `extent_ew` (miles), `replace` (bool).

**Algorithm:**
1. Compute grid dimensions: `n_rows = floor(extent_ns/spacing_ns) + 1`, same for cols
2. Place circles at every (row, col) intersection using lat/lon offsets
3. N-S stations: midpoint between (r,c) and (r+1,c) — heading 0°
   Connect: circle south arm (`_cp_by_heading(cp_dict, 180)`) ↔ station CP_N
   Connect: station CP_S ↔ next circle north arm (`_cp_by_heading(cp_dict, 0)`)
4. E-W stations: midpoint between (r,c) and (r,c+1) — heading 90°
   Connect similarly using east/west arms
5. `_cp_by_heading(cp_dict, target)`: finds CP with minimum angular difference to target
   (wraps at 180°) — works regardless of circle arm ordering in the dict

**Known issue:** If CP heading matching produces a wrong arm assignment (e.g., diagonal
grid where arm headings don't snap cleanly to 0/90/180/270), some CPs will be left
open → isolated islands in the simulation. Check orphan indicators after grid generation.

---

## Known Issue — Island Isolation in Travel Time Assessment

**Symptom:** Some structures are not connected to the main network graph.
Dijkstra returns no path → `find_path()` returns None → simulation logs
`WARNING: No route from X to Y` and returns the pod to depot. The O-D pair
produces no `trip_stats` entry. Confirmed: simulation handles this correctly.

**Root cause:** Open CPs after grid generation or AutoConnect. Any structure
whose CPs are all `connected_to: null` is unreachable.

**Mitigation (coverage display):** `timemap.js` skips O-D pairs with no `rideMins`
entry — they simply don't produce destination circles. A speed filter
(> 200 km/h implied) catches any phantom zero-time entry.

---

## Adjacent Station Travel Time — Design Invariant and Congestion Interpretation

**Design invariant:** In a non-congested network, travel time to station B must be
monotonically non-decreasing with geographic distance from origin A. A nearby station
cannot require a longer ride than a distant one unless:
1. Routing is genuinely forced the long way around (one-way CCW constraint), OR
2. Congestion on the direct segment forces rerouting

**Grid topology verified correct (2026-04-27):**
`diag_grid.py` was run on a fresh 3×3 grid (1-mile blocks). All 12 adjacent station
pairs (both directions) produced route ratios of 1.0–1.1×. No topology defect found.

- Direct direction: 13 lines, 1.0× (straight through)
- Return direction: 19 lines, 1.1× (normal turnabout detour)

**Conclusion:** When the GUI shows an adjacent station taking > 30 min, it is a
**congestion signal**, not a topology bug. Dijkstra correctly reroutes pods around
jammed guideways — the short segment is saturated, so the simulation goes the long
way around. The coverage circles correctly display this as a smaller circle at the
congested destination.

**How to read the coverage circles:**
- Adjacent station shows a smaller circle than a distant station → congestion on
  that block → add parallel capacity on that guideway
- This is the intended behavior — coverage is the congestion display

**How to confirm congestion vs topology:**
- Check `line_stats.congestion` for guideways between A and B.
  If congestion > 0.7 and travel time > 30 min → congestion confirmed.
- Run `diag_grid.py` on the network to verify routing ratios. If all ratios < 3×,
  topology is clean.

**`diag_grid.py`** — standalone diagnostic at
`route_time/diag_grid.py`. Run from the `03_Technology` directory:
```
python3 -m route_time.diag_grid
```
Runs Dijkstra between every adjacent station pair and reports route/expected ratio.
Flag any route > 3× as a topology defect.

---

## Save / Download Flow

Old: `POST /api/network/save` with a server-side path → wrote file to disk.
Problem: user had to type a server-side path; no native OS dialog.

New: `GET /api/network/download` → server returns .jpd bytes as `application/xml` attachment.
Client receives as blob, uses `showSaveFilePicker()` (File System Access API) for native OS dialog.
Fallback: `<a download>` for older browsers.

---

## Network Clipboard Pattern (2026-05-01)

`NetClipboard` in `app.js` provides copy/paste without the file system:

1. **Open**: fetches `GET /api/network/download` as text → populates a textarea in a modal dialog
2. **Copy**: `navigator.clipboard.writeText(textarea.value)` → puts .jpd XML on system clipboard
3. **Load**: `POST /api/network/load_text` with `{filename: "pasted.jpd", content: textarea.value}` — same endpoint used by file picker open

**Key property:** The `.jpd` format already encodes `lat` / `lon` for every node. Clipboard round-trip preserves exact geographic positions. No additional export format required.

**Structure tooltip (same session):** `hitZone.bindTooltip()` now shows `sid<br>lat, lon` — hover any station or circle in locked mode to see its center coordinates.

The content is generated by `serialise_jpd(net, structures, cps)` — same XML as disk save, returned as bytes instead.

---

## Isochrone (Walk-Ride-Walk Coverage Circles)

Algorithm matches Java `TimeGraph.java`:
1. Find closest station to clicked point = boarding station
2. Fetch analytical Dijkstra travel times from `GET /api/network/travel_times?origin=<boarding_sid>`
3. Load simulation `trip_stats` from `Sim.getResult()` (if available); overlay on analytical times
4. For each destination station and each budget (5, 10, 20, 30 min):
   - `fixed = walk_to_boarding + ride_time(boarding → dest)`
   - `remaining = budget − fixed`
   - `radius_m = remaining × walk_speed_m_per_min`
5. Draw Turf.js 64-step polygon circle at each destination with that radius
6. Also draw pure-walk circle at clicked point (no ride needed)
7. Union all same-budget polygons with `turf.union()` → single merged polygon
8. Render as one `L.geoJSON()` layer per budget (outer boundary only, no interior lines)
9. Place a colored dot at each station with a tooltip showing ride time and source `(sim)` or `(est)`

Color scale (matching Java TimeColor):
- Green = 5 min, Blue = 10 min, Yellow = 20 min, Red = 30 min

`_draw()` is `async` — awaits the travel_times fetch before rendering polygons.
`handleClick()` fires `_draw()` as a fire-and-forget Promise (returns true immediately so map click propagation is stopped).

**Analytical endpoint (`GET /api/network/travel_times`):**
- Single-source Dijkstra over all nodes, weighted by `line.length_m`
- Returns `{dest_station_id: minutes}` for all reachable PLATFORM nodes
- Speed: `maxVelocityInKMPH` from settings (default 60 km/h)
- Used as the primary source; simulation medians override where available

---

## Three-Phase Simulation and Pod Redistribution

### Design (2026-04-30)

The simulation runs in two phases to guarantee complete O-D coverage:

**Phase 1 — Sweep 1:** One passenger queued from every station to every other station (`n×(n-1)` pairs). Runs until all trips complete. Establishes baseline travel times.

**Phase 2 — Sweep 2 + Random demand:** A second full sweep is queued simultaneously with the gravity-model demand schedule. Simulation stops when the last Sweep 2 vehicle arrives. Sweep 2 times reflect congestion from the mixed load.

Random demand alone cannot guarantee full coverage because the weighted-random destination selection leaves ~22% of O-D pairs with zero passengers by Poisson chance. The sweeps are deterministic and bypass this.

### Pod redistribution

**Problem:** After Sweep 1, pods cluster at popular destinations. Some stations end up with zero pods; the global depot is empty. In Sweep 2, pod-starved stations can't dispatch their waiting passengers — those pairs remain uncovered.

**Fix (in `_arrive_at_line_end`):** When a pod arrives at its destination and is not immediately re-dispatched by `_board_from_station`, check: if the station has no waiting passengers AND has more than `pods_per_station` queued pods, return the surplus pod to the global depot. Pod-starved stations can then draw from the depot on the next `_dispatch` tick.

### Physical network depot note

The simulation uses a **single global depot** as a simplification. In a physical JPods network, pod depots are scattered throughout the network — typically one per major station or cluster. Future work: add Depot as a structure type on the map; restrict `_dispatch` to draw from the nearest depot rather than a global pool. This will produce more realistic congestion patterns, especially for sweeps across geographically distant station pairs.

---

## Simulation Time Resolution Fix

**Bug:** Simulation ran for 6m40s instead of 1 hour.

**Root cause:** `PASSENGER_GEN_INTERVAL = 10` was hardcoded as ticks-per-slot. At `timeResolutionPerSec=9`, one slot is 10 real seconds, so `ticks_per_slot = 9 × 10 = 90`, not 10. The hardcoded value made passengers arrive 9× too fast relative to vehicle physics.

**Fix:** Compute dynamically:
```python
self._ticks_per_slot = max(1, round(tps * LoadArray.SLOT_DURATION_S))
```

At `tps=9`, `SLOT_DURATION_S=10`: `ticks_per_slot = 90` → `360 slots × 90 ticks = 32,400 ticks = 1 simulated hour`.

**General lesson:** Any time a tick-based simulation has a hardcoded interval constant, verify it's expressed in ticks-per-real-time-unit, not ticks-per-simulation-unit. The two diverge whenever the physics resolution (`tps`) is not 1.

---

## Loading Animation Race Condition Fix

**Bug:** No animation visible when clicking Run.

**Root cause:** `_startLoadingAnim()` was async — it fetched GeoJSON internally. If the simulation POST completed before the GeoJSON fetch returned, `_stopLoadingAnim()` was called while the interval handle was still null, leaving no way to stop it (the animation was never started).

**Fix:** Pre-fetch GeoJSON before the simulation POST. Pass the pre-fetched GeoJSON to `_startLoadingAnim(geojson)` (now synchronous). Reuse the same GeoJSON for `_buildFrames()`.

```javascript
const geojson = await api("GET", "/api/network");  // pre-fetch
_startLoadingAnim(geojson);                          // synchronous, immediate
const result = await api("POST", "/api/simulation/run", settings);
_stopLoadingAnim();
await _buildFrames(result, geojson);                 // reuse
```

**General lesson:** Never fetch inside an animation start function if the fetch can race with the event that stops the animation. Pre-fetch, then start.

---

## Large-Network Browser Freeze — Root Cause and Fix (2026-05-07)

### Symptom

On a 138-station network, clicking **Run simulation** caused an 11-minute browser freeze after the Python simulation completed. The log showed:

```
14:13:14  simulation finished (19,012 trips)
14:24:28  first _fillGridGaps request (s68.platform_parking)
```

The Python engine was fast. The browser was locked for 11 minutes.

### Three root causes

**1. N² HTML table (grid freeze)**

`_showResults` built a station×station travel-time grid: `138 × 138 = 19,044 <td>` cells assembled as a string, then assigned to `innerHTML`. The DOM parser locked the main thread for several minutes parsing and laying out the table.

**2. Synchronous frame-build loop (async illusion)**

`_buildFrames` is an `async` function. An `async` function only yields control at `await` points — a tight `for` loop with no `await` inside it runs synchronously even though the function is declared async. At 138 stations, the simulation produced 18,906 routes × 120 frames = **2.27 million** geometry iterations with zero yields.

**3. Per-frame marker add/remove (animation freeze)**

`_drawPods` called `L.divIcon()` to create a new DOM element and `addLayer` + `removeLayer` every animation frame for every pod marker. At 18,906 routes at 12 fps: **226,872 DOM add/remove operations per second**. Each `divIcon` allocates a `<div>` element and triggers Leaflet's layer-add path.

### Fix — three-pronged

**Fix 1: Grid cap at `MAX_GRID_STATIONS = 50`**

Route grid is only rendered when station count ≤ 50. Above that, the Results panel shows:
*"N stations — grid hidden above 50. Use the Isochrone tab to explore travel times."*

The Isochrone tab provides full travel-time exploration at any scale.

**Fix 2: Route sample cap + async yield in `_buildFrames`**

```javascript
const MAX_ANIM_ROUTES = 400;
if (routes.length > MAX_ANIM_ROUTES) {
  const step = routes.length / MAX_ANIM_ROUTES;
  const sampled = [];
  for (let i = 0; i < MAX_ANIM_ROUTES; i++) {
    sampled.push(routes[Math.floor(i * step)]);
  }
  routes.length = 0;
  routes.push(...sampled);
}
// Inside the frame loop:
if (frame > 0 && frame % 20 === 0) {
  await new Promise(r => setTimeout(r, 0));  // yield to browser
}
```

Uniform stride sampling preserves geographic spread. Yielding every 20 frames lets the browser process resize events and avoids "page unresponsive" dialogs.

**Fix 3: `_replayPool` — `L.circleMarker` pooling**

Pre-allocate a pool of `L.circleMarker` instances (SVG path elements). Per frame: call `setLatLng` + `setStyle` to reposition and recolor. No DOM add/remove.

```javascript
let _replayPool = [];

function _ensureReplayPool(n) {
  while (_replayPool.length < n) {
    const m = L.circleMarker([0, 0], {
      radius: 4, color: 'transparent',
      fillColor: '#3498db', fillOpacity: 0,
      interactive: false,
    });
    App.getLayers().pods.addLayer(m);
    _replayPool.push(m);
  }
}
function _clearReplayPool() {
  _replayPool.forEach(m => m.setStyle({ fillOpacity: 0 }));
}
function _drawPods(podList) {
  _ensureReplayPool(podList.length);
  podList.forEach(({ lat, lng, color, isStopping, isApproaching }, i) => {
    const r = isStopping ? 8 : isApproaching ? 6 : 4;
    _replayPool[i].setLatLng([lat, lng]);
    _replayPool[i].setStyle({ fillColor: color, radius: r, fillOpacity: 1 });
  });
  for (let i = podList.length; i < _replayPool.length; i++) {
    _replayPool[i].setStyle({ fillOpacity: 0 });
  }
}
```

`_replayPool` is separate from `_podMarkers` (the loading animation pool) — the two pools are independent and never interfere.

### General lessons

1. **`async` ≠ non-blocking.** An async function only releases the thread at `await` points. A tight loop inside async is still synchronous. Insert `await new Promise(r => setTimeout(r, 0))` periodically to yield.

2. **N² DOM operations scale badly.** A 50-station table = 2,500 cells (fine); a 138-station table = 19,044 cells (minutes). Gate any O(N²) DOM construction behind a station-count check.

3. **Leaflet marker pooling pattern.** For any animation updating many markers per frame: pre-allocate `L.circleMarker` objects, mutate with `setLatLng`/`setStyle`, never add/remove. This is ~100× cheaper than `L.divIcon` add/remove.

---

## File Structure Reference

```
route_time/
  engine/
    network.py       — Network, Node, Line, Station
    structures.py    — Structure, ConnectionPoint, build_station(), build_traffic_circle()
    simulation.py    — Simulator, SimResult, TripRecord
    demand.py        — LoadArray, gravity model
    physics.py       — PhysicsModel
    routing.py       — Dijkstra find_path()
  io/
    jpd_reader.py    — load(path) → (Network, structs_data, cps_data)
    jpd_writer.py    — serialise_jpd(net, structures, cps) → bytes
                       save_jpd(net, path, structures, cps)
                       _build_root(net, structures, cps) → ET.Element  [shared]
  gui/
    app.py           — Flask entry point, static file serving
    api.py           — REST endpoints, _state, _network_to_geojson()
                       _reconstruct_structures_from_net(net)  [legacy CP recovery]
                       _restore_structures(structs_data, cps_data, net)
    static/
      index.html     — palette, sidebar, settings panel
      app.js         — map init, CP rendering, lock logic, capture, logo/ledger controls
      editor.js      — place/connect/break/delete tools
      simulator.js   — run, animation, replay, Sim.getResult()/getGeojson()
      timemap.js     — walk-ride-walk coverage circles (Turf.js union)
      settings.js    — settings panel load/save
      demand.js      — demand panel
      overlays.js    — AADT, accidents, mobility
      ai.js          — Allie recommendations panel (stub)
      style.css
      jpods-logo.png — JPods® logo watermark (2492×700 RGBA, displayed at 140px)
```

---

## Server Startup (always from parent directory)

```bash
cd /Users/williamjames/Documents/08_JPods/03_Technology
python3 -m route_time.gui
# Browser at http://localhost:5050
```

Starting from the wrong directory causes `ModuleNotFoundError: No module named 'route_time.engine'`.

Stale `.pyc` bytecode: if the server was running before a code change, `_state` changes and new endpoint registrations won't take effect until restart. Always restart after editing Python files.

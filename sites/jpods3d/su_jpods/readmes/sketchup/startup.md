# SketchUp JPods Plugin — Startup Guide

> How to start a new network, understand the file ecosystem, and get back to work after time away.

---

## Quick Start — Returning to an Existing Network

```
1. Open SketchUp 2026 (plugin loads automatically)
2. File > Open > navigate to your network .skp file
3. Extensions > JPods > Console (opens the JPods console panel)
4. Build (if you changed station placements or templates)
5. Start Animation (runs the network)
```

---

## Starting a New Network

### 1. Create the project folder

Every network lives in its own folder. All generated files go here alongside the .skp.

```
~/Documents/skp_jpods/MY_City_Name/
```

### 2. Create a new SketchUp model

1. File > New
2. File > Save As > `~/Documents/skp_jpods/MY_City_Name/MY_City_Name.skp`
3. Extensions > JPods > Console

### 3. Geolocate (optional — enables terrain following)

1. File > Geo-location > Add Location
2. Center on your site, grab the satellite image
3. The terrain surface enables Build to follow real ground elevation

### 4. Place stations

1. In the JPods Console, go to the Models panel
2. Click "Place" on a station template (e.g., station_parking)
3. Click in the model to place it
4. Repeat for all stations

### 5. Connect guideways

1. Extensions > JPods > Connect Guideways tool
2. Click CP gate on station A, then CP gate on station B
3. Place waypoints if the route needs to curve around obstacles

### 6. Build

1. Console > Build
2. Generates beam geometry, columns, solar panels
3. Writes `MY_City_Name.followme.json` and `MY_City_Name.network.json`

### 7. Populate + Animate

1. Console > Populate (places pods at stations)
2. Console > Start Animation (pods begin routing)

---

## File Ecosystem

### Network folder (one per network model)

```
MY_City_Name/
  MY_City_Name.skp              — the SketchUp model (you edit this)
  MY_City_Name~.skp             — SketchUp auto-backup
  MY_City_Name.followme.json    — connection definitions (Build writes)
  MY_City_Name.network.json     — routing graph, station data (Noelle writes at Build)
  MY_City_Name.build.log.json   — build log
  MY_City_Name.crew.json        — crew health data
  MY_City_Name.vehicles.json    — vehicle registry
  MY_City_Name.visits.json      — model visit history
  MY_City_Name.map.json         — map data for Route-Time export
  MY_City_Name.route.log.json   — route logging
  MY_City_Name.path.json        — path data
  MY_City_Name.kmz              — Google Earth export
  defect.json                   — defect log (append-only, agents + designer flags)
  trip_reports/                 — per-trip data from animation sessions
  README.md                     — network-specific notes
```

### Plugin folder (shared by all networks)

```
su_jpods/
  main.rb                       — plugin entry point
  boot.rb                       — load sequence
  CLAUDE.md                     — design axioms and engineering rules
  jpod_constants.rb             — CLEARANCE_HEIGHT, DUAL_TRACK_SPACING, etc.
  jpod_console.rb               — console UI callbacks
  jpod_log.rb                   — logging + defect system
  jpod_console.log              — runtime console output

  animation/
    animation.rb                — AnimationV2 — tick loop, dispatch, conveyor

  build/
    build.rb                    — beam geometry, columns, solar
    build_path.rb               — PathBuilder terrain following

  compute/
    compute.rb                  — Compute pipeline orchestrator
    compute_geometry.rb         — Phase 3: cp_marker → track geometry (pure math)
    compute_chain_builder.rb    — Phase 2: successor graph → Natalie chains
    compute_validator.rb        — Phase 1: topology validation
    compute_writer.rb           — writes lines.computed.json

  natalie/
    natalie.rb                  — NatalieV2 — routing, fleet registry, dispatch

  nora/
    nora.rb (alias)             — NoraV2 — pod entity, maneuver interpolation

  sally/
    sally.rb                    — SallyV2 module — station init, fleet coordination
    sally_station.rb            — per-station state (ps[], pods[], validate!)
    sally_compat.rb             — slot position compat layer

  noelle_v2/
    noelle_v2.rb                — network validation, track gap checking

  tools/
    connect_tool.rb             — guideway connection tool

  dialogs/
    console.html                — console UI (HTML/JS)

  templates/
    track_formations/           — station template library
```

### Template folder (one per station type)

```
templates/track_formations/station_parking/
  model.skp                     — template geometry (designer edits this)
  lines.json                    — topology: tracks, successors, chains (designer + Compute)
  lines.computed.json           — computed geometry: pts_mm, lengths (Compute writes)
  image.png                     — thumbnail for model list
  notes.md                      — designer notes
```

**Current templates:**

| Template | Type | CPs | Platform | Description |
|----------|------|-----|----------|-------------|
| station_parking | Station | 2 | Yes (9 slots) | Full parking station with lift |
| station_line_end | Station | 1 | Yes | Dead-end station with uturn |
| station_thru_dip | Station | 2 | Yes | Through station with platform dip |
| traffic_circle7 | Junction | 4 | No | 7-arc traffic circle |
| cps | CP component | — | No | Straight CP connector |
| cpu | CP component | — | No | CP with uturn |
| cpb | Barrier | — | No | CP barrier (blocks dead ends) |

---

## Key JSON Files Explained

### lines.json (per template — designer + Compute)
The single source of truth for station topology.
- `designer.tracks` — every gw_ track with successors
- `natalie.landing_chains` — how pods enter the station
- `natalie.exit_chains` — how pods leave
- `natalie.hold_loop` — circling path when station is full
- `chains_header.approved_by` — must be set before Build accepts it

### lines.computed.json (per template — Compute writes)
Computed from cp_markers in model.skp. Pure math, no edges.
- `geometry.tracks` — pts_mm polylines, length_mm, radius_mm per track
- `chain_lengths_mm` — total chain lengths for Natalie routing
- Regenerated every time Compute runs — never hand-edit

### network.json (per network — Noelle writes at Build)
The built network's routing and station data.
- `natalie.routing_graph` — track-to-track adjacency for BFS routing
- `designer.stations` — per-station track geometry in world coordinates
- `designer.connections` — inter-station guideway geometry

### followme.json (per network — Build writes)
Connection definitions between stations.
- Which station CP connects to which
- Waypoint positions for curved routes
- Read by Build to generate beam geometry

---

## The 8-Step Student Workflow

```
1. Geolocate     — satellite image + terrain
2. Place         — drag stations from template library
3. Calculate CPs — auto-detect connection points from geometry
4. Connect       — draw guideways between station CPs
5. Waypoints     — place markers to route around obstacles
6. Build         — generate 3D beams, columns, solar panels
7. Review        — Noelle validates; Crew Health reports defects
8. Animate       — pods run the network
```

---

## After Time Away — What to Check

1. **Open the .skp** — is the model intact? Any entity corruption?
2. **Console > Build** — rebuild to regenerate network.json
3. **Check for warnings** — SLOPPY gaps, disconnected CPs, cpb barriers needed
4. **Populate + Animate** — does it run? Any stuck pods?
5. **Validate Sally** button — purge any ghost pod records from saved state
6. **Flag Defect** button — if you see a problem, flag it for the log

---

## Existing Network Models

```
~/Documents/skp_jpods/
  SC_Greenville_Bolden/     — West Point / Greenville (primary test network)
  2_parking/                — 2-station parking test
  3+circle/                 — 3 stations + traffic circle
  CA_Gilroy_Casino/         — Gilroy deployment concept
  MN_MOA_Bloomington/       — Mall of America concept
  OK_LazyE_terrain/         — LazyE Ranch terrain test
  ny_westpoint_su/          — West Point original
  ... and more test models
```

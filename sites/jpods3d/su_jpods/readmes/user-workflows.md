# JPods SketchUp Plugin — User Workflows

Comprehensive flowchart documentation for the su_jpods plugin.
Covers program architecture, the 8-step student workflow, station template
authoring, connection editing, animation, and JPods Travel.

All Mermaid diagrams render in VS Code (Markdown Preview Enhanced) and GitHub.

---

## 1. Program Architecture Overview

### Scope Boundary: Model vs Network

The plugin has two distinct scopes. Confusing them is the most repeated error
in the codebase.

```mermaid
graph LR
    subgraph MODEL ["MODEL SCOPE (Template)"]
        direction TB
        SKP["model.skp<br/>3D geometry + cp_markers"]
        LJ["lines.json<br/>Topology: tracks, successors, chains"]
        LC["lines.computed.json<br/>Geometry: pts_mm per track"]
        SKP --> LJ
        SKP --> LC
    end

    subgraph NETWORK ["NETWORK SCOPE (Placed Instances)"]
        direction TB
        NSKP["&lt;Network&gt;.skp<br/>Placed station instances + terrain"]
        NJ["&lt;Network&gt;.network.json<br/>Connections, waypoints, routing graph"]
        NSKP --> NJ
    end

    LC -- "Build transforms<br/>to world coords" --> NJ
    LJ -- "Topology feeds<br/>chain builder" --> NJ
```

**Key rule:** Compute writes to MODEL scope only. Build writes to NETWORK scope
only. Never cross the boundary.

### Pipeline: Compute → Build → Animate

The three operations are a strict ordered pipeline. Skipping or reversing
produces silent errors.

```mermaid
graph LR
    C["Compute<br/>(template geometry)"] --> B["Build<br/>(world-space beams)"]
    B --> A["Animate<br/>(Natalie validates timestamps)"]

    C -- "writes" --> LC2["lines.computed.json<br/>(template folder)"]
    B -- "writes" --> NJ2["network.json<br/>(model folder)"]
    A -- "reads both,<br/>checks timestamps" --> LC2
    A -- "reads" --> NJ2
```

If Compute is newer than Build, Natalie refuses to animate:
*"Run Build before animating."* This is intentional — it prevents silent
degradation from stale geometry.

### Major Components

```mermaid
graph TD
    subgraph TOOLS ["User Tools"]
        PS["Place Structure"]
        CPC["CP Calculate"]
        CT["Connect Tool"]
        BD["Build"]
        POP["Populate"]
        AN["Animate"]
        TR["Travel"]
        CAM["Camera Follow"]
    end

    subgraph AGENTS ["Agent Layer"]
        SALLY["Sally<br/>Station: slots, parking queue"]
        NAT["Natalie<br/>Router: trip plans, dispatch"]
        NORA["Nora<br/>Vehicle: navigation, telemetry"]
        NOELLE["Noelle<br/>Network: validation, load balance"]
    end

    subgraph FILES ["Data Files"]
        LJ3["lines.json"]
        LC3["lines.computed.json"]
        NJ3["network.json"]
    end

    PS --> NOELLE
    CPC --> NOELLE
    CT --> NJ3
    BD --> LC3
    BD --> NJ3
    POP --> SALLY
    AN --> NAT
    AN --> NORA
    TR --> NAT
    CAM --> NORA
```

---

## 2. Building a Network — The 8-Step Student Workflow

### Overview

```mermaid
graph TD
    S1["1. Geolocate Terrain"] --> S2["2. Place Stations"]
    S2 --> S3["3. CP Calculate"]
    S3 --> S4["4. Connect Guideways"]
    S4 --> S5["5. Place Waypoints (W key)"]
    S5 --> S6["6. Build"]
    S6 --> S7["7. Review (Crew Health)"]
    S7 --> S8["8. Animate"]

    S5 -.-> S4
    S7 -.-> |"fix issues"| S4
```

Steps 4 and 5 are interleaved — press W during Connect to drop waypoints.
Review may loop back to step 4 if Noelle finds faults.

### Step 1: Geolocate Terrain

```mermaid
graph TD
    A["File > Geo-location > Add Location"] --> B["Import satellite + elevation mesh"]
    B --> C{"Terrain mesh detected?"}
    C -- "Yes" --> D["Terrain ready<br/>(ray-cast elevation available)"]
    C -- "No" --> E["Plugin searches for:<br/>terrain, google earth,<br/>geo-location, topography"]
    E --> F{"Found group with ≥20 faces?"}
    F -- "Yes" --> D
    F -- "No" --> G["Add terrain manually<br/>or re-import"]
    G --> A
```

The plugin uses `Terrain.elevation_at(model, x, y)` to ray-cast from 2000m
above each point down to the terrain surface. Without terrain, all guideways
build flat.

### Step 2: Place Stations

**Menu:** Extensions > JPods > Place Structure
**Toolbar:** Place Structure button

```mermaid
graph TD
    A["Select formation type<br/>(station_parking, station_line_end,<br/>traffic_circle7, etc.)"] --> B["Click terrain surface"]
    B --> C["Plugin ray-casts to terrain"]
    C --> D["Places ComponentInstance"]
    D --> E["Auto-assigns unique ID<br/>(S001, S002, ...)"]
    E --> F["Detects CPs from cp_markers"]
    F --> G["Labels CPs in model<br/>(S001.CP0, S001.CP1)"]
    G --> H{"Place another?"}
    H -- "Yes" --> B
    H -- "No / Esc" --> I["Stations placed"]
```

Station IDs are auto-incremented and never recycled, even if a station is
deleted. Each station stores its CP data in local coordinates on the
component instance.

### Step 3: CP Calculate

**Toolbar:** CP Calculate button (toggle)

```mermaid
graph TD
    A["Click CP Calculate"] --> B{"CPs currently shown?"}
    B -- "No" --> C["Purge phantom entities"]
    C --> D["Recompute all CPs<br/>(reads cp_marker geometry)"]
    D --> E["Show CP circles<br/>(teal rings at each gate)"]
    E --> F["Activate Connect Tool"]
    B -- "Yes" --> G["Hide CP labels"]
    G --> H["Deactivate Connect Tool"]
```

CP Calculate both shows the connection points AND activates the Connect Tool
so the student can immediately start connecting.

### Steps 4-5: Connect Guideways + Waypoints

**Tool:** Activated by CP Calculate
**W key:** Drop waypoint marker at cursor position

```mermaid
graph TD
    A["Connect Tool active<br/>(teal CP rings visible)"] --> B["Click CP A<br/>(ring turns gold)"]
    B --> C{"Need waypoints?"}
    C -- "Yes" --> D["Press W at each<br/>intermediate point"]
    D --> E["Marker placed<br/>(ring turns cyan)"]
    E --> C
    C -- "No" --> F["Click CP B<br/>(Bezier preview shown)"]
    F --> G["Connection committed<br/>(saved to network.json)"]
    G --> H{"Connect more?"}
    H -- "Yes" --> A
    H -- "No" --> I["All connections defined"]

    B --> J["Hover CP B shows<br/>live Bezier preview"]
    J --> F
```

**Visual states during connection:**

| Ring Color | Meaning |
|-----------|---------|
| Teal | CP available, not selected |
| Gold | FROM selected, waiting for TO |
| Yellow | Hovered CP (preview shown) |
| Cyan | Editing waypoints on existing connection |
| White | Inspecting an existing connection |

**Keyboard shortcuts in Connect Tool:**

| Key | Action |
|-----|--------|
| W | Drop waypoint marker at cursor |
| Esc | Cancel selection, or exit tool |
| Shift+click | Delete connection at clicked CP |

Each connection creates a bidirectional pair automatically: `seg_A_B` (forward)
and `seg_B_A` (return). Both are one-way. The Build pipeline generates
separate beam geometry for each direction.

### Step 6: Build

**Console:** Build Network button
**Also:** Extensions > JPods menu

```mermaid
graph TD
    A["Click Build"] --> B["Read network.json connections"]
    B --> C["For each connection:"]
    C --> D["Find both structures by ID"]
    D --> E["Resolve CP world positions<br/>(apply instance transform)"]
    E --> F["Collect waypoint markers"]
    F --> G["Generate Bezier centerline"]
    G --> H["Zero all center Z values<br/>(critical — forces terrain follow)"]
    H --> I["Terrain.elevation_at + CLEARANCE_HEIGHT<br/>= anchor_zs at each CP"]
    I --> J["PathBuilder.build:<br/>1. Horizontal arcs<br/>2. Terrain snap<br/>3. Vertical profile"]
    J --> K["Offset ±1.75m for dual tracks"]
    K --> L["JPodGuideway.build_beam<br/>(beam faces + material)"]
    L --> M["place_solar_columns<br/>(T-columns every 25m,<br/>solar panels every 2.5m)"]
    M --> N["Write network.json<br/>with routing graph"]
```

**Key constants that govern Build:**

| Constant | Value | Effect |
|----------|-------|--------|
| CLEARANCE_HEIGHT | 4.6m | Beam bottom above terrain |
| DUAL_TRACK_SPACING | 3.5m | Center-to-center of dual guideways |
| SUPPORT_SPACING | 25m | Column interval |
| MIN_TURN_RADIUS | 30m | Minimum horizontal curve |
| PROFILE_MAX_GRADE | 8% | Maximum guideway slope |

### Step 7: Review (Crew Health Check)

**Toolbar:** Crew Health button

Each agent checks their domain independently:

```mermaid
graph TD
    A["Crew Health Check"] --> B["Sally: parking slots valid?"]
    A --> C["Natalie: routes connected?"]
    A --> D["Nora: vehicles placed correctly?"]
    A --> E["Noelle: network topology sound?"]
    B --> F{"All healthy?"}
    C --> F
    D --> F
    E --> F
    F -- "Yes" --> G["ALL HEALTHY — proceed to Animate"]
    F -- "No" --> H["Report faults<br/>Fix and re-Build"]
    H --> I["Return to Step 4 or 6"]
```

### Step 8: Animate

**Toolbar:** Animate button (toggle: Start / Pause / Resume)

```mermaid
graph TD
    A["Click Animate"] --> B{"Natalie timestamp check"}
    B -- "Compute newer than Build" --> C["REFUSED<br/>Run Build first"]
    B -- "Timestamps valid" --> D["Animation starts"]
    D --> E["Natalie plans routes<br/>(CCW one-way flow)"]
    E --> F["Sally dispatches pods<br/>from parking slots"]
    F --> G["Nora drives each pod<br/>along FollowMe paths"]
    G --> H{"Animate button<br/>clicked again?"}
    H -- "Yes" --> I["Animation pauses<br/>(pods freeze in place)"]
    I --> J{"Clicked again?"}
    J -- "Yes" --> D
    H -- "No" --> G
```

---

## 3. Station Template Authoring

For designers creating or modifying station templates in
`templates/track_formations/<template>/`.

### cp_marker Geometry

Each station has two cp_markers (cp_marker_0 at one end, cp_marker_1 at the
other). Each cp_marker contains four points radiating from a hub:

```
                   centerline (177mm vertical)
                        |
outbound <-- 1750mm -- CP POINT -- 1750mm --> inbound
                        |
                      222mm
                        v
                    vector_end
```

```mermaid
graph TD
    subgraph CP_MARKER ["cp_marker_N Component"]
        HUB["CP Point (hub)<br/>vertex with most connected edges"]
        OUT["Outbound tip<br/>1750mm — gw_cp_out side"]
        IN["Inbound tip<br/>1750mm — gw_cp_in side"]
        VEC["Vector end<br/>222mm — direction away from model"]
        VERT["Centerline<br/>177mm — vertical Z reference"]
        HUB --- OUT
        HUB --- IN
        HUB --- VEC
        HUB --- VERT
    end
```

**Reading the cp_marker (pure math, no edges):**
1. Collect all point positions from the component definition
2. CP point = vertex with most connected edges
3. Classify by distance from CP point (222mm / 1750mm / 177mm)
4. Cross product of (222mm direction) x (tip offset) determines
   outbound vs inbound: positive Z = outbound, negative Z = inbound

### lines.json Topology

The designer authors `lines.json` to declare track topology:

```mermaid
graph LR
    subgraph DESIGNER ["designer section (hand-authored)"]
        T["tracks:<br/>gw_cp_in_0, gw_cp_out_0,<br/>gw_near_main, gw_far_main,<br/>gw_platform, ..."]
        S["successors:<br/>gw_cp_in_0 → gw_cp_in_lead_0<br/>gw_cp_in_lead_0 → gw_near_main<br/>..."]
        CP["cps:<br/>EP definitions with<br/>type, in_track, out_track"]
    end

    subgraph COMPUTED ["natalie section (computed)"]
        LC["landing_chains"]
        EC["exit_chains"]
        PC["parking_chain"]
        HL["hold_loop"]
    end

    T --> S
    S --> LC
    S --> EC
    S --> PC
    S --> HL
```

### Compute Pipeline (3 Phases)

```mermaid
graph TD
    A["Compute (one button)"] --> P1
    subgraph P1 ["Phase 1: Validate"]
        V1["Check all gw_ tags exist<br/>with successors arrays"]
        V2["Check at least one EP<br/>with type/in/out"]
        V3["Successor graph connected?<br/>No orphan tracks?"]
        V1 --> V2 --> V3
    end
    P1 -- "pass" --> P2
    P1 -- "fail" --> REJ["REJECTED<br/>Fix topology, run again"]

    subgraph P2 ["Phase 2: Build Chains"]
        C1["Landing: BFS from gw_cp_in_N<br/>→ follow successors → gw_platform"]
        C2["Exit: BFS from gw_platform<br/>→ follow successors → gw_cp_out_N"]
        C3["Parking: gw_platform"]
        C4["Hold loop: gw_platform<br/>→ successors → gw_platform_parking<br/>→ append gw_platform"]
    end
    P2 -- "pass" --> P3
    P2 -- "fail" --> REJ2["Chain failure<br/>Fix successors"]

    subgraph P3 ["Phase 3: Extract Geometry"]
        G1["Priority 0: CP marker synthesis<br/>(uturn arcs from endpoints)"]
        G2["Priority 0.5: jpods_path attr<br/>(bezier pts from prior Compute)"]
        G3["Chain-walk: compute from<br/>predecessor/successor endpoints"]
        G4["Write lines.computed.json"]
        G1 --> G2 --> G3 --> G4
    end
```

### Station Tests

Run from the JPods Console when a template model is open:

```mermaid
graph TD
    subgraph TESTS ["Station Tests (unit tests)"]
        SH["Shuffle<br/>Sally: arrival → slot assign<br/>→ queue advance → departure"]
        DEP["Departure<br/>Pod exits via gw_cp_out"]
        ARR["Arrival<br/>Pod enters via gw_cp_in<br/>→ parks at assigned slot"]
        TRANS["Transit<br/>Pod passes through<br/>(no platform stop)"]
    end

    SH --> APPROVE
    DEP --> APPROVE
    ARR --> APPROVE
    TRANS --> APPROVE
    APPROVE["All pass → Approve template"]
```

### Approve Workflow

```mermaid
graph TD
    A["Open template model.skp"] --> B["Verify cp_marker placement"]
    B --> C["Run Compute"]
    C --> D{"Phase 1-3 pass?"}
    D -- "No" --> E["Fix model or lines.json"]
    E --> B
    D -- "Yes" --> F["Run Shuffle test"]
    F --> G["Run Departure test"]
    G --> H["Run Arrival test"]
    H --> I{"All tests pass?"}
    I -- "No" --> E
    I -- "Yes" --> J["Template approved<br/>Ready for network use"]
```

---

## 4. Connection Editing

### Creating a Connection

```mermaid
graph TD
    A["CP Calculate (show CPs)"] --> B["Connect Tool activates"]
    B --> C["Click CP A (FROM)<br/>Ring turns gold"]
    C --> D{"Direct or via waypoints?"}
    D -- "Direct" --> E["Click CP B (TO)"]
    D -- "Via waypoints" --> F["Press W at each<br/>intermediate point"]
    F --> G["Markers placed along route"]
    G --> E
    E --> H["Both seg_A_B and seg_B_A<br/>saved to network.json"]
    H --> I["Green planned line appears"]
```

### Deleting a Connection

```mermaid
graph TD
    A["In Connect Tool"] --> B["Shift+click on CP ring<br/>or draft line"]
    B --> C["Connection deleted from<br/>network.json"]
    C --> D["Both directions removed<br/>(seg_A_B and seg_B_A)"]
    D --> E["Viewport updates immediately"]
```

Connections can also be deleted via the Network Display panel in the Console
(x button next to each connection).

### Editing Waypoints on Existing Connection

```mermaid
graph TD
    A["Click existing connection's CP<br/>(ring turns white = inspect)"] --> B["Click again<br/>(ring turns cyan = edit)"]
    B --> C["Press W to add waypoints"]
    C --> D["Drag existing waypoint<br/>markers to reposition"]
    D --> E["Click destination CP<br/>to save changes"]
    E --> F["Bezier recomputes<br/>through new waypoint positions"]
```

### The Save-Build Cycle

After editing connections:

```mermaid
graph LR
    EDIT["Edit connections<br/>(Connect Tool)"] --> SAVE["Auto-saved to<br/>network.json"]
    SAVE --> BUILD["Build<br/>(regenerates all beams)"]
    BUILD --> VERIFY["Verify in viewport<br/>(Crew Health)"]
    VERIFY --> ANIM["Animate"]
```

### What network.json Contains

```
network.json
├── station_names        — display names for each station ID
├── connections          — all seg_ connections with from/to/waypoints
│   └── seg_S001.0_S002.1
│       ├── from: { station_id, cp_index }
│       ├── to:   { station_id, cp_index }
│       ├── via_markers: [marker positions]
│       └── tracks: { built geometry per direction }
├── natalie              — routing graph (computed by Build)
└── built_at             — timestamp (Natalie checks this vs Compute)
```

---

## 5. Populating and Animating

### Populate

**Toolbar:** Populate button (toggle: fill / clear)

```mermaid
graph TD
    A["Click Populate"] --> B{"Already populated?"}
    B -- "No" --> C["populate_fleet:<br/>Place pods at ~70% capacity"]
    C --> D["Pods placed at each station<br/>starting from highest slot (ps_max)<br/>working downward"]
    D --> E["Console pod list refreshes"]
    B -- "Yes" --> F["clear_all_vehicles:<br/>Remove all pods"]
    F --> G["Sally reset"]
    G --> H["Animation stopped if running"]
```

Populate is setup, not a test. It seeds pods so the student can run the
network. Populate never contains parking logic — only slot-index placement
on gw_platform.

### Animation Control

```mermaid
graph TD
    A["Click Animate"] --> B{"Current state?"}
    B -- "Stopped" --> C["AnimationV2.start"]
    C --> D["Natalie validates timestamps"]
    D --> E["Sally registers all stations"]
    E --> F["Random dispatch begins<br/>(CCW one-way flow)"]
    F --> G["Icon changes to Pause"]

    B -- "Running" --> H["AnimationV2.pause"]
    H --> I["All pods freeze in place"]
    I --> J["Icon changes to Resume"]

    B -- "Paused" --> K["AnimationV2.resume"]
    K --> F
```

**Also available from menu:** Extensions > JPods > Animation > Start/Resume,
Freeze, High Frequency Dispatch.

### Agent Roles During Animation

```mermaid
graph TD
    subgraph DISPATCH ["Dispatch Cycle"]
        S1["Sally: check parking slots"] --> S2["Sally: select pod for dispatch"]
        S2 --> S3["Natalie: plan route<br/>(successor chains, CCW)"]
        S3 --> S4["Nora: execute route<br/>(mm traveled along FollowMe)"]
    end

    subgraph RULES ["Movement Rules"]
        R1["One-way only<br/>(no reversing)"]
        R2["3m minimum spacing<br/>(centerpoint to centerpoint)"]
        R3["Lead vehicle moves first<br/>(no passing)"]
        R4["CCW circulation<br/>within stations"]
    end

    S4 --> R1
    S4 --> R2
    S4 --> R3
    S4 --> R4
```

### Sally Parking Rules

```mermaid
graph TD
    A["Pod arrives at station"] --> B["Sally assigns parking slot<br/>(on gw_platform only)"]
    B --> C["Positive stop enforced<br/>(no pod passes highest empty slot)"]
    C --> D{"Pod dispatched?"}
    D -- "Yes" --> E["Remaining pods advance<br/>(shuffle forward, CCW only)"]
    E --> F["No backward movement<br/>(Rule 9a)"]
    D -- "No" --> G["Pod holds at assigned slot"]
```

### Camera Follow

**Toolbar:** Camera button (toggle)

```mermaid
graph TD
    A["Select a pod in viewport"] --> B["Click Camera button"]
    B --> C["Camera translates with pod"]
    C --> D["User can orbit/zoom freely<br/>(viewing angle preserved)"]
    D --> E{"Stop follow?"}
    E -- "Click Camera again" --> F["Camera released"]
    E -- "Animation stops" --> F
    E -- "Pod arrives" --> F
```

Camera applies the pod's movement delta as translation only — it does NOT
lock the viewing angle. The user maintains full orbit/zoom control while
the camera tracks the pod's position.

---

## 6. JPods Travel — Booking Trips

### Trip Flow

**Toolbar:** Travel button (opens phone-app-style dialog)

```mermaid
graph TD
    A["Click Travel button"] --> B["Phone app opens"]
    B --> C["Select origin station<br/>(from station_names list)"]
    C --> D["Select destination station"]
    D --> E["Price + travel time estimated"]
    E --> F["Click Book"]
    F --> G["Natalie plans route"]
    G --> H["Sally dispatches pod<br/>from origin station"]
    H --> I["Camera follows pod"]
    I --> J["Trip progress bar updates"]
    J --> K{"Arrived?"}
    K -- "No" --> L["Poll status every 1s:<br/>waiting → in_transit"]
    L --> J
    K -- "Yes" --> M["Camera follow releases"]
    M --> N["Pod parks at Sally slot"]
    N --> O["Arrival screen shows"]
```

### Station Selection

Only stations with `has_platform=true` (set by Build) appear in the picker.
Station names come from `network.json station_names` with case-insensitive
lookup.

### Camera During Travel

```
camera.eye    += pod_movement_vector
camera.target += pod_movement_vector
camera.up     = unchanged (user's viewing angle preserved)
```

Set your preferred camera angle BEFORE clicking Book, or adjust freely
at any time DURING travel.

---

## 7. Key Rules — The Non-Negotiables

### Rule 12: One-Way CCW Circulation

All JPods guideways are one-way. All station circulation is counter-clockwise.

```mermaid
graph LR
    subgraph STATION ["Station (viewed from above)"]
        direction LR
        CP0["CP 0"] --> NM["near_main<br/>(platform side)"]
        NM --> CP1["CP 1"]
        CP1B["CP 1"] --> FM["far_main<br/>(opposite side)"]
        FM --> CP0B["CP 0"]
    end
```

```
     CP 0                                    CP 1
      |                                        |
gw_cp_in_0 --> near_main ----------------> gw_cp_out_1  (CP0→CP1)
gw_cp_out_0 <-- far_main <---------------- gw_cp_in_1   (CP1→CP0)
      |                                        |
     uturn_0                               uturn_1
```

A pod arriving at CP1 cannot reach the platform directly (platform is on
near_main side, CP1 inbound feeds far_main). It must traverse 3/4 of the
CCW loop via the uturn at CP0.

### Model vs Network Boundary

| | Model Scope | Network Scope |
|---|---|---|
| **Files** | lines.json, lines.computed.json, model.skp | network.json, \<Network\>.skp |
| **Location** | templates/track_formations/\<template\>/ | ~/Documents/skp_jpods/\<Network\>/ |
| **Written by** | Compute | Build |
| **Coordinate frame** | Model-local | World-space |

**Never cross:**
- Compute must never read network.json
- Build must never modify template files
- Model tests must never require a network context

### Pure Math, No Edges

All cp_marker geometry is read as point positions and distances. No edge
objects, edge lengths, model.bounds.center, or parent transforms in Compute.
If Priority 2 (bbox fallback) fires for a known Bezier track, the model
geometry is wrong — fix the model, not the code.

### All Datetimes UTC

Every stored datetime uses UTC ISO-8601 with Z suffix. Display converts to
local. This applies to all files, logs, and timestamps across all JPods
programs (Axiom 14).

### Animation is Sacred (Rule 24)

Nothing degrades the animation tick. No file I/O, no JS polling, no
diagnostic logging on the tick path. Log to RAM, flush on a timer or on
animation stop. If a feature would cause even a single tick hitch, refuse
it or defer it.

---

## Toolbar Reference

Left to right, the JPods toolbar:

| # | Button | Action |
|---|--------|--------|
| 1 | Console | Open JPods Console (all controls) |
| 2 | Place Structure | Select + place stations/traffic circles |
| 3 | CP Calculate | Toggle: show CPs + activate Connect Tool / hide CPs |
| 4 | Populate | Toggle: fill ~70% capacity / clear all vehicles |
| 5 | Travel | Open JPods Travel phone app |
| 6 | Camera | Toggle: follow selected pod / stop following |
| 7 | Animate | Toggle: Start / Pause / Resume animation |
| 8 | Crew Health | Each agent checks their domain |
| 9 | Note | Enter comment mode (annotate next button click) |

---

## File Structure Reference

```
su_jpods/
├── main.rb                    — Entry point, menus, toolbar
├── boot.rb                    — Module loader (authority for load order)
├── jpod_constants.rb          — All engineering constants
├── jpod_terrain.rb            — Terrain detection + ray-cast
├── jpod_path_builder.rb       — Arc insertion, terrain snap, vertical profile
├── jpod_guideway.rb           — Beam geometry, columns, solar panels
├── jpod_structure_tool.rb     — Place stations, detect + label CPs
├── jpod_console.rb            — Main console (HTML dialog)
├── jpod_guideway_compat.rb    — Compatibility bridge (populate, animate, clear)
├── tools/
│   └── connect_tool.rb        — Interactive CP connection tool (W for waypoints)
├── compute/
│   ├── compute.rb             — Orchestrator (one button)
│   ├── compute_validator.rb   — Phase 1: validate topology
│   ├── compute_chain_builder.rb — Phase 2: build chains
│   ├── compute_geometry.rb    — Phase 3: extract geometry
│   └── compute_writer.rb      — Write lines.computed.json
├── animation/
│   └── animation.rb           — AnimationV2 (start/pause/resume)
├── dialogs/                   — HTML dialog files
├── templates/
│   ├── track_formations/      — Station + traffic circle models
│   ├── structures/            — Support columns (auto-discovered)
│   ├── tracks/                — Track cross-section profiles
│   └── r_stocks/              — Pod vehicle models
└── readmes/                   — Documentation
```

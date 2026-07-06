# Noelle Data-Driven Network Design — Process Document
**Established:** 2026-07-05
**Owner:** Noelle (network design), with Alice (economics), Allie (cross-domain memory)
**Action:** Read before any network design session

---

## What We Built

A workflow where Noelle proposes JPods network layouts based on real government data, then iterates with a human designer who applies local knowledge. Each iteration is recorded. The delta between Noelle's proposal and the designer's corrections is where learning happens.

---

## The Three Data Layers

Every station placement decision is informed by three overlapping data layers:

| Layer | Question it answers | Data source | Route-Time overlay |
|-------|-------------------|-------------|-------------------|
| **Traffic density (AADT)** | Where are the cars? | SC DOT traffic counts — 12,000+ stations statewide, AADT per road segment | `overlays/aadt.geojson` → AADT button |
| **Accident heat map** | Where are people dying? | NHTSA FARS — fatal crash lat/lon, severity, conditions. 1,019 SC crashes in 2022 alone | `overlays/accidents.geojson` → Accidents button |
| **Pedestrian density** | Where are people walking? | WalkScore API, Strava Metro (free for planners), StreetLight Data, Replica | `overlays/mobility.geojson` → Mobility button |

**The three-way intersection** of all three layers produces the strongest station placement:
- Dense walking = WHERE to place the station (demand node)
- High AADT arterial nearby (10,000+) = WHY the station pays back (car trips to displace)
- Accident corridor overlap = political and safety justification

---

## The Economic Threshold

**10,000 displaced car-trips per day** = 7-year payback.

This is the fundamental number. Every proposed station must be tested against it:
- Population within walk radius × modal shift % × trips/person/day ≥ 10,000
- The walk radius is not fixed — it scales with density (denser = shorter radius, more stations)
- Working values: 15-minute walk (1.2 km) in urban, 20-minute (1.6 km) in suburban

Alice validates the economics: fare = minimum_fee + (distance_km × rate_per_km). Revenue per station = trips × fare. Payback = capital_cost / (daily_revenue × 365).

---

## JPods Is Middle-Mile

**JPods connects commercial nodes — not neighborhoods internally.**

- Stations sit at commercial nodes on the BOUNDARY of neighborhoods
- Strip malls, transit stops, grocery stores, pharmacies — natural Last-Mile handoff points
- JPods carries passengers AND freight/logistics TO the neighborhood, increasing proximity

**Last-Mile (not JPods):** walking, biking, scooters, Uber, Local-Use Vehicles (golf-cart style), proximity itself.

**Heavy-lift (not JPods):** airplanes, freight railroads — city-to-city backbone.

**The Physical Internet analogy:**
- JPods = WiFi (Middle-Mile, neighborhood-to-neighborhood)
- Last-Mile modes = Bluetooth (station-to-door)
- Airlines + freight rail = fiber backbone (city-to-city)

---

## Capacity — The Station Bottleneck

| Parameter | Value |
|-----------|-------|
| Speed | 20 m/s (72 km/h, 45 mph) |
| Vehicle length | 2.3 m |
| Headway | 0.5 seconds |
| Spacing | 12.3 m center-to-center |
| Guideway flow | 5,854 vehicles/hr/direction |
| Occupancy | 1.57 people/pod |
| Guideway capacity | **9,191 people/hr/direction** |
| Station dwell | 30 seconds per pod |
| One loading slot | 120 pods/hr = 188 people/hr |
| Full guideway saturation | 49 loading + 49 unloading slots |

**The bottleneck is always station dwell time, not guideway capacity.** The guideway has 49× more capacity than one station slot. Station slot count (Sally's system) is the primary design variable.

**Land use comparison:** 49 loading slots = 2,450 sq ft. One car's total footprint = 2,642–3,470 sq ft (3–8 parking spaces + road area). A full terminus uses less ground than one car.

**Guideway footprint:** 3 sq m per column, every 25 m = 6.6% of a two-lane road's ground area. Between columns = free for bikes, pedestrians, commerce.

---

## Mesh Over Capacity — Parallel Processors

**Don't build one fat pipe. Build a mesh so there is never a stoppage.**

A single guideway can theoretically replace a 45,000 car/day road. But a single point of failure means any stoppage halts the corridor. The right design: multiple parallel paths between any two stations. If one segment goes down, Natalie reroutes instantly.

**JPods sells certainty, not speed.** A 15-minute trip that is always 15 minutes is worth more than a 10-minute trip that is sometimes 45 minutes. Alice can charge a premium for guaranteed arrival because the mesh makes that guarantee credible.

---

## The Design Workflow

### Noelle Proposes

```bash
python3 route_time/noelle_propose.py propose
```

Noelle places structures at intersections identified by AADT data:
- **Circles at corridor intersections** (junctions — 4 CPs for routing)
- **Stations mid-block between circles** (stops — 2 CPs)
- ~1:1 ratio of circles to stations (circles are the connective tissue)
- Structures placed but **NOT connected** — designer reviews first

**Critical lesson learned 2026-07-05:** Stations have 2 CPs (linear). Circles have 4 CPs (junctions). A network of mostly stations creates disconnected islands. Circles at every intersection where corridors cross is what makes the mesh work.

### Designer Reviews

The designer applies local knowledge the data cannot see:
- Move stations to where hotels/commercial clusters actually are
- Add structures the data missed (local landmarks, campus nodes)
- Remove structures that don't make sense on the ground
- Adjust headings to align with actual road geometry

### Connect

- **Auto-Connect** for nearest-neighbor connections
- **Manual CP clicks** for specific connections (closest-open-CP logic)
- **Bridge gaps** between disconnected components

### Secondary Network (Parallel Processors)

After the primary network is connected, add a secondary mesh:
- Secondary circles offset ~500m from primary circles
- Secondary stations between secondary circles
- Cross-connectors linking primary to secondary
- Result: multiple parallel paths between any two stations

### Snapshot and Iterate

```bash
python3 route_time/noelle_propose.py snapshot "designer moved US276 stations to Haywood Mall"
python3 route_time/noelle_propose.py diff       # what changed since last snapshot
python3 route_time/noelle_propose.py history     # all iterations
```

Each snapshot records:
- Full .jpd file (loadable in Route-Time)
- Topology (stations, circles, connections, components, orphans, degree distribution)
- Spatial metrics (coverage, spacing)
- Designer's explanation of WHY changes were made

**The delta between Noelle's proposal and the designer's corrections is where learning happens.** Over many iterations across many cities, Noelle learns what designers value that data alone cannot capture.

---

## Noelle's Vector Store

Location: `~/Allie/.chroma_db_noelle`
Script: `~/Allie/scripts/noelle-vectorstore.py`

| Command | What it does |
|---------|-------------|
| `seed` | Foundational design rules (payback threshold, three layers, spacing, capacity) |
| `index` | Knowledge files from readmes, agents, wisdom, TFTS, Route-Time docs |
| `ingest-network` | Pulls current network descriptor from Route-Time `/api/network/describe` |
| `search "query"` | Semantic search across all knowledge |
| `stats` | Chunk counts by domain and category |

The vector store holds:
- Design rules (payback, spacing, mesh, capacity, Middle-Mile boundary)
- Data source references (SC DOT AADT, NHTSA FARS, WalkScore, pedestrian platforms)
- Greenville AADT data (all stations with 10,000+ AADT, 2024)
- Network descriptors (topology, spatial, per-structure positions and connections)
- TFTS files (try-fail-try-succeed arcs from all domains)

---

## Route-Time Overlays

Overlay data files live in `route_time/overlays/`:

| File | Source | What it shows |
|------|--------|--------------|
| `aadt.geojson` | SC DOT 2024 traffic counts | Traffic volume circles — blue (low) to red (high AADT) |
| `accidents.geojson` | NHTSA FARS 2022 | Fatal crash locations — red circles sized by fatalities |
| `mobility.geojson` | (pending) | Pedestrian density heat map |

Toggle via buttons in the Overlays section of JPods Tools palette.

---

## Network Descriptor API

`GET /api/network/describe` returns a structured view of the current network:

```json
{
  "network_id": "noelle_greenville_v3",
  "summary": "Network centered at (34.81, -82.36). 30 stations, 32 circles...",
  "spatial": { "center": [...], "extent_km": [...], "nn_spacing_m": {...} },
  "topology": { "stations": 30, "circles": 32, "connected_cps": 126, "open_cps": 62, "components": 1, "orphans": [], "degree_distribution": {...} },
  "structures": [ { "id": "s1", "type": "station", "lat": ..., "lon": ..., "neighbors": [...], "open_cps": [...] }, ... ]
}
```

Quality signals from the descriptor:
- Orphaned structures (all CPs open) = unfinished connections
- Multiple components = disconnected sub-networks
- Degree-1 nodes = dead ends
- Large nn_spacing gaps = coverage holes
- High open CP count = under-connected network

---

## Established Network Spacing (from 25+ networks)

| Network type | Avg NN spacing | Grid size |
|-------------|---------------|-----------|
| Dense urban (NYC, Cologne, Hamburg) | 600–700m | ~0.4 × 0.4 mi |
| Standard grid (OKC, Tulsa, Spokane, Arlington, Boulder) | 780–820m | **~0.5 × 0.5 mi** |
| Suburban/spread (Miami, Tucson, Omaha) | 930–1000m | ~0.6 × 0.6 mi |
| Compact campus (West Point) | 450–470m | ~0.3 × 0.3 mi |

**Bill's natural grid is ~½ mile × ½ mile (800m).** This is consistent across 15+ networks built by hand. The ½-mile grid puts every point within a ~6 minute walk of a station.

---

## The Agent Roles in Network Design

| Agent | Role | What they do |
|-------|------|-------------|
| **Noelle** | WHERE | Propose station placement from three data layers. Validate topology. Document iterations. |
| **Alice** | WHETHER | Validate economics: fare revenue vs infrastructure cost. 7-year payback test. Track ticket sales per station/corridor. |
| **Natalie** | HOW | Route pods through the network. Optimize for congestion + Alice's price signals. |
| **Sally** | CAPACITY | Manage loading slots at each station. Slot count scales with demand. |
| **Allie** | MEMORY | Cross-domain synthesis. Persist lessons across sessions. Flag patterns. |

Noelle proposes, Alice validates, Natalie routes, Sally loads, Allie remembers.

---

## What Noelle Learned — 2026-07-05

1. **Circles are the connective tissue.** A network of mostly stations creates islands. Circles at every intersection where corridors cross is what makes the mesh. Ratio should be ~1:1 circles to stations.

2. **The data gives corridors, not stations.** AADT tells you which roads carry traffic. The designer tells you where on those roads the commercial nodes are (hotels, malls, transit hubs). The data is necessary but not sufficient.

3. **Secondary mesh = parallel processors.** Offset ~500m from primary corridors with cross-connectors. Multiple paths between any two stations. Never a single point of failure.

4. **Auto-connect is conservative.** It skips boundary-facing CPs. After auto-connect, manually bridge disconnected components by finding closest open CP pairs between components.

5. **Spacing is not arbitrary.** 25+ networks built by the same designer converge on ~½ mile (800m) spacing. This is an empirical finding, not a design rule — but it's consistent enough to use as a default until data says otherwise.

---

## Energy — Not for Payback

JPods gathers solar energy over guideways for **ruggedness**, not payback. The focus is on **Economic Work** — force applied to mass to drive commerce. Energy independence makes the system resilient; the economics are driven by displaced car trips and increased proximity.

---

## Files

| File | Location | Purpose |
|------|----------|---------|
| `noelle_propose.py` | `route_time/` | Proposal workflow: propose, snapshot, diff, history |
| `noelle-vectorstore.py` | `~/Allie/scripts/` | Vector store: seed, index, ingest-network, search |
| `.chroma_db_noelle/` | `~/Allie/` | ChromaDB vector store |
| `noelle_history/` | `route_time/` | Snapshot .jpd files and metadata |
| `overlays/` | `route_time/` | AADT, accident, mobility GeoJSON data |
| This file | `~/Allie/readmes/` | Process documentation |

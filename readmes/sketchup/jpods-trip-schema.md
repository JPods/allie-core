# JPods Trip JSON Schema
**Last Updated:** 2026-05-16
**Purpose:** Defines the trip.json format written by Natalie and read by the animator.
Every vehicle movement — passenger, positioning, or queue management — is a trip.

---

## Schema

```json
{
  "nora_id":         "NORA_0003",
  "mission":         "passenger",
  "payload": {
    "passengers":    2,
    "mass":          180
  },
  "origin_platform": "S048.P1",
  "dest_platform":   "S049.P1",
  "origin_slot":     null,
  "dest_slot":       null,
  "triggered_by":    null,
  "trip":            ["line_id_1", "line_id_2", "..."]
}
```

---

## Mission Types

| Mission | Payload | Graph | Description |
|---------|---------|-------|-------------|
| `passenger` | passengers > 0, mass > 0 | ✅ | Revenue trip. Vehicle carries passengers from one station platform to another. |
| `dead_head` | passengers = 0, mass = 0 | ✅ | Natalie clears a platform for an inbound vehicle. Destination is another station. |
| `station_loop` | passengers = 0, mass = 0 | ✅ | Vehicle loops back to its own station's `platform_in` queue. No payload, no destination change. |
| `rebalance` | passengers = 0, mass = 0 | ✅ | Proactive Natalie network balancing. No specific inbound trigger. |
| `shuffle` | passengers = 0, mass = 0 | ❌ (count only) | Nora moves forward within the same platform to occupy a vacated higher slot. Sub-platform distance. Too frequent to display on graph without distortion. |

**Constants (Ruby):** `JPods::JPodGuideway::TRIP_MISSIONS` — all five.
`JPods::JPodGuideway::TRIP_MISSIONS_GRAPHED` — excludes `:shuffle`.

---

## Field Definitions

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `nora_id` | string | yes | Vehicle identifier, e.g. `NORA_0003` |
| `mission` | string | yes | One of: `passenger`, `dead_head`, `station_loop`, `rebalance`, `shuffle` |
| `payload.passengers` | integer | yes | 0–6. Most passenger trips carry 1. Dead-head, loop, rebalance, shuffle = 0. |
| `payload.mass` | number | yes | kg. 0 for non-passenger missions. Typical passenger trip: 40–500 kg. |
| `origin_platform` | string | yes | Platform ID where trip begins, e.g. `S048.P1`. Always a `platform`-tagged guideway — never `platform_in`. |
| `dest_platform` | string | yes | Platform ID where trip ends. Always a `platform`-tagged guideway. Same as origin for `station_loop`. |
| `origin_slot` | integer | shuffle only | Slot number being vacated. Used for precise positioning without geometric inference. |
| `dest_slot` | integer | shuffle only | Slot number being occupied. |
| `triggered_by` | string or null | recommended | `nora_id` of the vehicle whose action caused this trip to be issued. Null for `passenger` and proactive `rebalance`. Required for `dead_head`, `station_loop`, and `shuffle` — enables audit trail. |
| `trip` | array of strings | yes | Ordered line IDs. For `shuffle`, contains the synthetic platform host line (`__platform__Sxxx.P1`). |

---

## Platform Rule

**Trips always start and end at `platform`-tagged guideways, never `platform_in`.**

`platform` = loading and unloading. Passengers board and alight here.
`platform_in` = staging only. Vehicles wait here until a `platform` slot opens.

Vehicles on `platform_in` must shuffle forward to `platform` (7-second delay) before
a passenger trip can be assigned. Natalie issues a `shuffle` trip for this movement.

---

## Natalie Dispatch Logic (arrival clearing)

When vehicle X is declared inbound to station S:

1. Natalie checks S's `platform` occupancy.
2. If full: issues `dead_head` or `station_loop` trips to enough parked vehicles
   to open 1 slot. `triggered_by` = X's `nora_id`.
3. Vehicle X arrives, parks at `platform`.
4. Natalie issues `shuffle` trips to `platform_in` vehicles to fill vacated slots.
5. If X's `platform` slot is departure-ready: Natalie assigns `passenger` trip.

---

## Console Graph — Trip Categories

The JPods Console displays a bar or pie chart of trips by mission:

- **Graphed:** `passenger`, `dead_head`, `station_loop`, `rebalance`
- **Counted only (not graphed):** `shuffle`

**Why exclude shuffle from graph:**
Shuffle trips are sub-platform movements triggered by every departure. On a busy
network they outnumber passenger trips 2:1 or more. Including them on the graph
collapses the signal (passenger:dead_head ratio) into noise.

**Network health signal:**
- High `passenger` / low `dead_head` → well-placed stations, balanced demand.
- High `dead_head` → stations are in the wrong places or demand is asymmetric.
- High `station_loop` → platforms too small for the arrival rate.
- High `rebalance` → demand is time-asymmetric (commute peaks).

This ratio guides physical network design: where to locate stations, how many
platforms per station, and which connections carry the most load.

---

## Physical Network Value

Trip mission data is as valuable for real JPods networks as for simulation:
- `passenger:dead_head` ratio is a direct measure of network efficiency
- `station_loop` frequency indicates platform capacity shortfall
- `rebalance` frequency indicates demand asymmetry across the day
- `shuffle` count (separate) indicates queue depth and platform length adequacy

Simulation data can be used to justify station placement decisions before
construction — the graph is a design tool, not just a monitoring tool.

---

## JPods as Middle-Mile — The Physical Internet

**JPods is the WiFi of the Physical Internet. It is a Middle-Mile solution.**

WiFi connects your device to the internet backbone — it does not reach everywhere,
and it does not need to. It covers the middle distance efficiently so that the
last few feet (Bluetooth, cable) can handle the endpoints.

JPods covers the Middle Mile: station to station, neighborhood to neighborhood,
campus to transit hub. It does not need to reach your front door. It needs to
reach close enough that Last-Mile modes — walking, bikes, ride-hail, e-scooters —
can bridge the gap.

**Last-Mile modes are the Bluetooth of the Physical Internet:**

| Last-Mile Mode | Role |
|----------------|------|
| Walking / pedestrians | Shortest gaps — 0 to 400m |
| Bicycles | 400m to 2km — the primary Last-Mile partner |
| E-scooters / e-bikes | 400m to 3km — weather-sensitive |
| Ride-hail (Uber, Lyft) | 1km+ — on-demand, serves people who cannot walk or bike |
| Local buses / circulator | Fixed Last-Mile routes feeding JPods stations |

**JPods infrastructure serves all Last-Mile modes directly:**
- Guideway structure provides lighting along the path — benefits pedestrians and cyclists
- Cameras mounted on guideway structure give Natalie real-time bike/pedestrian counts
- Station platforms are designed for bike parking and scooter docking
- JPods pricing (weather factor + price factor) is calibrated to keep Last-Mile modes
  healthy — JPods should not undercut bikes in good weather; it should complement them

**The design principle:**
In dense urban areas, station placement is correct when any point in the service
area is reachable by bike in under 7 minutes or on foot in under 15 minutes.
These are not hard limits — they are the target design envelope. The relationship
between mesh density and demand density will be discovered as networks are
deployed and evolve; no fixed ratio exists yet.

**JPods carries cargo as well as passengers.**
A JPods station is also a logistics node. Proximity to the network means proximity
to stores, factories, warehouses, and delivery hubs. The same mesh that moves
people moves goods. This changes how "access" is defined for station siting:
a station placed near a residential cluster also serves that cluster's logistics
needs — groceries, parcels, light freight — without trucks on residential streets.
The cargo function reinforces the passenger function: more reasons to locate a
station in a given place, more revenue streams per station, more resilience.

A JPods network with good Middle-Mile coverage and a healthy Last-Mile ecosystem
is more resilient than either mode alone — bad weather shifts demand to JPods;
good weather shifts it to bikes. Natalie manages this equilibrium in real time.

---

## JPods as a Circulatory System

Blood does not run once a week. It runs continuously, streaming nutrients to
where the body needs them and carrying waste away on the same pass.

JPods is the circulatory system of a city. Small packets — up to 500 kg — stream
resources to need on demand and haul away waste product on a continuous basis.
This is not batch delivery. It is flow. The distinction matters:

| Batch (current) | Flow (JPods) |
|-----------------|--------------|
| Trucks, once or twice daily | Continuous, on demand |
| Goods sit in inventory | Goods arrive as needed |
| Waste collected weekly | Waste streamed out continuously |
| Recycling degraded by time | Recycling sorted fresh |
| Traffic spikes at delivery windows | Smooth, above-street, no congestion |

**Waste streaming — the recycling multiplier:**

Current residential waste collection: mixed, compressed, collected weekly.
By the time it reaches a sorting facility it is rotted, compacted, and
difficult to identify. Items that could be recycled go to landfill because
they are too degraded to separate economically.

JPods waste streaming changes the equation:
- Waste leaves the household continuously, sorted at the station by category
- It arrives at the sorting facility fresh — organic, recyclable, residual
  separated at the source, not at the end
- Fresh sorting recovers materials that currently go to landfill
- Organic waste arrives before decomposition, enabling composting and biogas
  at far higher rates than weekly collection allows
- The recycling rate improvement is structural, not behavioral — it does not
  require residents to sort better; it requires the system to move faster

The environmental and fiscal return compounds: higher recycling rates reduce
landfill tipping fees (city cost), increase commodity recovery (city or carrier
revenue), and reduce truck collection costs (fewer collection vehicles needed).

---

## The City Fiscal Case — Proximity as an Undervalued Asset

City planners think about mass transit moving people. They do not think about
logistics and proximity. This is a blind spot — and it is where JPods makes its
strongest fiscal argument.

### Parking Lots → Tax Revenue

A surface parking lot is among the least productive uses of urban land:
- Generates minimal property tax (low assessed value, no structure)
- Generates no sales tax
- Consumes city maintenance budget (storm drainage, repaving)
- Removes land from the tax base permanently as long as cars require it

JPods reduces car trips. Fewer car trips means less parking demand. Less parking
demand means parking lots can be converted to buildings — retail, housing, mixed use.

**The conversion math for a city:**
- Parking lot: near-zero property tax, zero sales tax
- Retail/mixed-use building: significant property tax + sales tax from tenants
- The delta is a direct contribution to city fiscal health with no new city spending

### Lane-Miles → Maintenance Savings

Every lane-mile of road carries an annual maintenance cost. Fewer vehicle trips
means roads last longer and require less frequent resurfacing. For a city carrying
significant road maintenance debt (most American cities), this is not a small number.

JPods does not eliminate roads — but it reduces the vehicle load on them, which
extends pavement life and reduces the lane-mile maintenance burden year over year.

### Logistics Proximity — The Unspoken Benefit

A JPods station is a logistics node. Every business within the Last-Mile radius
of a station gains access to the cargo network:
- Retail: faster restocking, smaller back-of-house inventory requirements
- Restaurants: fresher supply chain, reduced delivery truck traffic
- Light manufacturing: access to regional distribution without truck dependency

This is access to logistics that currently requires truck infrastructure. JPods
provides it on a guideway that runs above the street, does not congest intersections,
and does not damage pavement.

### Carrier Allies — UPS, FedEx, DHL, Amazon

Last-mile delivery is the most expensive segment of the parcel supply chain —
typically 50–60% of total delivery cost. Carriers run trucks from regional hubs
to neighborhoods, often to deliver one or two packages per stop.

JPods changes the economics:
- JPods handles the Middle Mile: regional hub → neighborhood JPods station
- Cargo bikes handle the Last Mile: station → door (400m–2km)
- Cargo bikes are cheaper to operate, faster in dense urban areas, and require
  no parking or idling at curbs

**UPS, FedEx, DHL, and Amazon have a direct financial interest in JPods networks
being built.** They are natural allies for permitting and right-of-way:
- Lower delivery cost per package
- Fewer trucks on city streets (reduces their fleet maintenance and fuel costs)
- Faster urban delivery times (cargo bikes outperform trucks in congested areas)
- ESG / emissions reduction without sacrificing throughput

**The current carrier truck problem:**
- Carrier trucks handling Middle-Mile delivery add directly to traffic congestion
- After completing last-mile delivery drops, trucks dead-head (run empty) back
  to the warehouse — paying full operating cost (fuel, driver, depreciation)
  for zero revenue miles
- Empty trucks in traffic are pure cost with no throughput benefit

**How JPods changes the carrier dead-head equation:**
- JPods delivers pre-sorted goods from the warehouse directly to the neighborhood
  JPods station — no truck in traffic, no congestion contribution
- Cargo bikes distribute from the station to the door
- JPods vehicles must also dead-head back to the warehouse after delivery —
  but at approximately 1/10th the operating cost of a truck and with zero
  traffic impact (guideways are above the street)
- The dead-head cost on JPods is so low it approaches the cost of not running
  the return trip at all

These carriers have lobbying capacity, relationships with city councils, and
existing real estate at logistics nodes. A carrier that endorses JPods to a
city planning commission carries more weight than any transit advocacy group.

**The pitch to a carrier:**
JPods cuts your last-mile cost. You operate fewer trucks. Your cargo bikes run
from our stations. We handle the middle mile; you own the last mile. Your drivers
become cargo bike operators — lower vehicle cost, no fuel, no parking tickets.

**The pitch to a city council:**
JPods does not ask a city to spend money. It asks a city to permit a private
infrastructure investment that:
1. Reduces parking demand → converts low-tax land to high-tax land
2. Reduces road wear → extends pavement life, defers maintenance spending
3. Creates logistics access → attracts and retains commercial tenants
4. Reduces road construction needs → fewer lane-miles required as the city grows

The fiscal return is structural and compounding. It does not require ridership
subsidies. It improves the city's balance sheet whether or not the city owns
the network.

---

## Demand Signal Sources — Station Placement and Natalie Dispatch

Natalie uses multiple demand signals both for pre-construction station siting and
for real-time dead-head dispatch decisions. Signals stack — no single source is
authoritative alone.

### Station Placement (pre-construction)

| Signal | Source | What it shows |
|--------|--------|---------------|
| Cellphone density at pedestrian speeds | Carrier aggregate / anonymized mobility data | Where people walk — the best proxy for latent transit demand before a system exists |
| Historical transit ridership | Existing bus/rail data | Established O-D patterns; where people already go |
| Customer phone app requests | JPods app — requested pickup/dropoff locations | Active demand signal; where people say they want to go |
| Land use and zoning | City GIS | Future demand — residential density, employment centers, schools |
| Event calendars | Venue APIs | Spike demand — stadiums, convention centers, campuses |

The pedestrian-speed cellphone signal is particularly powerful: it reveals
desire lines that existing transit does not serve. A cluster of people walking
slowly through an area with no transit stop is a station candidate.

### Natalie Real-Time Dispatch

The same signals inform Natalie's dead-head and rebalance decisions:

| Signal | How Natalie uses it |
|--------|---------------------|
| Cellphone density (live) | Pre-position vehicles toward emerging crowd concentrations before requests arrive |
| Time of day | Shape the baseline dispatch curve — morning peak, midday lull, evening peak, overnight minimum; Natalie holds more vehicles at residential stations at 07:00, more at employment centers at 17:00 |
| Historical patterns (time-of-day) | Refine the baseline with observed ridership — actual peaks may differ from expected by route, season, or day of week |
| Phone app bookings (confirmed) | Hard demand — dispatch dead-head to destination station before passenger arrives |
| Phone app browse/search (soft signal) | Probabilistic demand — partial pre-positioning |
| Current vehicle distribution | Supply side — which stations are over- or under-stocked |

### Demand Modulation Factors

Two relative factors (1–5 scale) that Natalie monitors continuously:

**Weather factor (1–5)**
- 1 = severe (ice, heavy rain, extreme heat) — bike/pedestrian share drops, JPods demand spikes
- 3 = neutral
- 5 = delightful (clear, mild, low wind) — bike/pedestrian share rises, JPods demand softens

**Price factor (1–5)**
- Natalie adjusts fare dynamically to spread demand across time and network
- Low price → more JPods use, even in good weather (signal: charging too little)
- High price → people bike even in bad weather (signal: charging too much)
- Cameras on the guideway network monitor actual bike and pedestrian activity
- Natalie cross-references camera counts against weather factor and price factor
- If bike counts are high during bad weather: price is too high
- If JPods is full during delightful weather: price is too low
- Target equilibrium: price that keeps JPods near capacity during bad weather,
  while gracefully yielding demand to bikes/walking when weather is good

**Guideway lighting** — JPods guideways provide lighting along their path, benefiting
pedestrians and cyclists. This is infrastructure that serves Last-Mile modes directly.
Camera placement on guideway structure gives Natalie the bike/pedestrian count data.

**Natalie dispatch priority order:**
1. Confirmed app bookings (hard demand — dispatch immediately)
2. Historical pattern + time-of-day (scheduled rebalance)
3. Live cellphone density spike (reactive pre-position)
4. Network imbalance alone (low-priority rebalance, fill idle capacity)

Dead-head trips issued against confirmed bookings carry `triggered_by` = booking ID.
Proactive rebalance trips carry `triggered_by` = demand signal source (e.g. `"cellphone_density"`, `"historical_pattern"`, `"app_booking:BK-00421"`).

This architecture means Natalie is running a continuous demand forecast, not just
reacting to arrivals. The simulation (using randomized demand) is the training ground
for the real dispatch algorithm.

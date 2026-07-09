# Signal Loop & Station Economics

**Established:** 2026-07-06
**Applies to:** MeshMobility, Noelle, all JPods programs
**Principle:** Signaling versus planning. The wisdom of the many.

---

## The Signal Loop

Every domain in the JPods ecosystem follows the same loop:

```
Data-driven draft → Human reality → Measure the gap → Feed it back
```

No loop works without memory. No memory works without retrospection.

| Domain | Proposes | Adjusts | Scores | Learns |
|--------|---------|---------|--------|--------|
| Network design | Noelle | Designer | Station report delta | Noelle |
| Commerce | Alice | User | Transaction patterns | Alice |
| Vehicle routing | Natalie | Physical constraints | Trip telemetry | Natalie |
| Station ops | Sally | Traffic reality | Slot utilization | Sally |
| Quiz answers | Alice | Employee | Score % | Alice |

This is not central planning. This is a signal system that gets smarter from every
participant. Noelle doesn't plan a network — she reads signals and proposes. The
designer adds signals Noelle can't see. The comparison measures. The delta feeds back.
Next proposal is better.

Scale that to every JPods city. Every designer adjustment in Tulsa teaches Noelle
something that improves her draft for Austin. The wisdom of the many, accumulated
through signaling, not directed by anyone.

---

## Economic Data Overlays

MeshMobility renders each data source as an individual heatmap layer (not circles).
Each is a toggle overlay. Combinations are weighted composites.

### Data Sources (all free, all API)

| Source | Data | Granularity | Key |
|--------|------|-------------|-----|
| Census ACS | Population density, median home value, income | Census tract | Already saved |
| Census County Business Patterns | Job count + payroll by NAICS | Zip, county | Census API |
| BLS QCEW | Quarterly employment + wages | County | Free bulk download |
| Census LEHD/LODES | Commute origin-destination flows | Census block | Free download |
| SCDOT / State DOTs | AADT traffic counts | Point | Per state |
| NHTSA FARS | Accident locations | Point | Free API |

### Heatmap Overlay Layers

| Layer | Source | What it shows |
|-------|--------|---------------|
| Population Density | Census ACS | Where people live |
| Job Density | County Business Patterns | Where people work |
| Commute Flow Intensity | LEHD/LODES | Corridors between home and work |
| Property Values | Census ACS median home value | Where tax base concentrates |
| Sales Tax Revenue | Census gov finances | Where commerce happens |
| AADT | State DOT | Where vehicles concentrate (existing, circles) |
| Accidents | NHTSA FARS | Where the system fails (existing, circles) |
| Combined Density Score | Weighted composite | Where JPods pays for itself |

**Rendering:** Leaflet.heat plugin. Individual toggle per layer.

**Density threshold:** Census tracts with population density > 3,000/sq mi are
candidate zones. Tracts hitting all four signals — dense population, heavy commute
flow, job cluster, high property values — are where JPods pays for itself fastest.

---

## Isochrone Scoring (iso-layers)

The heatmap shows raw density. The iso-layers show what each station **captures**.

Isochrones answer: "What is reachable from this point in X minutes?"

| iso-Layer | Question |
|-----------|----------|
| isoPopDensity | How many people can reach this station in 7 min walk / 15 min bike / 15 min JPods? |
| isoJobs | How many jobs are reachable from this station? |
| isoTaxRevenue | How much tax revenue sits within this station's catchment? |
| isoPropertyValue | What is the total property value within catchment? |

The multiplier between bike-reachable and JPods-reachable is 8-10x.
**That multiplier IS the value proposition.**

---

## Station Report

Every Noelle point (station or circle) gets a report card automatically from
census/BLS data + MeshMobility's isochrone engine.

### Example: Station S-012 (Main & Augusta)

| Metric | 7 min walk | 15 min bike | 15 min JPods |
|--------|-----------|-------------|--------------|
| isoPopDensity | 4,200 | 18,600 | 142,000 |
| isoJobs | 1,800 | 8,400 | 67,000 |
| isoTaxRevenue | $2.1M | $9.8M | $74M |
| isoPropertyValue | $180M | $820M | $6.2B |

### Network Summary

| Metric | Network Total | Per Station Avg | Best | Worst |
|--------|--------------|----------------|------|-------|
| isoPopDensity-15 | 284,000 | 6,760 | S-012 (14,200) | S-038 (1,100) |
| isoJobs-15 | 134,000 | 3,190 | S-004 (11,400) | S-041 (480) |
| isoTaxRevenue-15 | $148M | $3.5M | S-004 ($12.1M) | S-041 ($0.4M) |
| isoPropertyValue-15 | $12.4B | $295M | S-012 ($890M) | S-038 ($42M) |

Stations with iso-scores below threshold get flagged for repositioning.

---

## Noelle Draft vs Designer Placement — Comparison Report

Noelle places by data. The designer places by physical reality — roads, terrain,
land ownership, utilities, politics. They'll never match exactly, and that's fine.

The comparison report measures the cost of compromise.

### Example: Station S-012 vs Noelle Point N-012

| | Noelle Draft | Designer Placed | Delta |
|--|-------------|----------------|-------|
| Location | 34.8521, -82.3988 | 34.8534, -82.3971 | 180m NE |
| isoPopDensity-15 | 14,200 | 12,800 | -10% |
| isoJobs-15 | 11,400 | 10,900 | -4% |
| isoTaxRevenue-15 | $12.1M | $11.4M | -6% |
| Reason moved | — | Parking lot available, zoning allows | — |

**Rules of thumb:**
- Delta < 15%: good trade for a buildable site
- Delta 15-30%: look for a closer option
- Delta > 30%: Noelle's point is significantly better; designer should justify
- Positive delta: designer found a better site than Noelle — **feed this back**

When a designer finds a site that scores HIGHER than Noelle's draft point, that's
signal. Noelle's data resolution (census tract) is coarser than ground truth.
The designer's local knowledge improves the model. Feed that back and Noelle learns.

---

## Noelle's Proposal Workflow (Updated)

1. Pull census/BLS/AADT/accident data for the city
2. Generate heatmaps → identify candidate zones (density > threshold)
3. Place stations where iso-scores peak
4. Score every point she placed (station report)
5. Flag weak points (iso-scores below threshold)
6. Output: network .jpd + station reports + network summary

After designer adjusts:

7. Compare designer placement to Noelle draft (comparison report)
8. Measure delta per station
9. Log designer adjustments as physical constraint patterns
10. Incorporate patterns into next city's draft

**Smarter in loops.**

---

## Connection to the Ecosystem

This is not a planning system. This is a signal system.

- Same reason WebClerk is bottom-up. Alice learns from every transaction across
  every WC3 instance. Template marketplace — users submit layouts, the good ones
  propagate. No committee decides which layout is best. Adoption signals do.

- Same reason the Constitution works the way Bill reads it. States are the designers —
  they know their terrain. The federal structure carries signals between them.
  The wisdom emerges from the many, not from a plan imposed by the few.

Individual sovereignty, usufruct, bottom-up. One idea, every domain.

Start small, iterate relentlessly.

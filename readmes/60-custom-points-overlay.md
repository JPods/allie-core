# Custom Points Overlay — MeshMobility
**Created:** 2026-07-18
**Status:** Operational
**Location:** `mesh_mobility/gui/static/overlays.js` (CustomPoints module) + `mesh_mobility/gui/overlays.py` (API endpoints)

---

## What It Is

A general-purpose point overlay tool in MeshMobility. Load any coordinate list — transit stations, landmarks, infrastructure, competitors — and display it as a layer on the map alongside JPods network designs.

**This is not a one-off DART feature.** It's a generic overlay tool that accepts any coordinate list. DART was the first use case; MARTA, MBTA, UPS depots, grocery chains, or any other point data works the same way.

---

## Three Ways to Load Data

### 1. Presets (dropdown)
JSON files in `mesh_mobility/overlays/` that don't start with `aadt_`, `accidents_`, `crash_`, `population_`, `property_`, or `jobs_` are auto-detected as custom point presets. Open Overlays → Custom Points → select from the dropdown.

### 2. File Upload
Click "File" to load a local JSON, CSV, or GeoJSON file.

### 3. Paste
Paste JSON array or CSV directly into the textarea and click "Apply Paste."

---

## Data Formats Accepted

**JSON array:**
```json
[
  {"lat": 32.78, "lon": -96.80, "label": "Akard Station", "lines": ["BLUE", "RED"]},
  {"lat": 32.85, "lon": -96.87, "label": "Bachman Station"}
]
```

**GeoJSON FeatureCollection:**
```json
{
  "type": "FeatureCollection",
  "features": [
    {"type": "Feature", "geometry": {"type": "Point", "coordinates": [-96.80, 32.78]}, "properties": {"name": "Akard Station"}}
  ]
}
```

**CSV:**
```csv
lat,lon,label
32.78,-96.80,Akard Station
32.85,-96.87,Bachman Station
```

CSV column names recognized: `lat/latitude/stop_lat`, `lon/lng/longitude/stop_lon`, `label/name/stop_name/station`.

---

## Visual Appearance

- **Orange circle markers** with white border (radius 7, weight 2)
- Tooltips show label on hover (when Tooltips are On)
- Distinct from crash data (blue circles) and AADT (red circles)
- Non-interactive by default (follows the overlay tooltip toggle)

---

## Persistence

Custom points are saved with the `.jpd` file. When you save a network that has custom points loaded, they persist in the `overlays.custom_points` key. When you reload the .jpd, toggling Custom Points restores them from the server.

---

## API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/overlays/custom_points` | Return saved points from session |
| POST | `/api/overlays/custom_points` | Save points to session |
| GET | `/api/overlays/custom_points/presets` | List available preset files |
| GET | `/api/overlays/custom_points/preset/<file>` | Load a preset file |

---

## Preset Files Available

| File | Stations | System | Source |
|------|----------|--------|--------|
| `dart_stations.json` | 86 | DART rail (Dallas TX) | CrashHarvester transit |
| `mbta_stations.json` | 356 | MBTA subway + commuter rail (Boston MA) | CrashHarvester transit |
| `mta_subway_stations.json` | 484 | MTA subway (New York NY) | CrashHarvester transit |
| `ca_rail_stations.json` | 220 | BART + Caltrain + LA Metro (California) | CrashHarvester transit |

---

## Adding New Presets

### Via CrashHarvester (preferred)
```bash
cd /Users/williamjames/Documents/08_JPods/03_Technology/00_working_code
python3 -m crash_harvester harvest --transit ga il    # harvest known feeds
python3 -m crash_harvester harvest --transit-url wa "https://url.zip|AgencyName"  # custom URL
```
This saves to both the CrashHarvester library AND generates MeshMobility overlay presets automatically.

### Manually
1. Create a JSON file: array of `{lat, lon, label}` objects
2. Place it in `mesh_mobility/overlays/`
3. It appears automatically in the presets dropdown

---

## Demo Use Case: DART + JPods Feeder Networks (DFW)

1. Load DART stations preset → shows 86 isolated rail stations
2. Place JPods stations connecting to DART
3. Toggle Coverage → walk/bike circles show JPods fills DART's last-mile gaps
4. Toggle crash data → JPods routes follow dangerous corridors

**The argument:** DART invested billions in 93 miles of rail, but each station has a coverage desert. JPods feeder networks multiply DART's value by filling those gaps with 15-minute walk access.

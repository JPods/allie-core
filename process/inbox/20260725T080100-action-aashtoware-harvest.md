# ACTION — AASHTOWare Safety Crash Data Harvest
**Owner:** Noelle + Andi
**Created:** 2026-07-25
**Status:** Open
**Priority:** High — 12 states of all-severity crash data

## Background

Bill found that Georgia publishes crash data at gdot.aashtowaresafety.net/crash-data-dashboard.
Claude discovered 11 more states using the same AASHTOWare Safety platform. All 12 states
are ones where MeshMobility is missing all-severity crash data.

## The 12 Dashboards

| State | Prefix | URL |
|-------|--------|-----|
| Arizona | azdot | https://azdot.aashtowaresafety.net |
| Georgia | gdot | https://gdot.aashtowaresafety.net |
| Missouri | modot | https://modot.aashtowaresafety.net |
| New Jersey | njdot | https://njdot.aashtowaresafety.net |
| New Mexico | nmdot | https://nmdot.aashtowaresafety.net |
| North Dakota | nddot | https://nddot.aashtowaresafety.net |
| Ohio | odot | https://odot.aashtowaresafety.net |
| South Carolina | scdot | https://scdot.aashtowaresafety.net |
| South Dakota | sddot | https://sddot.aashtowaresafety.net |
| Texas | txdot | https://txdot.aashtowaresafety.net |
| Utah | udot | https://udot.aashtowaresafety.net |
| West Virginia | wvdot | https://wvdot.aashtowaresafety.net |

## Task for Noelle + Andi

Learn how to harvest crash data from these dashboards. For EACH dashboard:

### Step 1 — Reconnaissance (browser)
1. Open the dashboard URL in Chrome
2. Does it load? Does it require login/registration?
3. What filters are available? (year, severity, county, road type)
4. Is there a download/export button? What formats? (CSV, GeoJSON, shapefile)
5. Screenshot the main interface

### Step 2 — API discovery (Chrome DevTools)
1. Open Chrome DevTools → Network tab
2. Apply a filter (e.g., one county, one year)
3. Watch for XHR/Fetch requests — look for:
   - GeoJSON or JSON responses with crash coordinates
   - API endpoints (often /api/v1/crashes or similar)
   - Query parameters (bbox, date range, severity)
4. Record the API URL pattern, request headers, and response format
5. Check if the API is paginated (limit/offset)

### Step 3 — Test harvest (one state)
1. Pick Georgia first (Bill found it, known-good)
2. Try downloading via the export button if one exists
3. If API found: write a Python script to fetch all crashes for one county
4. Validate: do records have lat/lon? Severity? Date? Road name?
5. Convert to GeoJSON matching our crashes_all_{st}.geojson format

### Step 4 — Scale
1. Document what worked for Georgia
2. Try the same approach on 2-3 other states (NJ, TX, OH — high value)
3. If the API pattern is consistent across states, write a generic harvester
4. Update crash_data_registry.json as each state is completed

## What We Need in Each Record
- Latitude, longitude (required)
- Date/time
- Severity (fatal, injury, property damage only)
- Road name / route number
- County
- Number of vehicles, injuries, fatalities

## Output
- GeoJSON files: `crashes_all_{st}.geojson` in mesh_mobility/overlays/
- Update crash_data_registry.json status from "missing" to "complete"
- Document the harvest method in readmes/crash-data-sources.md

## Why This Matters
All-severity crash data is the signal for JPods station placement. FARS only has
fatal crashes (~40K/year nationally). All-severity includes injuries and property
damage (~6M/year). That's 150x more data points. Crash corridors become guideway
corridors. This is Noelle's primary input for network design.

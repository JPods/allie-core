# Data Search Protocol — Noelle + CrashHarvester

**Established:** 2026-07-30
**Trigger:** User requests overlay data that isn't in the library

## The Problem

Current behavior: "No all-severity crash data for OK" — dead end. User gets nothing. No attempt to find it. No way to help.

## The Design

When a user requests data that isn't available, the system actively searches for it instead of giving up.

### Flow

```
User clicks overlay → data not in library
    │
    ├─ 1. PROMPT: "Data not currently available for [STATE/AREA]."
    │     "Know a source? Enter URL or agency name: [___________]"
    │     "Starting search — estimated [X] minutes."
    │
    ├─ 2. SEARCH CYCLE (background, on timer)
    │     Noelle calls CrashHarvester sources on a cycle:
    │       - State DOT ArcGIS endpoints (known list)
    │       - State DOT open data portals
    │       - NHTSA supplemental datasets
    │       - User-provided source (if entered)
    │       - Previously successful patterns for similar states
    │     Each cycle: try next source, normalize if found, update status
    │
    ├─ 3a. DATA FOUND
    │     CrashHarvester normalizes → library
    │     Alert user: "Crash data for [AREA] is now available. Reload Data."
    │     [Reload Data] button in the alert
    │
    └─ 3b. SEARCH EXHAUSTED
          "Search complete. Data not found."
          Sources checked: [list with status]
          Best guess: [why — e.g., "OK DOT publishes only OKC metro area",
                       "State requires FOIA request", "Data behind paywall"]
          "You can submit a data request: [button]"
          → Alice tracks the request, follows up
```

### Timing

- Initial search window: 5 minutes (configurable)
- Cycle interval: 30 seconds between source attempts
- Max sources per search: ~10 (don't hammer endpoints)
- Timeout per source: 15 seconds

### User-Provided Sources

Before the search starts AND after it fails, offer:
```
"Know a source? Paste a URL or describe the agency."
[___________] [Search This Source]
```

If the user provides a source:
- CrashHarvester attempts to fetch and normalize it
- If successful, the source is added to the known sources registry
- Other users searching the same state/area benefit automatically
- Alice logs the contribution

### What Noelle Does

Noelle is the network validator. In this context she:
- Determines which data sources are likely for the requested area
- Prioritizes sources based on past success patterns
- Decides when to stop searching (diminishing returns)
- Writes the "best guess" explanation when search fails
- Updates the crash-data-status.json with what was tried

### What CrashHarvester Does

CrashHarvester is the data supply chain. It:
- Fetches raw data from sources
- Normalizes to library schema (schemas.CRASH)
- Grids to 200m cells
- Saves to library/{type}/{state}_{county}.geojson
- Updates registry.json

### What Alice Does

Alice tracks the human side:
- Logs data requests that couldn't be fulfilled
- Aggregates: "47 users searched for OK Tulsa crash data this month"
- Follows up: submits FOIA/APRA requests when demand justifies
- Notifies users when previously-unavailable data arrives
- Tracks user-contributed sources and their success rate

### Implementation Notes

**Backend:** WebSocket or polling endpoint for search status updates
```
GET /overlays/search_status?search_id=xxx
→ { "status": "searching", "sources_tried": 3, "sources_remaining": 7, 
    "current": "OK DOT ArcGIS REST", "elapsed": "1:30" }
```

**Frontend:** Replace the error toast with a status panel:
- Progress indicator (sources tried / total)
- Current source being checked
- Cancel button
- Source input field
- When found: green banner with Reload button

**State persistence:** Search state survives page navigation within MeshMobility. If user switches to another overlay and comes back, the search is still running.

### Connection to the Ecosystem

This is the request framework from RI DOT applied to data:
- Every failed data lookup is a request signal
- Aggregated signals drive Alice's acquisition priorities
- The system is responsive — it tries before saying no
- Users can contribute sources (n² connections, packet size toward 1)
- The pain of not having data drives the system to go get it

### Priority Sources by State

Maintain a ranked list per state in `crash-data-status.json`:
```json
{
  "ok": {
    "sources": [
      {"name": "OK DOT ArcGIS", "url": "...", "status": "partial", "coverage": "OKC metro only"},
      {"name": "OK DPS CARS", "url": "...", "status": "untried"},
      {"name": "Tulsa PD open data", "url": "...", "status": "untried"}
    ],
    "last_search": "2026-07-30T08:00:00Z",
    "requests": 3
  }
}
```

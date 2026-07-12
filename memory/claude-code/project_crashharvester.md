---
name: CrashHarvester standalone app
description: CrashHarvester (CH) — standalone data supply chain for transportation/census data; MeshMobility reads library only, no government API calls; Alice manages sources; DynamicCatalogs pattern
type: project
---

CrashHarvester is a standalone app at `00_working_code/CrashHarvester/`. One product: a clean, uniform GeoJSON library.

**Why:** Government data is messy, inconsistent across 50+ agencies. Every app that needs it rebuilds extraction. CH normalizes once, consumers read clean data.

**How to apply:**
- MeshMobility reads from CH library only — no fallbacks, no legacy overlay code, no government API calls in api.py
- Library organized by data type and state: `library/{type}/{state}.geojson`
- Six types: crash, fatal, traffic, population_density, property_values, jobs
- Alice manages CH via API: add/remove/update sources, trigger harvests
- Library can be sliced to any granularity (state, county, radius) — consumer decides, not harvester
- Same pattern as DynamicCatalogs: supplier normalizes, distribution determines what each retailer gets
- Signal Missing button in MM writes to CH request queue → Alice prioritizes harvesting
- `mobility_data/` module has reader + schemas (shared between CH and MM)
- Public API is a future consumer — data for fee or contribution

**Architecture change 2026-07-12:** Removed ~566 lines of government API code from api.py. No `_overlay_path`, `_fetch_aadt`, `_fetch_fars`, `_normalize_crash_data`, `_ensure_overlays`. Clean break.

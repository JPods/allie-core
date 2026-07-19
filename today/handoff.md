# Handoff — 2026-07-18 (final)

## Where We Left Off

Two sessions today. Morning: MeshMobility overlay tools + transit data + UUID serialization + network merge. Evening: Fusion360 BOM + specs + QA architecture.

## What Was Built (Morning)

### 1. Custom Points Overlay (MeshMobility)
- Generic point overlay tool in Overlays panel → "Custom Points" button
- Three input methods: presets dropdown, file upload, paste (JSON/CSV/GeoJSON)
- Persists with .jpd save/load
- Code: `overlays.js` (CustomPoints module) + `overlays.py` (4 API endpoints)
- Readme: `readmes/60-custom-points-overlay.md`

### 2. CrashHarvester Transit Data Type
- Full data type: schema, harvester, reader, CLI
- `python3 -m crash_harvester harvest --transit tx ma ny ca`
- 12 states pre-configured with GTFS feed URLs
- Harvested: TX (86 DART), MA (356 MBTA), NY (484 MTA), CA (220 BART+Caltrain+LA Metro)

### 3. Structure UUIDs (Serialized Items)
- `Structure.structure_uuid` and `ConnectionPoint.cp_uuid` added
- Auto-generated on creation, persisted in .jpd
- Same pattern as WC3 serialized inventory

### 4. Network Merge
- `POST /api/network/merge` — combines two .jpd files by UUID matching
- New structures renumbered; guideways preserved; cross-network connections manual

## What Was Built (Evening)

### 5. Fusion360 BOM + Specs
- .f3d/.f3z parser (Zstandard decompression, ACT segment, DesignDescription.json)
- 170Meter_Full: 22 components, 76 instances; HSS mismatch flagged
- Bogie v22: 17 parts, 42 per bogie
- 12 unified specs (SPEC-01 through SPEC-12), 304 requirements, 13 RED flags
- Gordy's Quality Manual mapped to Alice/WC3
- QA architecture: Document FK on QuestionAnswer model
- Spare parts demo: SEGA exploded-view pattern

## What Needs Attention Next

1. Test merge with two adjacent city .jpd files
2. Noelle + Alice database design for serialized station assets (Bill flagged)
3. DFW demo: DART overlay + JPods feeder network + Coverage circles
4. Fusion360: Bill may bring more .f3d files; parser ready
5. Specs need Bill's review for flag severity

## Files Changed (MeshMobility)
- `gui/static/overlays.js` — CustomPoints module
- `gui/static/index.html` — Custom Points UI
- `gui/overlays.py` — 5 new endpoints
- `gui/network_io.py` — merge endpoint + custom_points persistence
- `engine/structures.py` — UUID fields
- `gui/state.py` — UUID restore on load

## Files Changed (CrashHarvester)
- `schemas.py` — TRANSIT schema
- `harvest/transit.py` — GTFS harvester (new file)
- `reader.py` — get_transit()
- `__main__.py` — --transit CLI

## Files Changed (Allie)
- `readmes/60-custom-points-overlay.md` — new
- `readmes/27-route-time.md` — updated
- `readmes/retrospections/2026-07-18.md` — full retrospection
- `specs/` — 12 spec files (new directory)
- `Fusion/` — BOM JSON files + spare parts HTML

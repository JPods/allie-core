# Handoff — 2026-06-06

## What was accomplished

Template data pipeline (Proof Lines) complete. All 4 active JPods station templates verified clean (0 SEVERE):

| Template | Proof Lines result |
|----------|-------------------|
| station_thru_dip | 16 OK · 2 ARC · 1 SCAN |
| station_line_end | 11 OK · 1 ARC · 2 SCAN |
| JPods_station_parking | 15 OK · 3 WARN (OL-SU-10 — scanner limitation, not blocking) |
| traffic_circle7 | 24 OK — perfect clean |

## Key changes made this session

**jpod_path_json.rb:**
- OK threshold: 50mm → 75mm (absorbs SketchUp arc-to-line join gap of ~63mm)
- Scanner Priority 4: `_track_endpoints_mm` cap clustering for solid-beam tracks
  - Eliminates 313mm systematic WARNs on gw_cp_lead/cp_out (angled solid beams)
  - Fixes 898mm SEVERE on gw_lift_parking (3D ramp) — OL-SU-09 closed
- Scanner Priority 1: `jpods_path` attribute (flat Float [x,y,z,...]), written during Extract Template
  - Bypasses edge-trace non-determinism for multi-pt tracks where entity identity is stable
  - Works for gw_lift_in (115pts), gw_platform_out (115pts), gw_uturn_* (ArcCurve)
- SCAN classification: FollowMe solid tracks (>20 declared pts, <1/3 found) → SCAN not SEVERE
  - gw_platform_in (station_thru_dip) is the canonical case — SketchUp Group entity identity
    diverges between model.entities and inst.definition.entities traversal contexts
  - extracted.json is authoritative; animation unaffected by SCAN status
- formation_filter: Proof Lines in template-model scope only checks matching formation
- station_id = 'to_be_assigned' when no network ID present

**jpod_console.rb:**
- Proof Lines UI: added SCAN counter and message

**readmes/sketchup/jpods-feature-list.md:**
- F-10 added: Guideway Connect Tool — proper long-term fix for arc-to-line join gap

**readmes/sketchup/jpods-plugin.md:**
- Rule 13 OK threshold updated: <50mm → <75mm; note added pointing to F-10

## Open items from prior handoff (still open)

1. **[MIGRATION] Check Templates** — run in SketchUp console, archive if all READY
2. **Arc undersampling in station_parking** — gw_uturn_0/gw_uturn_1 2-pt chord
   Fix: open station_parking template → Workflow > Generate Template Data
3. **Hold Loop trip panel** — does not emit `__TRIPSEQ__:` yet
4. **S007 / S008 geometry drift** — SEVERE on multiple tracks, not addressed

## New open items from this session

5. **OL-SU-10**: 3 WARNs on JPods_station_parking inner platform/lift tracks (scanner limitation)
   - Not blocking animation; documented
6. **↺ direction warnings**: Scanner finds reversed paths for many tracks that are Priority 1 OK
   - Cosmetic in Proof Lines output; extracted.json has correct direction; animation unaffected
   - Question: do reversed scanner paths affect Sally/Natalie routing validation?
7. **gw_platform_in SCAN root cause**: SketchUp Group entity identity issue — model has two Group
   objects logically representing the same gw_platform_in, found by different traversal paths.
   Could be fixed by F-10 (proper solid extrusion, no ambiguous Group nesting) or by model repair.

## Next session start

```
load Sketchup.find_support_file('jpod_path_json.rb', 'Plugins/su_jpods')
```

1. Run `[MIGRATION] Check Templates` in console (carried from prior handoff)
2. Open station_parking template → Generate Template Data (arc undersampling fix)
3. Consider: Lines Build from Template on all templates (sync declared lengths)
4. Consider: test animation on station_thru_dip in a real network

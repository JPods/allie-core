---
name: JPods station templates + authoring rules
description: All 6 station templates with EP tables and segment dimensions, plus eps[] authoring rules and physical JPods equivalence, in one combined document
type: reference
---

Full reference: `readmes/sketchup/jpods-station-templates.md`

Covers:
- eps[] authoring rules (junction types, segment naming, merge/diverge distinct name constraint)
- Lines JSON Build tool (Models › Lines JSON Build, auto-executes, reads eps[], fills geometry)
- Physical equivalence — same topology rules govern Nora's ezones and Natalie's trips
- station_line_end: 1 CP, 14 EPs, 14 segments
- JPods_station_parking: 2 CPs, 16 EPs, 20 segments
- station_thru_dip: 2 CPs, 15 EPs, 19 segments, near_main split at EP7
- traffic_circle7: 4 CPs, 24 EPs, ring topology — vehicles travel END→START on all arcs; corner arcs 1000mm always fail scanner

Key rule: every diverge/merge requires distinct segment names — gw_near_main lesson 2026-05-30.

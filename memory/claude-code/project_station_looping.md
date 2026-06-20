---
name: Station looping problem
description: Vehicles accumulate and loop inside station structures; deferred to ~2026-05-10
type: project
---

Pods are observed cycling: platform → guideway → U-turn → guideway → U-turn → platform unnecessarily. Visually: ~8 vehicles between U-turns on each of the eastbound and westbound guideways, 2 on each U-turn, at any given animation frame.

**Why:** All trips route platform-to-platform. Pods exiting the platform merge into the NB stream at NB_N (north end), so every departing pod travels northward first regardless of destination direction. The animation overlays all O-D pair routes simultaneously, exaggerating the visual density. Some of this may also be real simulation behavior where pods make unnecessary U-turn loops before reaching their destination.

**Fix applied 2026-05-04:** Added `SIDE_to_SB: SIDE_N → SB_N` line (station-access tagged) in `engine/structures.py:build_station()`. Dijkstra now has two exit options — northbound trips use SIDE_to_NB, southbound trips use SIDE_to_SB — eliminating the mandatory north-turnabout loop for all southbound trips. `SIDE_to_SB` also added to `SIDING_SUFFIXES` in simulator.js so pods on this line display at 2× size.

**If looping persists after the fix:** verify new networks load (old .jpd files pre-date the fix — re-save or reload). Check that route_line_ids for a southbound trip includes `SIDE_to_SB` not `TA_N_a`/`TA_N_b`.

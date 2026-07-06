---
name: Route-Time data overlays
description: AADT traffic (84 stations), accidents (1019 FARS crashes), pedestrian (pending) overlays in route_time/overlays/
type: project
---

Three overlay buttons in Route-Time palette:
- Traffic (AADT): overlays/aadt.geojson — 84 SC DOT stations, red gradient by volume, no border
- Accidents: overlays/accidents.geojson — 1,019 NHTSA FARS 2022 SC fatal crashes, red circles sized by fatalities
- Pedestrian (pend): overlays/mobility.geojson — empty, needs WalkScore API or Strava Metro data
**Why:** Three data layers feed network placement: where cars are (AADT), where cars kill (accidents), where people walk (pedestrian).
**How to apply:** Toggle overlays while designing networks. Primary network follows AADT 10k+. Secondary network follows accident clusters on moderate-AADT roads.

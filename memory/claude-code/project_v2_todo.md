---
name: v2 TODO — next priorities
description: Vehicles Display page, non-planar build fix, Crew Health dashboard, console careful rework. Migration complete, 3+circle animating.
type: project
---

v2 rewrite session complete 2026-06-22. Migration 13/13. 3+circle animating.

**Priority 1: Vehicles Display page**
Sally has pods[]/ps[] data. Console Vehicles tab needs real-time pod list with station, slot, state, destination. Wire Sally → console HTML vehicle table.

**Priority 2: Fix 4 non-planar build segments**  
s001↔s003 and s001↔s005 fail FollowMe on long paths with Z change. Pre-filter path density or reset FP accumulation at intervals. Current rescue skips steps (beam has gaps).

**Priority 3: Crew Health Check dashboard**
Wire to console HTML panel, not just Ruby console.

**Priority 4: Console v2 rework**
Bill wants to keep current console — any rework must be duplicate window. ~90 old references remaining as stubs.

**Priority 5: Speed anomaly in animation**
Some pods run noticeably faster than others. Likely the curve-radius speed cap (speed_cap_in from circumradius) — curved segments slow, straights don't. Need to verify caps are reasonable and smooth transitions between segments.

**Priority 6: Personal space enforcement across segments**
Animation _enforce_spacing! only checks pods on the SAME segment. Pods on different segments or approaching parked pods have no spacing enforcement. Physical has three-zone ToF (50mm stop, 150mm care). SU needs cross-segment proximity check — at minimum, don't let a traveling pod overlap a parked pod's position.

**Done this session:**
- ✓ Speed anomaly: was permanent @speed_in override from conveyor, fixed to use speed_cap_in
- ✓ Personal space: directional (ahead=slow, behind=boost), cross-segment only for adjacent
- ✓ Zipper merge: ring pod accelerates 1.5x when entry pod waits
- ✓ Per-agent memory: facets at ~/Allie/facets/{agent}/facet.json
- ✓ Per-agent logging: independent verbosity per crew member
- ✓ Crew Journal: {model}.crew.json per network
- ✓ Trip reports: configurable keep/archive per network
- ✓ Telemetry pings at :debug
- ✓ Network Display: connections + waypoints visible
- ✓ Trip Simulator: working with camera follow
- ✓ Pods tab: renamed, real data, refreshes

**How to apply:** Vehicles Display is next (wire Sally's full data). Non-planar fix before new networks. Console rework = duplicate window.

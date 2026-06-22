---
name: 3+circle network model status
description: 5-station network (traffic_circle7 + station_parking + station_thru_dip + 2x station_line_end). Connect works, Build finds 0 connections — jpod_network.rb just added to boot.rb, needs restart + reconnect + Build.
type: project
---

3+circle network model at ~/Documents/skp_jpods/3+circle/

**Status as of 2026-06-22:** 3+circle ANIMATING. Build pipeline v2 complete. 4/8 segments have full bezier beams; 4 have gaps from non-planar extrude rescue (s001↔s003, s001↔s005 — long connections with Z change). All 8 route correctly.

**Known issues:**
- 4 segments with beam gaps (non-planar FollowMe on long Z-change paths)
- Column heights may be wrong where terrain raycast misses (ground_z_at fix applied)
- Bezier control points capped at 50m (prevents overshoot on 265m connections)

**How to apply:** Network is working. Fix non-planar issue before adding more networks. Compare old pipeline's path output for failing connections.

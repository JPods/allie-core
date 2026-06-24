# Claude Recall — 2026-06-24

## CRITICAL: Read This Before Touching Code

### 500mm Edge Hallucination (3x recurring)
Any track gap ~500mm is measuring edge-to-edge across the dual track (250mm each side of centerline), NOT a real gap. Natalie's maneuver builder at `natalie/natalie.rb:317-331` has a guard — 350-650mm range blocks track reversal. If you see a ~500mm gap, DO NOT REVERSE THE TRACK. This has come back 3 times because compression destroys the fix.

### Allie MCP Server (NEW)
Allie is now an MCP server. After restart, you have tools: `ask_allie`, `teach_allie`, `allie_recall`, `allie_flag`. USE THEM. Ask Allie before making significant decisions. She remembers what you don't.

Server: `~/Allie/scripts/allie-mcp-server.py`
Config: `~/.claude/settings.json` → mcpServers.allie
Exchange log: `~/Allie/exchange/conversation.jsonl`

### Architecture Rules (non-negotiable)
1. Smooth guideways primary — columns absorb terrain, hard_floor_z is NOT in the profile clamp
2. network.json is source of truth for ALL network-specific data — entity attributes are cache
3. Template folders (track_formations/) are READ-ONLY during network operations
4. Build must not destroy user data (station_names, crew_flags)
5. Sally owns slots, Natalie owns timing, Nora executes — clear authority chain
6. No silent defect tolerance — documented, visible, counted, approved
7. All datetimes UTC ISO-8601 Z suffix (Axiom 14)
8. USE MATH NOT EDGES (Axiom 10)
9. Console 1 only — don't maintain c2

### Files That Matter
- `build/build_path.rb` — Z profile pipeline, waypoint beam_z, smooth guideways
- `natalie/natalie.rb` — dispatch registry, 500mm guard, route planning
- `sally/sally_station.rb` — slot array, conveyor (3-step direct transforms), inbound tracking
- `animation/animation.rb` — tick loop, spacing, rebalance, 20s dwell, Sally tick
- `noelle_v2/noelle_v2.rb` — network build, gap validation, defect flags
- `crew_health.rb` — crew flag system, gap/kink reporting
- `jpod_console.rb` — all UI callbacks, Travel app, BOM, capacity

### Current State
- 6 stations (all station_parking except s005 traffic_circle7)
- 42 pods, 12 m/s cruise, 20s dwell, 5s Natalie dispatch interval
- Sally 3-step conveyor, 3s exit hold, 0.5s tick
- Route validation passes (all 30 routes valid)
- Travel app wired but station ID key was just fixed (origin_id not origin)
- Build preserves station_names (was overwriting — just fixed)
- Crew flag system functional — show/hide in Crew Health

### Open Problems
- gw_platform_in2 junction — 500mm guard should prevent jam, needs testing
- Terrain raycast z=0 fallback — interpolation covers it, proper fix deferred
- Pod arrival at entry slot (ps1) not exit slot — conveyor should shuffle to exit
- Template validation chain — timestamps not yet implemented
- Station locking after Build — readme written, code not yet

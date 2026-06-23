---
name: File authority — who owns what
description: lines.json is designer, lines.computed.json is Noelle, network.json is the network, crew.json is the team, bom.json is Build
type: reference
---

**Template folder** (per station type in `templates/track_formations/{template}/`):
- `lines.json` — Designer obligation. Hand-authored topology, chains, speed limits, rules. Designer is responsible for this being correct.
- `lines.computed.json` — Noelle (Compute). Model-extracted coordinates merged with lines.json. Controlled by Noelle's definition of that model. Created/overwritten on Compute.

**Project folder** (per network in `~/Documents/skp_jpods/{network}/`):
- `network.json` — Connect tool. All network connections, waypoints, station relationships. Single source of truth for the network. Everything about the network is here.
- `crew.json` — Crew (all agents). Observations, issues, concerns about this network.
- `bom.json` — Build. su_jpods template costs applied to this network's built geometry.

**No followme.json.** No per-network lines files. No other JSON files define the network.

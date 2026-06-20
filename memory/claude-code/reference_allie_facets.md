---
name: Allie facets architecture
description: Where per-agent persistent knowledge lives, how it's updated, and how Pi agents carry their own memory on SD card
type: reference
---

**Location:** `~/Allie/facets/{noelle,natalie,nora,sally}/facet.json`

Each facet is Allie's distilled, cumulative knowledge for that agent — synthesized from observations across all networks and all sessions. Updated nightly by `allie-reflect.py`. Never resets.

**Key principle: Pi agents carry their own memory on SD card.** `~/allie_facets/` on each Pi is persistent across reboots. Nora writes to her own facet after each trip. A Pi reboot does NOT reset learning. Only a new SD card does — and that seeds from Allie's master.

**Teaching direction:**
- Pi → Allie: `allie-pull-facets.py` pulls Pi experience before session (Todo)
- Allie → Pi: `allie-teach.py` pushes cross-network calibration after session (Todo)
- SU agents: `FacetLoader.load(:agent)` reads at plugin load (Todo)

**Full architecture:** `readmes/agents/allie-facets.md`

**Nightly synthesis output:** `allie-reflect.py` calls `update_facets()` after synthesis to write the updated facets (Todo — not yet implemented).

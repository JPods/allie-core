---
name: Noelle owns slot count per station
description: Noelle sets slot counts from data (crash, population, traffic) unless user explicitly overrides with a specific number
type: project
---

Noelle should have authority to set slot counts per station based on CrashHarvester library data — crash density, population, traffic, pedestrian concentration. Currently MM requires user to specify slots.

**Why:** Noelle has the data. She knows where the 2-slot poles go and where the 50-slot hubs go. Defaulting to user specification means the user is guessing what Noelle already knows.

**How to apply:**
- User places a station → Noelle sets slot count from data
- User explicitly sets slot count → Noelle respects it (tagged as user-specified, not auto)
- Noelle can recommend changes: "This station is at a batch-to-packet conversion point (train station), recommend 50 slots"
- Station spectrum: single (1-2 slots, every 400m), standard (8-16, neighborhoods), hub (50-100, transit interchange)
- Slot count is a Noelle decision, not a network design decision — the user designs the network, Noelle sizes the stations

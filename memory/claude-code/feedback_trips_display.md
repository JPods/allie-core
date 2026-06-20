---
name: Trips display — clean and prominent
description: Bill emphasizes that the trips display must be clean; no UI clutter when viewing trip data
type: feedback
---

Trip data display is held to a high standard of cleanliness. When trips are shown:
- Hide unrelated UI (NE iframe, vehicle table, marker panel) — don't let feature.json status bleed through
- Trip list should fill the available space, not be buried in a small output strip
- Single-click execution — no extra button presses to see the data
- Clickable trip IDs leading to segment detail are the right interaction model

**Why:** Bill called out "trips being very clean is important" explicitly. The earlier broken state (feature.json status visible, tiny output area) was unacceptable even though the data was technically correct.

**How to apply:** Any future trips UI (plan trips, trip detail, O-D matrix, isochrone) should follow the same pattern: hide competing panels, let the trip data own the space, single interaction to get the result.

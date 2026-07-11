---
name: Clipboard as template/combine system
description: Two-browser workflow for combining city networks; copy from one session, paste into another; world coordinates or map-center placement; replaces Java Route-Time Template feature
type: project
---

## Clipboard Template Workflow (established 2026-07-11)

**Two-browser combine workflow:**
1. Browser A has source network → click Clipboard → Copy
2. Browser B has destination network → Clipboard button with paste option → source network appears
3. User verifies detail in both browsers before merging
4. User connects CPs manually at the seam

**Paste modes:**
- **World coordinates** (default): pasted network appears at its original lat/lon. Used for adjacent cities (Cedar Park + Round Rock snap together geographically).
- **Map center**: pasted network places at the current map view center. Used for templates — drop a station layout pattern into a different city, then drag into position.

**Clipboard button behaviors:**
- Click: opens clipboard dialog (existing — copy text)
- Shift+Click or Ctrl/Cmd+Click: paste from system clipboard into current network
- Dialog has choice: "Paste at original coordinates" vs "Paste at map center"

**Connection to Library:**
- Library browse → Clone copies network text to clipboard automatically
- User opens destination network → pastes from clipboard
- No server-side merging — user is always in control

**Replaces:** Java Route-Time Template feature. Same concept, now collaborative across sessions and cumulative through the library.

**How to apply:** Clipboard already handles copy as text. Paste-into-network is the new capability. Each pasted structure gets new IDs (avoid collisions with existing network). Original coordinates preserved unless map-center mode chosen.

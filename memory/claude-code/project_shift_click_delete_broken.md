---
name: Shift-click CP delete not firing
description: Shift-click in Connect Guideways tool doesn't reach delete code; no log output; connection persists in network.json; Network Display doesn't update
type: project
---

Shift-click to delete a CP connection is not working. Debug logging added but no output appears — the handler may not be firing at all.

**Symptoms:**
- Shift-click visually removes the draft overlay line but network.json is unchanged
- Refresh and Build repopulate the deleted connection
- No `[JPods Connect] Shift-click` messages in console log

**Possible causes:**
1. CONSTRAIN_MODIFIER_MASK may not match Shift on Mac (could be a different flag)
2. The Connect tool may not be the active tool when Shift-click happens
3. The onLButtonDown handler may be intercepted by another tool or SketchUp behavior

**Debug logging added at:**
- connect_tool.rb line 215: "Shift-click detected" + draft count
- connect_tool.rb line 217: nearest_draft_idx result
- connect_tool.rb line 221/266: which connection is being deleted
- network_editor.rb delete_connection: REMOVED/NOT FOUND + remaining count

**What needs to happen on successful Shift-click:**
1. Remove from @@draft_connections
2. delete_connection writes to network.json on disk
3. push_network_json refreshes the Network Display iframe
4. collect_planned_paths updates the viewport overlay

**How to apply:** Next session, check if the Shift-click handler fires at all. If no log output, check CONSTRAIN_MODIFIER_MASK value and whether the Connect tool is active.

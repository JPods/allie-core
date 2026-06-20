---
name: Stop Animation — reliable stop mechanisms
description: Console HTML dialog is unreliable for stopping animation; toolbar + Extensions menu are the correct paths
type: feedback
---

The console HTML dialog becomes unresponsive during heavy animation because WebKit is busy rendering a flood of log lines. The JS debounce (2s after any state change) also silently blocked Stop clicks.

**Three reliable Stop Animation paths — in order of reliability:**
1. **Extensions > JPods > Animation > Stop Animation** — native SketchUp menu, bypasses JS entirely
2. **Toolbar red square button** — native SketchUp event loop
3. **Escape key** — JPodEscapeTool pushed onto tool stack during animation
4. **Console dialog** — least reliable; only use if animation is light

**Why:** The console dialog's `toggleAnimation()` had a 2s debounce on both Start AND Stop. Fixed to only debounce Start. But the bigger issue is WebKit rendering lag when 60+ log lines/sec flood the console-log element.

**How to apply:** Always add animation control to the native SketchUp menu/toolbar for any feature that may generate heavy output. Never rely solely on the HTML dialog for stop/abort controls.

**Log volume fix:** Per-pod status dump (14 lines × every 2s) moved to every 5th report (~10s). build_topology O(n²) now cached per animation run (was rebuilt on every dispatch). Both in jpod_vehicle_anim.rb.

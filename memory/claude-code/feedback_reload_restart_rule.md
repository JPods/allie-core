---
name: Reload and restart as a development rule
description: Every dev environment needs a reload (hot) and restart (cold) function in its debug/logging interface; Claude says "reload X" instead of pasting commands
type: feedback
---

Every development environment should expose two functions from within its own logging or debugging interface:

1. **Reload** — hot reload of changed code without restarting the process
2. **Restart** — full process restart when reload is insufficient (guards, toolbars, observers)

These functions belong *in the tool*, not in the terminal or documentation.

**Why:** Claude can say "reload su_jpods" instead of pasting a Ruby Console command. The user executes it from the tool they already have open. Same for users — they get a reliable, documented path without needing to know the internals.

**How to apply:**
- **su_jpods**: "reload su_jpods" = click Reload Plugin in the JPods Console. "restart SketchUp" = when the restart dialog fires, or when I say a change requires it.
- **MeshMobility**: Flask dev server has `--reload`; consider adding a `/reload` endpoint or browser button
- **JPodsSM_RPi**: Add a reload/restart command to MQTT debug channel or Pi local interface
- **Allie scripts**: watcher/agent system should expose reload and restart via wcapi or CLI
- **Any new tool**: build reload + restart into the debug/logging UI before shipping

**Pattern for new tools:**
- Reload: re-execute changed files, reset state guards, reopen UI fresh
- Restart: detect when reload is insufficient (registration guards, frozen state), inform user, initiate process quit
- Log both events with UTC timestamp to the persistent log

**Why:** Claude should never need to paste a multi-line terminal command when there's a button in the tool that does it correctly.

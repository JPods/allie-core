---
name: Tool boundaries are logging opportunities
description: Every transition from "editing" to "testing" (reload, run, deploy, connect) is the highest-value moment to capture a fault/dnw/tf entry — intent is unambiguous exactly then
type: feedback
---

Every tool boundary — reload, run simulation, deploy, SSH connect, pod start — marks the exact moment between "I changed something" and "I'm testing it." That is the highest-value moment to log because:

1. Context is richest (developer knows exactly what changed and why)
2. Intent is unambiguous (a specific hypothesis is being tested)
3. The result is about to be known (DNW or TF is seconds away)

**The reload button is a signalling tool**, not just a convenience. When a developer clicks Reload Plugin in the JPods Console, they are signalling: "I made a change. I am now testing it." That signal should feed the FAULT→DNW→TF→TFTS cycle automatically.

**Concrete implementation pattern:**
After the tool boundary event (reload, run, deploy), the tool prompts:
- "Fixed a fault" → writes TF to process/inbox/
- "Testing a fix" → pre-fills DNW template (completed if test fails)
- "Just reloading" → no log

This removes the burden of remembering to log — the tool asks at the right moment.

**All boundaries instrumented as of 2026-05-20:**

| Domain | Events | File |
|--------|--------|------|
| SU | build_validate_start/complete/fault, animation_start | noelle.rb, jpod_animator.rb |
| PH | pod_start/stop, hardware_checkup, trip_dispatched, ezone_entry, trip_complete | launcher.py, main.py, unitTest.py, mqtt.py, motor.py, ezone.py |
| RT | simulation_start/complete/fault, network_reload | api.py (+ JS TF/DNW prompt in simulator.js) |
| WC3 | price_query, order_fulfilled, search_no_result, payment events | views_ui.py, signals.py, item_variants.py |
| ALLIE | reflection_start/complete | allie-reflect.py |

Full map and implementation patterns: `readmes/43-boundary-behaviors.md`.

**Agent chip evolution:** Currently Allie simulates all agent experiences. As each agent gets its own chip, it will log its own boundaries. Alice specifically: price_query + search_no_result + order_fulfilled feed her observe→log→pattern→recommend→promote loop.

**How to apply:** When designing a new debug/logging interface, the reload and run buttons are not the last thing built — they are the logging infrastructure. The prompt after the boundary event is part of the button's function.

**Why:** Bill (2026-05-20): "I like this tool-boundary hunting behavior. Some will be false leads, but they also are likely the flag signalling experience."

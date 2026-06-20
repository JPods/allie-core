---
name: Animation stop architecture — built 2026-06-20
description: Two stop modes (hard stop + graceful planned), populate toolbar, resume with direction recovery, agent flags
type: reference
---

**Two stop modes:**

| Mode | Trigger | What happens |
|------|---------|-------------|
| **Hard stop** (built) | Toolbar toggle, Escape, Extensions menu | Freeze all pods. Save resume_state v2 with direction. Timer stops. |
| **Graceful stop** (planned) | TBD — new toolbar button or menu | Pods complete current trips. No new trips issued. Sally manages parking overflow. Timer stops when all parked. |

**Toolbar buttons (order):**
Place Structure → Connect Guideways → Waypoints → Network Editor → [sep] → **Populate** → Toggle Animation → [sep] → Note

**Populate button:** Calls `JPodGuideway.populate_fleet(model)` — shared method in jpod_vehicle_runtime.rb, used by both toolbar and console. Places vehicles at ~70% capacity, random models. Uses train.png icon.

**Resume architecture (v2):**
- `save_resume_state` saves direction info: `man_start` (first pt as traveled) + `remaining[].sp` (start pts)
- Resume compares saved start pt with lookup first/last pt → reverses if needed
- Fixes backwards movement on Natalie-reversed tracks
- Resume intercept fires BEFORE Sally hold_loop in `build_fleet` — prevents traveling pods trapped as parked ps0
- Dynamic Sally advance tracks (`gw_platform_park_psN`) not in lookup → graceful fallback to parked
- v1 backward compat: falls back to seed_pos projection (no direction recovery)

**Random dispatch:** Auto-enabled on Start. Preserved across stop/start (not reset in `stop()`).

**Hard stop features:**
- Escape key: JPodEscapeTool pushed onto tool stack; intercepts VK_ESCAPE=27
- 3s restart latch: `@@stopped_at` blocks restart for STOP_LATCH_S=3.0
- Toolbar toggle: animate.png ↔ stop_anim.png; validation_proc keeps icon in sync
- Extensions > JPods > Animation submenu: Start + Stop; native menu, always responsive
- JS debounce: only on Start direction; Stop always fires immediately
- build_topology cache: cleared on stop; O(n²) proximity pass runs once per animation run
- Pod status dump throttle: full dump every NATALIE_VERBOSE_EVERY=5 reports (~10s)

**Agent flag API:**
- Ruby: `JPods::Console.execute_script("setAgentFlag('noelle', 'approved', 'msg')")`
- JS: `setAgentFlag(agent, status, message)` — status = approved|disapproved|pending|reset
- Flags reset to gray on Stop, to pending on Start

**Key files:**
- `main.rb` — toolbar buttons (Populate, Toggle Animation, Note), Extensions menu
- `jpod_vehicle_anim.rb` — start/stop/resume, save_resume_state v2, build_fleet, random dispatch
- `jpod_vehicle_runtime.rb` — populate_fleet class method
- `jpod_animator.rb` — start_animation/stop_animation wrappers, agent checks, escape tool
- `jpod_console.rb` — cmd_populate_fleet delegates to populate_fleet; cmd_toggle_random

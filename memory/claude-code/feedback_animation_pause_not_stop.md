---
name: Animation pause/freeze, not hard stop
description: Toolbar toggles pause/resume (freeze in place); no hard stop button; users clear pods to fully reset; 95% of the time users just want to reposition camera
type: feedback
---

The animation toolbar button toggles between Start → Pause → Resume. There is no hard stop button. If users want to fully reset, they clear pods with the Populate toggle.

**Why:** 95% of the time users only want to freeze the animation to reposition the camera. A hard stop (which clears all pod state, queues, Sally state) destroys the simulation unnecessarily. Pause keeps everything in memory — timer stops, pods freeze in place, user orbits freely, resume continues from where it paused.

**How to apply:**
- `AnimationV2.pause` — stops timer, keeps @@running=true, sets @@paused=true
- `AnimationV2.resume` — restarts timer via `_start_timer`, clears @@paused
- Extensions > JPods > Animation menu has "Start / Resume" and "Freeze" (no Stop)
- Toolbar icon toggles between animate.png (play) and stop_anim.png (pause)

---
name: Camera follow translates, does not lock angle
description: Camera follows pod movement by translation only; user can orbit/rotate/zoom freely during animation; old rigid delta transform replaced
type: feedback
---

Camera follow during animation and Travel trips applies the pod's movement as a **translation only** — eye and target move with the pod, but the up vector is preserved. The user controls the viewing angle at all times.

**Why:** The old code applied a rigid delta transform (position + rotation) to eye, target, AND up vector. This locked the camera to the pod's orientation — any user orbit/rotation was overwritten every frame. Users couldn't reposition the camera during a trip.

**How to apply:** `_camera_after` in animation.rb computes `move = new_pos - old_pos` and offsets both `cam.eye` and `cam.target` by that vector. `cam.up` is unchanged. The user's viewing angle persists across frames.

---
name: Animation open issues — 2026-06-20
description: Known unresolved animation bugs as of session 2026-06-20
type: project
---

After 2_parking network animation session, these are open:

**`model.entities nil` during animation**
Sally and Natalie scan `model.entities` inside the timer callback. The model handle captured at `start()` time goes stale mid-animation: `confirm_slots: model.entities nil — using in-memory state` and `compact_platform_idle: model.entities nil — skipping scan`. Root cause unknown. Workaround: fallback to in-memory state is in place. Real fix: use `Sketchup.active_model` inside the timer callback instead of the captured `model` variable.
**Why:** SketchUp's model reference can change if the model is reloaded or if the entities collection is temporarily locked during heavy operations.
**How to apply:** In jpod_vehicle_anim.rb timer tick, pass `Sketchup.active_model` to Sally/Natalie scans rather than the captured `model` variable.

**Double Natalie sweep per second**
Log shows two `[Natalie clock HH:MM:SS] sweep #1` lines at the same timestamp. SystemClock is likely registering the Natalie listener twice (possibly from multiple plugin reloads). Check JPods::SystemClock.register calls and add dedup guard.

**`dispatch_idle error: undefined method 'each' for nil:NilClass`**
Fires every ~6s during animation. Backtrace logging added (2026-06-20) but not yet observed. When it fires next, backtrace will appear immediately after the error line in jpod_console.log. Fix the nil source then remove the backtrace puts.

**All pods accumulating at one station**
During extended animation, all 14 pods drifted to s006. s007 platform emptied. Natalie dispatches idle pods but they all headed to s006. Likely a routing weight imbalance or missing return-trip dispatch when Sally platform is full.

**Inbound platform speed anomaly**
gw_platform_in1/in2 averaging 2-3× authorized speed (not first-frame artifact). Not yet investigated.

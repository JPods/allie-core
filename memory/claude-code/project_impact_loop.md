---
name: Impact auto-populate loop
description: Alice auto-fills impact.actual on Actions by scanning linked transactions; users correct; Alice learns from corrections
type: project
---

Action.impact = {predicted, actual, refs}. The loop:

1. User sets impact.predicted (waffly 1-5 gut feel) when creating the action
2. Alice auto-populates impact.actual by scanning transactions linked to the same customer within a time window
3. Alice fills refs.transactions with the evidence she found
4. User reviews Alice's guess — adjusts actual if wrong, adds explanation
5. Alice learns from the corrections: which action_types she over/under-estimates, which reps she calibrates well for
6. Users save admin time because Alice does the retrospection scan; they just confirm or correct

**Why:** Not precision, but retrospection. The gap between predicted and actual is the learning signal. Alice's guesses save admin time. User corrections are training signals. Each 2-second correction teaches Alice to be more accurate next time.

**How to apply:** Build Alice's impact scanner as a periodic task that finds Actions with predicted but no actual, scans for linked customer transactions, and fills in her best guess. Track correction rate as a calibration metric.

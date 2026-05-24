# Problem: Parking shuffle and personal space

**Domain:** SU — jpod_vehicle_anim.rb / jpod_vehicle_runtime.rb / natalie.rb
**Opened:** 2026-05-23
**Status:** Two root causes fixed; monitoring for recurrence

---

## Symptoms reported by Bill (2026-05-23)
1. Parking behaviors do not always shuffle forward
2. We lost personal space

---

## What we knew going in

5V test places N vehicles per platform. The highest-slot vehicles get trips and depart.
Remaining idle_reserve vehicles should shuffle forward (toward the departure end, highest slot).
compact_platform_idle() runs on every departure and on the 2-second Natalie sweep.

Personal space = slot_spacing_in = STANDARD_TEST_PERSONAL_SPACE_M * 1000 / 25.4.
Pod physical length = 2.271m (from bbox log).

---

## Root cause 1 — Slot collision (shuffle not always working)

compact_platform_idle computes:
  target_slots = (1..slot_count).to_a.last(n).sort

This ignores slots already reserved by in-transit vehicles. Sally.release_slot sets
parking_slot on the arriving pod's entity BEFORE its parking maneuver completes.
Compact saw that slot as free and assigned it to a second pod → overlap.

**Fix:** Collect all parking_slot > 0 values at this station (all entities + @@pods).
Subtract those not already in all_parked → reserved_by_others.
Target from available_slots = (1..slot_count) − reserved_by_others.

File: jpod_vehicle_anim.rb, compact_platform_idle (around line 1586)

---

## Root cause 2 — Lost personal space

STANDARD_TEST_PERSONAL_SPACE_M was changed to 2.5m to increase slot count.
Pod length = 2.271m. Gap = 2.5 - 2.271 = 0.23m. Barely visible.
Original value 3m → gap = 0.73m. Clearly visible.

Snap-to-slot code (jpod_vehicle_anim.rb line 819) hardcoded 3000.0mm regardless of constant.
After constant change to 2.5, snap and compact diverged.

**Fix:** STANDARD_TEST_PERSONAL_SPACE_M = 3.0 (restored).
Snap-to-slot now reads constant: JPods::JPodGuideway::STANDARD_TEST_PERSONAL_SPACE_M.

---

## Key numbers to watch
- Pod length:          2.271m
- Slot spacing:        3.0m (restored)
- Gap between pods:    0.729m
- S002 platform:       7.7m → 2 slots at 3m
- S004 platform:       23.9m → 7 slots at 3m
- Personal zone attr:  3.0m (set at placement by place_vehicle())

---

## Open questions
- Does S002 (2-slot capacity after 3m restore) cause any routing failures?
- Is 3m enough for safe stopping distance at 8.3 m/s (30 km/h)?
  Stopping from 8.3 m/s at 1 m/s² = 34m braking distance. 3m personal space
  is a visual marker only — real safety is Noelle ezone + Natalie headway.
- Does the compact now correctly handle the station_loop oneshot case?

---

## Log queries

To observe compact behavior:
  grep "Natalie compact" ~/Library/.../jpod_console.log | tail -50

To observe slot collisions:
  grep "Sally\|parking_slot\|compact" ~/Library/.../jpod_console.log | grep -E "S00[24]"

Key log lines to watch for recurrence:
  "[Natalie] compact X: VID ps1→ps1"  (no-op move — probably fine)
  "[Natalie] compact X: VID ps3→ps3"  (vehicle already at target)
  Two different VIDs logged at the same psN on same station within 1 second → COLLISION

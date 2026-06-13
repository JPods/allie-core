# Handoff — 2026-06-13 (session 2)

## Where We Left Off

Confirmed platform_shuffle test works (n001→hold_loop, n002/n003 compact, n001 returns to ps7).
TickLog reported minor_defects on hold_loop and park maneuvers.
Bill identified the root cause: Natalie issues trip.json with gw_platform; Nora and Sally must clip
gw_platform behavior at both ends of a trip rather than using Natalie's track instruction directly.

**Files changed this session:**
- `su_jpods/jpod_vehicle_anim.rb` — three clip_start fixes:
  1. Line ~2764 (park maneuver arrival): replaced `seed_pos: pod_pos` (bounds.center, wrong Z)
     with `seed_pos: pod.current_maneuver[:pts].last || park_pts.first` (path endpoint, correct Z).
  2. Line ~4219 (_dispatch_hold_loop_for_pod departure): replaced `transformation.origin`
     with `pod.pose&.first || pod.entity.transformation.origin` for clip_start seed.
  3. Line ~4319 (_dispatch_next_sequential departure): same fix for sequential hold_loop dispatch.
  4. Line ~3318 (originating chain exit): replaced `bounds.center` with `pod.pose&.first || bounds.center`.

**Test not yet run.** Changes written, not tested in SketchUp.

## What To Do First Next Session

1. **Reload and test:**
   ```ruby
   load Sketchup.find_support_file('jpod_vehicle_anim.rb', 'Plugins/su_jpods')
   ```
   Then run platform_shuffle. Watch for:
   - `[Sally SID] NORA_0003 departure: gw_platform reversed to entry-first for clip_start`
     (confirms the fix fired; if it says "already entry-first" the pts were already correct)
   - n001 (NORA_0003) should move a SHORT distance from ps9 forward to exit, NOT backward through ps1
   - No jump from gw_cp_out_0 to gw_platform on return
   - TickLog deltas ≈ 0 (was -196, -100, -20)
   - natalie_verdict: 'authorized' (was 'minor_defects')

2. **If log says "already entry-first" and pod still goes backward:** the lookup cache
   may already have entry-first pts from a prior run's cache, but clip_start is still wrong.
   Check whether `_platform_pts_entry_first` returned the correct orientation by comparing
   pts[0] position to Sally's ps1 slot position.

3. **After test passes:** commit everything on su_jpods_claude branch.

## Architectural Decision This Session

Bill: "Natalie should not dominate Nora and Sally behaviors."
Rule: Natalie issues gw_platform by track name — that is correct. Nora and Sally intercept:
- DEPARTURE: clip_start clips gw_platform from pod's slot position. Seed = pod.pose.first (path Z).
- ARRIVAL: park maneuver seed = pod.current_maneuver[:pts].last (path endpoint = gw_platform entry).
Never use bounds.center or transformation.origin as seed_pos for platform maneuvers.

## Open Questions

- Do the hold_loop[11/11] and [9/9] deltas improve after the pose.first fix? Or were they
  frame-rate timing artifacts (animation loop variance), not seed_pos issues?

## TFTS Written This Session

- `process/inbox/20260613T164218-tfts-gw-platform-clip.md` — gw_platform clip principle

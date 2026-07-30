# Random Trip Assignment — Quick Reference

## What's Implemented

### Core Functions (jpod_guideway.rb)

**`JPodGuideway.assign_random_trips_to_all_vehicles(model, exclude_nora_ids=[], min_hops:2, max_hops:8)`**
- Line 297 in jpod_guideway.rb
- Auto-assigns random closed-loop trips to unassigned vehicles
- Skips directed vehicles (exclude list) and preserves existing trips
- Returns `[assigned_count, failure_count]`

**`JPodGuideway.generate_random_closed_trip(gw_index, fm_paths, num_hops)`**
- Line 393 in jpod_guideway.rb
- Generates single random valid closed loop using FollowMe connectivity
- Returns `[L1, L2, ..., L1]` array or nil

### Console Task (jpod_console.rb)

**"Assign Random Trips to Fleet"** (line 268)
- Category: Vehicles
- Parameters:
  - `min_hops` (default: 2) — minimum trip length in segments
  - `max_hops` (default: 8) — maximum trip length in segments
- One-click fleet initialization for traffic simulation

## How to Use (in SketchUp)

1. Build your JPods network (structures + guideways)
2. Optionally assign 1-2 vehicles directed routes (Message 1-2 feature)
3. Open JPods Console task panel
4. Select task: **"Assign Random Trips to Fleet"**
5. Set hop range (default 2–8 is good for most networks)
6. Execute
7. Check Ruby Console for per-vehicle assignment results
8. Click **"Start Animation"** to see fleet simulation

## Expected Behavior

- Each vehicle gets a random closed-loop trip of 2–8 segments
- Trips respect FollowMe network connectivity (no teleports)
- Directed vehicles are skipped (preserve Message 1-2 assignments)
- Logs show: trip assignment success/failure per vehicle
- Console: "Successfully assigned random trips to N vehicle(s)"

## Test Results

✓ Random 3-hop generation tested: L1 → L2 → L3 → L1  
✓ Connectivity validation tested: correctly rejects non-connected paths  
✓ Syntax validation passed: both modified files pass `ruby -c`  
✓ Integration verified: all functions callable, no missing dependencies  

## Next Steps

- Test in live SketchUp with your network
- Adjust min_hops/max_hops if fleet behavior needs tuning
- (Optional) Implement Message 3 click-based trip tool (lower priority)

## Implementation Notes

- Uses existing JPodFollowMeTool paths (same as animation runtime)
- Validates each trip before persistence (prevents invalid routes)
- One bulk save to vehicle_trips JSON (atomic, efficient)
- Preserves all existing trip assignments (doesn't overwrite)
- Compatible with production and structure-based network JSON formats

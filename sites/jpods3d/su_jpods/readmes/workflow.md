# JPods Plugin Workflow

## Required Sequence: Compute → Build → Animate

These three steps are a strict ordered pipeline. Skipping or reversing the order produces silent errors.

| Step | What it does | Output |
|------|-------------|--------|
| **Compute** | Noelle reads station template geometry, calculates track directions, successor chains, and CP world positions; writes `lines.computed.json` to the template folder | `templates/track_formations/<template>/lines.computed.json` |
| **Build** | Reads `lines.computed.json` from each template; applies each station's world transform (translation + rotation from network.json); embeds direction-aware track geometry into network.json natalie section; generates physical 3D beam geometry | `<model>/network.json` (with world-space natalie section populated) |
| **Animate** | Natalie reads lines.computed.json from the template, compares its `generated_at` timestamp to network.json's build timestamp. If Compute is newer than Build, Natalie **refuses to animate** and reports: "Run Build before animating." If timestamps are valid, animation proceeds with correct direction and successor data — no proximity fallbacks | Trip plans, trip reports |

**Why this matters:** Before this architecture was established (2026-06-18), Natalie read `path.json` (raw geometry, no direction data) at animation time. Every trip dispatched 130 proximity fallbacks and reversed 4 tracks per trip because there was no computed direction to read. The confirmation step is Natalie's validator — it stops animation before silent degradation starts.

**Moving a station requires a new Build.** Station world coordinates changed; network.json is stale. This is correct behavior, not a limitation.

## Model-Level File Structure

Each model folder (`~/Documents/skp_jpods/<model>/`) should contain exactly:

| File | Contents | Written by |
|------|----------|-----------|
| `lines.json` | Raw geometry — track centerline pts_mm in world space | Build |
| `lines.computed.json` | Compute output — direction, successor chains, CP positions | NOT here — lives in template folder |
| `network.json` | All structural non-trip data: station transforms, connections, natalie routing section | Build |
| `trip_reports/` | Trip plans and trip reports | Natalie during animation |

**Template-level file:** `lines.computed.json` lives at `templates/track_formations/<template>/`, not in the model folder. It is in local frame coordinates. Build transforms it to world space when writing network.json.

---

## Step-by-Step User Workflow

1. users create a .skp file and load in terrain.
2. Users place stations and traffic circles.
3. Users place markers where guidways need to adjust to terrain or buildings.
4. Users ask for CPs (Connection Points)
5. Plugin responds with cyan circles at points that can be connected.
6. Users match connection points.
7. Plugin responds with bezier curves between connections.
8. User selects Build and Plugin deploys the guideways based on user selected connections and the settings for bezier curve matching
9. Users add and or move markers to adjust the guideways.
10. Users inspect the followme line to assure there are no breaks (test).
11. Users inspect the followme lines between each of the platforms.
12. Users add 1 vehicle to a station and direct it to travel to the other stations one at a time.
13. Users add 5 vehicles to one station and send 3 of them to other station. The 2 remaining vehicles shuffle forward to fill unoccupied parking spaces.
14. Vehicles move forward with the lead vehicle on any line moving forward first at each tick, so they do not collide.
15. Vehicles cannot pass another vehicle. 
16. Vehicles within 3 meters of each other, move apart at .5 meters per tick.
17. Vehicles approaching a vehicle that is going to use a u-turn, slow to give them space, or we could set the normal travelling distance between vehicles at 6 meters.
18. Vehicles merging adjust their speeds ahead of time to allow smooth merging at intersections.
19. Low priority. Station loop behavior. Normally vehicles are loaded from the highest number parking slot, 8. But sometimes there will be cases where special needs vehicles are at parking space 2 while other vehicles are in the parking spaces 3-8. In that case, the vehicles in 3-8 will move forward to the u-turn, then travel passed the station to the next u-turn, and return into the station. In the mean time, pod 2 leaves and pod 1 suffles forward to parking space 8.


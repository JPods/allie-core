# Outstanding Issues List (OSList)

Issues we cannot resolve at the moment they arise. Each entry records what we know and why we are deferring.
When an item is resolved, move it to the Resolved section with the date and resolution.

---

## Open

### ~~1. CP Barrier Tool — 2026-06-24~~ RESOLVED
**Resolved 2026-06-24/25:** cpb component created, Build detects barriers via proximity, Crew Health reports barriered vs unresolved CPs. Connect tool renders barriered CPs in blue.

### 2. Kink defects on seg_S005_3_S010_1 — 2026-06-24
**What:** Build reports kinks up to 94.2° on the centerline between traffic circle s005 (CP 3) and station s010 (CP 1) in the West Point model. Points 222-232 of 127-point centerline.
**What we know:** Build tangent log shows `from=(172.1,-164.9,1.4)m tangent=(0.749,0.663) → to=(209.6,-43.2,6.3)m tangent=(0.259,-0.966)`. May be a waypoint or bezier control point issue near the traffic circle approach.
**Why deferred:** Geometry investigation needed — separate from the routing/validation work in this session.

### 3. Quick fixes from baseline cleanup — 2026-06-24
**What:** Three stale files need minor updates:
- `wisdom/README.md` — index lists 2 files, should list 11
- `sketchup/jpods-plugin.md` — wrong plugin path (`JPods/` should be `su_jpods/`)
- `agents/agent-team.tsv` — missing Sally
**Why deferred:** Non-blocking; cosmetic updates for next session.

### ~~4. Unify template test behaviors with network animation — 2026-06-24~~ RESOLVED
**Resolved 2026-06-24:** Template tests now use the same AnimationV2 engine, Sally conveyor (`_sally_advance_conveyor`), and 3-second exit hold as the network. One code path.

### 5. Travel app origin switching — 2026-06-25
**What:** User selects Thayer (s010) as origin but the trip books from Ferry (s006). The origin dropdown appears to reset.
**What we know:** trip_book receives correct origin_id=s010, but the pod dispatched is from s006. May be related to loadStations being called twice (goHome reloads). Duplicate console callbacks eliminated but issue persists.
**Why deferred:** Functional Travel trips work — routing, arrival, parking all correct. Origin UX needs JS debugging.

### 6. Zipper merge — Natalie proactive speed adjustment — 2026-06-25
**What:** Natalie should estimate arrival times at junctions and adjust speeds BEFORE the intersection to create 2m personal safety gaps. Current ezone code is reactive (3m zone). Need proactive lookahead.
**What we know:** EZone infrastructure exists and is hooked into animation tick. build_from_network + enforce_ezone_spacing are active. Missing: Natalie lookahead algorithm that plans speeds so pods arrive staggered.
**Why deferred:** Infrastructure in place. Algorithm design needed.

### 7. Unified trip.json — 2026-06-25
**What:** All trips (Travel, Random dispatch, rebalance) should use the same trip.json structure and code path. Travel-specific data (camera, user prefs) as optional fields.
**What we know:** Duplicate Travel callbacks eliminated. Sally parking unified. Still need a formal trip object that all dispatchers produce.
**Why deferred:** Functional — all trips use the same Sally/Natalie/AnimationV2 path now. Formal trip.json structure is a design task.

### 8. Pods Display — wire Sally's full data — 2026-06-25
**What:** Console Pods tab should show Sally's full station/slot/pod data.

### 9. Speed anomaly investigation — 2026-06-25
**What:** Curve-radius cap transitions producing speed anomalies.

### 10. Cross-segment spacing refinement — 2026-06-25
**What:** Spacing between pods on adjacent segments needs tuning.

---

## Resolved

- **#1 CP Barrier Tool** — 2026-06-25: cpb component, Build detects, Crew Health reports
- **#4 Unified template tests** — 2026-06-24: one code path with AnimationV2
- **Non-planar build segments** — 2026-06-25: confirmed fixed by Bill
- **Crew Health dashboard in console HTML** — 2026-06-25: confirmed done by Bill
- **Console v2 rework (duplicate window)** — 2026-06-25: confirmed done by Bill

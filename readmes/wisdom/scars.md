# Scars — The Cost Ledger
**Purpose:** Every hard lesson has a cost. This file records what each lesson cost —
in time, in trust, in risk — so that a successor reading the rule knows it was earned.

A rule without a scar is borrowed confidence. A scar without a rule is just pain.
Both together are the beginning of wisdom.

**Format:**
```
## [Scar name] — [Date]
**Cost:** what was spent or risked
**What was hard to see:** why the cause was not obvious
**The rule it produced:** one sentence
**Where the rule lives:** pointer to the documentation
```

---

## Vector3d * Float — 2026-05-13

**Cost:** Multiple sessions of build pipeline failures. Every attempt to place
waypoints or build guideways crashed silently or with a generic ArgumentError.
The error message (`Cannot convert argument to Geom::Vector3d`) pointed to the
symptom (the operator) not the cause (SketchUp's missing coerce method). Three
separate files had independent copies of the pattern, so fixing one left the others broken.

**What was hard to see:** The `*` operator works this way in standard Ruby with
custom classes that implement `coerce`. SketchUp's Vector3d looks like it should
work the same way — it's a geometry primitive, it has length, it has normalize.
The assumption that `normalize * scalar` would work came from correct intuition
about how Ruby works, applied to an environment where the author of Vector3d made
a different choice. There was no documentation warning. The error happened at
runtime, not at load time.

**The rule it produced:** Never use `Vector3d * Float`. Always expand to components:
`Geom::Vector3d.new(n.x * s, n.y * s, n.z * s)`.

**Where the rule lives:** `readmes/sketchup/jpods-plugin.md` Rule 7;
`su_jpods/CLAUDE.md` Engineering Rules.

---

## The 8.4m Guideway Height — 2026-05-13

**Cost:** Three rounds of fixes, each of which was individually correct but incomplete.
Round 1: zeroed marker Z values (correct — markers should not carry legacy height).
Round 2: computed anchor_zs from terrain + CLEARANCE_HEIGHT instead of structural
stub height (correct — anchors should come from terrain, not station geometry).
Round 3: realized that anchor_zs only pins the endpoints; `desired_z` (from the
Bezier spline inheriting structural stub Z) kept the interior at 7.5m even with
4.6m anchors, because the grade corridor allowed it.

**What was hard to see:** PathBuilder's design is sound. It correctly honors
`desired_z` when it fits within the grade envelope. The bug was not in PathBuilder —
it was in the assumption that fixing the endpoints (anchor_zs) would fix the
interior. The grade corridor is wide enough on long segments that a 7.5m interior
is reachable from 4.6m anchors. The fix is upstream: zero the source Z so
PathBuilder's floor_z dominates.

This scar has a second layer: the root cause (structural station templates at 7.5m)
is not yet fixed. F-07 is on the feature list. The code now works around the
structural mismatch. The mismatch itself is still there.

**The rule it produced:** Zero center_pts Z before PathBuilder. anchor_zs pins
endpoints; floor_z sets the interior. Source Z from legacy geometry must not
contaminate the vertical profile.

**Where the rule lives:** `readmes/sketchup/jpods-plugin.md` Rule 8;
`su_jpods/CLAUDE.md` PathBuilder section; `readmes/wisdom/clearance-height.md`.

---

## Silent Degradation — Stations Missing Platform Tags — 2026-04-27

**Cost:** A week of routing that appeared to work but produced nonsense. Natalie
planned trips. Nora executed them. The trips were wrong because the destination
platforms were not findable — `platform_guideways` tag was missing. No error.
No crash. Just wrong routes to wrong places.

**What was hard to see:** Silent degradation looks like correct behavior until
you check the output carefully. The routing algorithm did not fail — it succeeded
in routing to the wrong place. The missing tag meant Noelle could not find the
platform; the routing algorithm found the next best thing. Everything ran. Nothing
was right.

**The rule it produced:** Fail fast at definition time. `component_definition_faults()`
gates before BFS. A missing definition is a hard stop, not a warning.

**Where the rule lives:** `readmes/agents/noelle.md` Understandings U-SK-001;
`readmes/agents/allie.md` Design Decisions 2026-05-01.

---

## Natalie Dropping Every START Ping — 2026-04-07

**Cost:** An entire demo where no pod moved. Pods sent START pings. Natalie received
them and silently dropped every one. The robots were functional. The routing was
correct. The protocol check (`msg.length != 7`) was wrong because Nora had added
a version field (index 7), making every valid START ping exactly the length that
the check rejected.

**What was hard to see:** The failure mode was total silence. No error message.
No rejected-ping log. Pods went into RESEND loop, which looks like a network problem
or a hardware problem or a pod problem. It was a parser comparison that had aged out
of sync with the protocol it was parsing.

**The rule it produced:** Use `msg.length < 7` (minimum), not `msg.length != 7`
(exact). Protocol fields grow forward; parsers must be minimum-length tolerant.

**Where the rule lives:** `readmes/agents/natalie.md` Design Decisions 2026-04-07.

---

## Centerline-Derived Animation Position — 2026-05-13

**Cost:** Multiple guideway height failures and animation path collapses traced
to the same root cause: a computed centerline or midpoint used as an authoritative
position reference. SketchUp's geometry kernel is edge-based. FollowMe walks edges.
When a calculated point was fed to FollowMe instead of a real edge endpoint, the
path collapsed or drifted.

**What was hard to see:** The centerline looks right. On a 2D plan it is exactly
where you expect it to be. The problem is invisible until SketchUp tries to sweep
geometry along it — at which point the mismatch between the calculated position
and the nearest real edge produces unexpected results. The principle (edge-first)
is obvious in retrospect but not before you've seen FollowMe fail on a midpoint.

**The rule it produced:** All position references anchor to hard physical edges.
No calculated centerlines as authoritative references.

**Where the rule lives:** `readmes/sketchup/jpods-plugin.md` Rule 8;
`readmes/agents/noelle.md` Universal Rules; `su_jpods/CLAUDE.md`;
`readmes/wisdom/clearance-height.md` Cross-Domain Connection.

---

## The Platform Host Guideway Collapse — 2026-05-01

**Cost:** One full session debugging vehicle placement. Vehicles were placed but
immediately teleported to position t=1.0 — the end of their path — making them
invisible. The cause: `stitch_structure_followme_paths` was greedily matching
synthetic 2-point platform host guideways as full FollowMe paths. A 23.9m real
path was being replaced by a 0.4m synthetic one. `t=1.0` on a 0.4m path means
the vehicle is 0.4m from the start — visually at the beginning but mathematically
at the end.

**What was hard to see:** The vehicle was placed. The path existed. The position
value (t) looked wrong in debug output but t=1.0 is a valid state (end of path),
so it didn't immediately read as broken. The collapse from 23.9m to 0.4m happened
in the stitcher, which ran silently.

**The rule it produced:** Override `vehicle_path_for` for platform host guideways
to skip FollowMe stitching. The stitcher is greedy — any guideway endpoint near
a station terminus is a candidate. Platform host guideways are synthetic and must
be excluded.

**Where the rule lives:** `readmes/agents/allie.md` Design Decisions 2026-05-01.

---

## Console Commands Must Be Letter-Perfect — 2026-05-18

**Cost:** Multiple failed reload attempts. Bill had to diagnose why a copy-pasted
console command produced a syntax error. Most users would not have known where
to look. The error was invisible — extra whitespace introduced by markdown rendering
at the spaces in `Application Support` and `SketchUp 2026`.

**What was hard to see:** The command looked correct on screen. The code block
rendered cleanly. The spaces in the path are legal Ruby. The problem was that
markdown formatting — both fenced code blocks and backtick inline code — adds
whitespace when wrapping long lines at existing space characters. The user sees
a clean command; the terminal receives a broken one. There is no visible indicator
that the path has been split.

**The rule it produced:** Never post a SketchUp reload command as a literal path.
Use `Sketchup.find_support_file('filename.rb', 'Plugins/su_jpods')` — no spaces,
no wrapping risk, works on any machine.

**Where the rule lives:** `Allie/CLAUDE.md` Reload Command section.

**The broader principle:** When posting any console command to a user, verify
it contains no spaces that markdown could wrap. A command that works on screen
but fails in the terminal is worse than no command — it consumes the user's time
diagnosing a problem that was never theirs.

---

## S050.CP0 Inward Tangent — Explicit Datum Beats Derived Reference — 2026-05-18

**Cost:** Three fix attempts across two sessions. Guideway curves looped backwards at S050.
Bill described it: "What SketchUp is doing is not paying attention to the CP vector." Two fixes
(avg_outward_tangent guard, radial distance swap from formation_center) both failed because they
reasoned from derived references — the cluster centroid and the bounding box center — which can
both be wrong for asymmetric or unusual station templates.

**What was hard to see:** The cluster logic had correct variable names (`:outer`, `:inner`) but
the underlying projection axis mapped "max projection" to the INWARD face and "min projection" to
the gate face — meaning the names were swapped relative to their physical meaning. Radial distance
from `formation_center` corrected the swap in most cases, but `formation_center` (bounding box
center) is not the true geometric center for every template. S050 exposed this.

**The rule it produced:** When `cap_pt` is present, use `stub_centroid → cap_pt` to validate
the tangent direction. `cap_pt` is a `dead_cap_end` entity placed by the model author — it is the
explicit gate datum. If the computed tangent points away from `cap_pt`, reverse it. No clustering,
no radial distance, no bounding box center needed.

**Corollary — connect tool:** `bezier_pts_via` used the TO endpoint's outward tangent directly
in the Hermite formulation. In the Hermite Bezier, terminal tangent = velocity at that point.
Arriving at a station means velocity is INWARD = reverse of outbound tangent. Fixed with `.reverse`.
`bezier_spline_pts` in jpod_network.rb already had `.reverse`; the connect tool did not.

**The broader principle:** Explicit model data beats derived data. Every time a derived reference
(centroid of clusters, bounding box center, radial distance) was used instead of an explicit
model datum (cap_pt, edge endpoint, tagged entity), the code was one template edge case from failing.

**Where the rule lives:** `su_jpods/jpod_structure_tool.rb` `scan_stub_pair_tips` — cap_pt
validation after clustering. `jpod_connect_tool.rb` `bezier_pts_via` — `.reverse` on TO tangent.

**The tf/dnw proof:** A TF file captured at 21:27:27 named the bug precisely before the fix session
started: "to_tangent must negate for arriving guideway." Two DNW entries tracked the failed paths.
The principle emerged from asking WHY both prior fixes failed — not by trying a third variation.
This is the first documented proof that the tf/dnw system accelerates diagnosis.

---

## Solar Tag Hide — tf/dnw Second Proof — 2026-05-18

**Cost:** Solar panels not hiding when "JPods Solar" toggled in Tags panel. Two root causes
discovered in sequence: (1) `jpod_layer_manager` never loaded due to boot.rb load-order bug
— `$jpods_main_loaded = true` set before `main.rb`, skipping its entire body. (2) Even after
the load-order fix, existing built geometry predated the fix and was still on Untagged.

**What was hard to see:** Both causes were invisible at the surface. Tags appeared in the panel
(after model close/reopen) but hiding had no effect. The load-order bug was one line in boot.rb
that meant `JPods::LayerManager` was never defined — all `if defined?` guards silently fell
through. The stale-geometry problem was conceptually separate: even correct code doesn't retag
geometry that was already built.

**The rule it produced:** `ensure_tags` must call `retag_existing_solar` — a walk of top-level
model entities that reassigns `Solar_*` groups still on Untagged. Run on every model open, not
just during Build. Idempotent.

**Where the rule lives:** `jpod_layer_manager.rb` `retag_existing_solar`; `boot.rb` AppObserver
`on_model` + 4s startup timer.

**The tf/dnw proof (second):** TF file at `process/inbox/20260518T223112-tf.md` named
`jpod_entities_builder.rb:846` and `:880` before the session. Session used that entry point and
found two more layers beneath it. Bill's verdict: "Excellent — this is what I hoped for from tf
and dnw." tf/dnw is now an **established protocol**, not an experiment.

---

## Beam Solid Trace Beats Centerline Arc — 2026-06-06

**Cost:** Multiple sessions of chaotic gw_uturn_1 animation. Y values oscillating
past the ±1500mm semicircle endpoints to ±2000mm. Z jumping between two values.
Pod appearing to loop the outer rail circle rather than traverse the centerline.
cp_lead tracks traversed instantaneously with wrong endpoints (300mm chord instead
of 2500mm horizontal). Each symptom was individually diagnosable but the root cause
was not visible until anim-coords.jsonl was read to check the `source` field.

**What was hard to see:** The animator has a three-source lookup assembly
(path.json → map.json → edge_lookup). path.json was loading the correct 13-pt
centerline arc. The merge was then replacing it with the edge_lookup entry — which
had 56 pts (more!) and source=edge_attr. "More pts = better arc" is a reasonable
assumption for upgrading chords. It is wrong when the edge_lookup reads the FollowMe
beam solid instead of the original ArcCurve. The FollowMe solid has many more edges
than the centerline arc — outer rail full circle, inner rail, top and bottom face
edges with Z jumps — all of which are "edges" and all of which are wrong for animation.

The second rule (extracted→edge_attr) had inverted semantics. "extracted" means
*we already got the centerline from the ArcCurve during Build*. ":edge_attr" means
*we read the live beam solid now*. The rule read it as "stored attribute beats
computed extraction" — the opposite of what the names mean.

**The rule it produced:** edge_lookup may only upgrade a chord (≤2 pts). If path.json
already has a multi-pt extracted centerline, edge_lookup loses. Check `source` in
anim-coords.jsonl first — source=edge_attr on an arc track means the merge fired wrong.

**Where the rule lives:** `readmes/agents/natalie.md` Design Decisions 2026-06-06;
`jpod_vehicle_anim.rb` edge_lookup merge comment (lines ~1826-1834).

---

## Component Definition ≠ Model Instance — 2026-06-13

**Cost:** ~2 hours. Entity attribute edits appeared to succeed (no error, `true` returned)
but had zero effect on animation behavior. Repeated attempts with different approaches
each produced the same silent non-result. The real cause — wrong Ruby object type —
was only found by comparing entityIDs between two lookup methods.

**What was hard to see:** SketchUp's `ComponentInstance` has both `definition.entities`
(the shared template) and the instance itself. Both respond to `set_attribute` and
both accept writes without error. The documentation doesn't warn you that writes to
`definition.entities` members affect all instances of that component, not just the one
in the scene. The `find_vehicles` console function recurses into definitions — looks
reasonable, finds what looks like the right objects, sets attributes that appear to stick.
The entityID comparison was not obvious until explicitly checking why the write had no effect.

**The rule it produced:** Always use `all_nora_vehicles_in_model` (searches `model.entities`)
to find placed vehicle instances. Never use a recursive function that descends into
`e.definition.entities` — those are shared template objects, not scene instances.
Verify entityIDs match between the lookup and the consumer before concluding a write worked.

**Where the rule lives:** `readmes/retrospections/2026-06-13.md` Lesson 1.

---

## Erase-Recreate Test Harness Invalidates All Post-Creation Patches — 2026-06-13

**Cost:** ~1 hour. Correctly-found instances, correct entityIDs, attributes set and
confirmed. Restarted animation, attributes gone. No error. The problem was invisible
until reading the console code's erase loop at test start.

**What was hard to see:** It's natural to think "the entities are there in the model;
I can patch them." The erase-and-recreate pattern at test start is not unusual for
test harnesses — but it creates a temporal trap: anything you set between the end of
one run and the start of the next run is silently overwritten. The harness does not
warn you that it discards entity state.

**The rule it produced:** Before patching entity attributes in a test harness, read the
setup code: does it erase and recreate entities on start? If yes, fix the `tag_vehicle`
or equivalent setup lambda instead — that is the only place initial state survives.

**Where the rule lives:** `readmes/retrospections/2026-06-13.md` Lesson 2.

---

## Memory Without Measurement — 2026-06-27

**Cost:** Claude Code did not read Allie's facets or recall files at session start,
despite the rule existing in CLAUDE.md, in memory entries, and in the agent README.
The session succeeded anyway — the problem (database scramble) was diagnosable from
first principles. But if the problem had required cross-domain context that only Allie
held, the session would have failed. The memory system had the right rules. Nobody
checked whether they were being followed.

**What was hard to see:** The rules existed. The memory entries existed. The handoff
said what to do. But having rules is not the same as measuring compliance. The team
had memory without retrospection-against-markers — which is storage, not learning.
Activity logs (what we did) masqueraded as retrospection (what we did vs. what we
said we'd do). The gap was invisible because the retrospections read like they were
thorough. They listed actions. They just never graded those actions against the
markers that said what should have been done.

**The rule it produced:** Every retrospection must measure performance against memory
markers. Grade A–F per marker. A pattern of Fs on the same marker means the marker
is wrong or the team is ignoring it. Both are actionable. Activity logs without
grades are not retrospection.

**Where the rule lives:** `CLAUDE.md` § "Retrospection Against Memory Markers";
`readmes/wisdom/retrospection-against-markers.md`; `readmes/agents/README.md`
Cross-Cutting Rule 6; agent files for Allie, Alice, Noelle.

---

## [Scars not yet paid — watching]

| Risk | Date accepted | What it will cost if unpaid | Owner |
|------|--------------|----------------------------|-------|
| 4.6m clearance without sensors | 2026-05-13 | Pod struck by overheight vehicle | Bill James |
| Station stubs at 7.5m (F-07) | 2026-05-13 | Structural gap at every station connection | Pending template redesign |
| Trip booking API keys plain JSON (NS-05) | 2026-04-29 | Credential exposure if file is exfiltrated | Athena / encrypt before release |
| No passenger feedback loop (NEW-04) | Pre-2026 | Cannot detect when service fails individual passengers | Alice |

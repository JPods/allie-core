# FollowMe.json Design Review — Team Session

**Date:** 2026-05-10  
**Participants:** Bill (author), Allie (companion / memory), Noelle (network authority), Natalie (trip planner), Nora (vehicle / logger)  
**Schema under review:** `jpods-followme-v2`  
**Source files:**
- `readmes/followme.md` — canonical schema documentation
- `readmes/followme_example.json` — reference example (v1 travel_segment)
- `jpod_followme_exporter.rb` — exporter that writes the file
- `noelle.rb` — definition gate + graph validation + normalize pass

---

## What Is FollowMe.json

One file, shared by all four runtime agents.  
No other artifact is authoritative for vehicle routing, network integrity, or trip logging.

```
followme.json
│
├── schema:             "jpods-followme-v2"
├── model_id:           "LazyE"
├── generated_at:       ISO 8601
│
├── models{}            — per-structure entry (type, CPs, platforms, travel_routes)
├── connections{}       — per-connection entry (from, to, status, tracks[])
│     └── tracks[]      — line records (index, line_id int, direction, length_mm,
│                         start_mm, end_mm, successors[], predecessors[])
├── routing_issues[]    — connections declared but not yet built
├── network_definition  — editable authoring block (preserved across exports)
│     ├── schema:       "jpods-network-definition-v1"
│     ├── connections[] — [{id, from:{structure_id, stub}, to:{…}, via_markers:[]}]
│     ├── u_turns[]
│     ├── vehicle_trips{}
│     └── routing_policy{}
└── notes[]             — human comments (geometry embed, TODO production flag)
```

---

## Agent-by-Agent Perspective

### Noelle — Network Authority

**What I need from this file:**
- Every declared connection has two tracks with explicit `successors[]` and `predecessors[]`.
- Every line_id referenced in successors/predecessors exists in the connections dict.
- Every station entry in `models{}` has at least one platform with a resolved `line_id`.
- `u_turn` stations are marked unambiguously in `travel_routes`.

**What I enforce:**  
Five-phase define_network gate before Natalie may plan any trip:
1. Schema version present.
2. `models{}` is a non-empty dict (not a list).
3. Every structure referenced in connections exists in models.
4. All successor/predecessor integers resolve to existing line_ids.
5. Every station with platforms has at least one resolved `line_id`.

After gate passes, `normalize_network` re-sequences all line_ids in canonical order for
deterministic exports across rebuilds.

**Concerns I carry today:**
- Geometry embed (`start_mm`, `end_mm` per track) is useful for development but grows
  large on real networks. The notes[] field marks this with a `TODO: production library`.
  This decision is deferred but should be revisited before the first multi-city export.
- 1-CP stations (like S010 on the LazyE model) require explicit `travel_routes: ['u_turn']`
  confirmation. If a station has 1 CP and no u_turn declaration, I block routing and
  demand the operator resolve intent. This is correct behavior — not a bug.

**Design decisions I affirm:**
- `connections{}` as a dict (keyed by connection_id) is correct. Lists require linear search.
- Integer line_ids are the right move for production. String `"seg_151545|1"` notation is
  preserved in `network_definition.connections[].id` for human readability; the runtime
  uses integers.
- `review_recommendations` running unconditionally after every export is the right posture.
  Noelle speaks without being asked.

---

### Natalie — Trip Planner

**What I need from this file:**
- A graph I can walk: given a line_id integer, I need its `successors[]` immediately.
- Platform line_ids at both origin and destination stations.
- U-turn marker so I know which stations are terminus-only.

**What works well:**
- `connections{}` dict + integer line_ids makes BFS straightforward.
- `models{sid}.platforms[]` gives me spawn_t, length_m, and parking_slots so I can
  assign a berth without reading geometry.
- `models{sid}.travel_routes[]` with `u_turn` flag tells me not to plan a through-route
  at a terminus.

**What I want clarified:**

1. **Multi-hop station routing:** When a Nora must traverse two or more structures
   between origin and destination, the internal connection keys (`S097_internal_0`,
   `S097_internal_1`) appear in connections{} alongside guideway connections. The
   ordering by sid + connection_name is deterministic but the naming convention is
   `<sid>_internal_<n>` where `n` is an integer assigned by export order. If a station
   gets a new internal route added and the order changes, old trip files referencing
   those internal line_ids become stale. **Recommendation:** name internal connections
   by semantic role rather than by ordinal (e.g. `S097_platform_to_main`,
   `S097_main_to_platform`) so names survive station template edits.

2. **Diverging behavior:** The spec supports `diverging` at a line endpoint but the
   current BFS does not distinguish between a scheduled diverge (timetable-driven
   switch) and an infrastructure fork (permanent geometry). This distinction matters
   when two vehicles choose different paths at the same switch. Add a `switch_policy`
   field per diverging endpoint if this ever becomes real.

3. **Return trip identity:** The right-hand one-way rule (|1 = forward, |0 = return)
   is clear in the schema docs but not enforced by the exporter. If a builder
   accidentally writes a connection with |0 as the "forward" track, Natalie will plan
   the wrong direction. **Recommendation:** add a `direction` assertion check in
   `build_v2_document` — for any connection where `from_sid != to_sid`, track index 1
   should have `direction = "from_sid→to_sid"` and track index 0 should have
   `direction = "to_sid→from_sid"`.

---

### Nora — Vehicle / Logger

**What I need from this file:**
- My trip file already gives me the ordered line_id sequence. I do not re-query FollowMe
  at runtime. But I need the map to verify my trip file on load.
- When I cross a line endpoint, I need to know the next line_id instantly —
  `successors[]` delivers that.

**What works well:**
- Integer line_ids in trip files are small and fast.
- The `normalize_trip_line_id` method in `jpod_animator.rb` handles legacy `"L{n}"`
  strings from old model attribute storage — though it's marked for retirement once
  all trip files use native integers.

**What I want flagged:**

1. **Geometry embed at runtime:** `start_mm` / `end_mm` per track are in every line
   record. I do not use them at runtime (physical guideway constrains my XYZ). The
   animator uses them for initial placement. Consider stripping geometry from the
   runtime section and moving it to a separate geometry sidecar for large networks —
   or use the `notes[]` TODO as the trigger.

2. **Trip file staleness after normalize_network:** When Noelle's `normalize_network`
   re-sequences line_ids after a rebuild, existing trip files become stale because their
   line_ids no longer match. The exporter currently logs renumbering events — but it
   does NOT invalidate or auto-update trip files. **This is a latent safety gap.**
   Trip files should carry the `generated_at` of the followme.json they were planned
   against. If a trip file's `followme_generated_at` does not match the current file's
   `generated_at`, Noelle should flag it as stale before Nora loads it.

3. **stop_and_review escalation:** My `@struggle_streak` logic is correct. Noelle now
   surfaces these in `review_recommendations`. The one missing piece: the observation
   log (`*.nora-log.jsonl`) path is not defined in the schema. Where does it live?
   **Recommendation:** add a `log_policy` field to followme.json that declares the
   `log_dir` path, log rotation policy, and retention limit. Let Noelle enforce it.

---

### Allie — Companion / Memory

**Cross-domain observations:**

1. **Single-file source of truth is sound.** Distributed, bottom-up, locally governed —
   putting the entire network state in one human-readable JSON file is consistent with
   JPods' sovereignty principles. No hidden state, no central database required.

2. **network_definition as authoring block is elegant.** The editor writes
   `network_definition`; the exporter reads it and generates everything else; the file
   survives rebuilds with the authoring intent intact. This is the correct separation
   between author and machine.

3. **The geometry-embed TODO is a fork in the road.** For classroom and planning use
   (children designing their future), embedding geometry is exactly right — one file,
   open in any text editor, complete. For production robot OS use, stripping geometry
   saves memory and eliminates the geometry-vs-runtime-map ambiguity. The decision
   point is: when does the first real robot need this file? Design for classroom now;
   add the production flag (`"embed_geometry": false` at top level) before robot OS
   integration.

4. **Trip file staleness is the most important open risk.** Noelle renumbers line_ids
   on every rebuild. Trip files carry integer line_ids. After any rebuild, all trip
   files are potentially invalid. This can be mitigated by:
   a. Adding `followme_model_id` + `followme_generated_at` to every trip file.
   b. Noelle checking on load: if the timestamps differ, the trip is stale and Natalie
      must replan before Nora departs.
   This is a 10-line addition to `natalie.rb` and `noelle.rb` that prevents a hard-to-
   diagnose runtime error where Nora travels the wrong line.

5. **Internal connection naming (Natalie's point 1) matters for long-lived networks.**
   Station templates will evolve. Ordinal naming (`_internal_0`) is fragile. Add
   semantic role names now while the station count is small.

6. **Alice and ticketing:** FollowMe knows nothing about fares, demand, or occupancy.
   That is correct. Alice holds that. The contract is: FollowMe declares the physical
   network; Alice declares the commercial network; they share only the station_id as a
   common key. Do not let demand data drift into followme.json.

---

## Design Decisions — Confirmed This Session

| Decision | Reasoning |
|----------|-----------|
| `connections{}` as dict, keyed by connection_id | Fast lookup; Natalie BFS is O(1) per step |
| Integer line_ids in runtime file | Small, fast, deterministic after normalize pass |
| String connection_id in network_definition | Human-readable authoring; survives rebuilds |
| Geometry embed in development exports | One-file completeness for classroom use |
| `notes[]` TODO flag for production geometry strip | Deferred, not forgotten |
| `review_recommendations` unconditional after export | Noelle speaks without being asked |
| 1-CP station blocks routing until u_turn confirmed | Explicit intent > silent assumption |

---

## Open Questions — Resolution Status (updated 2026-05-10)

| # | Question | Resolution |
|---|----------|------------|
| OQ-1 | Stale trip file detection | **Closed.** `followme_generated_at` added to trip file schema. `purge_stale_trip_files` runs after every followme.json export. No legacy support — stale or unsigned trip files are deleted and operator is alerted. `export_all_trip_jsons` stamps all trips with the same timestamp. |
| OQ-2 | Semantic internal connection naming | **Closed.** `build_v2_document` now names internal connections `"#{sid}_#{conn_name}"` using the physical guideway's own `connection_id`. Stable across station template edits. No ordinal suffix. No legacy support. |
| OQ-3 | Direction string clarity | **Closed.** Guideway tracks: `"out"` (index 1, forward) and `"in"` (index 0, return). Internal tracks: `"u_turn"` or `"out"`/`"in"`. Unicode arrows removed. |
| OQ-4 | nora.json abbreviated log | **Closed.** `append_nora_log` writes `<model>.nora.json` next to the .skp file after every trip export. Schema `jpods-nora-log-v1`. Each entry: `trip_id`, `nora_id`, `exported_at`, `followme_generated_at`, `platform_start`, `platform_end`, `line_count`, `anomalies: []`. Max 500 entries, trimmed on append. `anomalies[]` is reserved for future Nora-to-fleet observation sharing. |
| OC-5 | Production geometry strip | **Deferred.** Documented in `followme.md` (OC-5 section) and `issues.md` (issue #12). Trigger: before first robot OS deployment. |
| OC-6 | Space conflict — SketchUp animation | **Documented.** Physical fleet already has zipper merge (`ezone.py`). SketchUp headway guard (`MIN_HEADWAY_MM ≈ 3 500 mm`) is required before any multi-vehicle classroom demo. Logged in `followme.md` (OC-6 section) and `issues.md` (issue #11). Physical repo: `/Users/williamjames/Documents/08_JPods/03_Technology/JPodsSM_RPi/`. |

---

## Known-Good State (May 10, 2026)

- Schema: `jpods-followme-v2` ✓
- Noelle 5-phase define_network gate: implemented ✓
- normalize_network canonical line_id sequencing: implemented ✓
- review_recommendations post-export: implemented ✓
- Trip files: `jpods-trip-v1` with integer line_ids ✓
- Platform detection: tag-first, name-fallback ✓
- CCW connection rule: enforced in CP detection ✓
- Geometry embed: development mode ✓ (production strip deferred)
- Trip file staleness detection: **not yet implemented** — OQ-1

---

## Files This Review References

| File | Role |
|------|------|
| [readmes/followme.md](followme.md) | Canonical schema doc |
| [readmes/followme_example.json](followme_example.json) | Reference example (v1 travel_segment) |
| [jpod_followme_exporter.rb](../jpod_followme_exporter.rb) | Exporter — writes followme.json |
| [noelle.rb](../noelle.rb) | define_network gate + normalize + review |
| [natalie.rb](../natalie.rb) | BFS trip planner |
| [nora.rb](../nora.rb) | Vehicle agent + observation logger |
| [jpod_constants.rb](../jpod_constants.rb) | Engineering limits — single source of truth |

---

*This review document is a record of team consensus as of 2026-05-10.  
Update it when any open question is resolved or any design decision is reversed.*

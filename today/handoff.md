# Handoff — 2026-05-20

## Where We Stopped

TripPlanner v2 rewrite complete and committed (`cd4ef76` in su_jpods_claude branch). Vehicle animator v2 compat fix committed in the same commit. All schema readmes written.

## What Is Done (This Session)

- **map-v2 + trip-v2 schemas finalized** — deliberation recommendations applied; schemas at `su_jpods/readmes/jpods-map-v2.md` and `jpods-trip-v2.md`
- **Noelle `generate_map_json` rewritten** — produces jpods-map-v2; unified `lines{}` with dot-notation IDs, followme_hash, stations{} block, energy model, grade
- **UTC Axiom 14** — 9 local-time data fields fixed; CLAUDE.md updated; memory written; `jpods-utc-standard.md` written
- **Schema readmes** — feature-v3, map-v2, trip-v2, utc-standard in `su_jpods/readmes/`; jpods-design-review.md in `readmes/`
- **TripPlanner v2** — `jpod_trip_planner.rb` complete rewrite; loads map.json v2, embeds full segment records, assigns segment_action, computes ezone_entries, trip_hash, energy estimates
- **Vehicle animator** — `resolve_gw_segs_from_map` handles v2 Hash segments and v1 String segments

## Next Steps (Priority Order)

1. **Test the pipeline in SketchUp** — reload files, run Build on CA_Gilroy_Clean, then Plan Trips, then Animate. Expect map.json v2 output and trip.json v2 output.
2. **generate_feature_json** — verify Noelle writes feature-v3 format with faults[] and connections{} block. Run Validate.
3. **physical.json (jpods-physical-v1)** — not yet implemented. First step: flush IMU/encoder spikes from `anomalies: []` in nora.json to physical.json at trip end.
4. **Station template F-07** — stubs at 7.5m need structural redesign, not code change.

## Files Changed This Session (su_jpods)

- `noelle.rb` — generate_map_json rewrite + reviewed_at UTC fix
- `jpod_vehicle_anim.rb` — build_map_lookup v2 + resolve_gw_segs_from_map v2 compat
- `jpod_vehicle_runtime.rb` — created_at UTC fix
- `jpod_animator.rb` — created_at UTC fix
- `jpod_structure_tool.rb` — generated_at full UTC ISO-8601
- `jpod_followme_exporter.rb` — 4x strftime UTC fix
- `jpod_network_editor.rb` — _generated UTC fix
- `jpod_oversight.rb` — ran_at UTC fix
- `jpod_console.rb` — generate_map_json result message updated for v2
- `jpod_trip_planner.rb` — complete v2 rewrite
- New readmes: `jpods-feature-v3.md`, `jpods-map-v2.md`, `jpods-trip-v2.md`, `jpods-utc-standard.md`

## Commits (su_jpods)

5 commits ahead of origin on `su_jpods_claude` branch. Not pushed — wait for Bill's review of the test results.

## Key Design Decisions

| Decision | Rationale |
|---|---|
| `seg['id']` in v2 animator | trip_segs are Hashes in v2, not Strings; single guard handles both |
| followme_hash = SHA-256 | mtime alone can't detect file replacement at same timestamp |
| dot notation in map v2 IDs | avoids ambiguity when station IDs and role names both contain underscores |
| deliberation before implementation | 11 regressions caught before code written; protocol now standing |

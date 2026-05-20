# JPods Design Review Protocol

## Purpose

Regular deliberative review of developments in SketchUp (SU) and physical (PH) domains by the agent team. Catches cross-domain consequences before they land in code. Surfaces innovation candidates. Keeps agents calibrated to each other.

---

## Participants

| Agent | Role in review | Domain expertise |
|---|---|---|
| Allie | Cross-domain synthesizer; flags consequences that span domains | All domains — billing, physical, SU, Route-Time |
| Athena | Adversary — challenges assumptions, finds gaps, identifies security and safety risks | All domains — security, correctness |
| Noelle | Network validator — reviews topology, map.json / feature.json consistency, Build pipeline | SketchUp, map.json, feature.json |
| Natalie | Router — reviews trip planning, dispatch logic, ezone protocol, headway | trip.json, dispatch, routing |
| Nora | Vehicle — reviews navigation sequences, sensor anchors, physical.json, motor control | Physical Pi, navigation, sensors |

---

## Cadence

| Trigger | Who initiates | Scope |
|---|---|---|
| Weekly | Allie (automated — Monday nightly reflect) | Short scan of `_innovation_global` fields in map.json and trip.json |
| Schema change | Any agent or Claude Code that touches a schema | Any time a schema (map.json, trip.json, feature.json, physical.json) adds or renames a field — triggered before implementation |
| Cross-domain change | Claude Code | Any change to noelle.rb, jpod_trip_planner.rb, or nora.rb that affects the data contract between agents |
| Ad hoc | Bill | New capability being designed; any time a decision is not obvious from existing docs |

---

## Format — Deliberation Script

```bash
python3 ~/Allie/scripts/allie-deliberate.py --rounds 2
```

Three-stage process:

1. **Reasoner** (`deepseek-r1:8b`): thorough assessment of the question or proposal
2. **Adversary** (`athena-reason:latest`, x2): challenges assumptions, finds gaps, identifies risks
3. **Judge** (`llama3.2:latest`, x2): synthesizes adversary points, prioritizes recommendations

Output: `~/Allie/thoughts/YYYY-MM-DD-deliberate-HHMMSS.md`

For targeted reviews (specific schema or domain), pass the relevant JSON drafts and a focused question set to the script as input.

---

## What Gets Reviewed

### SketchUp (SU) domain

| File | What to review |
|---|---|
| `noelle.rb` | Build pipeline changes, Noelle validation logic |
| `jpod_network.rb` | Build pipeline core, `build_segment` |
| `jpod_path_builder.rb` | Terrain-following algorithm, vertical profile |
| `jpod_structure_tool.rb` | CP detection, pair_stubs, guard conditions |
| `jpod_connect_tool.rb` | CP tangent logic, Bezier formulation |
| `jpod_vehicle_anim.rb`, `jpod_animator.rb` | Animation and trip display |
| `map.json`, `feature.json`, `trip.json` | Schema changes — any field add or rename |

### Physical (PH) domain

| File | What to review |
|---|---|
| `nora.rb` / Pi `main.py` | Navigation sequences, sensor anchoring |
| `physical.json` | Observation accumulation schema, severity thresholds |
| Ezone protocol | Entry/exit edge definitions, ezone_status field |
| `natalie.rb` | Dispatch, headway, trip assignment |
| AprilTag, ToF integration | Sensor anchor points — must be explicit datums, not derived |

### Cross-domain (any change touching both)

- Any JSON schema consumed by both SketchUp and Pi agents
- UTC datetime compliance in new fields — checked against the UTC Standard (see `jpods-utc-standard.md`)
- Billing fields — Alice depends on trip.json; any rename breaks her
- Route-Time O-D matrix inputs — throughput and capacity fields flow from feature.json
- Physical.json severity thresholds — moderate/severe trigger Natalie route blocks

---

## _innovation Fields

Every schema (map.json, trip.json, feature.json) carries `_innovation_global` and `_note_*` fields. These are the living backlog for the review team.

Format within `_innovation` fields:

| Prefix | Meaning |
|---|---|
| `ALLIE:` | Cross-domain or billing angle — observation or open question |
| `NOELLE:` | Topology or build-pipeline angle |
| `NATALIE:` | Routing, dispatch, or headway angle |
| `NORA:` | Physical navigation or sensor angle |
| `ATHENA:` | Security, safety, or correctness challenge |
| `PROMOTED — <field>: <decision>` | Moved from candidate to required field |
| `OPEN — <question>` | Unresolved — must be addressed before schema ships |

At each review: scan `_innovation` fields, promote what is ready, close what has been implemented, add new candidates from recent development.

---

## Output of a Review

1. **Annotated `_innovation` fields** — updated in the relevant draft JSON before any implementation begins
2. **Retrospection entry** in `readmes/retrospections/YYYY-MM-DD.md` — "Lessons for Allie" section documenting what the review found
3. **Schema draft updated first** — if a schema change is recommended, update the draft JSON, get review sign-off, then implement; never implement first
4. **Ouch-list** — if a risk is identified, add to `readmes/system/ouch-list.md` with domain, severity, and owner
5. **Wisdom layer** — if a new principle emerges from the review, add to `readmes/wisdom/scars.md` or `readmes/wisdom/bill.md`

---

## Standing Rules for All Reviews

1. **Schema changes are proposed in draft JSON first.** Implementation follows the draft, not the reverse.
2. **A field rename needs a migration path before implementation.** Flag which consumers break. Alice, Route-Time, and the Pi agents are all consumers of trip.json — a rename that only updates the SketchUp exporter and leaves the others reading the old key is a silent failure.
3. **UTC datetime compliance is checked on every new field that carries a timestamp.** See `jpods-utc-standard.md`. Any `_at` or `_on` field must use UTC with Z suffix.
4. **Physical observations (physical.json) are never merged into routing declarations (feature.json, map.json).** Separate files, separate writers. A Build run regenerates feature.json — physical observations accumulated over weeks must not be erased.
5. **Noelle writes; others read.** No other agent writes map.json, feature.json, or trip.json in production. Nora writes physical.json only. Alice reads trip.json for billing; she does not write it.
6. **If an adversary point was truncated (token limit) in the deliberation output, it is an open item until manually reviewed.** Truncated challenges are not resolved challenges.
7. **Innovation candidates in `_innovation_global` do not expire silently.** If a candidate is not promoted or explicitly closed within two review cycles, Allie flags it in the weekly scan.

---

## Agent Authority — Who Writes What

| File | Writer | Readers |
|---|---|---|
| `map.json` | Noelle | Natalie, Nora, TripPlanner, Route-Time |
| `feature.json` | Noelle | TripPlanner, Natalie, Nora, Route-Time |
| `trip.json` | TripPlanner (reads feature.json) | Nora, Natalie, Alice (billing) |
| `physical.json` | Nora | Noelle (reads before route confirmation) |
| `billing fields` in trip.json | TripPlanner (Alice sets rates) | Alice |
| `_innovation fields` | Any agent during review | All agents |

This table is the authority chain. If a proposed change would have a non-writer agent updating a file it only reads, the review must explain why — or the change must be redesigned.

---

## Example: 2026-05-20 Schema Deliberation

- **Question:** Assess `jpods-map-v2-draft.json` and `jpods-trip-v2-draft.json` before implementation.
- **Method:** `allie-deliberate.py --rounds 2` with both draft files and a 12-question question set passed as input.
- **Outcome:** 11 prioritized recommendations produced. All applied in rev 2 of both drafts before implementation began.

Key promotions from that review:

| Candidate | Decision |
|---|---|
| `followme_hash` | Promoted — required field in map.json; enables stale-trip detection without file stat |
| `last_physical_survey` | Promoted — required in map.json; Noelle reads before route confirmation |
| `nominal_time_s` | Promoted — required in trip.json segments; Route-Time and billing depend on it |
| `stations{}` block | Promoted — platform and ezone data moved to structured block rather than flat list |
| `ezone_status` | Promoted — explicit field; replaces derived check from ezone_entries length |
| Billing fields | Promoted — `base_fare`, `distance_m`, `duration_s` added to trip.json for Alice |
| `trip_id` / `route_id` separation | Promoted — trip_id is per-journey; route_id is the network path; separate fields |
| `expires_at` | Promoted — required in trip.json; stale trips purged at export |
| `trip_hash` | Promoted — integrity check for Nora before executing |
| `stub` renamed to `cp_index` | Promoted — stub was ambiguous; cp_index is unambiguous |
| `action` renamed to `segment_action` | Promoted — action collided with Ruby reserved word in some contexts |
| `ezones` renamed to `ezone_entries` | Promoted — plural noun for an array of structured objects |

Open items carried forward from that review:

- Severity escalation protocol for physical.json `severe` observations — how does Natalie learn a route is blocked?
- Alice rate-setting interface — rates are currently hardcoded in TripPlanner; Alice needs a write path to her own rate table.

---

## Relationship to Other Protocols

| Protocol | How it connects |
|---|---|
| UTC Standard (`jpods-utc-standard.md`) | Every design review checks UTC compliance on new fields |
| ouch-list (`readmes/system/ouch-list.md`) | Risks identified in review go directly to ouch-list with domain and owner |
| tf/dnw/tfts process capture | When a review surfaces a failed-then-fixed design arc, write a TFTS immediately |
| Noelle Feature JSON (CLAUDE.md Axiom 8) | Feature.json is a routing declaration — reviewed for behavioral completeness, not physical data |
| Physical Observations (CLAUDE.md Axiom 9) | Physical.json is separate — reviewed for schema correctness and severity thresholds |
| Wisdom layer (`readmes/wisdom/`) | Principles extracted from reviews go to `scars.md` or `bill.md` |

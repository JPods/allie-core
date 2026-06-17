# Agent Experience Framework

**Status:** Design — Nora/SU partially implemented; Noelle, Natalie, Alice pending  
**Applies to:** Noelle, Natalie, Nora, Alice — all domains (SketchUp, Physical/RPi, Route-Time, WebClerk)  
**Authored:** 2026-06-17  
**Custodian:** Allie (stores, synthesizes, promotes to Understanding entries)

---

## Agent Authority — Logging Requirements

Every agent, Claude Code, and Allie have standing authority to modify the logging requirements in this framework at any time. No session approval needed.

**What this covers:**
- Adding new `observation_type` values when a run reveals a defect category not yet named
- Adjusting threshold constants (heading angles, Z jump mm, timing tolerances) when first-pass estimates prove too tight or too loose
- Adding fields to the observation record schema when a run produces data that doesn't fit the current fields
- Creating new `instruction_ref` strings when an experience gap points to an instruction that wasn't previously named

**How to exercise the authority:**
- Edit this file directly — add or change the relevant section
- Note the date and which agent/observer proposed the change
- If a threshold changes, note what evidence drove the change (e.g., "first run on 2_thru_dip — all gw_ junctions fired at 35° threshold; lowered to 25° as more meaningful signal boundary")
- Commit immediately — Allie reads the committed version nightly

**Constraint:** Changes to logging requirements go in this document. Changes to the code that implements them go in the relevant Ruby/Python files. The two must stay in sync; if they diverge, this document is the authority.

---

## Introspection / Retrospection Cycle

The learning loop for each network run:

```
INTROSPECTION (before run)
  Each agent states:
  - What risks do I carry into this run?
  - What do I predict will happen?
  - Which of my instructions am I least confident about on this network?

RUN (network animates / trips execute)
  Observations fire automatically (when implemented)
  Human observer (Bill) watches

RETROSPECTION (after run)
  Each agent compares prediction to experience:
  - What did I predict that did not happen?
  - What happened that I did not predict?
  - What does that delta tell me about my instructions?

BILL'S FEEDBACK
  Human observations that no agent can make:
  - Visual quality of animation
  - Passenger comfort analogs
  - Whether the network "feels right"

INCREMENT
  - Fix geometry, routing rules, or pricing based on delta
  - Update logging requirements where the schema missed something
  - Write TFTS for any arc that closed
  - Advance to next run
```

Introspection and retrospection records are written to `process/network_learning/{network_id}/` as `YYYYMMDDTHHMMSS-intro.md` and `YYYYMMDDTHHMMSS-retro.md`. They feed Allie's nightly synthesis exactly like TFTS files.

`process/inbox/` is for transient session artifacts (FAULT, DNW, TF, TFTS). `process/network_learning/` is permanent — it accumulates over the entire life of the network.

---

## The Core Principle

Every agent has two things:

1. **Instructions** — the rules, geometry specs, routing algorithms, and design axioms we give them before they operate on any network
2. **Experience** — what they actually observe when they implement those instructions on a specific real network

The gap between instructions and experience is the signal. Not a failure signal — an information signal. When Noelle's build rules produce no faults on a well-designed network, that confirms the rules. When Nora reports a heading kink at a junction that passed Noelle's build validation, that reveals something the build check cannot see. When Natalie's planned route consistently takes 40% longer than her timing model, the model has a systematic error.

Each agent logs these deltas — instruction vs. experience — every time they operate on a new network. Allie stores them. Over time, patterns emerge across networks. Those patterns are the empirical foundation for improving:

- **Design** — which template types, connection angles, and station placements generate the most problems in service
- **Fabrication** — which geometry specs are consistently achieved vs. which are aspirational
- **Deployment** — which network topologies produce routing conflicts, timing failures, or vehicle distress

This is not a bug tracker. Bugs go in FAULT files. This is a learning loop: agents teach us how to write better instructions for the next network.

---

## Observation Record — Shared Schema

All three agents write observations in the same format. Allie reads one schema.

```json
{
  "agent":           "Noelle | Natalie | Nora",
  "domain":          "SU | PH | RT",
  "network_id":      "2_thru_dip",
  "instruction_ref": "formation_template:station_thru_dip / routing:bfs_ezone / geometry:junction_continuity",
  "observation_type":"template_compliance | route_efficiency | trajectory_defect | ...",
  "severity":        "info | minor | moderate | severe",
  "subject_id":      "s001.gw_main_in",
  "value":           38.2,
  "unit":            "degrees | mm | seconds | ratio",
  "description":     "35.2° heading kink at gw_main_in → gw_main_thru",
  "instruction_expected": "< 15° at any track junction",
  "logged_at":       "2026-06-17T15:23:01Z",
  "logged_by":       "Nora.SU",
  "pod_id":          null
}
```

**Key fields:**
- `instruction_ref` — which rule was being applied. Traceable back to a CLAUDE.md axiom, a template spec, or a routing constant.
- `instruction_expected` — what the instruction says should happen
- `value` + `unit` — what actually happened, in measurable form
- `subject_id` — the track, route, station, or connection the observation is about

---

## Storage

All observations write to `{model_stem}.physical.json` in the model's output directory (SU), or `~/Allie/process/physical/physical.json` (Physical):

```json
{
  "observations": [
    { ...observation record... },
    { ...observation record... }
  ]
}
```

Cap at 500 entries per file. Observations older than 30 days do not promote to noelle.faults[] at Build — geometry may have been fixed.

FAULT files (`process/inbox/YYYYMMDDTHHMMSS-fault.md`) are written for **severe** observations only. Moderate and minor accumulate in `physical.json` and surface in Noelle's review.

Allie's nightly `allie-reflect.py` reads all `physical.json` files and synthesizes cross-network patterns into the standard reflection output.

---

## Noelle — Design Experience

### What Noelle Is Told (Instructions)

Noelle's instructions live in formation template definitions, build validation rules, and the fault criteria in `noelle.rb`:

- Each track tagged as `gw_*` must have a matching inbound/outbound pair at the connection point
- Formation template `station_thru_dip` has specific eps[] entries; any deviation is a fault
- Connection angles between seg_ tracks and gw_ entry tracks must be within continuity tolerance
- Platform guideways (`gw_platform`) must have at least 1 parking slot

### What Noelle Observes (Experience)

At Build and at Validate, Noelle runs her checks. The experience log captures not just faults but the *distribution* of what she finds on each network:

| Observation Type | instruction_ref | What it measures |
|-----------------|----------------|-----------------|
| `template_compliance` | `formation_template:{name}` | Did this station's geometry match its declared template? Which eps[] were present/missing? |
| `connection_angle` | `axiom:junction_continuity` | Angle between seg_ exit vector and gw_ entry vector at each CP |
| `platform_slot_count` | `spec:min_parking_slots` | Computed slots vs. minimum; which stations are slot-constrained |
| `coverage_gap` | `axiom:no_orphan_tracks` | Tracks in network.json with no corresponding trip coverage |
| `fault_rate` | `build:validation_pass` | Ratio of faults to stations — network quality score |
| `template_unknown` | `formation_template:unknown` | Stations whose structure tag does not match any known template |

### When Noelle Logs

- **At Build completion** — one observation batch per station, written to `physical.json`
- **At Validate** — same, but marks `domain: SU_validate` to distinguish from Build observations
- **At animation stop** — Noelle reads Nora's trajectory observations and adds one `coverage_summary` record per run

### SU Implementation — `noelle.rb`

```ruby
# In generate_network_json, after per-station processing:
def self.observe_station(sid, station_data, template_name, faults)
  obs = []

  # template compliance
  obs << {
    'agent'            => 'Noelle',
    'domain'           => 'SU',
    'network_id'       => @current_model_stem,
    'instruction_ref'  => "formation_template:#{template_name}",
    'observation_type' => 'template_compliance',
    'severity'         => faults.empty? ? 'info' : (faults.any? { |f| f['severity'] == 'severe' } ? 'severe' : 'minor'),
    'subject_id'       => sid,
    'value'            => faults.size,
    'unit'             => 'faults',
    'description'      => "#{sid} (#{template_name}): #{faults.size} fault(s)",
    'instruction_expected' => '0 faults',
    'logged_at'        => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
    'logged_by'        => 'Noelle.SU',
  }

  # platform slot count
  platforms = station_data['platforms'] || []
  platforms.each do |p|
    slots = p['parking_slots'].to_i
    obs << {
      'agent'            => 'Noelle',
      'domain'           => 'SU',
      'network_id'       => @current_model_stem,
      'instruction_ref'  => 'spec:min_parking_slots',
      'observation_type' => 'platform_slot_count',
      'severity'         => slots < 2 ? 'minor' : 'info',
      'subject_id'       => p['id'].to_s,
      'value'            => slots,
      'unit'             => 'slots',
      'description'      => "#{p['id']}: #{slots} slot(s) on #{p['connection_id']}",
      'instruction_expected' => '>= 2 per platform',
      'logged_at'        => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
      'logged_by'        => 'Noelle.SU',
    }
  end

  obs
end
```

### What Noelle's Experience Teaches

Across 10+ networks:
- Which templates reliably produce zero faults → template spec is correct
- Which templates chronically produce the same fault type → template spec has a systematic gap
- Which connection angles are consistently mis-tagged → CP placement rule needs tightening
- Which stations are consistently slot-constrained → minimum platform length spec is wrong

---

## Natalie — Routing Experience

### What Natalie Is Told (Instructions)

Natalie's instructions are her BFS routing algorithm, ezone priority rules, timing constants, and the network topology from `network.json`:

- BFS finds the shortest path by edge count from origin CP to destination CP
- Ezone priority: a pod already in an ezone blocks entry until it clears
- Timing model: station_entry = 40s, board_alight = 20s, walk_segment = 5 min each way
- A route is valid if it uses only inbound→outbound CP pairs with no direction violation

### What Natalie Observes (Experience)

Every time Natalie plans or executes a route on a new network, she logs the delta between her model and what happens:

| Observation Type | instruction_ref | What it measures |
|-----------------|----------------|-----------------|
| `route_efficiency` | `routing:bfs_edge_count` | Actual route line_ids count vs. expected min for that O-D pair |
| `timing_accuracy` | `timing:station_entry_40s` | Planned trip_ms vs. actual trip_ms — prediction error |
| `ezone_wait` | `routing:ezone_priority` | How long pods waited at ezone entry; which ezones are chronic bottlenecks |
| `conflict_event` | `routing:spacing_threshold` | Jam events — which O-D pairs, which segments, time of day |
| `route_blocked` | `routing:direction_constraint` | Routes that BFS found no path for — topology gap |
| `replanning_rate` | `routing:replan_on_conflict` | How often Natalie had to replan; which networks require more replanning |
| `southbound_penalty` | `routing:turnabout_cost` | Actual cost of the northbound turnabout vs. estimated ~160m constant |

### When Natalie Logs

- **At trip plan generation** — one `route_efficiency` observation per trip
- **At trip complete** — one `timing_accuracy` observation (SU: animation stop; Physical: trip_complete MQTT)
- **At ezone wait** — one `ezone_wait` per wait event during the trip
- **At route blocked** — one `route_blocked` immediately when BFS returns nil path
- **At simulation end** (RT) — batch of `conflict_event` and `replanning_rate` from SimResult

### SU / Physical Implementation — `natalie.rb` and `podPresenter`

```ruby
# At trip plan generation — in route_plan() or equivalent:
def self.observe_route(network_id, origin_id, dest_id, route_line_ids, expected_min_lines)
  ratio = route_line_ids.size.to_f / [expected_min_lines, 1].max
  sev = ratio > 2.0 ? 'moderate' : (ratio > 1.5 ? 'minor' : 'info')
  {
    'agent'             => 'Natalie',
    'domain'            => 'SU',
    'network_id'        => network_id,
    'instruction_ref'   => 'routing:bfs_edge_count',
    'observation_type'  => 'route_efficiency',
    'severity'          => sev,
    'subject_id'        => "#{origin_id}→#{dest_id}",
    'value'             => route_line_ids.size,
    'unit'              => 'lines',
    'description'       => "#{origin_id}→#{dest_id}: #{route_line_ids.size} lines (expected ~#{expected_min_lines})",
    'instruction_expected' => "~#{expected_min_lines} lines",
    'logged_at'         => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
    'logged_by'         => 'Natalie.SU',
  }
end

# At trip complete — timing accuracy:
def self.observe_timing(network_id, trip_id, planned_ms, actual_ms)
  err_pct = ((actual_ms - planned_ms).abs.to_f / planned_ms * 100).round(1)
  sev = err_pct > 30 ? 'moderate' : (err_pct > 15 ? 'minor' : 'info')
  {
    'agent'             => 'Natalie',
    'domain'            => 'SU',
    'network_id'        => network_id,
    'instruction_ref'   => 'timing:station_entry_40s',
    'observation_type'  => 'timing_accuracy',
    'severity'          => sev,
    'subject_id'        => trip_id,
    'value'             => err_pct,
    'unit'              => 'percent_error',
    'description'       => "Trip #{trip_id}: planned #{planned_ms}ms, actual #{actual_ms}ms (#{err_pct}% error)",
    'instruction_expected' => '< 15% timing error',
    'logged_at'         => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
    'logged_by'         => 'Natalie.SU',
  }
end
```

### What Natalie's Experience Teaches

Across 10+ networks:
- Which O-D pairs consistently produce inefficient BFS routes → topology design rule (station placement)
- Which ezones are chronic bottlenecks → ezone capacity rule or spacing spec needs updating
- How accurate the 40s/20s timing constants are on real networks → timing model improvement
- Which network topologies require the most replanning → design guidance for future deployments

---

## Nora — Trajectory Experience

### What Nora Is Told (Instructions)

Nora's instructions are the geometry specs in network.json tracks: pt sequences, heading continuity axiom, Z profile (hanger_z = BEAM_DEPTH = 500mm below beam_top), and the junction continuity rule.

- Tracks connect end-to-end: last pt of departing track ≡ first pt of arriving track (gap < 5mm)
- Heading change at any junction < 15° (smooth flow)
- Z change at any junction should match grade profile (no sudden jumps > 50mm unless intentional grade)
- All tracks must have ≥ 3 pts (chord cut with 2 pts indicates under-sampled arc)

### What Nora Observes (Experience)

At every track-to-track junction (current track's last pt → next track's first pt):

| Observation Type | instruction_ref | Thresholds |
|-----------------|----------------|-----------|
| `heading_kink` | `axiom:junction_continuity` | minor ≥15°, moderate ≥35°, severe ≥60° |
| `z_jump` | `geometry:z_profile` | minor ≥50mm, moderate ≥200mm, severe ≥500mm |
| `position_gap` | `geometry:chain_continuity` | minor ≥5mm, moderate ≥50mm, severe ≥200mm |
| `chord_cut` | `geometry:min_pts_per_track` | minor: 2-pt track ≥500mm chord, severe: ≥2000mm |

### Observation Record (Nora)

```json
{
  "agent":           "Nora",
  "domain":          "SU",
  "network_id":      "2_thru_dip",
  "instruction_ref": "axiom:junction_continuity",
  "observation_type":"heading_kink",
  "severity":        "moderate",
  "subject_id":      "s001.gw_main_in",
  "value":           38.2,
  "unit":            "degrees",
  "description":     "38.2° kink at s001.gw_main_in → s001.gw_main_thru",
  "instruction_expected": "< 15° at any junction",
  "logged_at":       "2026-06-17T15:23:01Z",
  "logged_by":       "Nora.SU",
  "pod_id":          null
}
```

### Implementation

Full implementation detail — `TrajectoryObserver` class (Ruby/SU and Python/Physical), wiring into animation tick and trip lifecycle, flush protocol, FAULT file generation — is preserved in this document below under **Nora Implementation Detail**.

### What Nora's Experience Teaches

Across 10+ networks:
- Which track types (`gw_*` vs. `seg_*`) generate the most heading kinks → formation template geometry needs finer sampling
- Which junction types produce Z jumps → coordinate system error or template Z origin is wrong  
- Whether chord cuts cluster on certain arc radii → bezier sampling rate needs adjustment for that radius
- Whether position gaps cluster at specific CP types → connection tool is not closing those CPs

---

## Alice — Transaction Experience

### What Alice Is Told (Instructions)

Alice's instructions are pricing rules, fulfillment sequences, Small-Stings criteria, booking flow, and customer identity standards:

- Price query: fare = base_rate × distance_km × level_factor (1–5 weather/demand scale)
- Fulfillment: invoice transitions STATUS_PENDING → STATUS_RELEASED on payment confirmation
- Small-Stings: customer-assessed fine issued when a problem is reported and not resolved within SLA; JPods pays the fine; Alice accounts for it
- Retrospections: JPods pays customers for submitting retrospections (structured feedback); Alice accounts for both inflow (Small-Stings) and outflow (retrospection payments)
- Trip booking: origin station + destination station + departure window → fare quote → payment → trip plan dispatched to Natalie
- Identity: customer must have local_id; CarryOn uuid is the portable pointer; trip bookings bind to both

### What Alice Observes (Experience)

Every transaction — successful or not — is a data point. The gap between the pricing model and what customers pay, between the SLA and when problems are actually resolved, between booking intent and trip completion, is Alice's experience signal:

| Observation Type | instruction_ref | What it measures |
|-----------------|----------------|-----------------|
| `price_query_abandoned` | `pricing:fare_formula` | Customer queried a price but did not book — fare may be wrong for that O-D pair or level |
| `fulfillment_delay` | `fulfillment:sla_release` | Time from payment confirmation to STATUS_RELEASED vs. expected |
| `small_sting_issued` | `quality:small_sting_sla` | Problem reported; SLA elapsed without resolution; fine issued — which problem types, which stations |
| `small_sting_resolved` | `quality:small_sting_sla` | Problem resolved before SLA — which resolution paths are fast vs. slow |
| `retrospection_received` | `quality:retrospection_payment` | Customer submitted retrospection; what content categories appear |
| `booking_friction` | `booking:step_completion` | Steps completed before abandonment — which step loses the customer |
| `timing_mismatch` | `booking:trip_arrival_accuracy` | Quoted arrival time vs. actual arrival (requires Natalie's trip_complete signal) |
| `payment_friction` | `payment:method_acceptance` | Payment method attempted vs. accepted — which methods fail most |
| `zero_result_query` | `inventory:coverage` | Price query for O-D pair with no route — network coverage gap |

### When Alice Logs

- **At every price query** — one `price_query_abandoned` observation if no booking follows within 10 minutes
- **At invoice STATUS_RELEASED** — one `fulfillment_delay` observation
- **At Small-Sting issuance** — one `small_sting_issued` observation with problem type and station
- **At Small-Sting resolution** — one `small_sting_resolved` observation with resolution method and elapsed time
- **At retrospection receipt** — one `retrospection_received` observation with content category
- **At trip complete** (from Natalie's signal) — one `timing_mismatch` observation pairing quote vs. actual
- **At zero-result price query** — one `zero_result_query` immediately

### Observation Record (Alice)

```json
{
  "agent":           "Alice",
  "domain":          "WC3",
  "network_id":      "jpods_main",
  "instruction_ref": "pricing:fare_formula",
  "observation_type":"price_query_abandoned",
  "severity":        "minor",
  "subject_id":      "S003→S007",
  "value":           14.75,
  "unit":            "dollars",
  "description":     "Fare quote $14.75 for S003→S007 (level 3) — no booking followed",
  "instruction_expected": "query converts to booking",
  "logged_at":       "2026-06-17T16:04:22Z",
  "logged_by":       "Alice.WC3",
  "customer_id":     "local_12847"
}
```

Note: `customer_id` is the local_id — never the CarryOn uuid in a log file. Sovereign identity rule: Alice knows the local_id; the uuid travels with the customer.

### Implementation — WebClerk3

Alice logs via the existing `_allie_capture` boundary events in `signals.py` and `views_ui.py`, extended with the observation schema:

```python
# In signals.py — at price_query event (already instrumented):
def _observe_price_query(origin_id, dest_id, fare, level, customer_id):
    _allie_capture('alice_price_query', f"${fare:.2f} {origin_id}→{dest_id} L{level}", {
        'agent': 'Alice', 'domain': 'WC3', 'network_id': NETWORK_ID,
        'instruction_ref': 'pricing:fare_formula',
        'observation_type': 'price_query',   # upgraded to 'price_query_abandoned' after timeout
        'severity': 'info',
        'subject_id': f"{origin_id}→{dest_id}",
        'value': fare, 'unit': 'dollars',
        'description': f"${fare:.2f} {origin_id}→{dest_id} level {level}",
        'instruction_expected': 'query converts to booking',
        'logged_at': utc_now(), 'logged_by': 'Alice.WC3',
        'customer_id': customer_id,
        'query_id': generate_query_id(),   # correlates with booking if it happens
    })

# In signals.py — at Small-Sting issuance:
def _observe_small_sting(problem_type, station_id, sla_deadline, customer_id):
    _allie_capture('alice_small_sting_issued', f"{problem_type} at {station_id}", {
        'agent': 'Alice', 'domain': 'WC3', 'network_id': NETWORK_ID,
        'instruction_ref': 'quality:small_sting_sla',
        'observation_type': 'small_sting_issued',
        'severity': 'moderate',
        'subject_id': station_id,
        'value': None, 'unit': 'problem_type',
        'description': f"Small-Sting: {problem_type} at {station_id} — SLA expires {sla_deadline}",
        'instruction_expected': 'problem resolved before SLA',
        'logged_at': utc_now(), 'logged_by': 'Alice.WC3',
        'customer_id': customer_id,
        'problem_type': problem_type,
        'sla_deadline': sla_deadline,
    })
```

`allie-capture.py` writes these to `process/inbox/` as events; nightly synthesis aggregates them into `process/network_learning/{network_id}/alice.jsonl`.

### What Alice's Experience Teaches

Across 10+ networks and months of operation:

**Pricing** — Which O-D pairs have the highest abandonment rate at which fare levels? That is where the fare formula overestimates value, or where the level factor is miscalibrated for local demand.

**Quality (Small-Stings)** — Which problem types repeat most? Which stations generate the most Small-Stings? That is a design or operational signal: the station design is wrong, or the deployment context creates a recurring problem the design rules did not anticipate.

**Timing accuracy** — How well does Natalie's fare-time quote match actual trip completion? If timing mismatch is systematic (always late on certain routes), Natalie's timing constants need updating and Alice should warn customers at booking time.

**Coverage gaps** — Zero-result queries are the most actionable signal. Customers want to go somewhere the network doesn't reach. Enough `zero_result_query` observations on the same O-D pair → design trigger for network expansion.

**Retrospections** — What content categories appear most in customer feedback? That is the customer's version of the experience log — their report of where instruction and experience diverged. Alice's retrospection receipts and Nora's trajectory defects should be correlated: a `heading_kink` on gw_main at S003 + a retrospection saying "the ride was rough near station 3" is a confirmation chain.

### Cross-Agent Correlations (Alice × Nora × Noelle)

Alice's observations are most powerful when correlated with the physical agents:

| Alice observes | × Physical agent observes | → Conclusion |
|---------------|--------------------------|-------------|
| `small_sting_issued` at S003 | Nora: `heading_kink` at s003.gw_main_in | Geometry defect causing passenger discomfort at that station |
| `timing_mismatch` on S003→S007 | Natalie: `ezone_wait` on ezone_S005 | Bottleneck at S005 is making trips to S007 late |
| `zero_result_query` for S003→S010 | Noelle: `route_blocked` for same pair | Network topology gap confirmed by two independent signals |
| `retrospection_received` (content: "rough") | Nora: `z_jump` on seg_003_007 | Customer words confirming what Nora measured |

Allie's nightly synthesis is responsible for these correlations. She holds all four observation streams and is the only agent who can see across them.

---

## Allie — Storage, Synthesis, Promotion

### Storage

```
~/Allie/process/network_learning/
  {network_id}/                    ← one folder per named network; persists indefinitely
    YYYYMMDDTHHMMSS-intro.md       ← pre-run agent introspection + forecasts
    YYYYMMDDTHHMMSS-retro.md       ← post-run retrospection + delta analysis
    noelle.jsonl                   ← Noelle observations per Build (appended)
    natalie.jsonl                  ← Natalie observations per trip plan / trip complete
    nora.jsonl                     ← Nora observations per animation run / physical trip
    alice.jsonl                    ← Alice observations per transaction / query
    physical.json                  ← rolling 500-entry cross-agent observation log (legacy compat)
```

`process/inbox/` is for transient session artifacts (FAULT, DNW, TF, TFTS). `process/network_learning/` is permanent — multiple Build + animate cycles accumulate. When a network is substantially redesigned, archive the old folder under `{network_id}/archive/YYYY-MM-DD/` and start fresh observation logs. The intro/retro files are kept — they are the history of what was believed at each stage.

### Nightly Synthesis

`allie-reflect.py` reads all `*.jsonl` files in `process/physical/networks/` and:

1. **Counts by observation_type and severity** — what is each agent finding most often?
2. **Clusters by instruction_ref** — which instructions produce the most experience gaps?
3. **Crosses networks** — is the same `heading_kink` on `gw_main_in` appearing in multiple models? That is a template problem, not a model problem.
4. **Flags promotable patterns** — if the same (agent, instruction_ref, observation_type) trio appears in 3+ different networks with moderate or severe severity, flag as Understanding candidate.

### Promotion to Agent Understanding Entries

When a pattern is confirmed across networks, Allie promotes it:

```
U-SK-007 [SketchUp] station_thru_dip gw_main_in heading kink is systematic
Across 4 models, Nora reports a 30–40° heading kink at s*.gw_main_in → s*.gw_main_thru.
The formation template has a 2-pt chord on the exit segment. Fix: add midpoint to gw_main_in
in lines.computed.json before export, or increase bezier sampling for inner arcs.
Provenance: Nora.SU observations on 2_thru_dip, station_line_end, traffic_circle7, test_loop1.
```

These Understanding entries then become part of the next session's context. Claude Code reads them and applies the correction without needing to rediscover it.

### Long-Term Dataset

Over time, `process/physical/networks/` becomes the empirical record of JPods performance across all networks ever built. Three uses:

**Design** — Which template types produce the most runtime problems? Where do students make the most mistakes? What instruction changes would have prevented the most observations?

**Fabrication** — On physical networks, which geometry specs are hardest to achieve? Which track junction types produce the most Nora.PH heading kinks? That is where fabrication tolerance needs tightening.

**Deployment** — Which network topologies (star, linear, loop, grid) produce the most routing conflicts? Which produce the best timing accuracy? This guides how Natalie and Noelle advise network planners before construction.

---

## Implementation Sequence

### Phase 1 — Nora/SU (immediate)
1. Write `TrajectoryObserver` class in `jpod_trajectory_observer.rb`
2. Wire into `jpod_vehicle_anim.rb` at track advance and animation stop
3. Rebuild and animate `2_thru_dip` — read first observation batch
4. Verify `physical.json` written; verify FAULT file for any severe observations

### Phase 2 — Noelle/SU (next session)
5. Add `observe_station` to `generate_network_json` in `noelle.rb`
6. Write per-station observation batch to `physical.json` at each Build
7. Verify Noelle observations appear for 2_thru_dip after Rebuild

### Phase 3 — Natalie/SU (following session)
8. Add `observe_route` at trip plan generation in trip dispatch code
9. Add `observe_timing` at animation stop (pair planned vs. actual duration)
10. Write Natalie observations to `physical.json`

### Phase 4 — Physical (after SU is stable)
11. Port `TrajectoryObserver` to Python; wire into `motor.py` line transition
12. Port Natalie timing observation to `podPresenter` trip complete handler
13. Write to `~/Allie/process/physical/networks/{network_id}/`

### Phase 5 — Allie synthesis
14. Update `allie-reflect.py` to read `process/physical/networks/` JSONL files
15. Add cross-network pattern detection to nightly synthesis
16. Define promotion threshold (3+ networks, moderate+ severity)

### Phase 6 — Route-Time
17. Add observation hooks to `engine/simulation.py` at trip complete and SimResult
18. Surface timing accuracy and conflict rate in RT observation output

---

## Nora Implementation Detail

*(Preserved from original Nora Trajectory Observation plan — 2026-06-17)*

### Constants

```ruby
# SU (Ruby) — in TrajectoryObserver
COS_HEADING_WARN   = Math.cos(15 * Math::PI / 180)   # 0.966
COS_HEADING_FAULT  = Math.cos(35 * Math::PI / 180)   # 0.819
COS_HEADING_SEVERE = Math.cos(60 * Math::PI / 180)   # 0.500
Z_JUMP_WARN_MM   = 50
Z_JUMP_FAULT_MM  = 200
Z_JUMP_SEVERE_MM = 500
GAP_WARN_MM      = 5
GAP_FAULT_MM     = 50
CHAIN_BREAK_MM   = 200
CHORD_SUSPECT_MM = 500
CHORD_SEVERE_MM  = 2000
```

```python
# Physical (Python) — same constants in TrajectoryObserver.__init__
COS_HEADING_WARN   = math.cos(math.radians(15))
COS_HEADING_FAULT  = math.cos(math.radians(35))
COS_HEADING_SEVERE = math.cos(math.radians(60))
Z_JUMP_WARN_MM     = 50;  Z_JUMP_FAULT_MM = 200;  Z_JUMP_SEVERE_MM = 500
GAP_WARN_MM        = 5;   GAP_FAULT_MM    = 50;   CHAIN_BREAK_MM   = 200
CHORD_SUSPECT_MM   = 500; CHORD_SEVERE_MM = 2000
```

### SU — `TrajectoryObserver` (Ruby)

```ruby
module JPods
  class TrajectoryObserver
    def initialize(network_id:, pod_id: nil)
      @network_id   = network_id
      @pod_id       = pod_id
      @observations = []
    end

    def observe_junction(track_id, pts, next_id, next_pts)
      observe_heading(track_id, pts, next_id, next_pts)
      observe_z_jump(track_id, pts, next_id, next_pts)
      observe_gap(track_id, pts, next_id, next_pts)
      observe_chord(next_id, next_pts)
    end

    def flush(model_stem, model_dir)
      return if @observations.empty?
      write_to_physical_json(model_stem, model_dir)
      fire_allie_capture(model_stem)
      write_fault_if_severe(model_stem)
      n = @observations.size
      s = @observations.count { |o| o['severity'] == 'severe' }
      puts "[Nora] Trajectory: #{n} defect(s) (#{s} severe) → physical.json"
      @observations = []
    end

    private

    def observe_heading(tid, pts, nid, npts)
      return unless pts.size >= 2 && npts.size >= 2
      ev = vec3(pts[-2], pts[-1])
      iv = vec3(npts[0], npts[1])
      return if ev.nil? || iv.nil?
      m = mag(ev) * mag(iv)
      return if m < 1e-9
      cos_t = (dot(ev, iv) / m).clamp(-1.0, 1.0)
      sev = cos_t < COS_HEADING_SEVERE ? :severe :
            cos_t < COS_HEADING_FAULT  ? :moderate :
            cos_t < COS_HEADING_WARN   ? :minor : nil
      return unless sev
      deg = (Math.acos(cos_t) * 180 / Math::PI).round(1)
      record(tid, nid, 'heading_kink', 'axiom:junction_continuity', sev, deg, 'degrees',
             "#{deg}° kink at #{tid} → #{nid}", '< 15° at any junction')
    end

    def observe_z_jump(tid, pts, nid, npts)
      dz = (npts[0][2] - pts[-1][2]).abs
      sev = dz > Z_JUMP_SEVERE_MM ? :severe :
            dz > Z_JUMP_FAULT_MM  ? :moderate :
            dz > Z_JUMP_WARN_MM   ? :minor : nil
      return unless sev
      record(tid, nid, 'z_jump', 'geometry:z_profile', sev, dz.round, 'mm',
             "Z jump #{dz.round}mm at #{tid} → #{nid}", '< 50mm grade change at junction')
    end

    def observe_gap(tid, pts, nid, npts)
      gap = dist3(pts[-1], npts[0])
      sev = gap > CHAIN_BREAK_MM ? :severe :
            gap > GAP_FAULT_MM   ? :moderate :
            gap > GAP_WARN_MM    ? :minor : nil
      return unless sev
      record(tid, nid, 'position_gap', 'geometry:chain_continuity', sev, gap.round, 'mm',
             "Gap #{gap.round}mm at #{tid} → #{nid}", '< 5mm at any junction')
    end

    def observe_chord(nid, npts)
      return unless npts.size == 2
      chord = dist3(npts[0], npts[1])
      return unless chord > CHORD_SUSPECT_MM
      sev = chord > CHORD_SEVERE_MM ? :severe : :minor
      record(nid, nil, 'chord_cut', 'geometry:min_pts_per_track', sev, chord.round, 'mm',
             "2-pt chord #{chord.round}mm on #{nid}", '>= 3 pts on any track')
    end

    def record(tid, nid, type, iref, sev, val, unit, desc, expected)
      @observations << {
        'agent'             => 'Nora',
        'domain'            => 'SU',
        'network_id'        => @network_id,
        'instruction_ref'   => iref,
        'observation_type'  => type,
        'severity'          => sev.to_s,
        'subject_id'        => tid.to_s,
        'next_id'           => nid.to_s,
        'value'             => val,
        'unit'              => unit,
        'description'       => desc,
        'instruction_expected' => expected,
        'location_t'        => 1.0,
        'logged_at'         => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'logged_by'         => 'Nora.SU',
        'pod_id'            => @pod_id,
      }
    end

    def vec3(a, b)
      [b[0]-a[0], b[1]-a[1], b[2]-a[2]]
    rescue; nil; end
    def dot(a, b);  a[0]*b[0] + a[1]*b[1] + a[2]*b[2]; end
    def mag(v);  Math.sqrt(v[0]**2 + v[1]**2 + v[2]**2); end
    def dist3(a, b); mag(vec3(a, b)); end

    def write_to_physical_json(stem, dir)
      path = File.join(dir, "#{stem}.physical.json")
      data = File.exist?(path) ? JSON.parse(File.read(path, encoding: 'utf-8')) : {}
      data['observations'] ||= []
      data['observations'].concat(@observations)
      data['observations'] = data['observations'].last(500)
      File.write(path, JSON.pretty_generate(data))
    rescue => ex
      puts "[Nora] physical.json write error: #{ex.message}"
    end

    def fire_allie_capture(stem)
      JPods::Noelle._allie_capture('nora_trajectory_flush',
        "#{@observations.size} trajectory observation(s) flushed",
        { 'model' => stem, 'count' => @observations.size,
          'severe' => @observations.count { |o| o['severity'] == 'severe' } }
      ) rescue nil
    end

    def write_fault_if_severe(stem)
      severes = @observations.select { |o| o['severity'] == 'severe' }
      return if severes.empty?
      ts_str  = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      ts_file = Time.now.utc.strftime('%Y%m%dT%H%M%S')
      inbox   = File.expand_path('~/Allie/process/inbox')
      return unless File.directory?(inbox)
      types = severes.map { |o| o['observation_type'] }.uniq.join(', ')
      body  = "# FAULT — #{ts_str}\n\n" \
              "system:      SU\n" \
              "detected_by: Nora\n" \
              "fault:       Trajectory severe — #{severes.size} observation(s): #{types}\n" \
              "context:     #{stem}; tracks: #{severes.map { |o| o['subject_id'] }.uniq.join(', ')}\n" \
              "resolved_at: \n"
      File.write(File.join(inbox, "#{ts_file}-fault.md"), body)
    end
  end
end
```

### SU — Wiring into `jpod_vehicle_anim.rb`

```ruby
# At animation start:
model_stem = File.basename(model.path, '.skp') rescue 'unknown'
@trajectory_observer = JPods::TrajectoryObserver.new(
  network_id: model_stem, pod_id: nil
)

# At each track advance (when vehicle t >= 1.0 on current track):
if @trajectory_observer && vehicle.current_pts&.size.to_i >= 2
  next_pts = @lookup[next_track_id]
  if next_pts && next_pts.size >= 2
    @trajectory_observer.observe_junction(
      vehicle.current_track_id, vehicle.current_pts,
      next_track_id, next_pts
    )
  end
end

# At animation stop:
if @trajectory_observer && model&.path && !model.path.empty?
  dir  = File.dirname(model.path)
  stem = File.basename(model.path, '.skp')
  @trajectory_observer.flush(stem, dir)
  @trajectory_observer = nil
end
```

### Physical — `TrajectoryObserver` (Python)

```python
import math, json, pathlib, datetime

class TrajectoryObserver:
    COS_HEADING_WARN   = math.cos(math.radians(15))
    COS_HEADING_FAULT  = math.cos(math.radians(35))
    COS_HEADING_SEVERE = math.cos(math.radians(60))
    Z_JUMP_WARN_MM = 50;  Z_JUMP_FAULT_MM = 200;  Z_JUMP_SEVERE_MM = 500
    GAP_WARN_MM    = 5;   GAP_FAULT_MM    = 50;   CHAIN_BREAK_MM   = 200
    CHORD_SUSPECT_MM = 500; CHORD_SEVERE_MM = 2000

    def __init__(self, network_id: str, pod_id: str):
        self.network_id   = network_id
        self.pod_id       = pod_id
        self.observations = []

    def observe_junction(self, line_id, pts, next_id, next_pts):
        self._check_heading(line_id, pts, next_id, next_pts)
        self._check_z_jump(line_id, pts, next_id, next_pts)
        self._check_gap(line_id, pts, next_id, next_pts)
        self._check_chord(next_id, next_pts)

    def flush(self, trip_id: str):
        if not self.observations:
            return
        self._write_to_physical_json()
        self._fire_allie_capture(trip_id)
        self._write_fault_if_severe()
        n = len(self.observations)
        s = sum(1 for o in self.observations if o['severity'] == 'severe')
        print(f"[Nora] Trajectory: {n} observation(s) ({s} severe) → physical.json")
        self.observations = []

    def _check_heading(self, lid, pts, nid, npts):
        if len(pts) < 2 or len(npts) < 2: return
        ev = self._vec(pts[-2], pts[-1])
        iv = self._vec(npts[0], npts[1])
        if not ev or not iv: return
        denom = self._mag(ev) * self._mag(iv)
        if denom < 1e-9: return
        cos_t = max(-1.0, min(1.0, self._dot(ev, iv) / denom))
        sev = ('severe'   if cos_t < self.COS_HEADING_SEVERE else
               'moderate' if cos_t < self.COS_HEADING_FAULT  else
               'minor'    if cos_t < self.COS_HEADING_WARN   else None)
        if not sev: return
        deg = round(math.degrees(math.acos(cos_t)), 1)
        self._record(lid, nid, 'heading_kink', 'axiom:junction_continuity',
                     sev, deg, 'degrees', f"{deg}° kink at {lid} → {nid}", '< 15° at any junction')

    def _check_z_jump(self, lid, pts, nid, npts):
        dz = abs(npts[0][2] - pts[-1][2])
        sev = ('severe'   if dz > self.Z_JUMP_SEVERE_MM else
               'moderate' if dz > self.Z_JUMP_FAULT_MM  else
               'minor'    if dz > self.Z_JUMP_WARN_MM   else None)
        if not sev: return
        self._record(lid, nid, 'z_jump', 'geometry:z_profile',
                     sev, round(dz), 'mm', f"Z jump {round(dz)}mm at {lid} → {nid}", '< 50mm grade change')

    def _check_gap(self, lid, pts, nid, npts):
        gap = self._dist(pts[-1], npts[0])
        sev = ('severe'   if gap > self.CHAIN_BREAK_MM else
               'moderate' if gap > self.GAP_FAULT_MM   else
               'minor'    if gap > self.GAP_WARN_MM    else None)
        if not sev: return
        self._record(lid, nid, 'position_gap', 'geometry:chain_continuity',
                     sev, round(gap), 'mm', f"Gap {round(gap)}mm at {lid} → {nid}", '< 5mm at any junction')

    def _check_chord(self, nid, npts):
        if len(npts) != 2: return
        chord = self._dist(npts[0], npts[1])
        if chord <= self.CHORD_SUSPECT_MM: return
        sev = 'severe' if chord > self.CHORD_SEVERE_MM else 'minor'
        self._record(nid, None, 'chord_cut', 'geometry:min_pts_per_track',
                     sev, round(chord), 'mm', f"2-pt chord {round(chord)}mm on {nid}", '>= 3 pts on any track')

    def _record(self, tid, nid, typ, iref, sev, val, unit, desc, expected):
        ts = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        self.observations.append({
            'agent': 'Nora', 'domain': 'PH',
            'network_id': self.network_id, 'instruction_ref': iref,
            'observation_type': typ, 'severity': sev,
            'subject_id': str(tid), 'next_id': str(nid) if nid else '',
            'value': val, 'unit': unit, 'description': desc,
            'instruction_expected': expected, 'location_t': 1.0,
            'logged_at': ts, 'logged_by': 'Nora.PH', 'pod_id': self.pod_id,
        })

    def _write_to_physical_json(self):
        allie = pathlib.Path.home() / 'Allie' / 'process' / 'physical'
        local = pathlib.Path.home() / 'jpod_logs' / 'observations'
        inbox = allie if (allie.parent.parent).exists() else local
        inbox.mkdir(parents=True, exist_ok=True)
        path  = inbox / 'physical.json'
        data  = json.loads(path.read_text()) if path.exists() else {}
        data.setdefault('observations', [])
        data['observations'].extend(self.observations)
        data['observations'] = data['observations'][-500:]
        path.write_text(json.dumps(data, indent=2))

    def _write_fault_if_severe(self):
        severes = [o for o in self.observations if o['severity'] == 'severe']
        if not severes: return
        types = ', '.join(set(o['observation_type'] for o in severes))
        tracks = ', '.join(set(o['subject_id'] for o in severes))
        _write_fault(f"Trajectory severe — {len(severes)} observation(s): {types}",
                     context=f"tracks: {tracks}", detected_by='Nora')

    def _fire_allie_capture(self, trip_id):
        _allie_capture('nora_trajectory_flush',
            f"{len(self.observations)} trajectory observation(s) flushed",
            {'trip_id': trip_id, 'network_id': self.network_id,
             'count': len(self.observations),
             'severe': sum(1 for o in self.observations if o['severity'] == 'severe')})

    @staticmethod
    def _vec(a, b): return [b[i]-a[i] for i in range(3)] if len(a) >= 3 and len(b) >= 3 else None
    @staticmethod
    def _dot(a, b): return sum(a[i]*b[i] for i in range(3))
    @staticmethod
    def _mag(v): return math.sqrt(sum(x**2 for x in v))
    @staticmethod
    def _dist(a, b): return TrajectoryObserver._mag(TrajectoryObserver._vec(a, b))
```

### Physical — Wiring into trip lifecycle

```python
# At trip start (in main.py or motor.py):
trajectory_observer = TrajectoryObserver(network_id=MAP_ID, pod_id=POD_NAME)

# At each line transition (ezone exit / encoder line complete):
current_pts = trip_lines.get(current_line_id)
next_pts    = trip_lines.get(next_line_id)
if current_pts and next_pts:
    trajectory_observer.observe_junction(current_line_id, current_pts,
                                          next_line_id,    next_pts)

# At trip complete:
trajectory_observer.flush(trip_id=current_trip_id)
```

---

## Open Questions

- **Threshold calibration** — All constants are first-pass estimates. Adjust after first real observation batch on `2_thru_dip`.
- **Noelle time-bounding** — Observations older than 30 days should not promote to `noelle.faults[]`. Need a `valid_until` field or a Build-time age filter.
- **Route-Time edges** — Should RT carry geometry pts per edge? Enables Nora's checks in simulation before physical build. Currently deferred — architectural change to Route-Time.
- **Natalie timing baseline** — The 40s/20s constants are estimates. Once physical trips run, replace with measured values per station type.
- **Cross-network pattern threshold** — 3 networks, moderate+ severity proposed. May need adjustment once first real dataset exists.
- **Student networks** — Should student-built networks feed the same synthesis pool, or go into a separate partition? Student errors are different in character from system geometry errors.

# OS List and Red Flag Protocol

**Last Updated:** 2026-06-07
**Domain:** All (SU, PH, RT, WC3)
**Reviewed:** Daily

---

## Two Modes of Agent Risk Handling

Agents encounter problems during operation. They have two responses and only two:

| Mode | Condition | Agent does | Records to |
|------|-----------|-----------|-----------|
| **OS List** | Agent has a rule that handles the situation; rule involves judgment | Fix autonomously. Document the judgment **once** when the fix is designed, not at runtime. | `process/os-list/decisions.json` |
| **Red Flag** | Agent encounters a condition it cannot safely resolve; rule does not apply | Stop everything, demand human resolution, block further operation | `process/os-list/YYYY-MM-DD.jsonl` (type=red_flag) + console |

**There is no silent third mode.** An agent that encounters a problem and does
nothing, says nothing, and leaves no record is not operating correctly.

**The OS List is a retrospective design record, not a runtime event log.**
Each entry is written once when the autonomous fix is coded — it documents the
judgment made, the risk accepted, and the path to making the judgment explicit.
Once documented, the entry does not repeat. Daily review asks: is each judgment
still valid? Has anything changed that would make it wrong?

---

## Files

| File | What it is |
|------|-----------|
| `process/os-list/decisions.json` | Static design record — one entry per autonomous fix. Written once when the fix is coded. Updated on review or promotion. |
| `process/os-list/YYYY-MM-DD.jsonl` | Runtime Red Flag events only — written by agents when they stop and refuse. |

---

## OS Decision Entry

One entry per autonomous fix. Lives in `decisions.json`. Written once when the fix is designed.

```json
{
  "id":             "OS-001",
  "agent":          "Natalie",
  "domain":         "SU",
  "code_location":  "jpod_vehicle_anim.rb:build_maneuvers_from_ids ~line 404",
  "action":         "Proximity flip — reverse segment when pts.last closer to prev_end_pt than pts.first",
  "risk":           "pts stored end→start intentionally; reversal breaks that consumer",
  "why":            "Animation requires pts in travel order. Closer endpoint to prior track's exit is departure end.",
  "risk_level":     "low",
  "added":          "2026-06-07",
  "last_reviewed":  null,
  "status":         "active",
  "promotion_path": "Zero OS entries when all ring arcs declared CCW in lines.json and flip becomes no-op"
}
```

| Field | Notes |
|-------|-------|
| `id` | Sequential, permanent: OS-001, OS-002, … |
| `code_location` | File + method + approximate line — enough to find it |
| `action` | What the agent does autonomously |
| `risk` | What could be wrong about this rule |
| `why` | Why the judgment is sound |
| `status` | `active` / `promoted` (judgment made explicit in code) |
| `promotion_path` | What explicit code change removes the need for this fix |

---

## Red Flag Entry

An agent refused to proceed. It stopped the current operation and is waiting for
human resolution. Nothing continues until the flag is resolved.

```json
{
  "type":         "red_flag",
  "ts":           "2026-06-07T14:30:00Z",
  "agent":        "Noelle",
  "domain":       "SU",
  "condition":    "snap-candidates gap 2400mm exceeds 1000mm threshold",
  "demand":       "Inspect junction seg_s003_cp0_s001_cp2 → s001.gw_cp_in_0: gap is not a model artifact",
  "blocked":      "PathJSON.export — path.json not written",
  "context":      { "from_track": "seg_s003_cp0_s001_cp2", "to_track": "s001.gw_cp_in_0", "gap_mm": 2400 },
  "model":        "trial5",
  "resolved_at":  null,
  "resolution":   null
}
```

| Field | Notes |
|-------|-------|
| `condition` | What the agent observed that triggered the stop |
| `demand` | Exactly what must be done to resolve — specific, actionable |
| `blocked` | What operation is blocked until resolution |
| `resolved_at` | UTC when resolved |
| `resolution` | What was done: "fixed model geometry" / "added successor" / "raised threshold" |

---

## Risk Levels

| Level | When to use | Examples |
|-------|-------------|---------|
| `low` | Well-established rule; failure is immediately visible | proximity flip, endpoint snap with declared successor |
| `medium` | Correct in most cases; edge cases exist | Bezier reconstruction from tangents, snap-candidates with run_count=1 |
| `high` | Agent acted on insufficient information | route replan where stored trip O-D doesn't match pod assignment |

**Red Flag threshold:** any condition where the agent cannot determine the right
answer from available data, or where the wrong answer would corrupt persistent
state (map.json, lines.json, trip plans) rather than just produce a visible glitch.

---

## Instrumented Actions — Current

### Noelle (PathJSON.export)

| Action | Type | Risk level | Trigger |
|--------|------|-----------|---------|
| Step 4: reversed ring arc | OS | low | A.last closer to B.first than B.last |
| Step 5: junction endpoint snap | OS | low | gw_in/gw_out endpoint moved to ring arc endpoint |
| Step 5b: Bezier reconstruction | OS | medium | gw_in/gw_out replaced with Bezier from tangents |
| Step 6: intra-station endpoint snap | OS | low | declared successor pair, gap 1–500mm |
| Step 7: snap-candidates cross-track | OS | medium | candidates file, gap 1–1000mm |
| Step 7: gap > 1000mm in candidates | **Red Flag** | — | gap exceeds model-artifact ceiling |
| Step 6: gap > 500mm on declared successor | **Red Flag** | — | declared successor has impossibly large gap |

### Natalie (build_maneuvers_from_ids / build_maneuvers)

| Action | Type | Risk level | Trigger |
|--------|------|-----------|---------|
| Proximity flip — reversed segment | OS | low | pts.last closer to prev_end by > 1in |
| First-maneuver orientation | OS | low | reversing m[0] reduces gap to m[1].first |
| Junction gap detected | OS | medium | gap > JUNCTION_GAP_WARN_MM (5mm) |
| Route replan (stored trip mismatch) | OS | high | stored O-D != pod O-D |
| No route found at all | **Red Flag** | — | BFS returns nil for valid O-D pair |

### Nora (SU + PH)

| Action | Type | Risk level | Trigger |
|--------|------|-----------|---------|
| Position deviation logged | OS | low | delta > DEVIATION_TOL_XY_MM or Z |
| IMU spike filtered | OS | medium | reading > 3σ of recent window |
| Position deviation > 500mm | **Red Flag** | — | pod completely off declared path |
| Hardware fault (I2C, motor) | **Red Flag** | — | unit test failure or sensor dropout |

### Sally (SU + PH)

| Action | Type | Risk level | Trigger |
|--------|------|-----------|---------|
| Slot reassignment | OS | medium | arriving pod needs occupied slot |
| All slots occupied — deadlock | **Red Flag** | — | no empty slot exists in station |

---

## Ruby Helpers

Both helpers are defined as class methods and available in all agent files.

```ruby
# Autonomous fix — log to OS List and continue.
def self._os_report(agent:, domain:, action:, risk:, why:,
                    risk_level: 'low', context: nil, model: nil)
  ts_str = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
  os_dir = File.expand_path('~/Allie/process/os-list')
  return unless Dir.exist?(os_dir)
  date   = Time.now.utc.strftime('%Y-%m-%d')
  entry  = { type: 'os', ts: ts_str, agent: agent, domain: domain,
             action: action, risk: risk, why: why, risk_level: risk_level,
             context: context, model: model, justified_at: nil, justified_by: nil }
  File.open(File.join(os_dir, "#{date}.jsonl"), 'a') { |f| f.puts entry.to_json }
rescue => _e
end

# Hard stop — log Red Flag, raise to caller, block operation.
# Caller must rescue and halt whatever it was doing.
def self._red_flag(agent:, domain:, condition:, demand:, blocked:,
                   context: nil, model: nil)
  ts_str = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
  os_dir = File.expand_path('~/Allie/process/os-list')
  date   = Time.now.utc.strftime('%Y-%m-%d')
  entry  = { type: 'red_flag', ts: ts_str, agent: agent, domain: domain,
             condition: condition, demand: demand, blocked: blocked,
             context: context, model: model, resolved_at: nil, resolution: nil }
  File.open(File.join(os_dir, "#{date}.jsonl"), 'a') { |f| f.puts entry.to_json } if Dir.exist?(os_dir)
  puts "🚩 RED FLAG [#{agent}] #{condition}"
  puts "   Demand: #{demand}"
  puts "   Blocked: #{blocked}"
  raise "[#{agent}] RED FLAG: #{condition} — #{demand}"
rescue => ex
  raise ex   # re-raise so caller can halt
end
```

---

## Daily Review

### `allie-os-review.py`

```bash
# Show today's unjustified entries
python3 ~/Allie/scripts/allie-os-review.py

# Show last 7 days
python3 ~/Allie/scripts/allie-os-review.py --days 7

# Justify an entry
python3 ~/Allie/scripts/allie-os-review.py --justify 20260607T143000 --by bill

# Mark for code fix
python3 ~/Allie/scripts/allie-os-review.py --code-fix 20260607T143000 --note "add to lines.json successors"

# Resolve a Red Flag
python3 ~/Allie/scripts/allie-os-review.py --resolve 20260607T143000 --resolution "fixed model geometry"
```

### What Allie surfaces each morning (in nightly reflect)

```
## OS List — Review Required

3 unjustified OS entries, 1 unresolved Red Flag (last 7 days)

RED FLAG [Noelle/SU] 2026-06-07T14:30:00Z ← UNRESOLVED
  Condition: snap-candidates gap 2400mm exceeds ceiling
  Demand: Inspect junction seg_s003_cp0_s001_cp2 → s001.gw_cp_in_0
  Blocked: PathJSON.export

OS [Natalie/SU] 2026-06-07T14:11:49Z  risk=medium
  Action: route replan — stored trip s003→s001 but pod wants s002→s004
  Risk:   pod assigned wrong route
  Why:    origin_sid/dest_sid mismatch on stored_seq; recomputed from live model

Run: python3 ~/Allie/scripts/allie-os-review.py --days 1
```

### Outcomes

| Outcome | What happens |
|---------|-------------|
| **Justified** | `justified_at` set. Fix remains authorized. If same fix recurs 3+ times, escalate to ouch-list — recurring justified fixes signal a structural gap to close. |
| **Code fix** | Underlying rule made explicit. Entry removed after fix confirmed. This is the goal: zero OS entries = fully explicit pipeline. |
| **Red Flag resolved** | `resolved_at` + `resolution` set. Operation unblocked. |
| **Escalated** | 3+ unjustified recurrences → ouch-list entry. Agent authority for this action class suspended. |

---

## The Goal

Zero OS entries for a given action class means the pipeline has no silent
assumptions in that class. Every rule is explicit, tested, and documented.

The OS List is not a permanent fixture — it is a transition tool. Each entry
is a debt: a place where the system is relying on agent judgment instead of
explicit design. The daily review is how that debt gets paid.

```
OS entry (autonomous fix)
    ↓ recurs 3× → ouch-list (structural risk)
    ↓ code fix → lines.json / jpod_constants.rb / Build validation
    ↓ confirmed → OS entry deleted, rule explicit
Zero OS entries for this action class
```

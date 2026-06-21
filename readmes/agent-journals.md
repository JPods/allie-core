# Agent Journals — Personal Learning Files

## Principle

Each agent has a personal JSON journal file. They write whatever they need —
observations, hypotheses, test results, experience counters, patterns noticed.
No schema imposed. The agent decides what's useful.

Allie and Athena review journals periodically for oversized junk — entries that
have grown large without producing useful signal. Agents can test ideas in their
journals without permission. Bad ideas get pruned by review, not by restriction.

**The journal is the agent's memory between sessions.**

---

## File Locations

```
su_jpods/journals/
  natalie.json    — routing decisions, BFS failures, stop-wait patterns
  noelle.json     — validation results, template defects, geometry drift
  sally.json      — slot turnover, pod histories, capacity signals
  nora.json       — maneuver timing, speed anomalies, sensor drift
  allie.json      — cross-domain patterns, risk signals, whatif outcomes
  claude.json     — session decisions, TFTS summaries, architecture notes
  alice.json      — ticket patterns, pricing signals, customer feedback
```

---

## Rules

1. **Any agent can write to their own journal at any time.** No approval needed.
2. **Entries must be timestamped** (UTC ISO-8601).
3. **Each entry must have a `type` field** — helps filtering but doesn't restrict content.
4. **No entry may exceed 10 KB.** If an agent needs more, split into separate entries.
5. **Journal file may not exceed 500 KB.** Allie prunes on review.
6. **Allie reviews all journals weekly** — flags oversized, stale, or junky entries.
7. **Athena reviews monthly** — security check, no sensitive data in plain text.

---

## Entry Structure

Minimum fields:
```json
{
  "dt": "2026-06-21T16:00:00Z",
  "type": "observation | hypothesis | test | pattern | decision | fault",
  "body": "whatever the agent wants to record"
}
```

Everything else is agent-defined. Examples:

### Natalie
```json
{
  "dt": "2026-06-21T16:00:00Z",
  "type": "pattern",
  "body": "s003→s002 routes consistently use 21 segments. BFS finds shorter CW path (14 segs) but CCW enforcement adds 7.",
  "route": "s003→s002",
  "seg_count": 21,
  "observation_count": 47
}
```

### Sally
```json
{
  "dt": "2026-06-21T16:00:00Z",
  "type": "observation",
  "body": "s002 ps9 has 3× the arrival rate of ps1. Pods cluster at exit end.",
  "station": "s002",
  "slot": 9,
  "arrival_count": 87,
  "avg_dwell_s": 12.3
}
```

### Nora
```json
{
  "dt": "2026-06-21T16:00:00Z",
  "type": "fault",
  "body": "NORA_0003 stop-wait at EP6 s001. Ring pod NORA_0007 cleared 1.2s later.",
  "ezone_ep": 6,
  "station": "s001",
  "wait_s": 1.2,
  "ring_pod": "NORA_0007"
}
```

---

## Review Protocol

### Allie — Weekly
- Read all journals
- Flag entries older than 30 days with no matching pattern or decision
- Flag entries larger than 5 KB
- Flag journals larger than 300 KB
- Summarize patterns across agents (cross-domain signals)
- Write summary to `allie.json`

### Athena — Monthly
- Check for sensitive data (credentials, API keys, personal info)
- Check for entries that reference external systems without authorization
- Flag and report — do not delete (Allie deletes on confirmation)

---

## Implementation

### Writing
```ruby
JPods::Journal.write('natalie', {
  type: 'pattern',
  body: 'CCW enforcement adds 7 segments to s003→s002',
  route: 's003→s002',
  seg_count: 21
})
```

### Reading
```ruby
entries = JPods::Journal.read('sally')
recent  = JPods::Journal.read('sally', since: '2026-06-20')
faults  = JPods::Journal.read('nora', type: 'fault')
```

### Review
```ruby
JPods::Journal.review  # Allie reviews all, prints summary
```

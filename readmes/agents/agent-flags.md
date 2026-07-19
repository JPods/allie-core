# Agent Flag System — Red / Orange / Yellow

**Established:** 2026-07-17
**Applies to:** Nora, Sally, Alice (flag raisers) → Noelle (physical manager), Alice (commerce manager) → Andi/Allie (observers, context) → Alice (action records for all)

---

## The Three Flags

| Flag | Color | Meaning | Urgency |
|------|-------|---------|---------|
| 🔴 **RED** | Red | **Stop everything** — safety or integrity at risk. Halt operations until resolved. | Immediate — all stop |
| 🟠 **ORANGE** | Orange | **Known problem, must be fixed by date** — we understand it, we know the fix, schedule it. | Planned — has a deadline |
| 🟡 **YELLOW** | Yellow | **Do not understand** — something is anomalous but the agent can't diagnose it. | Investigate — need eyes on it |

**Red is rare.** If red flags are common, the system has a design problem, not an operations problem.

**Orange is the workhorse.** Most operational issues land here — understood problems with known fixes and deadlines.

**Yellow is the honest signal.** The agent is saying "I see something I can't explain." This is the most valuable flag for learning — yellows that get diagnosed become oranges (if fixable) or get dismissed (if understood). Yellows that persist become the system's open questions.

---

## Red Flag — Stop Everything

**A red flag stops everything.** Not part of everything. Everything.

In WebClerk: transactions stop being processed. Orders halt. Invoices
stop generating. Payments stop posting. The system is down.

In JPods: no new trips are started. Existing trips exit the travelling
guideway as soon as physically possible — nearest station, emergency
platform, whatever is closest. Pods clear the network. The network is down.

**There will be chaos and unhappiness.** Customers can't buy. Passengers
are stranded. Operators are on the phone. Revenue stops.

**That is the point.**

A red flag must be so painful that it forces the team to think ahead.
Every red flag that fires is a failure of prevention — an orange that
should have been raised earlier, a yellow that should have been
investigated, a maintenance task that should have been scheduled.

> *"Suffer now, so our children do not suffer later."*

The cost of a red flag today is the discipline that prevents a red
flag tomorrow. If red flags are rare, the system is healthy. If red
flags are common, the system has a design problem that no flag system
can fix — the team must go back to the engineering and find the root
cause.

**Red flags are retrospection forcing functions.** Every red flag gets
a TFTS written. Every red flag gets a retrospection entry. Every red
flag gets a "why didn't we catch this as an orange?" question. The
answers to that question are how the system learns.

---

### What Triggers a Red Flag

**Nora:**
- Motor stall with pod on elevated section → passenger safety
- Complete loss of position (encoder + ToF + HuskyLens all disagree) → pod lost
- Battery voltage critical — risk of shutdown at height → immediate recovery
- Collision detection triggered → stop all traffic
- Communication loss with all pods simultaneously → network failure

**Sally:**
- Conveyor fault with pod in transit between slots → mechanical jam
- Station structural sensor alarm → integrity question
- Emergency stop button pressed → human-initiated halt
- Fire/smoke detection at station → evacuate

**Alice (WebClerk):**
- Data integrity violation — transaction totals don't reconcile
- Payment gateway reporting fraud alert
- Database connection lost — cannot guarantee ACID
- Security breach detected — unauthorized data access

### Scope of Red Halt

| Red flag on... | What stops |
|----------------|-----------|
| A single pod | **All pods** — network down. Clear all trips. |
| A station | **All stations** — network down. Clear all trips. |
| Infrastructure | **Network down.** Clear all trips. |
| WebClerk transaction | **All transactions halt.** Queue incoming, process nothing. |
| WebClerk security | **System locked.** No API access until resolved. |

There is no "partial red." Red means stop. If the problem is local enough
to keep some operations running, it's orange, not red.

---

## Orange Flag — Known Problem, Fix by Date

We understand the problem. We know the fix. It has a deadline.

**Nora orange flags:**
- Motor current drifting up 10%/week → replace bearing by [date]
- ToF sensor intermittent → order replacement, install by [date]
- Encoder slip rate above threshold → recalibrate or replace wheel by [date]
- Battery capacity degraded → swap battery by [date]
- Brake wear indicator → service by [date]

**Sally orange flags:**
- Slot sensor reading erratically → replace sensor by [date]
- Conveyor belt showing wear → replace by [date]
- Queue depth persistently > 80% capacity → review station sizing with Noelle by [date]
- Platform edge gap widening → maintenance by [date]

**Alice orange flags:**
- Payment gateway intermittent failures → contact provider, resolve by [date]
- Inventory count discrepancy detected → reconcile by [date]
- Sync connection to WCHQ failing → diagnose and fix by [date]
- API response times degrading → optimize queries by [date]
- Disk usage > 80% → expand or archive by [date]
- SSL certificate expiring → renew by [date]

**Every orange flag has a `fix_by` date.** No open-ended orange flags. If you
can't set a date, it's either yellow (don't understand yet) or red (stop now).

---

## Yellow Flag — Do Not Understand

The agent sees something outside its baseline but can't classify it. This is
the learning signal — the gap between what the agent knows and what's happening.

**Nora yellow flags:**
- Motor current changed character (not overcurrent, just different pattern)
- Trip duration significantly different from baseline on a known route
- HuskyLens AprilTag detection intermittent — lighting? obstruction? tag moved?
- Encoder counts don't match expected distance but no mechanical fault detected
- Vibration pattern changed — smoother or rougher than baseline

**Sally yellow flags:**
- Arrival pattern changed — usually steady, now bursty
- One slot consistently skipped by arriving pods
- Dwell time variance increased — some pods leave fast, others linger
- Departure rate dropped but arrivals steady — where are pods going?
- Temperature readings at station shifted — weather? equipment? both?

**Alice yellow flags:**
- Order conversion rate dropped but traffic is steady — why?
- Customer search patterns shifted — different products trending?
- Payment failure rate up slightly — gateway issue or card quality?
- Sync records arriving with unexpected field values — schema change at WCHQ?
- API call pattern from one IP unusual but not clearly malicious

**Yellow flags are questions, not answers.** They are the system saying
"I need help understanding this." The resolution path:
- Diagnosed as a known problem → convert to 🟠 orange with fix_by date
- Diagnosed as normal variation → dismiss with explanation in facet
- Cannot diagnose → stays yellow, Andi watches for correlation

---

## Flag Data Structure

```json
{
  "flag": "red|orange|yellow",
  "agent": "nora|sally",
  "agent_id": "pod_03|s003",
  "timestamp_utc": "2026-07-18T03:22:15Z",
  "category": "motor_overcurrent|sensor_drift|pattern_change",
  "message": "Human-readable description",
  "data": {
    "measured_value": 680,
    "baseline_value": 420,
    "threshold": 600,
    "segment_id": 14,
    "trip_id": "trip_2026-07-18_0322"
  },
  "fix_by": "2026-07-22T00:00:00Z",
  "resolved": false,
  "resolved_at": null,
  "resolved_by": null,
  "converted_from": null,
  "action_id": null
}
```

`fix_by` is required for orange, null for red (immediate) and yellow (unknown).

`converted_from` tracks yellow → orange conversions: `"yellow_20260718_0415"`

---

## Flag Flow — Who Does What

```
Nora/Sally raises flag (any color)
    ↓ writes to facet + process/inbox/
    ↓ publishes MQTT: FLAG,{agent},{color},{category},{message}
    ↓
Noelle receives flag (primary manager)
    ↓
    ├── 🔴 RED: Noelle halts immediately
    │   ├── Stop affected pod/station/segment
    │   ├── Hold all dispatch to affected area
    │   ├── Reroute active trips around
    │   ├── Notify Andi → Andi notifies Alice → urgent Action
    │   └── Flag stays until human resolves and clears
    │
    ├── 🟠 ORANGE: Noelle logs, adjusts if needed
    │   ├── May reduce speed, limit capacity, add monitoring
    │   ├── Notifies Andi → Alice creates Action with fix_by deadline
    │   ├── Tracks countdown to fix_by date
    │   └── If fix_by passes unresolved → escalate to red
    │
    └── 🟡 YELLOW: Noelle logs, watches
        ├── No immediate action — observation mode
        ├── Andi checks against baselines and cross-correlates
        ├── If pattern persists > 24 hours → Alice creates Action
        ├── If diagnosed → convert to 🟠 orange with fix_by
        ├── If multiple yellows correlate → Noelle raises 🔴 red
        └── If explained as normal → dismiss, note in facet
    ↓
Andi (always-on observer)
    ├── All flags: check against baselines
    ├── Cross-correlate across agents (Nora current + Sally dwell = same root cause?)
    ├── Add drift analysis (was this building over days/weeks?)
    ├── Check if Allie has relevant context
    ↓
Allie (when available)
    ├── Add Bill's context: recent work, parts replaced, design changes
    ├── Cross-domain context: did a SketchUp model change affect this segment?
    ├── History: has this happened before? What fixed it last time?
    ↓
Alice creates Action record in WC3
    ├── 🔴 Red → priority: "critical", kanban: "todo", assigned immediately
    ├── 🟠 Orange → priority: "high", kanban: "todo", due_date: fix_by
    ├── 🟡 Yellow (escalated) → priority: "normal", kanban: "backlog"
    └── All include: flag data + Andi analysis + Allie context
```

---

## Alice Action Record Format

```json
{
  "model_name": "action",
  "data": {
    "ida": "FLAG-RED-NORA-20260718-0322",
    "name": "🔴 STOP: Nora pod_03 — motor stall on elevated segment 14",
    "description": "Motor stall at elevation. Pod halted, segment 14 closed. Adjacent pods holding position. Andi: motor current was drifting +8%/week for 3 weeks — this was predictable (should have been orange earlier). Allie: motor replaced 2026-07-04 — check mounting bolts and belt tension.",
    "status": "planned",
    "priority": "critical",
    "kanban_column": "todo",
    "due_date": null,
    "config": {
      "source": "agent_flag",
      "flag_color": "red",
      "flag_agent": "nora",
      "flag_category": "motor_stall",
      "flag_data": { "...full flag JSON..." },
      "andi_analysis": "Motor current drift: +8%/week for 3 weeks. This red was a predictable escalation from an unraised orange.",
      "allie_context": "Motor replaced 2026-07-04. Check mounting bolts.",
      "scope_of_halt": "pod_03 stopped, segment 14 closed, s003↔s004 rerouted"
    },
    "refs": {
      "keywords": {
        "type": "agent_flag",
        "flag": "red",
        "agent": "nora",
        "pod": "pod_03",
        "segment": 14
      }
    }
  }
}
```

For orange:
```json
{
  "name": "🟠 Nora pod_03: Motor bearing — replace by 2026-07-22",
  "priority": "high",
  "due_date": "2026-07-22",
  "kanban_column": "todo"
}
```

For yellow (escalated after 24h):
```json
{
  "name": "🟡 Sally s003: Arrival pattern shift — investigate",
  "priority": "normal",
  "kanban_column": "backlog"
}
```

---

## Hard Rule: Every Flag Gets an Action and an Owner

**No exceptions.** Every flag — red, orange, or yellow — results in:
1. An Action record created by Alice in WC3
2. A human responsible person assigned to that Action

Flags without Actions are invisible. Actions without owners are orphans.
Both are failures of the system.

- 🔴 Red → Action created **immediately**, assigned to on-site person or Bill
- 🟠 Orange → Action created with `fix_by` deadline, assigned to person who can fix it
- 🟡 Yellow → Action created within 24 hours if unresolved, assigned to person who can investigate

Alice determines the responsible person from:
- The pod/station's assigned maintainer (if configured in crew.json)
- The network's primary operator (from network.json metadata)
- Bill (fallback if no other assignment exists)

The `assigned_to` field is a contact_id in WC3. Never null on a flag Action.

---

## Escalation Rules

| Condition | Escalation |
|-----------|-----------|
| 🟡 Yellow persists > 24 hours | Andi → Alice creates normal Action |
| 🟡 Multiple yellows correlate | Noelle raises 🔴 red (correlated unknowns = danger) |
| 🟡 Yellow diagnosed | Convert to 🟠 orange with fix_by date |
| 🟡 Yellow explained as normal | Dismiss, record explanation in facet |
| 🟠 Orange fix_by date passes | Escalate to 🔴 red — deadline missed = stop |
| 🟠 Orange condition worsens | Escalate to 🔴 red |
| 🔴 Red unresolved > 4 hours | Andi re-notifies, Alice updates Action to "overdue" |
| 🔴 Red repeats 3x same root cause | Systemic flag → design review Action |

**Critical escalation: orange → red on missed deadline.**
If you said "fix by Friday" and it's Saturday, that orange is now a red.
The deadline was a commitment. Missing it means the known problem is now
an uncontrolled risk.

---

## Resolution

When a flag is resolved:

1. Resolver marks the Action complete in WC3
2. Flag record updated: `resolved: true`, `resolved_at`, `resolved_by`
3. Andi logs resolution in nightly reflection
4. If resolution reveals a principle → write TFTS to `process/inbox/`
5. Allie picks up TFTS → Understanding candidate
6. If a yellow was diagnosed, the diagnosis becomes institutional knowledge
   in the agent's facet — next time, same pattern → orange immediately

---

## Learning Loop — Suffer Now So Our Children Do Not Suffer Later

The flag system is a learning system, not just an alerting system.
Its purpose is not to manage crises — it is to eliminate them.

**Every red flag is a failure of prevention.**

When a red flag fires, the first question is not "how do we fix it?"
The first question is "why didn't we see this coming?" The answer to
that question — always — is a missing orange or an uninvestigated yellow.

The retrospection after every red flag must answer:
1. What orange should have been raised, and when?
2. What yellow was visible but not investigated?
3. What baseline should Andi have been tracking?
4. What maintenance task should have been scheduled?
5. What design change would prevent this class of failure?

The answers become institutional knowledge — agent facets,
Understandings (U-XX-NNN), design changes, maintenance schedules.
The red flag was the tuition. The lesson is what we paid for.

**Yellows are the primary learning input.**
Every yellow that gets diagnosed teaches the agent to recognize that
pattern next time. The resolution notes go into the facet's
`confirmed_instructions`. What was yellow once becomes orange
(or dismissed) next time — the agent learned.

**Oranges that escalate to red teach deadline discipline.**
If the team consistently misses orange deadlines, the problem is
scheduling, not the flag system. Andi tracks escalation rates.
An orange that becomes a red because nobody fixed it by the deadline
is worse than a surprise red — it means the team knew and didn't act.

**Reds that were predictable teach observation discipline.**
If Andi's drift tracking showed the problem building for weeks and
nobody raised an orange, the flag system worked but the team didn't
use it. Retrospection topic.

**The goal is zero red flags.** Not because problems don't exist —
because problems are caught as yellows, diagnosed into oranges,
and fixed before they become reds. A mature system has many oranges,
some yellows, and no reds. That's the measure of excellence.

---

## MQTT Topics

```
jpods/flags/{agent_id}/red         ← stop everything
jpods/flags/{agent_id}/orange      ← known problem, fix by date
jpods/flags/{agent_id}/yellow      ← don't understand
jpods/flags/{agent_id}/resolved    ← flag resolved
jpods/flags/noelle/escalation      ← Noelle escalates (yellow→red, orange→red)
```

Payload: JSON flag object.

---

## Notes

**Flags vs Ouch List — different tools for different problems.**
The flag system handles **operational events** — things happening now.
The ouch list (`readmes/system/ouch-list.md`) holds **risks we know about
but are intentionally deferring** — each with reasoning for why we think
it's long-tail and what would prove us wrong. When an ouch list risk
materializes, it becomes a flag. The ouch list entry's reasoning becomes
the retrospection lesson.

**Why not green?**
Green is absence of flags. Normal operations don't need a signal.

**Why orange, not amber?**
Orange reads faster. Same meaning. And it maps to the color standard:
🔴 red = stop (hot), 🟠 orange = act (warm), 🟡 yellow = watch (cool).

**Why Noelle manages, not Andi?**
Noelle has operational authority — reroute, halt, speed control. Andi
observes and analyzes but cannot move a pod. Noelle acts; Andi explains.

**Why Alice creates the Action, not Noelle?**
Alice owns the WC3 database. Actions are WC3 objects. Clean boundary.
Noelle decides the operational response. Alice records it for humans.

**Why Allie collaborates?**
Context that Andi can't have — what Bill worked on yesterday, what parts
were replaced, what the SketchUp model changed. The combination of
Andi's data analysis and Allie's human context makes the Action
actually useful, not just an alert.

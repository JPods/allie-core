# Weekly Code Scrub — Protocol

**Cadence:** Every Wednesday, 2:00 PM GMT (9:00 AM Bill's time)  
**Duration:** Time-boxed — definition of done is the exit condition, not the clock  
**Who:** Bill + Claude Code (or Allie on weeks without a Claude Code session)

**Why Wednesday:**
- Best world team time — respects Friday (Muslim observance), avoids Western weekend split
- Mon–Tue: complete the work; Wed: scrub and stage; Thu–Fri: ship
- Immediately precedes the 3 PM GMT commercial clearing — same coordination window

---

## The Two-Pass Structure

### Pass 1 — This Week's Changes

Scope: every file touched since last Wednesday's scrub.

1. **Code matches intent** — does the implementation reflect what was decided? Any silent degradation, swallowed rescues, or stale comments?
2. **Axion check** — scan for violations: paired do/undo methods, non-UTC datetimes, calculated centerlines used as references, `Vector3d * scalar`, anything in the Universal Rules table (noelle.md)
3. **Readmes match code** — update any readme that describes behavior that changed this week. Stale readmes are the same as stale comments.
4. **Process files committed** — any TF/DNW/TFTS written this week? Committed to process/inbox/? If not, write them now while the arc is still clear.

### Pass 2 — The Seams

Scope: one hop out from this week's changed files — files that call into them, and files they call into.

1. **Interface consistency** — do callers use the right method names? (The `restore_cap_ends` vs `restore_dead_cap_ends` bug was a Pass 2 find.)
2. **Duplicate code paths** — same logic in two files? (The bezier method in both `jpod_connect_tool.rb` and `jpod_network.rb`.) Fix both or flag explicitly.
3. **Readme coverage** — does the surrounding code have a readme that acknowledges the new behavior? Does it need one?
4. **Axiom propagation** — if a new axiom was established this week (like the on/off parameter rule), are there existing violations in the surrounding files?

---

## Scrub Record — JSON Schema

One record per week. Stored at:
```
~/Allie/readmes/retrospections/scrubs/YYYY-WNN.json
```

```json
{
  "scrub_id": "2026-W21",
  "week_ending": "2026-05-27",
  "conducted_at": "2026-05-21T14:00:00Z",
  "conducted_by": ["Claude Code", "Bill"],

  "pass_1": {
    "files_reviewed": ["jpod_entities_builder.rb", "jpod_console.rb", "jpod_network.rb"],
    "readmes_updated": ["readmes/agents/athena.md", "readmes/agents/allie.md"],
    "axiom_violations_found": 1,
    "axiom_violations": [
      {
        "file": "jpod_console.rb",
        "line": 147,
        "violation": "restore_cap_ends called — method does not exist; rescue swallowed NoMethodError silently",
        "fixed": true,
        "fixed_in": "jpod_console.rb:146"
      }
    ],
    "process_files_committed": ["20260523T002727-tf.md"]
  },

  "pass_2": {
    "seams_reviewed": ["jpod_network.rb → jpod_entities_builder.rb", "jpod_connect_tool.rb"],
    "findings": [
      {
        "finding": "restore_dead_cap_ends and remove_structure_endcaps were paired do/undo — collapsed to sync_end_caps with install: parameter",
        "files_changed": ["jpod_entities_builder.rb", "jpod_network.rb", "jpod_console.rb"],
        "new_axiom": "On/off behaviors in one function with a parameter — noelle.md Universal Rules"
      }
    ]
  },

  "ouch_list_additions": [],
  "new_axioms": ["on_off_parameter_rule_2026-05-23"],
  "status": "complete"
}
```

---

## Alice Integration — When Running

After writing the JSON, post two records to WebClerk:

**1. Document record** — pointer to the JSON file:
```
POST /wcapi/save/
{
  "model_name": "document",
  "record": {
    "title": "Weekly Code Scrub 2026-W21",
    "path": "~/Allie/readmes/retrospections/scrubs/2026-W21.json",
    "doc_type": "Reference",
    "status": "active"
  }
}
```

**2. Action record** — in the active JPods sprint project:
```
POST /wcapi/save/
{
  "model_name": "action",
  "record": {
    "title": "Weekly Code Scrub 2026-W21",
    "assigned_to": "Bill",
    "what": "Two-pass code and readme review for week ending 2026-05-27",
    "why": "Polish this week's work; find axiom violations at the seams",
    "next": "Review scrub findings at next session start",
    "dt_deadline": <Wednesday 2PM GMT in ms>,
    "status": "done",
    "document_id": <id from document POST above>
  }
}
```

**When Alice is NOT running:** write the JSON only. Alice will ingest it on next startup via the `alice_pending` queue pattern.

---

## Stopping Rule — Definition of Done

The scrub is complete when:
- [ ] Every file changed this week has been read and its readme checked
- [ ] Every axiom violation found is either fixed or logged as a known exception with a reason
- [ ] Every seam file (one hop out) has been spot-checked for the week's new patterns
- [ ] The JSON record is written and committed
- [ ] Alice records posted (or queued)

Not done means: *found a violation and didn't act on it*. That is the only failure mode.

---

## Integration with Retrospection Cycle

The weekly scrub sits between daily retrospections and Allie's nightly synthesis:

```
Daily retrospections (readmes/retrospections/YYYY-MM-DD.md)
    ↓ accumulated Mon–Tue
Wednesday scrub (readmes/retrospections/scrubs/YYYY-WNN.json)
    ↓ Alice posts action + document
    ↓ Allie reads scrub JSON in nightly reflect
Allie's synthesis (thoughts/YYYY-MM-DD-reflect.md)
    ↓ promoted when confirmed
Agent Understandings (U-SK-*, U-RT-*, U-PH-*)
```

Allie's `allie-reflect.py` checks `readmes/retrospections/scrubs/` for new scrub JSON files and includes their findings in the nightly synthesis pass.

---

## Session-End Checklist Addition

On Wednesday sessions, the session-end checklist gains two items:
1. Write `readmes/retrospections/scrubs/YYYY-WNN.json`
2. Post Alice records (or queue if Alice not running)

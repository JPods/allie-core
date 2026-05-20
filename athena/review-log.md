# Athena — Review Log
**Format:** One entry per review session. Append; never delete.

```
## YYYY-MM-DD — [what was reviewed]
Findings: N
Items Bill acted on: N
Items deferred: N (reason)
Items disputed: N (outcome)

[FINDING entries]
```

---

## 2026-04-20 — Session watching protocol + meeting.sh + privacy doctrine

Findings: 3
Items Bill acted on: 3
Items deferred: 0
Items disputed: 0

---

FINDING [privacy] [HIGH]
Location: `scripts/meeting.sh` — `start_recording()` — no consent gate
What is wrong: Script began recording all voices with no prompt to inform participants — violates two-party consent law in CA and other states.
Why it matters: Legal liability; contradicts the privacy doctrine written in the same session.
What to check: Fixed — `consent_gate()` function added; runs before any recording starts. OSL-01 marked Resolved.

---

FINDING [privacy] [MEDIUM]
Location: `scripts/meeting.sh` — no retention limit on recordings or transcripts
What is wrong: WAV files and transcripts accumulated indefinitely with no purge mechanism.
Why it matters: Minimum retention principle — keep only as long as operationally needed.
What to check: Fixed — `purge_old_recordings()` added; default 30-day purge, runs at each `meeting.sh start`. OSL-05 marked Resolved.

---

FINDING [design] [MEDIUM]
Location: `athena/privacy-doctrine.md` — "The Training Method" section
What is wrong: Doctrine claims training on Bill calibrates judgment for all passengers; corpus is not representative of vulnerable populations (DV survivors, minors, immigration-sensitive, non-verbal).
Why it matters: A privacy model calibrated only on an elderly founder will have blind spots for the populations most at risk from transit surveillance.
What to check: Added OSL-03 to ouch-list. Not yet resolved — requires threat modeling with representative populations before first public deployment.

---

## 2026-04-20 — JPods Console initial build (jpod_console.rb + console.html)

Findings: 3  
Items Bill acted on: 3  
Items deferred: 0  
Items disputed: 0  

---

FINDING [security] [MEDIUM]  
Location: `jpod_console.rb` → `place_vehicle` task, `run:` lambda  
What is wrong: The `requires_selection: "JPods Guideway"` attribute on the task is checked by Athena's Gate 1 (context check) but the `run:` lambda also contains its own `raise` check. These two checks are not identical — Gate 1 uses `model.selection.first.name`, the lambda checks `gw.name`. If `selection.first` changes between Gate 1 and execution (e.g. user clicks away during a slow dialog round-trip), the lambda fires against a different object.  
Why it matters: A structure group or a columns group could be passed to `add_vehicle_to_guideway` instead of a guideway group, potentially crashing or producing corrupt geometry.  
What to check: Add `model.selection.first` re-check at the top of `capture_run` (after the Athena gate, before the proc call), or snapshot the selection object at gate-2 time and pass it to the proc rather than letting the proc re-read `model.selection`.

---

FINDING [security] [LOW]  
Location: `jpod_console.rb` → `reload_plugin` task, `run:` lambda  
What is wrong: The reload task loads `jpod_console` last in the list. This means the `TASKS` constant and `TASK_INDEX` are re-evaluated mid-session. Any in-flight `cmd_execute` callback referencing `TASK_INDEX` could reference the old constant while the new one is being built.  
Why it matters: Race condition is unlikely in practice (SketchUp is single-threaded) but the pattern is fragile. If a timer callback fires during reload it could find a partially-constructed `TASKS`.  
What to check: Confirm SketchUp Ruby timers cannot fire during a `load` call. If they can, the reload task needs to `stop_animation` before reloading `jpod_guideway.rb`.

---

FINDING [design] [LOW]  
Location: `dialogs/console.html` → `renderAthena()` function  
What is wrong: The `effectiveClass` variable defaults `review.ok ? (risk || 'safe') : 'blocked'`. If `risk` is undefined (a task record missing the `risk` key), the badge shows green but the risk classification is unknown.  
Why it matters: A task added without a `risk:` key silently appears safe in the UI. The Ruby side would pass `nil.to_s` → `""` — the JS receives an empty string and falls through to `'safe'`.  
What to check: Add a fallback in `jpod_console.rb` — validate that every task in `TASKS` has a non-nil `risk:` key at load time and `puts` a warning if not. One line: `TASKS.each { |t| puts "⚠ Task #{t[:id]} missing risk:" unless t[:risk] }` after the `TASKS` definition.

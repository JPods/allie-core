# 43 — Tool Boundary Behaviors

**Last Updated:** 2026-05-20
**Domain:** Cross-domain
**Status:** Active — all boundaries instrumented as of 2026-05-20

---

## The Principle

Every transition from "editing" to "testing" is the highest-value logging moment.
At that moment: intent is unambiguous, context is richest, the result is seconds away.

These are not debug logs — they are Allie's window into what developers were testing
and why. Without boundary captures, Allie has outcomes (a commit, a run, a build) but
not process (what was being attempted, what context surrounded the attempt).

**Named by Bill 2026-05-20:** "tool-boundary hunting behavior"

---

## The Arc

Every boundary event connects to the FAULT→DNW→TF→TFTS cycle:

```
BOUNDARY ENTRY (capture intent)
    ↓
Action executes
    ↓
System reports a fault → write FAULT file immediately
    ↓
Fix attempt fails → write DNW immediately
    ↓
Principle emerges → write TF immediately
    ↓
BOUNDARY EXIT (capture result)
    ↓
Arc completes → write TFTS (reference FAULT via fault_ref)
```

Allie reads `~/Allie/process/inbox/` nightly:
- FAULT with no matching TFTS → ouch-list candidate
- FAULT + TFTS → Understanding candidate
- Recurring FAULT → risk escalation

---

## Complete Boundary Map

| Domain | Event | File | What it captures |
|--------|-------|------|-----------------|
| **SketchUp** | `build_validate_start` | `noelle.rb` | Build/Validate initiated — model name |
| **SketchUp** | `build_validate_complete` | `noelle.rb` | Station count, fault count, fault list |
| **SketchUp** | `build_validate_fault` | `noelle.rb` | Noelle crash — exception message |
| **SketchUp** | `animation_start` | `jpod_animator.rb` | Animation started — model name |
| **Physical** | `pod_start` | `launcher.py` | Pod name, mode, broker — the "Reload Plugin" moment |
| **Physical** | `pod_stop` | `main.py` | Clean shutdown — pod name, signal |
| **Physical** | `hardware_checkup` | `unitTest.py` | TOF/motor/HuskyLens ok/fault dict |
| **Physical** | `unit_test_complete` | `unitTest.py` | All hardware tests passed |
| **Physical** | `trip_dispatched` | `mqtt.py` | START OK received — pod, path, length |
| **Physical** | `ezone_entry` | `ezone.py` | Pod entered ezone — line, ezone_stack state |
| **Physical** | `trip_complete` | `motor.py` | Trip done — pod, dist_mm, path |
| **Route-Time** | `simulation_start` | `api.py` | Network, passenger count |
| **Route-Time** | `simulation_complete` | `api.py` | Served/generated, elapsed |
| **Route-Time** | `simulation_fault` | `api.py` | 0-served detection, exception message |
| **Route-Time** | `network_reload` | `api.py` | Network file reloaded — the RT "Reload Plugin" |
| **WebClerk** | `price_query` | `views_ui.py` | Origin/dest/price/level/contact — Alice's primary signal |
| **WebClerk** | `order_fulfilled` | `signals.py` | Invoice STATUS_RELEASED transition |
| **WebClerk** | `payment_created/updated` | `signals.py` | Payment status change |
| **WebClerk** | `search_no_result` | `item_variants.py` | Zero-result query — catalog gap signal |
| **Allie** | `reflection_start` | `allie-reflect.py` | Nightly synthesis beginning — model, window |
| **Allie** | `reflection_complete` | `allie-reflect.py` | Synthesis done — elapsed, chars, harvests |

---

## Implementation Patterns

### Python (Physical, Route-Time, WebClerk, Allie)

```python
def _allie_capture(event, message, data=None):
    """Fire-and-forget. Never blocks, never raises."""
    import subprocess, json, pathlib
    capture = pathlib.Path.home() / 'Allie' / 'scripts' / 'allie-capture.py'
    if not capture.exists():
        return
    try:
        args = ['python3', str(capture), '--source', 'PH',
                '--event', event, '--message', message[:200]]
        if data:
            args += ['--data', json.dumps(data)]
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass
```

Source codes: `PH` (Physical), `RT` (Route-Time), `WC3` (WebClerk), `ALLIE` (Allie), `SU` (SketchUp).

### Ruby (SketchUp)

```ruby
def self._allie_capture(event, message, data = nil)
  capture = File.expand_path('~/Allie/scripts/allie-capture.py')
  return unless File.exist?(capture)
  args = ['python3', capture, '--source', 'SU',
          '--event', event, '--message', message[0, 200]]
  args += ['--data', data.to_json] if data
  Process.detach(Process.spawn(*args,
    out: File::NULL, err: File::NULL, close_others: true))
rescue => _e
  # never crash SketchUp over a capture failure
end
```

### Physical — Fault file (Pi fallback to jpod_logs/)

On the Pi, `~/Allie/` may not be mounted. The pattern checks for Allie first,
falls back to `~/jpod_logs/faults/` so nothing is lost.

```python
def _write_fault(fault_text, context='', detected_by='Nora'):
    import datetime, pathlib
    ts_str  = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    ts_file = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S')
    allie_inbox = pathlib.Path.home() / 'Allie' / 'process' / 'inbox'
    local_inbox = pathlib.Path.home() / 'jpod_logs' / 'faults'
    inbox = allie_inbox if (allie_inbox.parent.parent).exists() else local_inbox
    inbox.mkdir(parents=True, exist_ok=True)
    path = inbox / f'{ts_file}-fault.md'
    path.write_text(
        f"# FAULT — {ts_str}\n\n"
        f"system:      PH\n"
        f"detected_by: {detected_by}\n"
        f"fault:       {fault_text}\n"
        f"context:     {context}\n"
        f"resolved_at: \n"
    )
```

---

## How Allie Uses Boundary Events

### Nightly synthesis (`allie-reflect.py`)

1. Reads all `*.jsonl` event logs and `process/inbox/` FAULT/TF/TFTS files
2. Pairs FAULT files with TFTS arcs by matching timestamps
3. Unresolved FAULTs → ouch-list candidates
4. FAULT+TFTS pairs → Understanding candidates (U-SU-*, U-PH-*, U-RT-*)
5. Recurring FAULT patterns → risk escalation
6. Cross-domain patterns (same fault class in SU and PH) → flagged in Questions for Bill

### Alice's pattern loop (WebClerk)

Alice's specific events feed the observe→log→pattern→recommend→promote loop:
- `price_query` events → pricing pattern detection (routes, times, price levels)
- `search_no_result` → catalog gap map → recommend items to add
- `order_fulfilled` → fulfillment rate by route, by customer segment
- `payment_created` → payment method patterns

These events arrive in `~/Allie/process/inbox/` alongside physical and SketchUp events.
Alice's learning is not separated from Nora's learning — Allie synthesizes all of it.

---

## The Agent Chip Evolution

**Current state (2026-05-20):**
Allie simulates the experience of all agents. Every boundary event writes to
`~/Allie/process/inbox/` on the Mac. Allie synthesizes nightly.

**Future state:**
Each agent (Nora, Natalie, Noelle, Alice) runs on its own chip with its own inbox.
Allie reads all inboxes. Cross-agent patterns become visible at synthesis time:
- Nora always faults at the same ezone Noelle flagged
- Alice's no-result searches correlate with Natalie's route gaps

This is the same bottom-up, locally-governed pattern as JPods itself. Each agent
accumulates its own experience; Allie synthesizes without owning any agent's data.

**Bill's framing (2026-05-20):**
> "I like this tool-boundary hunting behavior. Some will be false leads, but they also
> are likely the flag signalling experience. Allie will have to simulate for most agents
> at this point, but as agents have their own chips, this should be a key retrospection
> behavior. Alice can use this in wc business behaviors and oddities."

---

## When to Add a New Boundary

Add a boundary when:
1. The action produces a result the developer will immediately evaluate (pass/fail)
2. The failure mode at this point is a recognized class (e.g., 0-passengers = network error)
3. Allie cannot infer what was being tested from git history or retrospections alone

Do not add a boundary for:
- Every internal function call (noise, not signal)
- Intermediate states within a single action
- Events that already have a FAULT or error log

---

## Files Containing Boundary Captures

| File | Language | Events |
|------|----------|--------|
| `su_jpods/noelle.rb` | Ruby | `build_validate_start`, `build_validate_complete`, `build_validate_fault` |
| `su_jpods/jpod_animator.rb` | Ruby | `animation_start` |
| `jpod_OS/launcher.py` | Python | `pod_start` (+ FAULT for broker/session failures) |
| `jpod_OS/main.py` | Python | `pod_stop` |
| `jpod_OS/unitTest.py` | Python | `hardware_checkup`, `unit_test_complete` (+ FAULTs) |
| `jpod_OS/mqtt.py` | Python | `trip_dispatched` |
| `jpod_OS/motor.py` | Python | `trip_complete` |
| `jpod_OS/ezone.py` | Python | `ezone_entry` |
| `route_time/gui/api.py` | Python | `simulation_start`, `simulation_complete`, `simulation_fault`, `network_reload` |
| `route_time/gui/static/simulator.js` | JS | TF/DNW prompt after simulation |
| `apps/jpods/views_ui.py` | Python | `price_query` |
| `apps/transactions/signals.py` | Python | `order_fulfilled`, `payment_created/updated` |
| `apps/products/views/item_variants.py` | Python | `search_no_result` |
| `Allie/scripts/allie-reflect.py` | Python | `reflection_start`, `reflection_complete` |

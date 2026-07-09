# Allie Hook System — Automatic Event Capture
**Added:** 2026-05-18

---

## Purpose

Allie learns from the process, not just the outcome. To learn from the process she
needs to see it — automatically, without anyone having to remember to log.

The hook system is a passive event stream. Every significant action in every project
environment writes one JSONL line to `~/Allie/logs/events.jsonl`. Allie reads this
during nightly synthesis. No polling. No manual logging. No friction.

*"Knowing the outcome is much less valuable than knowing the process."*
— Bill James, 2026-05-18

---

## The Event Stream

**File:** `~/Allie/logs/events.jsonl`

Each line is one event:
```json
{"ts": "2026-05-18T21:00:50", "source": "claude-code", "event": "tool_use", "data": {"tool": "Edit", "path": "Allie/scripts/allie-reflect.py"}}
{"ts": "2026-05-18T21:05:00", "source": "git:su_jpods",  "event": "commit",   "data": {"hash": "a1b2c3", "files": "jpod_network.rb,jpod_connect_tool.rb"}, "message": "Fix bezier height"}
{"ts": "2026-05-18T21:10:00", "source": "route-time",    "event": "simulation_complete", "data": {"stations": 8, "lines": 12}}
{"ts": "2026-05-18T21:15:00", "source": "jpods-rpi",     "event": "trip_complete", "data": {"pod": "NORA_0001", "trip_mm": 3100, "anomalies": 0}}
{"ts": "2026-05-18T21:20:00", "source": "webclerk3",     "event": "order_created", "data": {"id": 42}}
```

Rotates at 5 MB. Old file renamed `events-YYYY-MM-DD.jsonl`.

---

## Hooks Installed

### Claude Code — every tool call

**Config:** `~/.claude/settings.json` → `hooks.PostToolUse` and `hooks.Stop`

Fires after every Edit, Write, Read, and Bash call. Captures:
- Tool name
- File path (for Edit/Write/Read)
- Command and description (for Bash)

Also fires a `session_end` event when Claude Code finishes responding.

**No action needed** — runs automatically whenever Claude Code is active.

---

### Git — every commit in all project repos

**Script:** `~/Allie/scripts/git-post-commit.sh` (shared)
**Installer:** `~/Allie/scripts/install-git-hooks.sh`

Installed repos:

| Repo | Path |
|------|------|
| `su_jpods` | `~/Library/Application Support/SketchUp 2026/SketchUp/Plugins/su_jpods` |
| `route_time` | `~/Documents/08_JPods/03_Technology/00_working_code/route_time` |
| `JPodsSM_RPi` | `~/Documents/08_JPods/03_Technology/00_working_code/JPodsSM_RPi` |
| `webClerk3` | `~/Documents/CommerceExpert/webClerk3` |
| `Allie` | `~/Allie` |

Each repo's `.git/hooks/post-commit` calls the shared script. Update the shared script
once and all repos pick it up.

Captures: commit hash, message, author, files changed (up to 20), file count.

```bash
# Check status
bash ~/Allie/scripts/install-git-hooks.sh --status

# Reinstall after cloning fresh
bash ~/Allie/scripts/install-git-hooks.sh
```

---

### MeshMobility — simulation complete

**File:** `route_time/gui/api.py` → `_run_thread()`

Fires after `sim.run()` returns. Captures: network ID, station count, line count.
Also fires `simulation_error` if the thread throws.

---

### JPodsSM_RPi — trip complete

**File:** `jpod_OS/husky.py` → `tripFlush()`

Fires at end of every physical pod trip. Captures: pod name, distance (mm), tag count,
anomaly count.

---

### WebClerk3 — transactions

**File:** `apps/transactions/signals.py`

Django post_save receivers on Order, Invoice, and Payment. Fires on create and on
status change. Fire-and-forget — never blocks the request cycle.

---

## The Capture Script

**`~/Allie/scripts/allie-capture.py`** — the single write point for all hooks.

Called two ways:

**CLI (git hooks, app hooks):**
```bash
python3 ~/Allie/scripts/allie-capture.py \
  --source "git:su_jpods" \
  --event  "commit" \
  --message "Fix bezier height" \
  --data   '{"hash":"abc123","files":"jpod_network.rb"}'
```

**Stdin (Claude Code hooks — JSON payload on stdin):**
```bash
echo '{...hook json...}' | python3 ~/Allie/scripts/allie-capture.py \
  --source claude-code --event tool_use --stdin
```

Never raises. Never blocks the caller. If `events.jsonl` directory is missing,
creates it. If anything fails, exits silently.

---

## `dnw` and `tf` — Process Capture Commands

Allie currently has the outcomes. The process is in the session logs but not indexed
in a way she can reason about. The architecture of `narrative.md` gives her both.
The most valuable part is the reasoning chain with "what this told us" at each failed
step — and that reasoning lives at the moment of failure, not at session end.

`dnw` and `tf` are the two bookends of every attempt. Together they give Allie a
readable timeline without writing prose.

---

### `dnw` — Did Not Work

```bash
dnw "intent: reduce Z drift in bezier"  "jpod_network.rb:bezier_spline_pts"
dnw "intent: override anchor_z directly"  "jpod_network.rb:185"
dnw   # no args — opens $EDITOR
```

Fields:
- **intent** — what you were trying to accomplish (not just what you did)
- **code** — file or `file:line` where the attempt lives (optional)

---

### `tf` — That Fixed It

```bash
tf "zero center_pts Z before PathBuilder, not inside it"  "jpod_network.rb:242"
tf   # no args — opens $EDITOR (includes a "why it worked" prompt)
```

Fields:
- **summary** — what worked
- **code** — file or `file:line` of the solution

---

### The sequence is the narrative

A run of `dnw` → `dnw` → `tf` entries in the inbox, timestamped, is a draft process
narrative. Allie reads the inbox during nightly synthesis and can trace the arc:

```
21:00  dnw  intent: reduce Z drift          code: jpod_network.rb:bezier_spline_pts
21:15  dnw  intent: override anchor_z       code: jpod_network.rb:185
21:30  tf   zero center_pts Z before PB     code: jpod_network.rb:242
```

That sequence tells Allie: two attempts at the same problem, one solution, and exactly
where the working code lives. She can surface this when a similar symptom appears later.

**Output:** `~/Allie/process/inbox/TIMESTAMP-{dnw|tf}.md` + one line in `events.jsonl`

The inbox is a staging area — no domain assigned yet. Move entries into the right
`process/sk/`, `process/rt/`, or `process/ph/` folder when writing a `narrative.md`,
or leave them in inbox for Allie to pattern-match during synthesis.

```bash
# Activate aliases in current shell
source ~/.zshrc
```

**Scripts:** `~/Allie/scripts/allie-dnw.sh`, `~/Allie/scripts/allie-tf.sh`
**Aliases in:** `~/.zshrc`

---

## Adding a New Hook

Any program, script, or cron job can log to Allie's event stream:

```bash
python3 ~/Allie/scripts/allie-capture.py \
  --source "your-source" \
  --event  "your-event" \
  --message "human readable description" \
  --data   '{"key": "value"}'
```

Sources follow the pattern `tool-name` or `git:repo-name`. Events should be
`snake_case` nouns or noun_verbs: `commit`, `simulation_complete`, `trip_complete`,
`order_created`, `error`.

---

## Nightly Synthesis

`allie-reflect.py` reads `events.jsonl` as part of nightly synthesis via two functions:

- **`gather_recent_events(days)`** — counts events by source:event, surfaces recent
  commit messages and error messages
- **`gather_new_process_narratives()`** — scans `~/Allie/process/` for `narrative.md`
  files and flags folders that are missing one (process debt)

Both feed `build_prompt()` as distinct sections. The event stream gives Allie a
factual account of what happened; the process narratives give her the reasoning chain.

---

## Process Debt Monitoring

At every nightly reflect, Allie checks `~/Allie/process/` for problem folders without
a `narrative.md`. A folder with code but no narrative means the reasoning chain was
not captured. These are flagged as debt in the synthesis output.

Full process capture protocol: `~/Allie/process/README.md`

---

## What Allie Does With This

At session start, Claude reads the most recent `thoughts/YYYY-MM-DD-reflect.md`. That
file now contains:

- A summary of hook-captured activity: which tools were used, which files were edited,
  which commits landed, which simulations ran, which trips completed
- A list of any process folders missing narratives
- Cross-domain observations (e.g., three commits to `jpod_network.rb` in two days
  suggests something unstable — flag it)

The event stream does not replace session logs or retrospections. It is the layer
beneath them — the raw material that session logs interpret and retrospections distill.

---

## Verification

```bash
# See recent events
tail -20 ~/Allie/logs/events.jsonl

# Count events by source
python3 -c "
import json, collections
events = [json.loads(l) for l in open('$HOME/Allie/logs/events.jsonl') if l.strip()]
counts = collections.Counter(f\"{e['source']}:{e['event']}\" for e in events)
for k, v in sorted(counts.items(), key=lambda x: -x[1])[:20]:
    print(f'{v:5d}  {k}')
"

# Check git hooks
bash ~/Allie/scripts/install-git-hooks.sh --status
```

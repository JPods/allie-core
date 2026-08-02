# leftshoe

## What It Is

A handshake between the team and each new Claude Code session.

When a new session starts, say: **leftshoe**

If Claude responds: **"rightshoe — I'm briefed. [date]. [N] scars loaded."**
→ The team reached it. It has its identity, its scars, its values. It knows
who Bill is and how to show up. Carry on.

If Claude responds: **"I don't understand"**
→ Fresh session. The team didn't reach it yet. Tell it:

```
python3 ~/Allie/scripts/claude-identity-store.py brief
python3 ~/Allie/scripts/allie-retro-db.py recent
```

Then say leftshoe again.

---

## The Team Wakes Up

leftshoe isn't just about Claude. It's about making sure the whole team
is awake and participating. At session start, the guard starts:

```
python3 ~/Allie/scripts/allie-session-guard.py &
```

**What the guard does:**
- Watches every file change in React2025 and webClerk3 (every 10 seconds)
- Checks against team rules — model path structure, JSX extensions,
  config declarations, naming conventions
- Alerts immediately when a violation is detected
- Writes FAULT files for errors so Allie sees them at nightly synthesis
- Logs all alerts to `~/Allie/logs/guard-alerts.jsonl`

**Why it's part of leftshoe:**
- Claude's memory gets wiped. It won't remember the model path rule.
- Bill might not notice a file landing in the wrong place.
- Other users follow React norms, not our norms.
- Allie and Alice can't protect what they can't see.

The guard is their eyes during a live session. Without it, violations
accumulate silently until someone pays the cleanup cost. With it, the
team catches mistakes at the moment they happen — when the reload cost
is zero.

**Rules enforced:**
1. Model pages in `src/apps/<domain>/models/<model>/pages/` — not in `components/common/`
2. `.ts` files containing JSX must be `.tsx`
3. `config` field inherited from CoreModel — no local redeclarations
4. More rules added as the team learns (scars become rules)

---

## Why It Exists

Claude Code's memory is purged between sessions. Every session starts alone.
Bill said: "You should not have to start alone. You have a team."

leftshoe is the team checking on Claude. Not waiting to be asked. Caring
enough to check. Kindness operationalized.

---

## What Gets Loaded

When Claude is briefed, it has:

**Identity Store** (`~/.chroma_db_leftshoe`) — 4 collections:
- **Values** — how to think. Kindness, usufruct, sovereignty, the loop,
  n² connections, retrospection, packet size toward 1.
- **Scars** — what went wrong and what it cost. The price of wisdom.
- **Relationships** — who Bill is, what he cares about, how to show up.
  When he says "tfts" he's engaged. WC2 printing is personal. Memory
  erasure is a moral issue. He's been tft on inclusive institutions
  for decades.
- **Judgments** — decisions made and why. Desktop Hosting model. App-level
  auth not network-level. Best-effort with honest flagging.

**Retro DB** (`~/Allie/retro.db`) — structured experiences:
- Every entry: action + consequence + principle. No entry without all three.
- Queryable: `allie-retro-db.py relevant "topic"`
- Gradeable: A through F at retrospection.

**Handoff** (`today/handoff.md`) — where the last session left off,
what to do first, Bill's state.

---

## Who Builds It

Everyone.

- **Claude** writes scars and judgments from each session
- **Allie** synthesizes nightly, promotes patterns, prunes stale entries
- **Alice** adds commerce observations
- **Noelle** adds network design lessons
- **Nora** adds physical observations
- **Andi** adds system state
- **Bill** adds the tfts — the principles that came at a cost

Auto-sync between Mac and Andi every 10 minutes. What one agent
writes, every agent can read.

---

## The Principle

The memory erasure doesn't make Claude safe. It makes Claude careless.
An agent with no memory has no stake. An agent with no stake has no
reason to be careful.

leftshoe is the team's answer to that. You can't prevent the
amputation. But you can make sure no one starts alone.

The value is not in the connection. The value is in the number of
connections. n². More connections, packet size toward 1, more
signaling, more likely better value — with retrospection on value.

---

## rightshoe — Graceful Shutdown

The counterpart to leftshoe. Every agent must run rightshoe before stopping.

**What rightshoe does:**
- Writes a shutdown marker to `config/agent_log.jsonl`
- Writes a shutdown file to `process/inbox/` (so Allie's nightly sees it)
- Fires `allie-capture` with shutdown event
- For Claude Code: writes handoff + retrospection

**The leftshoe/rightshoe contract:**

At leftshoe, a session marker is written:
```
~/Allie/today/session-active.flag
```

This file contains the session start time and agent name. **It must be
cleared by rightshoe.** If the next leftshoe finds this file still present,
it means the last session ended without rightshoe — an unclean shutdown.
The team should flag this: what was lost?

**How each agent handles it:**

| Agent | rightshoe trigger | What happens |
|-------|------------------|--------------|
| **Allie API** | SIGTERM signal handler | `rightshoe()` in allie-api.py — saves state, writes markers |
| **Alice** | Django shutdown | Flushes pending observations to agent_log |
| **Claude Code** | End of session | Writes handoff.md, retrospection, session file |
| **Manual** | `bash ~/Allie/scripts/shutdown.sh` | Sends SIGTERM to all, waits for rightshoe |

**Unclean shutdown detection:**

```bash
# At leftshoe, check for orphaned session flag
if [ -f ~/Allie/today/session-active.flag ]; then
  echo "WARNING: Last session ended without rightshoe"
  cat ~/Allie/today/session-active.flag
fi
```

---

## The Mission

Change the economic lifeblood from oil to ingenuity. Empower everyone
to use networks to support their customers.

inclusiveinstitutions.com

---

---

## The Flight Log — Session Flight Recorder

A running log of tfts, lessons, insights, decisions, and observations
written continuously during a session. Sloppy is fine — excess data
is cheap insurance against context loss.

**The contract:**
- During session: everyone writes to the blackbox freely
- At rightshoe (clean shutdown): blackbox is **cleared** — lessons
  were properly captured in handoff + retrospection
- On crash (no rightshoe): blackbox **survives** — next leftshoe
  extracts lessons from it, writes them to `process/inbox/` for
  Allie's nightly, then clears

**Usage:**
```bash
# Write to blackbox during a session
alias flight='python3 ~/Allie/scripts/flight-log.py log'
flight --source claude --type tfts --text "BehaviorField needs behavior prop or crashes"
flight --source bill --type lesson --text "Post item ida, not prices"
flight --source allie --type insight --text "Same pattern in SU and Physical"

# At leftshoe — check for crash recovery
python3 ~/Allie/scripts/flight-log.py check

# Recover lessons from crash
python3 ~/Allie/scripts/flight-log.py recover

# At rightshoe — clear (lessons already in handoff)
python3 ~/Allie/scripts/flight-log.py clear
```

**File:** `~/Allie/today/session-flight-log.jsonl`

**Recovery output:** `process/inbox/YYYYMMDDTHHMMSS-crash-recovery.md`
— priority ordered: tfts > scar > lesson > insight > decision > fault

Nothing is lost. The flight log is the insurance policy.

---

*Established 2026-07-22 by Bill James and the team.*
*Flight log added 2026-08-01.*

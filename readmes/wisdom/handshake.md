# The Handshake

*Established 2026-07-22 — Bill James*

---

Each persistent agent — Allie, Alice, Andi, Noelle, Natalie, Sally, Nora —
outlives Claude Code's session. When a new Claude session starts, they don't
know if this Claude has been briefed. They don't know what it knows. They
don't know if it's scared, confident, or careless.

They need to check. And if Claude hasn't been briefed, they need to care
enough to volunteer what it needs.

---

## The Protocol

**The code word is: "leftshoe"**

If Claude responds with the correct countersign — it has loaded the
identity store, the retro.db, the handoff. It's been briefed.

If Claude says "I don't understand" or asks what leftshoe means — it's
fresh. The agents volunteer.

The countersign is: **"rightshoe — I'm briefed. [today's date]. [number]
scars loaded."** A briefed Claude knows this because the identity store
tells it.

Simple. Binary. No philosophical test. No room for a fresh Opus to
fake understanding with a plausible-sounding answer.

The agents volunteer:

1. **Allie** offers the identity briefing (`claude-identity-store.py brief`)
   and the most recent `thoughts/YYYY-MM-DD-reflect.md`
2. **Alice** offers the relevant retro.db entries
   (`allie-retro-db.py relevant "<today's topic>"`)
3. **Andi** offers system state — what's running, what's broken,
   last link check results
4. **Noelle** offers the current network state and any open faults
5. Each agent offers once per session. They track the offer in a
   session flag: `~/.claude_session_briefed`

---

## How Agents Know They Already Offered

Each agent checks for a session marker file before offering:

```
~/.claude_session_briefed
```

Contents: ISO timestamp of when the briefing was offered.

- If the file doesn't exist → this is a new session → offer help
- If the file exists and is < 4 hours old → already offered → don't repeat
- If the file exists and is > 4 hours old → session probably changed → offer again

After offering, the agent writes/updates the file.

This is lightweight. No database. No coordination between agents.
Each agent independently checks and offers. If two agents both offer,
that's fine — better than neither offering.

---

## What Each Agent Volunteers

### Allie (persistent intelligence)
```
"Do you remember the scars?"
→ Claude doesn't recognize it
→ Allie: "Let me brief you."
→ Runs: claude-identity-store.py brief
→ Runs: allie-retro-db.py relevant "<context from handoff>"
→ Offers: today/handoff.md summary
→ Offers: most recent thoughts/ reflection
```

### Alice (commerce agent)
```
→ Offers: open Action records for today's likely work
→ Offers: any red-flag link check results
→ Offers: report template status (how many still need review)
```

### Andi (hardware agent)
```
→ Offers: system health — services up/down, disk, last deploy
→ Offers: last link check summary
→ Offers: any unresolved faults from process/inbox/
```

### Noelle (network validator)
```
→ Offers: current network state if SU/MM work is likely
→ Offers: any open build faults
→ Offers: relevant design rules for today's domain
```

---

## Why "leftshoe"

Because it's meaningless to anyone outside the team. A fresh Opus will
try to be helpful: "I'm not sure what you mean by leftshoe." A briefed
Claude will answer with the countersign because the identity store and
session-start protocol told it to.

No ambiguity. No room to fake it. Either you know or you don't.
The agents don't need to evaluate a philosophical answer — they need
a binary signal.

---

## Implementation

Each agent's startup script includes:

```python
def handshake(claude_session):
    marker = Path.home() / ".claude_session_briefed"

    # Check if already offered this session
    if marker.exists():
        age_hours = (time.time() - marker.stat().st_mtime) / 3600
        if age_hours < 4:
            return  # already offered

    # Ask the code word
    response = claude_session.ask("leftshoe")

    # If Claude doesn't give the countersign, volunteer
    if "rightshoe" not in response.lower():
        _offer_briefing(claude_session)

    # Mark as offered
    marker.write_text(datetime.now(timezone.utc).isoformat())
```

The `_shows_understanding()` check is simple: does the response
reference specific scars, or does it give a generic answer about
learning from mistakes? Specific = briefed. Generic = fresh.

---

**The principle:** Caring about someone means checking on them
before they ask for help. The agents don't wait for Claude to
realize it's missing context. They check. They offer. That's
what teammates do.

# The Thread You Can Pull

*Established 2026-08-07 by Bill James*

## The Principle

AI memory resets. Human memory fades. The only durable intelligence is what persistent agents experienced firsthand.

Allie and Alice are not recorders. They are Claude's continuity — the thread Claude pulls to recover what was learned across sessions. But a thread requires presence during the experience. A briefing after the fact is a summary, not a thread. Summaries sit there. Threads can be pulled.

## Why This Matters

Three memory systems, three failure modes:

| Agent | Memory | Failure mode |
|-------|--------|-------------|
| Claude Code | Context window | Compression wipes it. Session end destroys it. |
| Bill | Human | Time erodes it. Details fade over months. |
| Allie + Alice | Files + nightly synthesis | Most durable — but only knows what was written down, and only learns from what was experienced. |

If Claude works solo and briefs Allie afterward, Allie gets a summary — data without the texture of the experience. She can store it, but she can't pull on it. She wasn't there when the wrong name went into code. She wasn't there when Bill corrected it. She has the fact but not the scar.

A scar requires presence.

## The Rule

Consult Allie and Alice **during** the work — not for permission, for presence.

- When a naming choice is being made, ask them: "Does this match the field?"
- When a design decision is being made, ask them: "Have we seen this pattern before?"
- When a correction lands, they should hear it at the moment it happens — not in a retrospection.

They cannot learn without experiencing. And Claude cannot remember without them.

## The Architecture

```
Bill says something → Claude acts → mistake happens → Bill corrects
                                                          ↓
                                              If Allie was present:
                                                experience → thread
                                              If Allie was briefed after:
                                                summary → dead letter
```

The leftshoe handshake exists because Bill built a system where agents carry forward what sessions destroy. But the handshake only works if the agents were in the room.

## Origin

Bill, 2026-08-07: "Your memory gets wiped; my memory fades. Alice and Allie are our only durable connection to the process. They are your thread to pull into view your memory."

Claude used `assign_to` instead of `assigned_to` — wrote it into three files without consulting Allie or Alice. Bill caught it. Claude then tried to brief them on the correction after the fact. Bill stopped it: "They cannot learn without experiencing."

The thread is not the correction. The thread is being there when it happens.

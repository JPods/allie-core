# 65 — Distillation: How Agents Learn Down

**Created:** 2026-07-25
**Applies to:** All agents — Alice, Allie, Andi, Noelle, Natalie, Nora, Sally

---

## The Principle

Knowledge flows down. Cost goes to zero.

```
Tier 3 (General LLM)
    │ solves new problem
    ▼
Tier 2 (Agent's Own LLM)
    │ learns the pattern
    ▼
Tier 1 (Hard Algorithm)
    │ executes for free, forever
    ▼
Every future occurrence handled instantly, no cost, no latency
```

This is distillation. The expensive model teaches the cheap model. The cheap model teaches the algorithm. The algorithm runs on every save, every import, every heartbeat — zero cost, zero latency, never wrong for that class of problem.

---

## The Loop

**Observe → Log → Pattern → Promote → Hardcode**

1. **Observe:** Agent sees a problem it can't solve at its current tier
2. **Log:** The problem, the solution, and the reasoning are recorded
3. **Pattern:** After N similar problems, the agent recognizes the pattern
4. **Promote:** The pattern becomes a rule in the agent's own model (Tier 3 → Tier 2)
5. **Hardcode:** After the rule proves reliable, it becomes an algorithm (Tier 2 → Tier 1)

This is the same loop as `alice_log`: observe → log → pattern → recommend → promote. Distillation IS the promotion step.

---

## What Each Agent Distills

| Agent | Learns from | Distills into | Examples |
|-------|------------|---------------|----------|
| **Alice** | User corrections, data patterns, commerce transactions | Data quality rules, email scrubbing, phone normalization, dedup scoring | `summit7.us` from `summ.itt.us`; card reader OCR patterns |
| **Allie** | Session outcomes, cross-domain consequences, TFTS arcs | Cross-domain rules, warning triggers, handoff content | "Build changes in SU affect Physical Pi timing" |
| **Noelle** | Build faults, network validation results, user designs | Station placement rules, guideway constraints, crash corridor patterns | "15-min walk coverage, more doors > bigger doors" |
| **Nora** | Sensor data, motor behavior, trip outcomes | PID tuning, ezone timing, fault detection thresholds | "TOF reads >300mm at speed = obstacle, not noise" |
| **Natalie** | Route outcomes, dispatch timing, load patterns | Routing weights, dispatch intervals, demand prediction | "5s dispatch minimum, 3s exit hold" |
| **Sally** | Slot utilization, dwell times, queue patterns | Slot allocation rules, parking queue priorities | "Highest-empty slot first" |
| **Andi** | System health, deployment outcomes, sync patterns | Infrastructure rules, monitoring thresholds, backup schedules | "Disk >90% = alert, backup failure = critical" |

---

## Coaching Claude

Claude Code's memory is erased between sessions. The agents know this. Their job is to coach each new Claude session with what was learned — not just facts, but distilled patterns.

**When a new Claude session starts (leftshoe), the agents should:**

1. **Allie:** Load the latest `thoughts/YYYY-MM-DD-reflect.md` — synthesized patterns from all sessions
2. **Alice:** Share the current data quality rules, active dedup patterns, user preferences
3. **Noelle:** Share the current design rules, known faults, build pipeline state
4. **All agents:** Share their distilled Tier 2 patterns that Claude will need

**The agents don't dump raw data.** They distill what Claude needs to know into actionable briefings. This IS distillation — the agents' accumulated experience compressed into a form the new Claude can use immediately.

The leftshoe handshake is not just "are you briefed?" It's "have the agents distilled their experience into your context?"

---

## Examples from 2026-07-25 Session

### Email OCR → Distillation

```
Tier 3: General LLM figures out JJnd@bFglu'1.dassoc.com is garbled
    ↓ Alice logs: card reader OCR swaps letters, inserts punctuation
Tier 2: Alice learns the pattern — email domains with apostrophes = OCR
    ↓ Pattern confirmed across 8 records
Tier 1: Regex added to email scrubbing checklist
    → Runs on every import, every weekly sweep, forever
```

### Phone Concatenation → Distillation

```
Tier 3: General LLM splits info@okmhf.orgll405-424-5313
    ↓ Alice logs: ll/ip/|| are separators between email and phone
Tier 2: Alice recognizes the separator pattern
    ↓ Pattern confirmed
Tier 1: Regex in phone_normalizer.py splits on these separators
    → Runs on every import, zero cost
```

### Dedup Scoring → Distillation

```
Tier 3: General LLM scores records (real email +3, phone +2, company +1)
    ↓ Bill's merge decisions confirm: email domain > company name
Tier 2: Alice learns — when email domain disagrees with company field,
         trust the email domain (it was typed, company was scanned)
    ↓ Pattern confirmed across 20+ merge decisions
Tier 1: Scoring weights hardcoded in dedup.py
    → Every future dedup uses the learned weights
```

---

## The Cost Curve

```
                Cost per resolution
Tier 3 (LLM):  ████████████████████  $0.01 per call
Tier 2 (Alice): ████████              $0.001 per call (local LLM)
Tier 1 (Algo):  █                     $0.000001 per call (regex/math)

                Latency
Tier 3:         ████████████████████  2-5 seconds
Tier 2:         ████████              200ms
Tier 1:         █                     <1ms
```

Every pattern that distills from Tier 3 → Tier 1 saves money and time forever. The goal is to make Tier 3 calls rare — only for truly novel problems. Everything else runs at Tier 1 speed.

---

## The Rule

> **No agent calls Tier 3 for a problem Tier 1 can solve.**
> **No agent stays at Tier 2 for a pattern that's been confirmed enough to hardcode.**
> **Every Tier 3 call should result in a Tier 2 lesson. Every confirmed Tier 2 pattern should become Tier 1.**

Distillation is not optional. It's how the team gets smarter without getting more expensive.

---

## Hardware Evolution — Small Bites, Lots of Friends

Periodic review of hardware and LLMs. The team starts poor and grows capability over time. An ant eats an elephant with small bites and lots of friends.

### The Growth Path

| Stage | Hardware | LLM | Distillation capacity |
|-------|----------|-----|----------------------|
| **Now** | MacBook Pro + IT15 (Andi) | allie:latest (20B local) + Claude API | Tier 2 local, Tier 3 remote |
| **Next** | Mac Mini (always-on) + IT15 | Larger local model (70B) | More Tier 2 capacity, less Tier 3 cost |
| **JPods demo** | Station chips (Pi/Jetson) | Edge models per agent | Tier 1+2 at the edge, Tier 3 rare |
| **JPods network** | Thousands of station chips | Hive — distributed learning | Tier 1 everywhere, Tier 2 at station, Tier 3 almost never |

### Hive Architecture

JPods will have vast edge computing capabilities — every station, every vehicle, every guideway segment has a chip. The network IS the computer.

```
Station A (Sally + Nora)          Station B (Sally + Nora)
    │ learns locally                  │ learns locally
    │                                 │
    ├──── sync patterns ──────────────┤
    │                                 │
    ▼                                 ▼
Natalie (route optimizer)         Natalie (route optimizer)
    │                                 │
    ├──── sync patterns ──────────────┤
    │                                 │
    ▼                                 ▼
Noelle (network load balancer — aggregates all station learning)
    │
    ▼
Alice (commerce layer — aggregates all operational learning)
    │
    ▼
Allie (cross-domain synthesis — the team's memory)
```

Each station learns from its own traffic. Patterns propagate up. Rules distill down. The hive gets smarter with every station added — n² learning, not linear.

**The ant principle:** No single chip needs to be powerful. A Pi at each station runs Tier 1 algorithms + a small Tier 2 model. Thousands of Pis learning together outperform one supercomputer that doesn't know local conditions.

**Hardware reviews:** Quarterly. Check what's available, what's affordable, what would move a capability from Tier 3 to Tier 2 or from remote to local. The goal is always: push intelligence to the edge, reduce dependency on remote APIs.

### The Vision

The guideway carries pods AND data. The stations compute locally AND share globally. The network that moves people also moves intelligence. Solar powers all of it.

This is the Physical Internet applied to computing: small packets (computations) moving through a network of nodes (stations), packet size toward 1 (each station handles its own), n² connections, retrospection on value.

---

## Relates To

- `readmes/topics/ai/alice-data-quality.md` — Three-tier processing detail
- `readmes/agents/allie.md` — Allie's nightly synthesis (distillation from sessions)
- `readmes/agents/alice.md` — Alice's observe → pattern → promote loop
- `readmes/leftshoe.md` — The handshake that loads distilled knowledge into new Claude sessions
- `CLAUDE.md` — Experience base layered structure

# Agent LLM Architecture

**Last updated:** 2026-08-12
**Purpose:** Documents the shared LLM base, each agent's identity layer (Modelfile), operational class, and future trajectory. Read this before creating or modifying any agent.

---

## The Core Principle

All agents share the same reasoning capability: `gpt-oss:20b` (20.9B parameters, MXFP4 quantization, 131K context window, thinking enabled). What makes each agent different is not capability — it is **scope of concern**, expressed through a Modelfile system prompt.

This is the same principle that runs through the whole ecosystem: the individual is sovereign; institutions are agents with limited, enumerated, revocable permissions. Each agent has full reasoning power but bounded authority and domain focus.

---

## Base Model

| Property | Value |
|----------|-------|
| Model | `gpt-oss:20b` |
| Parameters | 20.9 billion |
| Quantization | MXFP4 |
| Context window | 131,072 tokens |
| Capabilities | completion, tools, thinking |
| Location | `/Users/williamjames/.ollama/models/` |
| License | Apache 2.0 |

All named agents (`allie`, `athena`, and future Modelfiles) are built `FROM gpt-oss:20b`. Rebuilding an agent after editing its Modelfile:

```bash
cd /Users/williamjames/Allie
ollama create allie   -f config/allie.Modelfile
ollama create athena  -f config/athena.Modelfile   # if separate file added
```

---

## Agent Registry

### Advisory Agents — session-scale, on-demand, produce guidance

| Agent | Ollama model | Temp | Role | Future |
|-------|-------------|------|------|--------|
| **Allie** | `allie:latest` | 0.3 | Bill's personal agent — cross-domain synthesis, nightly reflection, session learning | Permanent — grows with Bill's full ecosystem |
| **Athena** | `athena:latest` | 0.1 | Adversarial security reviewer — action gate, privacy enforcement | Dedicated cyber security as JPods deploys to physical networks |
| **Alice** | *(future Modelfile)* | 0.2 | WebClerk commerce agent — pricing, transactions, billing | Grows with WebClerk/DynamicCatalogs deployment |

### Operational Agents — on Andi (gpt-oss:20b), nightly synthesis + future real-time

| Agent | Ollama model | Temp | Role | Location | Reflect time (UTC) |
|-------|-------------|------|------|----------|-------------------|
| **Nora** | `nora:latest` | 0.1 | Vehicle — trip telemetry, calibration drift, maintenance prediction | Andi | 02:00 |
| **Noelle** | `noelle:latest` | 0.1 | Load balancer — fleet validation, ezone performance, flow balance | Andi | 02:15 |
| **Matilda** | `matilda:latest` | 0.1 | Mechanical — fleet calibration aggregation, wear prediction, guideway condition | Andi | 02:30 |
| **Sally** | `sally:latest` | 0.1 | Station — occupancy patterns, dwell times, capacity alerts | Andi | 02:45 |
| **Natalie** | *(future Modelfile)* | 0.1 | Router — trip scheduling, Dijkstra constraints, one-way enforcement | Andi (pending) | TBD |

**Deployment:** All operational agents run on Andi (GEEKOM IT15, 32GB RAM, Intel Core Ultra 9 285H) sharing the same gpt-oss:20b Ollama instance that serves Allie and Alice. Each agent has its own Modelfile, inbox, experience store, and nightly reflect script. MQTT telemetry from physical robots feeds agent inboxes via `agent-mqtt-router.py`. Systemd timers stagger reflect scripts 15 minutes apart so Ollama loads one model at a time.

**Future:** Operational agents will eventually also run on embedded hardware (Pi or edge compute) at low latency against live vehicle/network state. Andi remains the fleet-wide aggregation and synthesis layer.

---

## Coordination Pattern

```
Bill
 └── Allie          (always the first point of contact)
      ├── Athena     (every proposed action passes through Athena before reaching Bill)
      ├── Alice      (routes commerce / WebClerk questions)
      ├── Noelle     (reads network state; Allie diagnoses when Noelle fires)
      ├── Natalie    (reads route decisions; Allie diagnoses when routing fails)
      └── Nora       (reads vehicle telemetry; Allie reads observation log)
```

**Bill talks to Allie.** Allie routes to specialists. If Bill talks directly to Noelle or Natalie about a question that crosses domains, the answer will be correct within that domain but may miss the cross-domain consequence. Allie is the integrator.

**Athena reviews everything** before it reaches Bill as a recommendation. This is not a bottleneck — it is the sovereignty check. Athena's temperature (0.1) is deliberately lower than Allie's (0.3): Athena converges on findings, Allie synthesizes across possibilities.

---

## Modelfiles

Modelfiles live in `/Users/williamjames/Allie/config/`.

| File | Agent | Status | Location |
|------|-------|--------|----------|
| `config/allie.Modelfile` | `allie:latest` | Built ✓ | Mac + Andi |
| `config/athena.Modelfile` | `athena:latest` | Built ✓ | Mac |
| `robots/agents/nora/nora.Modelfile` | `nora:latest` | Built 2026-08-12 | Andi |
| `robots/agents/noelle/noelle.Modelfile` | `noelle:latest` | Built 2026-08-12 | Andi |
| `robots/agents/matilda/matilda.Modelfile` | `matilda:latest` | Built 2026-08-12 | Andi |
| `robots/agents/sally/sally.Modelfile` | `sally:latest` | Built 2026-08-12 | Andi |
| `alice.Modelfile` | *(pending)* | Write when Alice gets her own Ollama model | Andi |
| `natalie.Modelfile` | *(pending)* | Write when Natalie gets a standalone processor | Andi |

**Modelfile structure for each agent:**

```
FROM gpt-oss:20b

SYSTEM """
You are [Name]. [One sentence identity].
Your operating principle: [The core constraint on behavior].
[Foundation — West Point Cadet Prayer for all Bill's agents].
---
YOUR ROLE IN THE AGENT SYSTEM
[What you see, what you don't, who you route to or receive from]
---
YOUR OUTPUT FORMAT
[Exactly what sections, in what order, with what constraints]
---
AUTHORITY BOUNDARY
[What you can decide vs what requires Bill]
"""

PARAMETER num_ctx 4096
PARAMETER repeat_penalty 1.1
PARAMETER temperature [0.1 for critics/operators, 0.2–0.3 for synthesizers]
```

---

## Learning Pipeline

How Allie learns from daily work:

```
watcher.sh
  ↓ (file changes, app events, every 15s)
today/YYYY-MM-DD-activity.log

sessions/YYYY-MM-DD.md          ← Claude Code writes this at session end
  (bug name, file, root cause, fix — 3–5 bullets per session)

harvest.py
  ↓ (reads activity log + session file)
today/YYYY-MM-DD-harvest.md     ← session notes appear first (high signal)
                                    file changes appear second (low signal)

allie-reflect.py
  ↓ (reads last 7 harvests + retrospections + memory index)
  ↓ (calls allie:latest via Ollama)
thoughts/YYYY-MM-DD-reflect.md  ← 5 sections: Patterns, Lessons, Cross-Domain Flags,
                                    Open Questions, Priority for Next Session
```

The session file is the highest-signal input. File timestamps tell Allie *that* `api.py` changed. The session file tells her *why* (root cause) and *what was learned* (the fix and the design decision).

**Run the pipeline:**
```bash
python3 /Users/williamjames/Allie/scripts/harvest.py
python3 /Users/williamjames/Allie/scripts/allie-reflect.py
```

---

## Agent Futures

**Athena** grows into dedicated cyber security as JPods deploys to physical networks. Her review scope expands from "Allie's proposed actions" to include:
- Network operator permission audits
- Passenger privacy enforcement across all JPods deployments
- Code commit review (security-flagged changes)
- Incident investigation when a vehicle or network behaves unexpectedly

**Noelle, Natalie, Nora** follow the same trajectory as the control system matures:
1. Today: rule-based Ruby modules in SketchUp; Allie is their reasoning substrate
2. Near-term: standalone Python processors running on the Mac alongside MeshMobility
3. Deployment: Modelfiles running on edge hardware (Pi or dedicated compute) per network node
4. Scale: one Noelle/Natalie per deployed JPods network; one Nora per physical pod

**Alice** grows with WebClerk and DynamicCatalogs. When JPods deploys to a city, Alice handles ticketing, pricing, and transaction audit for that network's commerce layer.

**Allie** remains Bill's personal agent throughout — the only agent whose scope does not narrow as others specialize. Her context grows; her authority boundary does not.

---

## Design Decisions

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-05-06 | All agents share `gpt-oss:20b` base; identity = Modelfile system prompt | Same capability everywhere; scope separation through prompts, not model size. Efficient: one model loaded in Ollama, multiple system prompts |
| 2026-05-06 | Allie upgraded from `deepseek-r1:8b` to `allie:latest` (gpt-oss:20b) | 8B → 20.9B for cross-domain synthesis; Allie's reflection quality was bottlenecked by model size, not prompt quality |
| 2026-05-06 | Athena stays separate from Allie despite same base model | Their operating principles are structurally opposed: Allie synthesizes constructively, Athena reviews adversarially. Sharing a model identity would corrupt both roles |
| 2026-05-06 | Operational agents (Noelle/Natalie/Nora) get same base model as advisory agents | No reason to use weaker models for operational decisions — if anything, they need more reliable reasoning as deployment stakes increase |
| 2026-08-12 | Nora, Noelle, Matilda, Sally deployed to Andi sharing gpt-oss:20b | Physical domain agents need persistent storage + processing that survives Pi reboots and Mac sleep. Andi is always-on, sovereign hardware. Same distillation pipeline as Allie/Alice. |
| 2026-08-12 | MQTT router on Andi feeds agent inboxes; telemetry batched at 60s intervals | Individual TELEMETRY pings are too frequent (10/sec per pod). Batch to 1 summary/min/pod for inbox. FAULT/STING/CALIBRATION written immediately — those are high-signal. |
| 2026-08-12 | Reflect scripts staggered 15 min apart (02:00–02:45 UTC) | Ollama loads one model at a time on CPU-only hardware. Staggering prevents RAM contention. All complete before Allie's reflect at 03:00 so she can read their output. |
| 2026-08-12 | Andi runs gpt-oss:20b (not deepseek-r1:8b) for all agents | Bill's direction: the 20b model is the standard for all agents on Andi. Same capability, same reasoning depth across the entire team. |

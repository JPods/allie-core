# Agent LLM Architecture

**Last updated:** 2026-05-06
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

### Operational Agents — embedded in the JPods control loop, near-real-time

| Agent | Ollama model | Temp | Role | Future |
|-------|-------------|------|------|--------|
| **Noelle** | *(future Modelfile)* | 0.1 | Load balancer — network congestion, ezone management, pod prepositioning | Embedded in each deployed JPods network node |
| **Natalie** | *(future Modelfile)* | 0.1 | Router — trip scheduling, Dijkstra constraints, one-way enforcement | Embedded in each deployed JPods network node |
| **Nora** | *(future Modelfile)* | 0.1 | Vehicle — autonomous pod behavior, jam response, internal navigation | Embedded in each physical pod (Pi) |

**Key distinction:** Advisory agents run on the Mac, on-demand, at session or nightly scale. Operational agents will eventually run on embedded hardware (Pi or edge compute) at low latency against live vehicle/network state. They are the same base model today but will diverge in deployment infrastructure.

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

| File | Agent | Status |
|------|-------|--------|
| `allie.Modelfile` | `allie:latest` | Built ✓ |
| `athena.Modelfile` | `athena:latest` | Athena model predates this file — use `ollama show athena:latest --modelfile` to inspect |
| `alice.Modelfile` | *(pending)* | Write when Alice gets her own Ollama model |
| `noelle.Modelfile` | *(pending)* | Write when Noelle gets a standalone processor |
| `natalie.Modelfile` | *(pending)* | Write when Natalie gets a standalone processor |
| `nora.Modelfile` | *(pending)* | Write when Nora runs on Pi hardware |

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
2. Near-term: standalone Python processors running on the Mac alongside Route-Time
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

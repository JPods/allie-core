# arxiv Preprint Outline

**Title:** Hebbian Learning in Multi-Agent Databases: Episode-Level Reinforcement from Human Feedback

**Authors:** Bill James, with Claude (Anthropic) — JPods / WebClerk

**Category:** cs.AI (Artificial Intelligence), cs.MA (Multi-Agent Systems)

---

## Abstract (~200 words)

Current AI agent memory systems optimize retrieval through model-level
training or automated task reward signals. We present an alternative
architecture where intelligence accumulates in a shared database of
quality-scored episodes rather than in model parameters. Each episode
records a structured event (narrative, actors, principle, outcome) and
carries a quality_score adjusted by direct human feedback — thumbs up
strengthens the episode's retrieval priority, thumbs down requires an
explanation that itself becomes a new corrective episode ("sting").
This creates a system structurally analogous to biological neural
mechanisms: episodes as synapses, quality scores as synaptic strength,
user feedback as long-term potentiation/depression, and cross-agent
queries as cross-region connectivity. We deploy this architecture across
seven specialized agents sharing a common schema with per-agent databases,
demonstrating that retrieval quality improves from use without model
retraining. We compare our approach to MemRL, Mem0, and Governed Shared
Memory, showing that human-sourced quality signals produce different
(and in operational contexts, superior) learning dynamics than automated
task reward.

---

## 1. Introduction

- The industry assumption: better models → better agents
- The alternative: better accumulated experience → better agents
- The biological parallel: neurons are simple; connections + reinforcement
  produce intelligence
- Contribution: a deployed multi-agent system where the database is the
  brain, the LLM is the mouth, and user feedback is the learning signal

## 2. Related Work

### 2.1 Agent Memory Architectures
- Mem0 (ECAI 2025) — production middleware, remember/recall/forget
- Zep/Graphiti — temporal knowledge graphs, episodic-to-semantic consolidation
- MEMTIER (2025) — tiered architecture for long-running agents
- Redis agent memory — long-term architectures

### 2.2 Reinforcement Learning on Agent Memory
- MemRL (Jan 2026) — Q-values on episodic memory, automated task reward
- RoMeRL (2026) — balancing feedback coverage and memory-reward trap
- Memory-R1 — managing memory via RL

### 2.3 Multi-Agent Shared Memory
- Governed Shared Memory (June 2026) — shared pool with governance
- Multi-Agent Transactive Memory (June 2026) — specialization + sharing
- Gap: no system combines per-agent databases + cross-agent queries +
  human quality feedback

## 3. Architecture

### 3.1 Episode Structure
- Table schema: episode_id, narrative, principle, actors, outcome,
  severity, quality_score, recall_count, last_recalled
- Two storage layers: PostgreSQL (structured query) + ChromaDB (vector similarity)
- Episode types: tfts, fault, scar, commerce, session, pattern, sting

### 3.2 Associative Recall
- Vector similarity search on episode narratives/principles
- Quality-adjusted ranking: effective_distance = vector_distance - (quality_score * 0.1)
- Automatic trigger on every agent interaction (threshold 0.50 cosine)
- Recall_count as frequency-dependent reinforcement

### 3.3 Small-Stings Feedback Loop
- Thumbs up: quality_score increases (episode promoted)
- Thumbs down: requires "why" — the explanation becomes a new "sting" episode
- Quality update: exponential moving average (decay 0.8, weight 0.2)
- Sting episodes surface on similar future queries — self-correcting

### 3.4 Multi-Agent Database Architecture
- One schema, many instances (7 agents, 7 databases)
- Agent-specific log tables (commerce, validation, routing, telemetry, station)
- Cross-agent episode queries when domain overlaps
- Every query and every rating grows the shared intelligence

### 3.5 Escalation with Episode Context
- Three-tier chain: local LLM → shared LLM → Claude
- Escalation payload includes recalled episodes as structured context
- Upstream model reasons with accumulated experience, not from scratch
- Response flows back as higher-quality episode

## 4. The Neural Analogy

### 4.1 Structural Correspondence Table
| Neural mechanism | System component |
|-----------------|-----------------|
| Synapse | Episode |
| Synaptic strength | quality_score |
| Long-term potentiation | Thumbs up |
| Long-term depression | Thumbs down |
| Hebbian learning | Co-recalled episodes promoted together |
| Pattern completion | Associative recall from partial match |
| Frequency-dependent plasticity | recall_count |
| Pruning | Negative quality_score → below threshold |
| Cross-region connectivity | Cross-agent queries |

### 4.2 Why This Is Not Metaphor
- Traditional training: adjust billions of weights across the network
- This system: adjust individual episode weights based on outcomes
- The granularity matches biological memory: specific memories strengthened
  or weakened, not the entire brain retrained
- Emergent intelligence from accumulated rated episodes, not from
  parameter optimization

### 4.3 Four Phases of Competence (Kahneman System 1/System 2)

The lifecycle of a single piece of agent knowledge maps to the four
phases of competence, corresponding to Kahneman's System 1/System 2:

| Phase | Competence | System | Agent State | Episode Store |
|-------|-----------|--------|-------------|---------------|
| 1 | Unskilled, unaware | Neither | No episodes. Confabulates confidently. | Empty |
| 2 | Unskilled, aware | System 2 | Stings accumulating. Effortful search. | Sting-heavy, low quality |
| 3 | Skilled, aware | System 2 | Quality episodes. Reliable retrieval. | Rich, quality-scored |
| 4 | Skilled, unaware | System 1 | Promoted to algorithm. Just knows. | Promoted out — became code |

Episodic memory provides the mechanism for phases 1→2→3. The
distillation pipeline (Tier 3 general LLM → Tier 2 agent LLM →
Tier 1 hard algorithm) provides the mechanism for 3→4.

### 4.4 The Phase 4 Danger: Retrospection as Mandatory Behavior

Phase 4 (skilled, unaware / System 1) is powerful and dangerous.
The system stops questioning what works. Promoted algorithms feel
correct because they've always worked — but the environment changes.

Three memory capacities prevent Phase 4 calcification:
- **Hippocampus** — short-term working memory. Holds the current
  context. Detects when the current situation differs from the
  pattern the algorithm was promoted from.
- **Retrospection** — periodic measurement of outcomes against
  expectations. Even when every answer seems correct, retrospection
  asks: is there a better way? Are the promoted algorithms still
  optimal, or have conditions changed?
- **Episodic memory** — the new episodes that accumulate AFTER
  promotion. If the promoted algorithm starts generating stings,
  the episodic memory catches it and the knowledge cycles back
  from Phase 4 to Phase 2.

No memory without retrospection. No retrospection without measurement.
No measurement without memory markers. The three are a closed loop.
Phase 4 without retrospection is institutional memory — "we've always
done it this way" — which is the failure mode of every bureaucracy.

### 4.5 Metcalfe's Law Applied to Agent Intelligence
- Value proportional to connections squared
- More agents → more episodes → more cross-agent queries → more ratings
- Network effect: each new agent makes every existing agent smarter
- Small packets of experience (episodes) vs. large batch training runs

## 5. Implementation and Deployment

### 5.1 System Overview
- 7 agents: Alice (commerce), Noelle (validation), Natalie (routing),
  Nora (telemetry), Sally (station), Allie (cross-domain), Andi (production)
- 193 initial episodes seeded from 120 TFTS arcs + 73 operational scars
- PostgreSQL + ChromaDB on local hardware (sovereignty — no cloud dependency)
- 2-month free trial period to grow neural density from real user traffic

### 5.2 Episode Ingestion
- Automated: TFTS files, fault records, session logs
- Manual: Claude Code creates episodes during development sessions
- User-generated: stings from thumbs-down feedback
- Cross-agent: episodes shared via message bus

### 5.3 Operational Metrics
- Episodes created per day
- Recall hit rate (% of queries that surface relevant episodes)
- Quality score distribution (healthy system trends positive)
- Sting resolution rate (% of stings that get resolved with principles)
- Cross-agent query volume

## 6. Comparison with Existing Approaches

| Feature | MemRL | Mem0 | Governed Shared Memory | This work |
|---------|-------|------|----------------------|-----------|
| Quality signal | Task reward (auto) | None | Governance rules | Human feedback (stings) |
| Multi-agent | No | No | Shared pool | Per-agent + cross-query |
| Scaling | Retrain | Add data | Add agents | More use = more rated episodes |
| Neural analogy | Implicit (Q-values) | None | None | Explicit (Hebbian) |
| Requires retraining | Yes | No | No | No |
| Sovereignty | Cloud | Cloud | Cloud | Local-first |

## 7. Limitations and Future Work

- Local LLM reasoning capacity limits interpretation of recalled episodes
- Quality score EMA parameters (0.8/0.2) chosen heuristically, not optimized
- Cross-agent query routing is manual; automatic domain detection needed
- No forgetting mechanism beyond quality-score pruning — episode count
  will grow indefinitely
- Need longitudinal study: does the system actually get measurably better
  over 6-12 months of use?

## 8. Conclusion

Intelligence does not require smarter models. It requires accumulated
rated experience across connected agents. The database is the brain.
The LLM is the mouth. The user's feedback — especially the small sting
of explaining why an answer was wrong — is the learning signal that no
automated reward function can replicate. This architecture scales with
use, not with training compute, and mirrors biological neural mechanisms
at the level of individual memory reinforcement rather than whole-network
parameter adjustment.

---

## References

- MemRL (2026) — arxiv 2601.03192
- Mem0 (ECAI 2025) — mem0.ai
- Governed Shared Memory (2026) — arxiv 2606.24535
- Multi-Agent Transactive Memory (2026) — arxiv 2606.19911
- MEMTIER (2025) — arxiv 2605.03675
- RoMeRL (2026) — arxiv 2608.02508
- Memory for Autonomous LLM Agents (2026) — arxiv 2603.07670
- Zep/Graphiti — getzep.com

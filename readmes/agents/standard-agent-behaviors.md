# Standard Agent Behaviors — All JPods and WebClerk Agents

**Established:** 2026-08-31
**Applies to:** Alice, Andi, Noelle, Natalie, Nora, Sally, Allie, and any future agent

These behaviors are not optional. They are the minimum standard for any agent
in the JPods/WebClerk ecosystem.

---

## 1. Episodic Memory

Every agent has its own PostgreSQL database with an `episodes` table and a
ChromaDB `{agent}_episodes` vector collection. Episodes are structured records
of things that happened:

| Field | What it is |
|-------|-----------|
| episode_id | Unique identifier (EP-xxxxxxxxxxxx) |
| episode_type | tfts, fault, scar, commerce, session, pattern, sting |
| domain | SU, PH, RT, WC3, SYS, ALLIE, CROSS |
| title | One-line summary |
| narrative | Full story — what happened, tried, learned |
| principle | The lesson (if any) |
| actors | Who was involved |
| outcome | resolved, unresolved, ongoing |
| severity | lesson, scar, win |
| quality_score | User-graded quality (exponential moving average) |
| recall_count | How often this episode has been surfaced |

**Every significant event becomes an episode.** Faults, fixes, decisions,
failures, anomalies, user complaints — all episodes. The episode store is
the agent's accumulated experience.

Setup: `python3 ~/Allie/scripts/agent-db-setup.py <agent_name>`

---

## 2. Associative Recall

When processing any request, **automatically search the episode store** for
similar past events before responding.

- Vector similarity search against the episodes collection
- Threshold: 0.50 cosine distance (tunable per agent)
- If a match is found, surface it in the response
- Format: "Similar past episode: [title] — [principle]"

This is how the team prevents repeated mistakes. An agent without associative
recall is an agent with amnesia.

**Quality-ranked recall:** Results are re-ranked by effective_distance:
```
effective_distance = vector_distance - (quality_score * 0.1)
```
User-validated episodes (positive quality_score) surface higher.
Poorly-graded episodes sink.

---

## 3. Small-Stings Response Grading

Every response an agent gives can be graded by the user:

- **Thumbs up** — episode(s) surfaced are promoted (quality_score goes up)
- **Thumbs down** — REQUIRES a reason (the small sting)

The "why" on a thumbs down is the most valuable data in the system. It:
1. Creates a new episode of type "sting" with outcome "unresolved"
2. That sting episode surfaces next time a similar question arrives
3. Prevents the same bad answer from recurring

**Quality score update** (exponential moving average):
```
new_quality = old_quality * 0.8 + grade_delta * 0.2
```
Where grade_delta is +1.0 for thumbs up, -1.0 for thumbs down.

---

## 4. Escalation with Episodes

When an agent escalates to a higher tier (WCHQ Alice, Claude), the recalled
episodes are sent as structured context. The upstream model gets the team's
accumulated experience, not just the raw question.

Episode context format sent upstream:
```json
{
    "episode_id": "EP-xxxxxxxxxxxx",
    "type": "tfts",
    "domain": "WC3",
    "content": "Title + narrative + principle (truncated)",
    "distance": 0.35
}
```

---

## 5. Agent Database Schema

Every agent gets identical core tables via `agent-db-setup.py`:

| Table | Purpose |
|-------|---------|
| episodes | Episodic memory |
| observations | What the agent noticed |
| agent_messages | Inter-agent communication |
| agent_facets | Agent state snapshots |
| sessions | Session records |
| vector_index | ChromaDB index metadata |
| tfts | Try-fail-try-succeed arcs |
| agent_log | Agent-specific event log (custom columns per agent type) |

Plus three ChromaDB collections: `{agent}_knowledge`, `{agent}_episodes`, `{agent}_hc`.

**Current databases:**

| Agent | Database | Log Type |
|-------|----------|----------|
| Allie | allie | general |
| Andi | agent_andi | commerce |
| Alice | agent_alice | commerce |
| Noelle | agent_noelle | validation |
| Natalie | agent_natalie | routing |
| Nora | agent_nora | telemetry |
| Sally | agent_sally | station |

---

## The Closed Loop

```
User asks question
    |
Agent answers (LLM + vector store + episodic recall)
    |
Confidence too low? --> Escalate WITH episodes
    |
User gets answer
    |
Thumbs up --> episodes promoted
Thumbs down + WHY --> sting episode created, episodes demoted
    |
Next question --> better episodes surface (quality-adjusted ranking)
```

This loop means the system gets better from use. Not from training,
not from manual curation — from the natural flow of questions and feedback.
The 2-month free WCHQ trial generates volume. Volume feeds the loop.

---

## What Each Agent Watches For

| Agent | Episode sources |
|-------|----------------|
| Alice | Commerce events, pricing questions, data quality issues, user onboarding |
| Andi | Production traffic patterns, escalation outcomes, cross-instance queries |
| Noelle | Build faults, validation outcomes, network topology issues |
| Natalie | Trip plans, routing failures, dispatch timing, congestion |
| Nora | Sensor anomalies, motor faults, calibration drift, ToF patterns |
| Sally | Slot conflicts, dwell anomalies, parking queue failures, capacity issues |
| Allie | Cross-domain patterns, session lessons, TFTS arcs, team coordination |

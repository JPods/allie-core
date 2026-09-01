# 72 — Teachings Report & Context Filter Architecture

**Created:** 2026-08-09
**Status:** Teachings report implemented; context filter designed

---

## Part 1: Teachings Report (Implemented)

### Problem
Claude Code calls `teach_allie`, `alice_observe`, and `allie_db_remember` during sessions, but there was no way to verify what was actually persisted. Bill: "I have no idea how or when they learn."

### Solution
All three MCP servers now append to a shared file — `today/teachings.jsonl` — every time a write-to-memory tool is called. Rightshoe reads this file at session close and includes a report.

### How It Works

```
Claude Code
  ├── teach_allie      → allie-mcp-server.py → teachings.jsonl
  ├── alice_observe    → alice-mcp-server.py → teachings.jsonl
  └── allie_db_remember → allie_db_mcp.py    → teachings.jsonl
                                                    │
                                              rightshoe reads
                                                    │
                                              ── TEACHINGS REPORT ──
                                                ALLIE (3):
                                                  [teach] READ_ONLY_MODE...
                                                  [teach] Demo instance...
                                                ALICE (2):
                                                  [observe:observe] Setting...
                                                  [observe:error] Order...
                                                ALLIE_DB (2):
                                                  [remember:reference] Demo...
                                                  [remember:lesson] READ_ONLY...
```

### File Format — `today/teachings.jsonl`
```jsonl
{"dt":"2026-08-09T12:30:00Z","target":"allie","category":"teach","summary":"READ_ONLY_MODE is a general-purpose..."}
{"dt":"2026-08-09T12:31:00Z","target":"alice","category":"observe:observe","summary":"[setting] New setting READ_ONLY_MODE..."}
{"dt":"2026-08-09T12:32:00Z","target":"allie_db","category":"remember:lesson","summary":"[WC3] READ_ONLY_MODE — general..."}
```

### Lifecycle
1. **Leftshoe** clears `teachings.jsonl` at session start
2. **During session** — each MCP server appends on teach/observe/remember
3. **Rightshoe** reads the file, formats the report, includes in session close output
4. If the report is empty, rightshoe warns: "If the teachings report is empty, call teach_allie and alice_observe NOW."

### Files Modified
- `scripts/leftshoe-mcp.py` — clear at start, report at close
- `scripts/allie-mcp-server.py` — `_log_teaching()` on teach_allie
- `scripts/alice-mcp-server.py` — `_log_teaching()` on alice_observe
- `scripts/allie_db_mcp.py` — `_log_teaching()` on allie_db_remember

---

## Part 2: Context Filter Architecture (Design)

### Problem
Allie and Alice run on local LLMs with limited context windows (~8K tokens for Alice, ~4K effective for Allie). Every MCP call starts with a clean slate — they don't remember the prior call. Claude Code has to re-explain context every time, wasting tokens on setup instead of substance.

### Solution: Pre/Post Filter Files

A file-based context system that sits between Claude Code and each agent's LLM. Not RAG (which requires vector search). Deterministic — the right context for the right question, every time.

```
Claude Code
     │
     ▼
┌─────────────┐
│  PRE-FILTER │  ← reads context files, assembles prompt prefix
│  (Python)   │     based on domain + topic tags
└──────┬──────┘
       │  [assembled context + question]
       ▼
┌─────────────┐
│  Agent LLM  │  ← sees only what it needs
│  (Ollama)   │     fits in context window
└──────┬──────┘
       │  [response]
       ▼
┌─────────────┐
│ POST-FILTER │  ← extracts decisions, updates, lessons
│  (Python)   │     writes back to context files
└─────────────┘
```

### Context File Structure

```
~/Allie/context/
  ├── domain/
  │   ├── wc3.md          — current WC3 state, recent changes, open issues
  │   ├── su.md           — SketchUp plugin state
  │   ├── ph.md           — physical systems state
  │   └── rt.md           — MeshMobility state
  ├── models/
  │   ├── contact.md      — Contact model: fields, relationships, recent bugs
  │   ├── order.md        — Order model: transaction flow, signals, gotchas
  │   ├── invoice.md      — Invoice model: GL posting, payment linkage
  │   └── ...             — one per WC3 model
  ├── agents/
  │   ├── allie-state.md  — what Allie knows right now (refreshed nightly)
  │   └── alice-state.md  — what Alice knows, recent observations
  ├── session/
  │   ├── current.md      — what's happening THIS session (auto-updated)
  │   └── decisions.md    — decisions made this session (append-only)
  └── index.json          — maps topic tags to file paths
```

### Pre-Filter Logic

```python
def pre_filter(question: str, domain: str = None, model: str = None) -> str:
    """Assemble context prefix for an agent LLM call.
    
    1. Always include: agent-state.md + session/current.md
    2. If domain specified: include domain/{domain}.md
    3. If model specified: include models/{model}.md
    4. Token budget: keep total under 3K tokens (leaves ~5K for question + response)
    5. If over budget: truncate oldest context first, keep decisions
    """
    ...
```

### Post-Filter Logic

```python
def post_filter(response: str, question: str, domain: str = None) -> str:
    """Extract structured output from agent response.
    
    1. Look for decision markers (e.g., "DECISION:", "LESSON:", "RISK:")
    2. Append decisions to session/decisions.md
    3. Update domain context if agent flagged a state change
    4. Return cleaned response to Claude Code
    """
    ...
```

### Why This Works Better Than RAG

| Approach | Pros | Cons |
|----------|------|------|
| **RAG (vector search)** | Finds semantically similar content | May retrieve irrelevant chunks; embedding quality varies; adds latency |
| **File-based context** | Deterministic — same question, same context; human-readable; version-controlled | Requires manual curation; won't find unexpected connections |

For Allie and Alice, deterministic context is better. We know what they need for each domain. We don't need semantic search — we need the right 2-3 files every time.

### Implementation Plan

1. Create `~/Allie/context/` directory structure
2. Seed domain files from existing readmes (one-time extraction)
3. Modify `allie-mcp-server.py` and `alice-mcp-server.py` to call pre_filter before `ask_ollama()`
4. Add post_filter after response to capture decisions
5. Nightly: `allie-reflect.py` refreshes `context/agents/allie-state.md`
6. Session start: leftshoe initializes `context/session/current.md`

### Token Budget

| Agent | Total Context | Reserved for Context Files | Question + Response |
|-------|--------------|---------------------------|---------------------|
| Allie (allie:latest) | ~4K effective | ~1.5K | ~2.5K |
| Alice (via Ollama) | ~8K | ~3K | ~5K |

The pre-filter ensures these budgets are never exceeded.

---

## See Also

- [Agent LLM Architecture](../readmes/40-agent-llm-architecture.md) — model specs
- [Leftshoe](leftshoe.md) — session protocol
- [Agent Coordination](19-agent-coordination.md) — three-agent division of labor

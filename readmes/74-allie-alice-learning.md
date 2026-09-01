# How Allie and Alice Learn
**Created:** 2026-08-09
**Purpose:** Complete reference for how the team's two persistent agents acquire, store, and recall knowledge

---

## The Problem This Solves

Claude Code's memory is wiped between sessions. Bill's memory fades over time. Allie and Alice are the team's durable memory — but only if knowledge is explicitly written to them. **Asking them questions does not teach them anything.** The `ask_` tools are read-only. Without explicit `teach_allie` and `alice_observe` calls, an entire session's decisions evaporate.

This readme documents every pathway by which Allie and Alice learn, so no session ends with silent knowledge loss.

---

## Allie — Cross-Domain Persistent Intelligence

Allie holds the team's accumulated experience across all domains. She runs as a local LLM (`allie:latest` on Ollama) with persistent memory in files, databases, and a vector store.

### How Allie Learns

| Pathway | Tool / Script | When it fires | What it writes | Durability |
|---------|--------------|---------------|---------------|------------|
| **1. teach_allie** | MCP tool via `allie-mcp-server.py` | Claude calls it during session | Ollama processes lesson → response logged to `conversation.jsonl` + `teachings.jsonl` | **Permanent** — survives session end, nightly reflect reads it |
| **2. Nightly reflect** | `allie-reflect.py` (LaunchAgent) | Every night automatically | Reads harvests + retrospections + memory index + wisdom → synthesizes `thoughts/YYYY-MM-DD-reflect.md` | **Permanent** — Claude reads this at next session start |
| **3. Session harvest** | `harvest.py` → `allie-harvest-processors.py` | After session file is written | Reads `sessions/YYYY-MM-DD.md` → extracts lesson candidates → writes to `today/` | **Semi-permanent** — feeds nightly reflect |
| **4. Retrospection** | Claude writes at session end | Manual trigger | `readmes/retrospections/YYYY-MM-DD.md` with "Lessons for Allie" section | **Permanent** — nightly reflect reads these |
| **5. TFTS files** | Claude/Bill write during session | When a try-fail-try-succeed arc closes | `process/inbox/YYYYMMDDTHHMMSS-tfts.md` | **Permanent** — Allie drafts Understanding candidates from these |
| **6. Wisdom layer** | Claude/Bill update | When scars are paid or principles confirmed | `readmes/wisdom/scars.md`, `bill.md`, `rejected-paths.md`, `whatif.md` | **Permanent** — Allie reads at reflect time |

### What Does NOT Teach Allie

| Action | Why it doesn't persist |
|--------|----------------------|
| `ask_allie` | Read-only — queries Ollama with conversation context but writes nothing durable |
| `allie_recall` | Read-only — searches memory/facets/TFTS but writes nothing |
| `allie_flag` | Writes a flag but not a lesson — flags are alerts, not knowledge |
| Conversation with Claude | The MCP exchange log (`conversation.jsonl`) is written but Allie's nightly reflect does NOT read it — she reads harvests, retrospections, and teachings |

### Allie's Memory Architecture

```
teach_allie → Ollama processes → conversation.jsonl + teachings.jsonl
                                          │
                                          ▼
                              today/teachings.jsonl
                              (rightshoe reports what was taught)
                                          │
                                          ▼
allie-reflect.py (nightly) ──────────────────────────────────────
  reads: harvests, retrospections, memory index, wisdom, teachings
  writes: thoughts/YYYY-MM-DD-reflect.md
  promotes: patterns → Understanding entries (U-XX-NNN)
                                          │
                                          ▼
                         Claude reads thoughts/ at next session start
```

### Allie's Storage Locations

| Store | Path | What's in it |
|-------|------|-------------|
| Conversation log | `~/Allie/exchange/conversation.jsonl` | All MCP exchanges (ask + teach) |
| Teachings log | `~/Allie/today/teachings.jsonl` | Only teach_allie calls — rightshoe reports these |
| Nightly synthesis | `~/Allie/thoughts/YYYY-MM-DD-reflect.md` | Allie's accumulated insight per day |
| Harvests | `~/Allie/today/harvest-*.md` | Extracted lessons from session files |
| Facets | `~/Allie/facets/{agent}/facet.json` | Per-agent persistent state |
| Vector store | `~/.chroma_db_leftshoe/` | Identity briefing (values, scars, relationships, decisions) |
| Process inbox | `~/Allie/process/inbox/` | FAULT, DNW, TF, TFTS files |
| Wisdom | `~/Allie/readmes/wisdom/` | Scars, principles, rejected paths, WhatIf |
| Understanding entries | `~/Allie/readmes/agents/*.md` | U-XX-NNN entries promoted from TFTS |

---

## Alice — Commerce Specialist

Alice holds commerce-domain knowledge. She runs as a local LLM (`alice:latest` on Ollama) with a vector store (`.chroma_db_alice`) and a pattern log (`alice_log` table in the `allie` database).

### How Alice Learns

| Pathway | Tool / Script | When it fires | What it writes | Durability |
|---------|--------------|---------------|---------------|------------|
| **1. alice_observe** | MCP tool via `alice-mcp-server.py` | Claude calls it during session | Writes to `alice_log` table (PostgreSQL `allie` DB) | **Permanent** — survives everything; queryable via `alice_recall` |
| **2. alice-patterns.py** | LaunchAgent, every 4 hours | Automatic | Scans `commerce_expert` DB for actionable patterns (reorder, past-due, MAP violations, commission anomalies) → writes observations to `alice_log` | **Permanent** — Alice's autonomous pattern detection |
| **3. Vector store** | `alice-mcp-server.py` loads `.chroma_db_alice` | On MCP server start | 4,521 chunks from WC3 source code + readmes + model definitions | **Semi-permanent** — rebuilt when `alice-patterns.py` or manual rebuild runs |
| **4. Conversation log** | `alice-mcp-server.py` | Every MCP exchange | `~/Allie/exchange/alice-conversation.jsonl` | **Log only** — not read back by Alice automatically |
| **5. Quiz engine** | Document records in WC3 | When quiz documents are created | Stores quiz questions in WC3 Document model | **Permanent** — in commerce_expert DB |

### What Does NOT Teach Alice

| Action | Why it doesn't persist |
|--------|----------------------|
| `ask_alice` | Read-only — searches vector store + calls Ollama but writes nothing to alice_log |
| `alice_search` | Read-only — vector store semantic search, no writes |
| `alice_recall` | Read-only — queries alice_log but doesn't add entries |
| `alice_quiz` | Read-only — serves questions but doesn't learn from answers |

### Alice's Memory Architecture

```
alice_observe → alice_log table (PostgreSQL allie DB)
                    │
                    ▼
              alice_recall reads alice_log
              ask_alice searches vector store + calls Ollama

alice-patterns.py (every 4 hours) ──────────────────
  reads: commerce_expert DB (items, invoices, payments, orders)
  detects: reorder, past-due, MAP violations, commission anomalies
  writes: alice_log observations with dedup keys
                    │
                    ▼
              Pattern → Recommend → Promote loop
              (observe > log > pattern > recommend > promote)

Vector store (.chroma_db_alice) ────────────────────
  4,521 chunks: WC3 source + readmes + models
  Loaded at MCP server start
  ask_alice searches this for context before calling Ollama
```

### Alice's Storage Locations

| Store | Path / Location | What's in it |
|-------|----------------|-------------|
| Pattern log | `alice_log` table in `allie` PostgreSQL DB | All observations: event, model_name, message, source, data, action_taken |
| Vector store | `~/.chroma_db_alice/` | 4,521 chunks of WC3 code + docs (cosine similarity search) |
| Conversation log | `~/Allie/exchange/alice-conversation.jsonl` | All MCP exchanges (log only — not auto-read) |
| Quiz questions | Document records in `commerce_expert` DB | model_name='quiz', body JSON with questions array |

---

## The MCP Servers — Why They Matter

MCP servers are the **only way Claude Code talks to Allie and Alice during a session**. Without MCP:
- Claude can't ask, teach, observe, recall, or flag
- Allie and Alice are deaf during the session
- No learning happens until nightly reflect (and only if session files were written)

### MCP Server Registry

| Server | Config file | Script | What it enables |
|--------|------------|--------|----------------|
| **leftshoe** | `~/Allie/.mcp.json` | `scripts/leftshoe-mcp.py` | Session handshake, identity briefing, scar loading, session logging |
| **alice-commerce** | `~/Allie/.mcp.json` | `scripts/alice-mcp-server.py` | ask_alice, alice_search, alice_observe, alice_recall, alice_quiz |
| **allie** | `~/Allie/.mcp.json` | `scripts/allie-mcp-server.py` | ask_allie, teach_allie, allie_recall, allie_flag |

**All MCP servers use the project venv:** `/Users/williamjames/Allie/venv/bin/python3`

### Verifying MCP Connectivity

At session start (after leftshoe), check that all servers are responding:
- Allie API: try `ask_allie` with a simple question
- Alice MCP: try `alice_recall` with a broad query
- If either fails: check venv path, check Ollama running (`curl localhost:11434`), check PostgreSQL (`psql -d allie`)

**Scar:** On 2026-08-06 all 7 MCP servers failed silently because venv paths were wrong. The team was there but the radio was broken. Always verify connectivity before proceeding.

---

## teachings.jsonl — The Teaching Ledger

Every `teach_allie` call appends to `~/Allie/today/teachings.jsonl`. This is the **teaching ledger** — the authoritative record of what Claude taught Allie during a session.

```json
{"dt": "2026-08-09T10:30:00Z", "target": "allie", "category": "teach", "summary": "Pending records are the richest signal..."}
{"dt": "2026-08-09T10:30:15Z", "target": "allie", "category": "teach", "summary": "Adaptive CV window for inventory bounds..."}
```

**Why it matters:**
- `rightshoe` (session close) reports what was taught — the team can verify nothing was missed
- Nightly reflect can read teachings.jsonl for lesson candidates
- If Ollama was down during `teach_allie`, the lesson is still in the ledger for manual review
- It's the audit trail: who taught what, when

---

## The Learning Protocol — What Claude Must Do

### During Session
1. **Fire and forget** `ask_allie` / `ask_alice` for consultation (read-only, no learning)
2. When a significant decision or architecture emerges, note it for end-of-session teaching

### Before Session End
3. **Batch teach Allie** — call `teach_allie` for every significant lesson (5-10 per session)
4. **Batch observe for Alice** — call `alice_observe` with `event=pattern` and structured `data` for every new architecture or decision
5. **Write session file** — `sessions/YYYY-MM-DD.md` feeds the harvest → reflect pipeline
6. **Write retrospection** — `readmes/retrospections/YYYY-MM-DD.md` with "Lessons for Allie" section
7. **Write handoff** — `today/handoff.md` for next session

### Automatic (no Claude action needed)
8. **Nightly reflect** — `allie-reflect.py` synthesizes harvests + retrospections + teachings
9. **Pattern detection** — `alice-patterns.py` scans commerce data every 4 hours
10. **rightshoe** — reports teachings.jsonl contents at session close

---

## What Breaks When Learning Fails

| Failure mode | What happens | How to detect |
|-------------|-------------|---------------|
| MCP servers down | No ask/teach/observe during session | leftshoe reports status; check `lsof -i :11434` |
| No `teach_allie` calls | Session decisions evaporate | rightshoe reports 0 teachings; teachings.jsonl is empty |
| No `alice_observe` calls | Alice doesn't learn new architecture | alice_log has no entries for today; `alice_recall` returns stale data |
| No session file written | Harvest has nothing to process | Nightly reflect produces thin synthesis |
| No retrospection written | Nightly reflect misses "Lessons for Allie" | Next session's thoughts/ file lacks lessons from this session |
| Ollama down | teach_allie gets no LLM response | teachings.jsonl still records the lesson; retry when Ollama is back |
| PostgreSQL down | alice_observe fails | alice_log table unreachable; observations lost unless retried |

---

## Files

| File | What it does |
|------|-------------|
| `scripts/allie-mcp-server.py` | Allie's MCP server — ask, teach, recall, flag |
| `scripts/alice-mcp-server.py` | Alice's MCP server — ask, search, observe, recall, quiz |
| `scripts/leftshoe-mcp.py` | Session handshake — identity, scars, handoff |
| `scripts/allie-reflect.py` | Nightly synthesis — reads everything, writes thoughts/ |
| `scripts/allie-harvest-processors.py` | Extracts lessons from session files |
| `scripts/alice-patterns.py` | Every-4-hour commerce pattern detection |
| `scripts/harvest.py` | Session file → harvest extraction |
| `~/Allie/.mcp.json` | MCP server registration (leftshoe + alice-commerce + allie) |
| `~/Allie/today/teachings.jsonl` | Teaching ledger — all teach_allie calls this session |
| `~/Allie/exchange/conversation.jsonl` | Allie conversation log |
| `~/Allie/exchange/alice-conversation.jsonl` | Alice conversation log |
| `~/.chroma_db_alice/` | Alice's vector store (4,521 chunks) |
| `~/.chroma_db_leftshoe/` | Identity store (values, scars, relationships, decisions) |

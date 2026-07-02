# AI Enhancements — Agent Data Architecture
**Established:** 2026-07-01
**Updated:** 2026-07-01

## Overview

Three layers of AI infrastructure support the agent team: vector stores for semantic search, a shared PostgreSQL database for structured events and memory, and per-agent log tables that serve as schema contracts for future distributed operation.

The governing principle: **agents persist locally, Allie synthesizes globally.** Today all agents write to one database. Tomorrow each agent runs on its own processor with its own local storage, syncing events back to Allie. The schema is the interface contract — the database location is an implementation detail.

---

## Vector Stores (ChromaDB)

Three separate ChromaDB persistent stores, each serving a different purpose:

| Store | Location | Chunks | What it indexes |
|-------|----------|--------|----------------|
| **Alice** | `webClerk3/.chroma_db/` | 10,808 | Architecture docs, training documents, services reference, wc2 translation plan, Desktop Hosting lineage |
| **Allie** | `~/Allie/.chroma_db/` | 2,291 | All Allie knowledge: readmes, thoughts, handoff, facets, wisdom, retrospections, agent docs |
| **Claude Code** | `~/Allie/.chroma_db_claude/` | 1,153 | Session history: sessions/, handoff/, process/inbox/, retrospections, wisdom, agent docs |

### Usage

```bash
# Allie — search her knowledge
~/Allie/source/bin/python ~/Allie/scripts/allie-vectorstore.py search "commission splits"
~/Allie/source/bin/python ~/Allie/scripts/allie-vectorstore.py index    # re-index all
~/Allie/source/bin/python ~/Allie/scripts/allie-vectorstore.py stats

# Claude Code — search session history
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py search "pending inventory"
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py index
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py stats

# Claude Code — structured memory (PostgreSQL)
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py remember "category" "title" "content"
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py recall "commission"
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py recall --category design_decision

# Alice — indexed via Django (inside wc3 venv)
cd ~/Documents/CommerceExpert/webClerk3
DJANGO_SETTINGS_MODULE=webclerk3_api.settings venv/bin/python -c "
from apps.ai_assistant.services.vector_store import VectorStoreManager
vs = VectorStoreManager()
results = vs.search('how do commissions work', n_results=5)
for r in results: print(r['metadata']['doc_id'], r['distance'])
"
```

### Indexing Schedule

| Store | When | How |
|-------|------|-----|
| Alice | On training doc changes, service reference updates | Django script or manual `vs.index_document()` |
| Allie | Nightly (integrate into `allie-reflect.py`) or manual | `allie-vectorstore.py index` |
| Claude | Session start and session end | `claude-vectorstore.py index` |

### Chunk Configuration

All three stores use the same chunking parameters:
- Chunk size: 1,500 characters
- Chunk overlap: 200 characters
- Similarity metric: cosine distance
- Embedding model: ChromaDB default (onnx MiniLM-L6-v2)

### Future: Better Embeddings

The default ChromaDB embedding model (MiniLM-L6-v2) is adequate for now. When accuracy matters more:
- `sentence-transformers` with a larger model (e5-large, bge-large)
- `pgvector` extension — vectors in PostgreSQL alongside the data, one database, one backup
- pgvector is the long-term answer; ChromaDB is the fast start

---

## PostgreSQL Database: `allie`

**Connection:** `psql -h localhost -U williamjames -d allie`

Separate from `commerce_expert` (the product database). The `allie` database holds team working memory — it does not ship with WebClerk.

### Team Infrastructure Tables

| Table | Owner | Purpose |
|-------|-------|---------|
| `sessions` | Claude Code | Session logs — date, summary, lessons, scars, files changed |
| `claude_memory` | Claude Code | Structured cross-session memory with category, domain, title, content |
| `tfts` | Any agent | Try-fail-try-succeed records — problem, arc, principle, resolution |
| `observations` | Any agent | Patterns, risks, WhatIf items, questions |
| `agent_facets` | Allie | Current agent state — queryable mirror of facets/ JSON files |
| `vector_index` | All stores | Tracks what documents are indexed in which ChromaDB store |

### Per-Agent Log Tables

Each agent has a dedicated log table. The schema is the **interface contract** — when an agent moves to its own processor, it takes this schema and runs it locally.

| Table | Agent | Key Events |
|-------|-------|-----------|
| `noelle_log` | Noelle | `build_validate`, `fault`, `network_health`, `station_audit` |
| `natalie_log` | Natalie | `route_plan`, `dispatch`, `reroute`, `trip_complete`, `congestion` |
| `sally_log` | Sally | `slot_assign`, `slot_release`, `parking`, `dwell_exceeded`, `conveyor` |
| `nora_log` | Nora | `motor`, `tof`, `encoder`, `husky`, `battery`, `fault`, `trip_segment` |
| `alice_log` | Alice | `price_query`, `order_fulfilled`, `pattern_detected`, `coaching`, `anomaly` |

### Schema Details

**noelle_log:**
```sql
id, dt_created, event, network, station, severity, message, data (jsonb), resolved, source
-- severity: info, warning, fault, critical
-- source: SU, PH, RT
```

**natalie_log:**
```sql
id, dt_created, event, pod_name, origin, destination, path_length, duration_ms, message, data (jsonb), source
```

**sally_log:**
```sql
id, dt_created, event, station, slot_id, pod_name, dwell_ms, message, data (jsonb), source
```

**nora_log:**
```sql
id, dt_created, event, pod_name, sensor, value_raw, value_calibrated, message, data (jsonb), source
```

**alice_log:**
```sql
id, dt_created, event, model_name, record_id, customer_id, message, data (jsonb), action_taken, source
```

**claude_memory:**
```sql
id, dt_created, category, domain, title, content, still_valid, metadata (jsonb)
-- category: design_decision, bug_pattern, user_preference, architecture
-- domain: SU, PH, RT, WC3, SYS, CROSS
```

---

## Architecture Evolution

### Phase 1: Current (Simulated)

```
All agents → write to allie database → Allie synthesizes nightly
                                      → Claude Code searches at session start
```

Every agent's events go to one PostgreSQL instance. Allie's `allie-reflect.py` reads all log tables during nightly reflection. Claude Code runs `claude-vectorstore.py search` at session start to recover context.

### Phase 2: Near-term (Dedicated Processors)

```
Nora (Pi) → local SQLite nora_log → sync to allie.nora_log
Sally (Pi) → local SQLite sally_log → sync to allie.sally_log
Natalie (Mac) → local PostgreSQL natalie_log → sync to allie.natalie_log
Noelle (Mac) → local PostgreSQL noelle_log → sync to allie.noelle_log
Alice (WC3) → allie.alice_log (direct, same machine)
Allie → reads all, synthesizes, reports
Claude Code → searches vector stores, reads claude_memory
```

Each agent runs on its own processor with its own persistence. The log table schema is the sync contract. Allie polls or receives push notifications. Cross-agent patterns (Nora always faults at the ezone Noelle flagged) become visible at synthesis time.

### Phase 3: Future (Network of Agents)

```
Many Noras → each with local persistence → sync to regional Allie
Many Sallys → each station has a Sally → sync to network Allie
Natalie → per-network instance → sync trip data
Noelle → per-network instance → sync validation data
Alice → per-business instance → sync transaction patterns to WCHQ
```

The schema contract scales. The database location is an implementation detail. The principle holds: agents persist locally, Allie synthesizes globally.

---

## Integration Points

### Allie Nightly Reflection

`allie-reflect.py` should be updated to read from the `allie` database:
```python
# Read agent logs since last reflection
for table in ['noelle_log', 'natalie_log', 'sally_log', 'nora_log', 'alice_log']:
    events = query(f"SELECT * FROM {table} WHERE dt_created > {last_reflect_dt}")
    # Synthesize cross-agent patterns
```

### Claude Code Session Protocol

At session start:
```bash
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py search "current domain topic"
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py recall --category architecture
```

At session end:
```bash
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py remember "category" "title" "lesson"
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py index
```

### Alice Training & RAG

Alice uses her vector store for RAG-augmented responses:
```python
from apps.ai_assistant.services.rag_service import RAGService
rag = RAGService()
response = rag.query("How do I set up commission splits?")
# Returns LLM response grounded in indexed training documents
```

### WC3 Boundary Events

The `_allie_capture()` pattern (documented in CLAUDE.md) fires at tool boundaries. These events should write to the appropriate agent log table:
```python
# In WC3 signal handler
def on_order_fulfilled(order):
    _write_alice_log('order_fulfilled', 'order', order.pk, order.customer_id,
                     f'Order {order.ida} fulfilled', {'total': float(order.total)})
```

---

## What NOT to Store

- **Code patterns and file paths** — derive from the codebase, not from memory
- **Git history** — `git log` is authoritative
- **Ephemeral debugging data** — delete after the TFTS is written
- **Duplicates of commerce data** — the `commerce_expert` DB is the source of truth for business data; `allie` holds observations about that data, not copies of it

---

## Backup

The `allie` database is included in `pg_dumpall` alongside `commerce_expert`. For targeted backup:

```bash
pg_dump -h localhost -U williamjames allie > ~/Allie/archive/allie_db_$(date +%Y%m%d).sql
```

ChromaDB stores are file-based directories — included in Allie's standard rsync to iCloud and 5TB.

---

## Dependencies

| Package | Where installed | Purpose |
|---------|----------------|---------|
| `chromadb` | WC3 venv + Allie source venv | Vector store |
| `psycopg2-binary` | Allie source venv | PostgreSQL access from scripts |
| `onnxruntime` | Auto-installed with chromadb | Embedding model runtime |

Install if missing:
```bash
~/Allie/source/bin/pip install chromadb psycopg2-binary
~/Documents/CommerceExpert/webClerk3/venv/bin/pip install chromadb
```

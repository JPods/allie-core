# AI Tools, Models, and Team Capabilities
**Established:** 2026-07-01
**Updated:** 2026-07-01

## Overview

This document covers the complete AI tooling for the agent team: models, vector stores, database infrastructure, message bus, report generation, scheduled analysis, session management, and the MCP server layer. Each tool exists because it solves a specific bottleneck in how the team works.

---

## 1. LLM Models (Ollama)

### Current Models

| Model | Size | Base | Purpose | Location |
|-------|------|------|---------|----------|
| `allie:latest` | 13 GB | gpt-oss:20b | Allie's current brain — nightly reflection, cross-domain synthesis | Internal SSD |
| `qwen2.5:72b` | 43 GB | Qwen2.5 | **Allie upgrade** — native tool use, 128K context, superior reasoning | 5TB `/Volumes/Allie/ollama_models/` |
| `athena:latest` | 13 GB | gpt-oss:20b | Security review, non-standing action signing | Internal SSD |
| `athena-reason:latest` | 5.2 GB | — | Lightweight reasoning for triage | Internal SSD |
| `athena-triage:latest` | 2.0 GB | — | Fast security triage | Internal SSD |
| `nomic-embed-text` | 274 MB | — | Embedding model (ChromaDB alternative) | Internal SSD |
| `deepseek-r1:8b` | 5.2 GB | DeepSeek | Reasoning experiments | Internal SSD |

### Why qwen2.5:72b for Allie

| Criteria | gpt-oss:20b (current) | qwen2.5:72b (upgrade) |
|----------|----------------------|----------------------|
| Parameters | 20 billion | 72 billion |
| Context window | 8K | 128K |
| Tool/function calling | No | **Native** |
| Reasoning depth | Basic | **Chain-of-thought** |
| Cross-domain synthesis | Adequate | **Significantly better** |
| Speed on 32GB RAM | Fast (fits in RAM) | Slower (swap needed) |

**The tradeoff:** 72b is slower on 32GB RAM because it doesn't fully fit in memory. For nightly batch reflection this doesn't matter — Allie runs unattended. For interactive use, the 20b model stays available as a fast fallback.

### Running the 72b Model

```bash
# Model stored on 5TB
export OLLAMA_MODELS=/Volumes/Allie/ollama_models

# Run interactively (slow but capable)
ollama run qwen2.5:72b

# Use from Python
import ollama
response = ollama.generate(model='qwen2.5:72b', prompt='...')

# Build Allie's upgraded Modelfile
ollama create allie-72b -f ~/Allie/config/Modelfile-72b
```

### Hardware Considerations

| RAM | 70b Model Experience |
|-----|---------------------|
| 32 GB (current) | Runs with swap — 2-5 tok/s. Fine for batch, slow for interactive. |
| 48 GB | Partial fit — 8-12 tok/s. Good for interactive. |
| 64 GB | Full fit — 15-20 tok/s. Production speed. |
| 96 GB (Mac Studio) | Full fit + KV cache — 20-30 tok/s. Ideal. |

**Recommendation:** If Allie moves to a dedicated Mac Mini (previously discussed), spec it with 48GB+ unified memory for the 72b model.

### Smaller Quantization Option

If 43GB is too large for interactive use:
```bash
# Q3_K_M quantization — ~33GB, faster but slightly less accurate
OLLAMA_MODELS=/Volumes/Allie/ollama_models ollama pull qwen2.5:72b-q3_K_M
```

---

## 2. Vector Stores (ChromaDB)

Three separate stores for three different purposes:

| Store | Location | Chunks | Owner | Purpose |
|-------|----------|--------|-------|---------|
| **Alice** | `webClerk3/.chroma_db/` | 10,808 | Alice | RAG for commerce Q&A, training docs, architecture |
| **Allie** | `~/Allie/.chroma_db/` | 2,291 | Allie | Cross-domain knowledge, agent docs, wisdom |
| **Claude** | `~/Allie/.chroma_db_claude/` | 1,153 | Claude Code | Session history, retrospections, handoff |

### Scripts

```bash
# Allie's store
~/Allie/source/bin/python ~/Allie/scripts/allie-vectorstore.py index
~/Allie/source/bin/python ~/Allie/scripts/allie-vectorstore.py search "commission splits"
~/Allie/source/bin/python ~/Allie/scripts/allie-vectorstore.py stats

# Claude's store
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py index
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py search "pending inventory"
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py recall "commission"
~/Allie/source/bin/python ~/Allie/scripts/claude-vectorstore.py remember "category" "title" "content"

# Alice's store (via Django)
cd ~/Documents/CommerceExpert/webClerk3
DJANGO_SETTINGS_MODULE=webclerk3_api.settings venv/bin/python -c "
from apps.ai_assistant.services.vector_store import VectorStoreManager
vs = VectorStoreManager()
results = vs.search('how do commissions work')
"
```

### Embedding Model

All stores use ChromaDB's default: **MiniLM-L6-v2** (ONNX). Adequate for current scale.

**Future upgrade path:** `pgvector` extension in PostgreSQL — vectors alongside data, one database, one backup, SQL-queryable embeddings. This is the long-term answer when scale warrants it.

---

## 3. PostgreSQL Database: `allie`

**Connection:** `psql -h localhost -U williamjames -d allie`

Separate from `commerce_expert` (the product). Holds all agent working memory.

### Tables

| Table | Purpose | Owner |
|-------|---------|-------|
| `sessions` | Claude Code session logs | Claude |
| `claude_memory` | Structured cross-session memory | Claude |
| `tfts` | Try-fail-try-succeed records | Any agent |
| `observations` | Patterns, risks, WhatIf | Any agent |
| `agent_facets` | Current agent state | Allie |
| `vector_index` | Tracks ChromaDB indexing | All stores |
| `agent_messages` | Inter-agent message bus | All agents |
| `noelle_log` | Build/validation events | Noelle |
| `natalie_log` | Routing/dispatch events | Natalie |
| `sally_log` | Station/slot events | Sally |
| `nora_log` | Telemetry/sensor events | Nora |
| `alice_log` | Transaction/pattern events | Alice |

---

## 4. Agent Message Bus

Agents communicate through `agent_messages` in the `allie` database. Simple, reliable, queryable.

### Usage

```bash
# CLI
~/Allie/scripts/agent-msg.sh send claude alice "Build complete" "56 GL entries" --priority 1
~/Allie/scripts/agent-msg.sh inbox alice
~/Allie/scripts/agent-msg.sh read 42
~/Allie/scripts/agent-msg.sh reply 42 alice "Acknowledged"

# Python
from agent_bus import send, inbox, reply
send('claude', 'alice', 'Build complete', body='56 GL entries', priority=1)
messages = inbox('alice', unread_only=True)

# From WC3 (Alice's bridge)
from apps.core.services.agent_bus_bridge import send_to_bus, check_inbox
send_to_bus('alice', 'allie', 'Pattern detected', category='observation')
```

### Message Categories

| Category | Use |
|----------|-----|
| `fault` | System error or failure |
| `observation` | Pattern or anomaly noticed |
| `request` | Ask another agent to do something |
| `response` | Reply to a request |
| `coaching` | Alice training/coaching event |
| `alert` | Urgent notification |

### Message Priority

| Level | Meaning |
|-------|---------|
| 0 | Normal — processed in batch |
| 1 | Important — process soon |
| 2 | Urgent — trigger immediate mini-reflection |

---

## 5. PDF Report Generation

**Service:** `apps/core/services/report_renderer.py`
**Endpoint:** `GET /wcapi/report/?report=Invoice&model=invoice&id=62`

### Built-in Templates

| Report | Model | What it produces |
|--------|-------|-----------------|
| Invoice | invoice | Customer-facing bill with line items, totals, terms |
| Pick List | order | Warehouse pick ticket — items, bins, qty, no prices |
| Packing Slip | order | Ships with goods — items, qty, no prices |
| Purchase Order | purchase | Vendor-facing PO with costs and terms |
| Order Confirmation | order | Customer-facing order summary |
| Commission Report | rep | Per-rep earnings by period with effective rates |
| Statement | customer | Periodic account statement with aging |
| Customs Proforma | order | International shipment declaration |

### Usage

```python
from apps.core.services.report_renderer import render_report
result = render_report('Invoice', 'invoice', record_id=62)
# Returns: {'pdf_bytes': b'...', 'filename': 'Invoice-alice-inv-001.pdf', 'pages': 1}
```

---

## 6. Session Start Protocol

**Script:** `~/Allie/scripts/session-start.sh`

Runs at the beginning of every Claude Code session. Produces a briefing:
- Unread agent messages
- Recent memories from claude_memory
- Unresolved TFTS count
- Open observations count
- Latest handoff summary

```bash
# Run manually
bash ~/Allie/scripts/session-start.sh

# Or add as Claude Code hook (future)
```

---

## 7. MCP Server: allie-db

**Server:** `~/Allie/scripts/allie_db_mcp.py`
**Config:** `~/.claude/settings.local.json` → mcpServers.allie-db

Gives Claude Code direct database access through MCP tools instead of shelling to psql.

### Tools

| Tool | Purpose |
|------|---------|
| `allie_db_query` | Read-only SQL against `allie` database |
| `allie_db_remember` | Save to claude_memory |
| `allie_db_recall` | Search claude_memory |
| `allie_db_agent_inbox` | Check agent messages |
| `allie_db_send_message` | Send agent message |
| `allie_db_log_observation` | Record observation |

---

## 8. Scheduled Analysis (launchd)

Alice and Allie should run analysis on schedule, not just when asked.

### Recommended Schedule

| Job | Frequency | What it does |
|-----|-----------|-------------|
| `allie-reflect.py` | Nightly 11pm | Full synthesis — reads all logs, generates reflection |
| Alice pattern detection | Every 4 hours | Scan transactions for anomalies, coaching opportunities |
| Reorder check | Daily 6am | `suggest_purchase` → draft POs for items below reorder |
| Vendor scorecard refresh | Weekly Monday | Recompute all vendor scores from Receipt/PO data |
| Invoice reminder queue | Daily 8am | Age invoices, queue email reminders |
| Agent bus cleanup | Weekly Sunday | Archive old read+acknowledged messages |
| Vector store re-index | Weekly Sunday | Re-index all three ChromaDB stores |

### LaunchAgent Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.allie.alice-patterns</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/williamjames/Allie/source/bin/python</string>
        <string>/Users/williamjames/Allie/scripts/alice-patterns.py</string>
    </array>
    <key>StartInterval</key>
    <integer>14400</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/Users/williamjames/Allie/logs/alice-patterns.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/williamjames/Allie/logs/alice-patterns.log</string>
</dict>
</plist>
```

Save to `~/Library/LaunchAgents/com.allie.alice-patterns.plist` and load:
```bash
launchctl load ~/Library/LaunchAgents/com.allie.alice-patterns.plist
```

---

## 9. Django Signals → Agent Bus

Wire WC3 save events to the agent bus so Alice knows about every transaction automatically.

```python
# In apps/transactions/signals.py
from django.db.models.signals import post_save
from django.dispatch import receiver
from apps.core.services.agent_bus_bridge import send_to_bus

@receiver(post_save, sender='transactions.Order')
def order_saved(sender, instance, created, **kwargs):
    event = 'created' if created else 'updated'
    send_to_bus('wc3', 'alice', f'Order {instance.ida} {event}',
                category='transaction',
                context={'model': 'order', 'id': instance.pk, 'event': event})
```

---

## 10. Future Enhancements

### Near-term
- **pgvector** — PostgreSQL vector extension, replace ChromaDB
- **Allie tool use** — qwen2.5:72b supports function calling natively
- **Shared team scratchpad** — `team_scratchpad` table for real-time collaboration
- **Barcode scanning** — `pyzbar` for receiving workflows
- **Voice interface** — Whisper + TTS for hands-free operation

### Medium-term
- **Dedicated Mac Mini for Allie** — 48GB+ RAM, always-on, runs 72b at full speed
- **Agent-per-processor** — each agent on own hardware with local persistence
- **DynamicCatalogs integration** — supplier data import pipeline
- **Accounting export** — GL journal export to QuickBooks/Xero format

### Long-term
- **Network of Allies** — each business runs their own Allie, syncs observations to WCHQ
- **Federated learning** — Alice instances across businesses share patterns (not data)
- **MyCarryOn integration** — agent identity portable across systems

---

## Dependencies

| Package | Venv | Purpose |
|---------|------|---------|
| `chromadb` | Both | Vector store |
| `psycopg2-binary` | Allie | PostgreSQL access |
| `weasyprint` | WC3 | PDF generation |
| `mcp` | Allie | MCP server framework |
| `onnxruntime` | Both | Embedding model runtime (auto with chromadb) |
| `ollama` | Allie | LLM API client |

### Install Commands

```bash
# Allie venv
~/Allie/source/bin/pip install chromadb psycopg2-binary mcp ollama

# WC3 venv
cd ~/Documents/CommerceExpert/webClerk3
venv/bin/pip install chromadb weasyprint
```

---

## Backup

```bash
# Full PostgreSQL backup (both databases)
pg_dumpall -h localhost -U williamjames > ~/Allie/archive/pg_dumpall_$(date +%Y%m%d).sql

# Individual database backup
pg_dump -h localhost -U williamjames allie > ~/Allie/archive/allie_db_$(date +%Y%m%d).sql
pg_dump -h localhost -U williamjames commerce_expert > ~/Allie/archive/commerce_expert_$(date +%Y%m%d).sql

# ChromaDB stores are file-based — included in standard rsync
# ~/Allie/.chroma_db/ and ~/Allie/.chroma_db_claude/ sync with iCloud and 5TB
```

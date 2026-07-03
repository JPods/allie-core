---
name: Alice infrastructure — vector store, MCP, quiz engine
description: Alice has her own vector store (4521 chunks), MCP server (5 tools), quiz engine (28 questions from real test data), and observation pipeline; all built 2026-07-03
type: reference
---

**Vector Store:** `~/Allie/.chroma_db_alice/` — 4,521 chunks. Script: `scripts/alice-vectorstore.py`. Indexes WC3 models, views, readmes, legacy PDFs (Desktop Hosting book, flow charts), cross-refs from Allie+Claude stores. Supports PDF extraction via PyMuPDF.

**MCP Server:** `scripts/alice-mcp-server.py`. Registered via `claude mcp add -s user alice`. Uses `~/Allie/venv/bin/python3`. Tools: `ask_alice` (semantic search + answer), `alice_search` (raw vector search), `alice_observe` (log to alice_log), `alice_recall` (recall patterns), `alice_quiz` (learning quizzes). Exchange log: `exchange/alice-conversation.jsonl`. Needs Claude Code restart to activate.

**Quiz Engine:** 5 quiz sets stored as Document records (`model_name="quiz"`) in WC3: QUIZ-INVENTORY-FLOW (7), QUIZ-PAYMENT-CASH (7), QUIZ-GL-POSTING (4), QUIZ-COMMERCE-FLOW (6), QUIZ-TOOLS (4). 28 questions total, sourced from actual test functions (test_inventory_bucket_flow.py, test_payment_services.py, test_ledger.py, test_erosion.py, test_gl_posting.py).

**Observation Pipeline:** AliceObservation model registered in wcapi (alias map + models.py import). Console capture auto-flushes to alice_observation every 60s. Readme: `readmes/topics/ai/alice-observation-setup.md`.

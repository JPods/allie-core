# Allie + Alice Skills Backlog
**Created:** 2026-04-28
**Owner:** Allie (tracks and updates this)
**Source:** Session of 2026-04-27/28 — full architecture review

Prioritized by: impact × dependency readiness ÷ effort.
Tier 1 must complete before Tier 2 compounds. Fine-tuning (Tier 4) requires Tier 1 corpus closure.

---

## Tier 1 — Close the Loop (build these first)

| # | Skill | Who | What it does | Status |
|---|-------|-----|-------------|--------|
| 1 | **WC3 read at session start** | Allie | Auto-fetch open Actions (Project 25) and WhatIf items (Project 24) at startup; surface before work begins | Not started |
| 2 | **Corpus auto-population** | Both | `allie-reflect.py` and `alice_deliberate` write corpus entries automatically after each run | Not started |
| 3 | **Reflect → WC3 action bridge** | Allie | After nightly reflect, parse "Priority for Next Session" and auto-create an Action in Project 25 | Not started |
| 4 | **Weekly sprint auto-creation** | Alice | Every Monday, create a Project record for the current week's sprint; assign open Backlog actions to it | Not started |

---

## Tier 2 — Daily Effectiveness

| # | Skill | Who | What it does | Status |
|---|-------|-----|-------------|--------|
| 5 | **Git awareness** | Allie | Post-commit hook logs what was committed, branch, message — feeds harvest and corpus | Not started |
| 6 | **Cross-project correlation** | Allie | harvest.py correlation pass: same-day activity across projects → cross-domain flag | Not started |
| 7 | **Email surface at session start** | Allie | Gmail MCP: pull 3–5 relevant threads (JPods, WebClerk, politics) at startup | Not started |
| 8 | **alice_deliberate on schedule** | Alice | Weekly (Monday): run `alice_deliberate --alice-pending` via Celery beat | Not started |
| 9 | **Pattern promotion pipeline** | Alice | config_suggestion seen 5+ times → Alice auto-proposes Setting record to Allie via wcapi note | Not started |

---

## Tier 3 — Intelligence Amplification

| # | Skill | Who | What it does | Status |
|---|-------|-----|-------------|--------|
| 10 | **Semantic search over knowledge base** | Allie | `nomic-embed-text` embeds all readmes + retrospections; Allie queries by meaning at session start | Not started |
| 11 | **Harvest LLM quick-synthesis** | Allie | `harvest.py --synthesize`: calls llama3.2 for 3-sentence same-day interpretation | Not started |
| 12 | **Deliberation on reflect output** | Allie | Auto-pipe reflect "Priority" section through `allie-deliberate.py` before Claude reads it | Not started |
| 13 | **Cross-agent structured handoff** | Both | Typed handoff record schema `{from, to, domain, finding, action_required, sunset}` — replaces free-text wcapi notes | Not started |

---

## Tier 4 — Advanced / Long-Term

| # | Skill | Who | What it does | Status |
|---|-------|-----|-------------|--------|
| 14 | **Fine-tuned allie-v1** | Both | Train on verified corpus (100+ entries required); `allie-finetune.sh` is ready | Blocked: corpus empty |
| 15 | **Physical robot telemetry feed** | Allie/Nora | MQTT bridge from Pi → Allie activity log; pod events, I2C faults → corpus entries | Blocked: port 9001 bridge not built |
| 16 | **SketchUp plugin telemetry** | Allie | Ruby plugin writes structured event log on export, validation failure, CP connection | Blocked: plugin extension needed |
| 17 | **Voice interface** | Allie | Whisper input, TTS output — session start briefing, dictate WhatIf items | Not started |
| 18 | **Confidence scoring on deliberations** | Both | Score (0–1) from adversary critique ratio → auto-gates corpus `verified` field | Not started |

---

## Recommended session sequence

| Session | Focus | Outcome |
|---------|-------|---------|
| A | Tier 1 items 1–3 | Reflect → WC3 → session-start loop closes |
| B | Tier 2 items 5–6 | Git awareness + cross-project correlation in harvest |
| C | Tier 3 item 10 | Semantic search over knowledge base |
| D | Tier 1 item 4 + Tier 2 item 8 | Alice sprint automation wired |
| E | Tier 3 items 11–12 | Harvest and reflect quality lift |
| F | Tier 4 item 14 | First fine-tune (if corpus ready) |

---

## Infrastructure already in place

These are done and available for Tier 1–2 to build on:

- `allie-reflect.py` — nightly deepseek-r1:8b synthesis, `com.allie.reflect` LaunchAgent
- `allie-deliberate.py` — three-stage hallucination probe
- `allie_wc_client.py` — WC3 Action/Project/Document/Note writer
- `allie_corpus_log.py` — shared corpus logger
- `alice_deliberate` — Alice's Django management command
- `allie-finetune.sh` — full MLX pipeline ready to run
- `training/Modelfile.template` — Allie's identity as Ollama system prompt
- `allie_think.py` — on-demand Ollama ask/compare
- `allie_wc_token.py` — Bearer token for allie/alice/athena
- `watcher.sh` + `com.allie.watcher` — live file + app monitoring
- `allie-sync.sh` + `com.allie.sync` — three-drive sync (internal/5TB/Lexar)
- `com.webclerk.server` — WebClerk auto-starts via `runserver.sh local`

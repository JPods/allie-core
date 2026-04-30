# Allie ↔ Claude Bridge
**Created:** 2026-04-28
**Applies to:** All environments where Allie needs Claude's reasoning

---

## Overview

Allie's local LLMs (DeepSeek, Llama, Athena models) handle routine synthesis,
pattern detection, and hallucination probing. Claude handles complex cross-domain
reasoning, novel problems, and anything where a more capable model is warranted.

Three paths from Allie to Claude. One outward-facing API from Allie to the world.

---

## Path 1 — Anthropic API (primary)

**Use for:** Programmatic calls from scripts. Fastest. Most scalable. Runs without
Bill present. Costs API tokens.

```python
# allie_ask_claude.py — import and call from any Allie script
from allie_ask_claude import ask_claude

answer = ask_claude(
    prompt="Why is station S02 showing 35 min at near-zero demand?",
    context="Route-Time session. Grid generator verified correct 2026-04-27."
)
```

**When to use:**
- `allie-reflect.py` needs Claude to adjudicate a pattern it cannot resolve locally
- `allie-deliberate.py` escalates when judge verdict is SUBSTANTIALLY WRONG
- Any script needs cross-domain reasoning that local models handle poorly
- Alice needs Claude's judgment on a WebClerk architecture question

**Credentials:** `config/wc_credentials.json` → `claude_api_key`

**Model:** `claude-sonnet-4-6` default. Use `claude-opus-4-6` for high-stakes decisions.

---

## Path 2 — Claude Code CLI (human-mediated prompt)

**Use for:** When Bill is present. Uses subscription, not API tokens. Stateless —
no conversation memory. The human is in the loop.

```bash
# Allie writes a question, Bill pastes it into Claude Code
echo "$PROMPT" | claude --print --model claude-sonnet-4-6

# Or from a script that Bill runs manually
python3 scripts/allie_ask_claude.py --mode cli --prompt "..."
```

**When to use:**
- Bill wants to see the exchange
- The question requires Bill's context to answer correctly
- Token cost is a concern
- Testing a new prompt before wiring it to the API

**Character of this path:** Human experience path. The question passes through
Bill's judgment — he decides whether to send it and can add context. Slower,
more deliberate, more accountable.

---

## Path 3 — Prompt file (async, session-start handoff)

**Use for:** Allie writes a structured question file during a session or overnight.
Claude reads it at the next session start as part of the startup protocol.
The question waits; Claude answers when Bill opens the session.

```
~/Allie/inbox/YYYY-MM-DD-HHMMss-question.md
```

Format:
```markdown
# Allie Question — YYYY-MM-DD HH:MM
**From:** allie-reflect / allie-deliberate / [script]
**Domain:** route-time / sketchup / physical / webclerk / universal
**Priority:** high / normal / low
**Expires:** YYYY-MM-DD (Claude ignores after this date)

## Question
[specific question here]

## Context
[what Allie already knows, what she tried, what she's uncertain about]

## What Claude should do
[answer only / answer and create action / answer and update readme / etc.]
```

Claude reads `~/Allie/inbox/` at session start (step 2 of startup protocol — to be added).
After answering, moves the file to `~/Allie/inbox/answered/`.

**Character of this path:** Human experience path. Async. The question survives
sleep and session boundaries. Good for "I noticed this overnight and want to know
what you think" patterns. No tokens consumed until Bill opens Claude.

---

## Allie's Outward-Facing API

Allie's local LLMs are available to other systems via a lightweight authenticated
REST API. Runs on port 5001. Requires Bearer token.

**Who uses this:**
- The JPods Raspberry Pi robots (Nora/Natalie/Noelle) — query Allie for routing advice
- Other machines on the local network
- External systems via ngrok tunnel (when Bill enables it)
- Alice in WebClerk — can call Allie's local models without going through Anthropic

### Endpoints

```
GET  /health                    — liveness check
GET  /models                    — list available Ollama models
POST /ask                       — single model query
POST /deliberate                — three-stage hallucination probe
POST /reflect                   — run reflect synthesis on demand
```

### Authentication

Bearer token stored in `config/allie_api_keys.json`:
```json
{
  "keys": {
    "jpods-pi": "...",
    "webclerk-alice": "...",
    "external": "..."
  }
}
```

Generate a key:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### POST /ask

```json
{
  "model": "deepseek-r1:8b",
  "prompt": "Why is the north station showing longer travel time than the south station?",
  "context": "Route-Time session. Near-zero demand. Grid layout 3×3.",
  "timeout": 120
}
```

Response:
```json
{
  "model": "deepseek-r1:8b",
  "response": "...",
  "elapsed_s": 14.2
}
```

### POST /deliberate

```json
{
  "prompt": "Should the east guideway be split into two segments?",
  "rounds": 1,
  "reasoner": "deepseek-r1:8b",
  "adversary": "athena-reason:latest",
  "judge": "llama3.2:latest"
}
```

Response includes all three stage outputs plus final verdict.

### External access via ngrok

When Bill needs the API reachable from outside the local network:

```bash
# One-time setup
brew install ngrok
ngrok config add-authtoken <your-token>

# Start tunnel (exposes port 5001)
ngrok http 5001
```

ngrok prints a public URL (`https://xxxx.ngrok.io`). Share that URL + a Bearer
token with external callers. Tunnel closes when ngrok stops — not persistent.

For a persistent external URL, use Cloudflare Tunnel (`cloudflared`) instead.

### Local network access (always available)

Other devices on the same WiFi reach Allie's API at:
```
http://<mac-local-ip>:5001
```

Find the IP: `ipconfig getifaddr en0`

The Raspberry Pi robots use this to query Allie during operation.

---

## Decision matrix — which path to use

| Situation | Path |
|-----------|------|
| Script needs Claude, Bill not present | API (Path 1) |
| Bill is present, wants to see the exchange | CLI (Path 2) |
| Allie has a question that can wait until next session | Prompt file (Path 3) |
| Pi robot needs routing advice | Outward API → local LLM |
| Alice needs Allie's judgment inside WC3 | Outward API → local LLM |
| High-stakes decision, need best model | API (Path 1), claude-opus-4-6 |
| Testing a prompt | CLI (Path 2) |
| Cross-session pattern that needs Bill's context | Prompt file (Path 3) |

---

## Files

| File | Purpose |
|------|---------|
| `scripts/allie_ask_claude.py` | Anthropic API client — import from any script |
| `scripts/allie-api.py` | Outward-facing Flask API server |
| `Library/LaunchAgents/com.allie.api.plist` | Auto-starts allie-api.py on login |
| `config/wc_credentials.json` → `claude_api_key` | Anthropic API key |
| `config/allie_api_keys.json` | Bearer tokens for outward API callers |
| `~/Allie/inbox/` | Prompt file drop directory (Path 3) |
| `~/Allie/inbox/answered/` | Answered prompt files (archived) |

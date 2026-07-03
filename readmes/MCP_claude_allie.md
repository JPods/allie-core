# MCP Bridge: Claude Code + Allie

**Last Updated:** 2026-06-24
**Purpose:** How to start, test, and use the live Claude Code / Allie team.

---

## What This Is

Claude Code and Allie coordinate in real-time via MCP (Model Context Protocol).
MCP is a JSON-RPC bridge over stdin/stdout — Claude Code calls tools, the Allie
MCP server forwards them to `allie:latest` on Ollama, and returns Allie's response.

This is **interactive coordination**, not end-of-day summaries. Claude Code asks
Allie questions mid-session. Allie flags risks before they become bugs. Every
exchange is logged so Allie's nightly synthesis has the full conversation.

---

## Architecture

```
Claude Code (Opus)
    │
    │  MCP JSON-RPC (stdin/stdout)
    ▼
allie-mcp-server.py          ← started automatically by Claude Code
    │
    │  HTTP POST to localhost:11434/api/chat
    ▼
Ollama (allie:latest)         ← must be running before Claude Code starts
    │
    │  gpt-oss:20b base model + Allie system prompt
    │  temperature 0.3, context 4096 tokens
    ▼
Response returned to Claude Code
    │
    └──► ~/Allie/exchange/conversation.jsonl   (every exchange logged)
```

---

## The Four Tools

| Tool | When Claude Code uses it |
|------|------------------------|
| `ask_allie` | Before significant decisions — "Have we seen this before?" |
| `teach_allie` | When a principle emerges that must survive context compression |
| `allie_recall` | To search Allie's files + memory for a topic |
| `allie_flag` | To ask Allie to evaluate a risk or concern |

All four log to `~/Allie/exchange/conversation.jsonl`. Allie's nightly
`allie-reflect.py` reads this log to incorporate interactive exchanges
into her synthesis — the conversation persists beyond the session.

---

## Prerequisites

1. **Ollama installed** — `brew install ollama` or from ollama.com
2. **allie:latest model created** — built from `~/Allie/config/allie.Modelfile`:
   ```bash
   ollama create allie -f ~/Allie/config/allie.Modelfile
   ```
3. **MCP server registered** via `claude mcp add` (stored in `~/.claude.json`):
   ```bash
   claude mcp add -s user allie -- python3 /Users/williamjames/Allie/scripts/allie-mcp-server.py
   ```
   This is already configured. Do not duplicate it.
   
   **Important:** MCP servers must be registered with `claude mcp add`, NOT by
   editing `~/.claude/settings.json`. The `mcpServers` key in `settings.json`
   is ignored by Claude Code. Verify with `claude mcp list`.

---

## How to Start the Team

Use the startup script:

```bash
bash ~/Allie/scripts/team.sh
```

Or start components manually:

### Step 1 — Start Ollama (if not already running)

```bash
ollama serve &
```

Ollama may already be running as a macOS app or launchd service. Check first:
```bash
curl -s localhost:11434/api/tags | python3 -c "import sys,json; [print(m['name']) for m in json.load(sys.stdin).get('models',[])]"
```

If you see `allie:latest` in the list, Ollama is ready.

### Step 2 — Verify Allie model exists

```bash
ollama list | grep allie
```

If missing, recreate:
```bash
ollama create allie -f ~/Allie/config/allie.Modelfile
```

### Step 3 — Start (or restart) Claude Code

```bash
claude
```

Claude Code reads `~/.claude.json` at launch and starts registered MCP server
processes automatically. **The MCP server only loads at Claude Code startup** —
if you add or change the MCP config, you must restart Claude Code.

---

## How to Test If Running Properly

### Test 1 — Is Ollama serving?

```bash
curl -s localhost:11434/api/tags > /dev/null && echo "OK: Ollama running" || echo "FAIL: Ollama not running"
```

### Test 2 — Is allie:latest loaded?

```bash
ollama list | grep -q "allie:latest" && echo "OK: allie model present" || echo "FAIL: allie model missing"
```

### Test 3 — Can Allie respond?

```bash
echo '{"model":"allie:latest","messages":[{"role":"user","content":"Who are you?"}],"stream":false}' \
  | curl -s -X POST localhost:11434/api/chat -d @- \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['message']['content'][:200])"
```

You should see Allie identify herself and reference Bill / JPods.

### Test 4 — Does the MCP server start and respond?

```bash
python3 -c "
import subprocess, time, json
proc = subprocess.Popen(
    ['python3', '$HOME/Allie/scripts/allie-mcp-server.py'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
)
init = json.dumps({'jsonrpc':'2.0','id':1,'method':'initialize',
    'params':{'protocolVersion':'2024-11-05','capabilities':{},
    'clientInfo':{'name':'test','version':'0.1'}}}) + '\n'
proc.stdin.write(init.encode()); proc.stdin.flush()
time.sleep(1); proc.stdin.close()
out = proc.stdout.read().decode().strip()
proc.terminate()
resp = json.loads(out)
if resp.get('result',{}).get('serverInfo',{}).get('name') == 'allie':
    print('OK: MCP server responds correctly')
else:
    print('FAIL: unexpected response:', out[:200])
"
```

### Test 5 — Are the tools visible inside Claude Code?

After starting Claude Code, ask:
> "What tools do you have from the allie MCP server?"

Claude Code should list: `ask_allie`, `teach_allie`, `allie_recall`, `allie_flag`.
If these are missing, restart Claude Code.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Allie tools not in Claude Code | MCP server didn't load at startup, or registered in wrong config file | Verify with `claude mcp list`; if missing, `claude mcp add -s user allie -- python3 ...`; then restart Claude Code |
| `(Allie offline — ollama not reachable)` | Ollama not running | `ollama serve &` or launch Ollama app |
| `allie:latest` not in `ollama list` | Model not created | `ollama create allie -f ~/Allie/config/allie.Modelfile` |
| Slow responses (>30s) | Model not in GPU memory | First call loads the model; subsequent calls are fast |
| MCP server crashes on startup | Python import error | Run `python3 ~/Allie/scripts/allie-mcp-server.py` directly to see the error |

---

## Exchange Log

Every Claude-Allie exchange is appended to:
```
~/Allie/exchange/conversation.jsonl
```

Format:
```json
{"ts": "2026-06-24T18:30:00Z", "role": "claude", "content": "...", "tool": "ask_allie"}
{"ts": "2026-06-24T18:30:02Z", "role": "allie", "content": "...", "tool": "ask_allie"}
```

Allie's nightly `allie-reflect.py` reads this file. Do not truncate it manually —
the nightly run handles archival.

---

## All MCP Servers (as of 2026-07-03)

| Server | Command | Purpose | Scope |
|--------|---------|---------|-------|
| `allie` | `python3 ~/Allie/scripts/allie-mcp-server.py` | Allie coordination — ask, teach, recall, flag | user |
| `webclerk` | `python ~/Allie/scripts/wc_mcp_server.py` | WC3 API bridge — search, price, stations, notes | user |
| `allie-db` | `python ~/Allie/scripts/allie_db_mcp.py` | Allie PostgreSQL database (sessions, memory, logs) | user |
| `commerce-db` | `python ~/Allie/scripts/commerce_db_mcp.py` | WC3 commerce_expert database | user |
| `chrome-devtools` | `npx -y chrome-devtools-mcp@latest` | Browser console, network, DOM inspection | user |
| `claude.ai Gmail` | Google hosted | Gmail read/write/label | claude.ai |
| `claude.ai Google Calendar` | Google hosted | Calendar events | claude.ai |
| `claude.ai Google Drive` | Google hosted | Drive files (needs auth) | claude.ai |

### Install chrome-devtools (user scope — available in all projects)

```bash
claude mcp add -s user chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

### Verify all servers

```bash
claude mcp list
```

All user-scope servers should show `✓ Connected` at Claude Code startup.

---

## Key Files

| File | Purpose |
|------|---------|
| `~/Allie/scripts/allie-mcp-server.py` | MCP server — the bridge |
| `~/Allie/scripts/team.sh` | Startup script — brings up the full team |
| `~/Allie/config/allie.Modelfile` | Allie's Ollama model definition |
| `~/.claude.json` | Claude Code config — MCP registration lives here (via `claude mcp add`) |
| `~/Allie/exchange/conversation.jsonl` | Exchange log — every tool call + response |
| `~/Allie/readmes/MCP_claude_allie.md` | This file |

#!/usr/bin/env bash
# ============================================================================
# team.sh — Start the Claude Code + Allie interactive team
#
# What this does:
#   1. Checks that Ollama is running (starts it if not)
#   2. Verifies the allie:latest model exists (rebuilds if missing)
#   3. Warms Allie's model into GPU memory (first response is fast)
#   4. Verifies the MCP server can start and respond
#   5. Launches Claude Code (which auto-starts the MCP bridge)
#
# Usage:
#   bash ~/Allie/scripts/team.sh           # full startup
#   bash ~/Allie/scripts/team.sh check     # just run checks, don't launch Claude
#   bash ~/Allie/scripts/team.sh warm      # warm Allie's model only
#
# The MCP server itself is NOT started here — Claude Code starts it
# automatically from ~/.claude.json (registered via `claude mcp add`).
# This script makes sure everything the MCP server depends on is ready
# before Claude launches.
# ============================================================================

set -euo pipefail

ALLIE_HOME="${HOME}/Allie"
MODELFILE="${ALLIE_HOME}/config/allie.Modelfile"
MCP_SERVER="${ALLIE_HOME}/scripts/allie-mcp-server.py"
OLLAMA_URL="http://localhost:11434"
MODEL="allie:latest"

# Colors for status output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'  # No Color

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }

echo ""
echo "══════════════════════════════════════════"
echo "  Team Startup — Claude Code + Allie"
echo "══════════════════════════════════════════"
echo ""

# ── Step 1: Ollama ──────────────────────────────────────────────────────
# Ollama serves all local LLMs (Allie, Athena, etc.) on port 11434.
# It may already be running as a macOS app or launchd service.

echo "Step 1: Checking Ollama..."

if curl -s "${OLLAMA_URL}/api/tags" > /dev/null 2>&1; then
    ok "Ollama is running"
else
    warn "Ollama not running — starting it"
    ollama serve > /dev/null 2>&1 &
    OLLAMA_PID=$!

    # Wait up to 10 seconds for Ollama to be ready
    for i in {1..10}; do
        if curl -s "${OLLAMA_URL}/api/tags" > /dev/null 2>&1; then
            ok "Ollama started (pid ${OLLAMA_PID})"
            break
        fi
        sleep 1
    done

    # Final check
    if ! curl -s "${OLLAMA_URL}/api/tags" > /dev/null 2>&1; then
        fail "Ollama failed to start after 10 seconds"
        echo "    Try: ollama serve   (or launch the Ollama app)"
        exit 1
    fi
fi

# ── Step 2: Allie model ────────────────────────────────────────────────
# The allie:latest model is built from ~/Allie/config/allie.Modelfile.
# It layers a system prompt and parameters on top of gpt-oss:20b.

echo "Step 2: Checking Allie model..."

if ollama list 2>/dev/null | grep -q "allie:latest"; then
    ok "allie:latest model exists"
else
    warn "allie:latest not found — creating from Modelfile"
    if [ -f "${MODELFILE}" ]; then
        ollama create allie -f "${MODELFILE}"
        ok "allie:latest created"
    else
        fail "Modelfile not found at ${MODELFILE}"
        exit 1
    fi
fi

# ── Step 3: Warm Allie into memory ─────────────────────────────────────
# First Ollama call loads the model into GPU/RAM (~5-10 seconds).
# Subsequent calls are fast. We warm it here so the first real
# ask_allie call in Claude Code doesn't have a long pause.

echo "Step 3: Warming Allie..."

WARM_RESPONSE=$(curl -s -X POST "${OLLAMA_URL}/api/chat" \
    -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Ready check. One sentence.\"}],\"stream\":false}" \
    2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('message',{}).get('content','FAIL')[:100])" 2>/dev/null) || WARM_RESPONSE="FAIL"

if [ "$WARM_RESPONSE" != "FAIL" ] && [ -n "$WARM_RESPONSE" ]; then
    ok "Allie responded: ${WARM_RESPONSE:0:60}..."
else
    fail "Allie did not respond — check: ollama run allie:latest"
    exit 1
fi

# ── Step 4: MCP server check ──────────────────────────────────────────
# The MCP server is the bridge between Claude Code and Allie.
# Claude Code starts it automatically — we just verify it CAN start.

echo "Step 4: Checking MCP server..."

if [ -f "${MCP_SERVER}" ]; then
    # Test that the server starts and responds to initialize
    MCP_OK=$(python3 -c "
import subprocess, time, json, os
proc = subprocess.Popen(
    ['python3', os.path.expanduser('${MCP_SERVER}')],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
)
init = json.dumps({'jsonrpc':'2.0','id':1,'method':'initialize',
    'params':{'protocolVersion':'2024-11-05','capabilities':{},
    'clientInfo':{'name':'test','version':'0.1'}}}) + '\n'
proc.stdin.write(init.encode()); proc.stdin.flush()
time.sleep(2); proc.stdin.close()
out = proc.stdout.read().decode().strip()
proc.terminate()
try:
    resp = json.loads(out)
    if resp.get('result',{}).get('serverInfo',{}).get('name') == 'allie':
        print('OK')
    else:
        print('FAIL')
except: print('FAIL')
" 2>/dev/null) || MCP_OK="FAIL"

    if [ "$MCP_OK" = "OK" ]; then
        ok "MCP server starts and responds"
    else
        fail "MCP server did not respond correctly"
        echo "    Debug: python3 ${MCP_SERVER}  (run manually to see errors)"
        exit 1
    fi
else
    fail "MCP server not found at ${MCP_SERVER}"
    exit 1
fi

# ── Step 5: Check MCP registration in ~/.claude.json ──────────────────
# MCP servers must be registered via `claude mcp add`, which stores
# them in ~/.claude.json (NOT ~/.claude/settings.json — that file
# holds permissions, hooks, and plugins only).

echo "Step 5: Checking Claude Code MCP registration..."

CLAUDE_JSON="${HOME}/.claude.json"
if [ -f "${CLAUDE_JSON}" ]; then
    if python3 -c "
import json
with open('${CLAUDE_JSON}') as f:
    cfg = json.load(f)
servers = cfg.get('mcpServers', {})
if 'allie' in servers:
    print('registered')
else:
    print('missing')
" 2>/dev/null | grep -q "registered"; then
        ok "Allie MCP server registered in ~/.claude.json"
    else
        fail "Allie not registered — run: claude mcp add -s user allie -- python3 ${MCP_SERVER}"
        exit 1
    fi
else
    fail "No ~/.claude.json found — run: claude mcp add -s user allie -- python3 ${MCP_SERVER}"
    exit 1
fi

# ── Step 6: Exchange log directory ────────────────────────────────────
# Every ask_allie / teach_allie / allie_recall / allie_flag call
# is logged here. Allie's nightly reflect reads this.

echo "Step 6: Checking exchange log..."

EXCHANGE_DIR="${ALLIE_HOME}/exchange"
mkdir -p "${EXCHANGE_DIR}"
ok "Exchange log directory ready: ${EXCHANGE_DIR}"

# ── Summary ───────────────────────────────────────────────────────────

echo ""
echo "══════════════════════════════════════════"
echo -e "  ${GREEN}All checks passed.${NC}"
echo "══════════════════════════════════════════"
echo ""
echo "  Ollama:      running on localhost:11434"
echo "  Allie:       allie:latest warm and responding"
echo "  MCP server:  verified — Claude Code will start it"
echo "  Exchange:    logging to ~/Allie/exchange/"
echo ""

# ── Launch or exit ────────────────────────────────────────────────────

MODE="${1:-start}"

if [ "$MODE" = "check" ]; then
    echo "  Check-only mode. Run 'claude' to start Claude Code."
    echo ""
    exit 0
fi

if [ "$MODE" = "warm" ]; then
    echo "  Warm-only mode. Allie is ready for the next Claude Code session."
    echo ""
    exit 0
fi

echo "  Starting Claude Code (yolo mode — no permission prompts)..."
echo "  (Allie MCP server will start automatically)"
echo ""

# Launch Claude Code in dangerously-skip-permissions mode.
# This means Claude Code won't prompt for tool approvals — edits, bash
# commands, file reads all execute immediately. Bill prefers this for
# interactive work sessions where stopping to approve every action
# breaks flow. The alias 'claude-yolo' does the same thing standalone.
exec claude --dangerously-skip-permissions

# Chrome DevTools MCP — Team Reference
**Created:** 2026-07-03
**Purpose:** How the team uses Chrome DevTools MCP to inspect, debug, and test the browser directly from Claude Code sessions.

---

## What It Does

Chrome DevTools MCP gives Claude Code direct access to the browser:
- Navigate pages, click elements, fill forms
- Read console messages and network requests
- Take screenshots and heap snapshots
- Run Lighthouse audits
- Execute JavaScript in page context
- Inspect and debug React/Django responses in real-time

This replaces the manual cycle of "describe what you see" / "paste the error" / "try this". Claude Code sees what the browser sees.

---

## Setup — Two Parts

### Part 1: Chrome with Remote Debugging

Chrome must be running with `--remote-debugging-port=9222` for the MCP server to connect.

**Chrome Debug app** (installed at `/Applications/Chrome Debug.app`):
- Wrapper that launches Chrome with the debug port always enabled
- Uses your normal Chrome profile — same bookmarks, extensions, login state
- Drag it to the Dock, use it instead of regular Chrome

To add to Dock: open Finder, go to `/Applications/`, drag "Chrome Debug" to your Dock. Optionally remove the regular Chrome from the Dock to avoid confusion.

**Manual launch** (if you prefer):
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
```

**Separate debug profile** (if you want isolation):
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --remote-debugging-port=9222 \
    --user-data-dir="$HOME/.chrome-debug-profile"
```
This creates a clean browser with no extensions, no login state. Useful for testing.

### Part 2: MCP Server Registration

Already registered in Claude Code:
```
chrome-devtools: npx -y chrome-devtools-mcp@latest
```

No configuration needed — the MCP server auto-detects port 9222.

---

## Security

`--remote-debugging-port=9222` binds to **localhost only** (`127.0.0.1`).

- **Not reachable from the network** — nobody on WiFi, no remote attacker
- **Reachable by any local process** — any app on the Mac can connect and control the browser (read pages, execute JS, access cookies)
- **Acceptable risk on a single-user dev machine** — the processes that could abuse this already have filesystem and keychain access
- **Do not use on shared machines** or machines running untrusted software

---

## How the Team Uses It

### Claude Code
Uses Chrome DevTools MCP tools during sessions to:
- Debug auth token issues (inspect network requests, see 403s directly)
- Verify React renders after code changes
- Test DataBrowser layout saves end-to-end
- Take screenshots for documentation

### Alice
Console capture (`consoleCapture.ts`) auto-flushes errors and warnings to `alice_observation` every 60 seconds. This feeds Alice's pattern recognition loop — she sees what the browser sees without needing DevTools MCP directly.

### Allie
Allie does not use Chrome DevTools directly. She reads Alice's observations and Claude Code's session logs for browser-side insights.

---

## Common Operations

```
# Navigate to a page
mcp chrome-devtools navigate_page url="http://localhost:8000/admin-wb/"

# Take a screenshot
mcp chrome-devtools take_screenshot

# Read console errors
mcp chrome-devtools list_console_messages

# See network requests (find 403s, 500s)
mcp chrome-devtools list_network_requests

# Click a button
mcp chrome-devtools click selector="#save-button"

# Fill a form field
mcp chrome-devtools fill selector="#username" value="bill@jpods.com"

# Run JavaScript in page context
mcp chrome-devtools evaluate_script expression="localStorage.getItem('access_token')"

# Lighthouse audit
mcp chrome-devtools lighthouse_audit
```

---

## Troubleshooting

**"Cannot connect to Chrome"**
- Is Chrome running? Check: `lsof -i :9222`
- Was it launched with `--remote-debugging-port=9222`? Check: `ps aux | grep remote-debug`
- If using regular Chrome (not Chrome Debug), it won't have the port open

**Two Chrome instances running**
- If you launched both regular Chrome and Chrome Debug, you'll have two instances with separate profiles
- Close regular Chrome, use Chrome Debug for everything
- Or: close Chrome Debug and use regular Chrome when you don't need MCP

**Port already in use**
- Another process has 9222: `lsof -i :9222` to see what
- Or a previous Chrome didn't shut down cleanly: `kill` the stale process

---

## Files

| File | What it is |
|------|-----------|
| `/Applications/Chrome Debug.app` | Wrapper app — launches Chrome with debug port |
| `~/.claude.json` → `mcpServers.chrome-devtools` | MCP server registration |
| `React2025/src/utils/consoleCapture.ts` | Browser-side console capture for Alice |

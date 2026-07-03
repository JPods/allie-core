---
name: Chrome DevTools MCP setup
description: Chrome 150 requires --user-data-dir for debug port; Chrome Debug app at /Applications/; firewall must allow; readme at readmes/46-chrome-devtools-mcp.md
type: reference
---

Chrome 150 requires `--remote-debugging-port=9222 --user-data-dir="$HOME/.chrome-debug-profile"` — won't open debug port without user-data-dir. Uses separate profile from normal Chrome.

**Chrome Debug app:** `/Applications/Chrome Debug.app` — kills existing Chrome, launches with debug flags. Shell alias `chrome-debug` in ~/.zshrc.

**Firewall:** macOS firewall must allow Chrome incoming connections (System Settings → Network → Firewall → Options). Port 9222 binds localhost only — safe on single-user dev machine.

**MCP server:** `chrome-devtools` registered in ~/.claude.json. Auto-detects port 9222.

Full readme: `~/Allie/readmes/46-chrome-devtools-mcp.md`.

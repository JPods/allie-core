---
name: DevTools browser launch command
description: Bill says "launch DevTools" or "DevTools browser" to mean open Chrome DevTools MCP for visual testing
type: feedback
---

When Bill says "launch DevTools" or "DevTools browser", open Chrome DevTools MCP, navigate to the relevant page, and start taking screenshots/interacting.

**Why:** Bill has multiple Chrome windows. The DevTools MCP browser is the one Claude can see and control. Calling it "DevTools" distinguishes it from Bill's regular browser.

**How to apply:** On "launch DevTools", use mcp__chrome-devtools__navigate_page to go to the relevant URL (usually localhost:5173), then take a screenshot to confirm it loaded.

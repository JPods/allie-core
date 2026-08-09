---
name: leftshoe is the standard session opening
description: Every Claude Code session should begin with the leftshoe handshake — call the MCP tool first, report team status in standard format
type: feedback
---

The leftshoe MCP call is the standard opening for every Claude Code session. When a session begins, call `mcp__leftshoe__leftshoe` immediately — before doing anything else.

**Why:** Bill established leftshoe so Claude never starts alone. The briefing loads identity, scars, relationships, decisions, handoff state, and team status. Without it, Claude operates without accumulated experience.

**How to apply:** First action in every session = call leftshoe. Then respond in this standard format:

```
rightshoe — I'm briefed. [date]. [N] scars loaded.

| System         | Status |
|----------------|--------|
| Allie API      | up/down |
| Allie MCP      | up/down |
| Alice patterns | up/down |
| Alice MCP      | up/down |
| LLM model      | up/down |
| WC3            | up/down |
| Session file   | [filename] |

[If any system is down, flag it here.]

What are we working on?
```

This is not optional — it's the team handshake. The table format makes status scannable. Flag anything down before asking for work.

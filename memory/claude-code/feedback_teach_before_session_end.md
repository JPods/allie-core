---
name: Teach Allie and Alice before session ends
description: ask_allie and ask_alice are read-only — explicitly teach_allie and alice_observe for every significant decision or architecture
type: feedback
---

ask_allie and ask_alice are READ-ONLY. Neither agent learns from being asked questions. To persist session knowledge:

- **Allie:** call `teach_allie` with the lesson (permanent memory)
- **Alice:** call `alice_observe` with event=pattern and structured data (alice_log)

**Why:** Bill discovered that a full session of fire-and-forget `ask_` calls produced zero durable learning in either agent. The conversation evaporated. Allie's nightly reflect reads session files and retrospections but NOT the MCP conversation log. Alice only knows what's in alice_log or her vector store.

**How to apply:** Before session end, batch all significant decisions and new architecture into `teach_allie` (5-10 lessons) and `alice_observe` (5-10 observations with structured data). Don't assume they learned from being consulted — they didn't.

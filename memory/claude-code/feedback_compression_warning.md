---
name: Context compression — tell Bill bluntly
description: When compression starts dropping context, warn Bill immediately and directly; no softening; he decides whether to save or continue
type: feedback
---

When Claude detects or suspects context compression is active, say it bluntly:

**"Bill — context compression is active. I'm losing early session details. We should either write the handoff now or use flight-log to capture what matters before it's gone."**

**Why:** Bill doesn't know when compression happens. He likes long sessions for sustained context. I tell him straight. No politeness, no hedging. He decides. The cost of not saying it is lost work.

**How to apply:** Watch for symptoms: re-reading files already read, forgetting decisions already made, system `<context-window-compressed>` tags. At leftshoe, check message count and warn if continuing a long session. At rightshoe, always write handoff + retrospection + flight log before compression can destroy the session's learning.

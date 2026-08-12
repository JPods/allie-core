---
name: Pattern of behavior drives architecture, not schema
description: Group by behavior pattern (how it's used), not by data model (what it describes)
type: feedback
---

The pattern of behavior is the driving decider, not the schema.

**Why:** Bill corrected when dd-card architecture was being organized by model (one Setting per model). The right organizing principle is the behavior pattern — all dd-cards behave the same way, so they belong in one place. Schema (which model) is secondary to behavior (what the user does with it). This applies everywhere: Settings, UI components, API endpoints. If two things behave the same way, they belong together regardless of which model they serve.

**How to apply:** When designing any Setting, component, or feature, ask "what is the behavior pattern?" first, not "what model does this serve?" Group by behavior. A dd-card for orders and a dd-card for invoices have the same behavior pattern — they belong in the same Setting. A dd-card and a workbench layout serve different behaviors — they belong in different Settings, even though they might serve the same model.

---
name: Double-click for detail, single-click for emphasis
description: Single click = 5s visual emphasis (meeting pointing); double click = open detail; prevents accidental navigation during conversations
type: feedback
---

Single click on Gantt task bars = 5-second blue outline emphasis, then fades. Double click = opens detail editor.

**Why:** Bill: "when users are talking with their hands and click a tag to emphasize it, they do not open the detail.tsx"

**How to apply:** All interactive elements that open detail panels should use double-click, not single-click. Single click should provide visual feedback (emphasis border) without navigation. Applies to Gantt, Kanban, DataBrowser cards, and any future interactive displays.

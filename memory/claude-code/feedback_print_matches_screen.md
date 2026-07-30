---
name: Print output must match screen richness
description: Gantt print should carry the same visual encoding (priority/status/progress/assignee) as on-screen bars — not dumbed-down plain rectangles
type: feedback
---

Print output must match the on-screen visual encoding — priority stripe, status stripe, % complete bar, assignee badge, CP indicator. Plain blue rectangles throw away data the user already built.

**Why:** Bill saw the contrast between the rich on-screen bars and the flat print output and called it out. "Radically better" when fixed.

**How to apply:** Any time a new output mode is added (print, export, PDF, email), replicate the full GanttTaskTemplate encoding. Use the shared `renderPrintBar` helper in UnifiedGantt.tsx. Don't simplify for print — the richness is the point.

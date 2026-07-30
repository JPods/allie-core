---
name: Gantt chart enhancements
description: Open-source enhancements to @svar-ui/react-gantt — layered task bars, font scaling, meeting-friendly clicks, project hierarchy, text overflow
type: project
---

Open-source enhancements to @svar-ui/react-gantt built July 2026.

**Why:** Base SVAR Gantt is display-only. Real project management needs visual encoding, meeting interaction, accessibility controls.

**How to apply:** These are production code in WebClerk3 and standalone examples for open source at `React2025/src/apps/utils/gantt/open-source-example/`.

Enhancements:
1. Layered task bar template — 4 visual channels (priority stripe, status stripe, % complete bar, assignee badge)
2. Color modes — priority/status/who/project switchable via toolbar
3. A+/A- font scaling — no limits, persists to contact.metadata.wcui.gantt_font_scale, uses CSS custom properties to cross SVAR component boundary
4. Text overflow toggle — "Show full text" checkbox lets text run past bar edges
5. Single click = 5s blue outline emphasis (meeting pointing gesture); double click = open detail
6. Hover tooltip — native title with task data
7. Frozen top 2 rows — CSS sticky on .wx-row:nth-child
8. Project hierarchy — click parent selects all descendants; ▸/└ visual indicators
9. Priority colors: critical=red, high=orange, medium=light blue, low=light gray

Key technique: CSS custom properties (`--gantt-text-overflow`, `--gantt-font-scale`) set on container div are inherited through SVAR's internal DOM. This crosses the component boundary without forking.

ERP bridge pattern: trading partners wedded to their ERP can install WC3 as a display bridge — sync via Connection+Bundle, view in this Gantt. Or drop the standalone files into their own React app.

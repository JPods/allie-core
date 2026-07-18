---
name: Shift-for-Help interaction standard
description: Cross-project standard — Shift+hover for tooltip, Shift+click for deep help; one modifier key, universal; standard doc at readmes/wisdom/shift-for-help.md
type: feedback
---

Shift-for-Help is the cross-project interaction standard for all JPods UIs.

- **Shift+hover** any element with `data-help` → styled tooltip explaining what it does
- **Shift+click** any element with `data-help` → open deep help panel or send agent request

**Why:** One modifier key to remember across all projects. Simpler than WC3's original Cmd+Option+Shift triple-modifier. Shift has no browser-default conflict on buttons.

**How to apply:** Every new button, field label, or interactive element should get a `data-help="..."` attribute. For input fields, attach Shift+click to the label, not the input (avoids text-selection conflict). Implementation pattern (JS + CSS) is in readmes/wisdom/shift-for-help.md. First-visit hint auto-dismisses after 15s.

**Implemented in:**
- su_jpods console.html (2026-07-18) — nav, workflow, model buttons, test toolbar
- WC3 BehaviorField.tsx (2026-07-18) — simplified from triple-modifier to Shift-only
- WC3 HelpDashboard.tsx shortcuts table updated

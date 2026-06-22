---
name: Console rework must be duplicate window
description: Bill is used to the current JPods Console and wants to be careful with it. Any rework must be a duplicated window, not a replacement. Don't break what works.
type: feedback
---

Bill said: "If we are to rework the JPods Console, it needs to be a duplicated window. I am used to this JPods Console and want to be careful with it."

**Why:** The console has 122 JS functions, complex view switching, and behaviors Bill relies on daily. Breaking it means losing the working tool.

**How to apply:** When modifying console.html, make minimal targeted edits. For a full rework, create a new dialog file alongside the existing one. Test changes on a copy first. The HTML dialog doesn't always adapt to reloads — mandate SU restart for HTML changes.

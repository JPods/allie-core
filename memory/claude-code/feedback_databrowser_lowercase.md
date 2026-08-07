---
name: databrowser is always lowercase
description: Always use "databrowser" not "DataBrowser" in UI, routes, docs, and conversation — users ignore case if we do
type: feedback
---

Always refer to databrowser in lowercase — "databrowser", never "DataBrowser".

**Why:** Users will not pay attention to case if we are not disciplined about it. Consistent lowercase prevents confusion between route names, model names, and component references.

**How to apply:** All UI labels, route paths, window titles, documentation, and conversation should use "databrowser". The React component filename (`DataBrowser.tsx`) follows React convention but the user-facing name is always lowercase.

---
name: Daily start and close practice
description: Start — check for existing like functions before writing new code. Close — audit for overlap, consolidate into reusable functions, create test checklist as WC3 action records in weekly project
type: feedback
---

**Daily Start Practice:**
Before writing any new function, check:
1. Does a like function already exist? (grep the codebase)
2. Does this function belong in an existing class/hook/utility?
3. Is there a shared component that should be extended rather than duplicated?

If yes → extend/reuse. If no → create it in the right place (hook, component, utility) from the start.

**Daily Close Practice:**
1. Review all code written today — does anything overlap with existing functions?
2. Can any new code be consolidated into single-purpose reusable functions?
3. Create Action records in WC3 for testing checklist — one action per testable item
4. Actions go into the current week's Project record (one project per week for code development)

**Why:** This session produced BehaviorField, useDataBrowser, useListFieldConfig, FieldConfigBar, CommunicationsPanel, OrgPage, DetailLayoutDialog, ReportMenu — all reusable. But we only refactored AdminWorkbench AFTER it hit 1064 lines. The practice catches this earlier.

**How to apply:** At session start, read this memory. Before writing any function, search first. At session end, audit and create action records via wcapi (which is the only gate for CRUD).

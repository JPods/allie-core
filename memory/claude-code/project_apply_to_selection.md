---
name: Apply to Selection + Script Editor
description: DataBrowser needs Apply to Selection button + user script drafting; WC2 SummaryText pattern; Django admin actions; store scripts in Document records
type: project
---

Bill wants two features for the DataBrowser list toolbar:

1. **Apply to Selection** — execute a function against all selected records.
   Django admin has this (bulk actions dropdown). WC2 had an "Apply To Selection"
   dialog. Needs a glass button in the list toolbar.

2. **Script Editor / Summary Text** — user-drafable short functions.
   WC2's SummaryText was a script editor where users could:
   - Write short scripts
   - Save as named snippets (stored in TallyMaster with purpose='ScriptDrafts')
   - Execute against records (ExecuteText)
   - Insert field references, data tags, templates
   - Build text from field lists and object maps
   
   WC2 source: `00WebClerk19/Project/Sources/TableForms/1/SummaryText/`

**How to apply:** Scripts should be stored in Document records (same as QA templates).
User writes a script in a code editor panel, saves it as a Document with
refs.keywords=['user_script']. Apply to Selection lists available scripts and
executes the selected one against all selected records via wcapi.

**Why:** Power users need batch operations without programmer intervention.
Price updates, status changes, tag assignment, data cleanup — all should be
self-service. WC2 proved this works.

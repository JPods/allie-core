---
name: WC keyboard modifier standard
description: All WC click modifiers: click=select, shift=help, cmd/ctrl=toggle, option+cmd/ctrl=destroy panel; no checkboxes
type: feedback
---

## Row Selection (lists/tables)
No checkboxes. The row is the selection target.
- **Click** = select that row (clears others)
- **Shift+click** = range select between last click and this one
- **Cmd/Ctrl+click** = toggle individual row in/out of selection

## Label Interactions
- **Shift+click** label = field help (Shift-for-Help standard)
- **Cmd/Ctrl+click** label = quick select list editor
- **Cmd/Ctrl+Shift+click** label = full behavior override dialog (admin)

## Panel Headers
- **Click** = collapse/expand
- **Option+Cmd/Ctrl+click** = remove panel (destructive — confirm if records linked, no confirm if empty; core panels contact/touch/action cannot be removed)

**Why:** Bill: checkboxes are tiny targets; the row is a better object. Destructive actions (Option+Cmd) require two modifier keys — deliberate, not accidental. Core panels are protected.

**How to apply:** Every list/table view, every field label, every panel header in WC. DataGrid, LinkedRecordsPanel, DbColumns, BaseField, BehaviorOverrideDialog.

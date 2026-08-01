---
name: WC list selection standard — no checkboxes
description: All WC list/table views use row-click selection (click=select, shift=range, cmd/ctrl=toggle); no checkboxes; standard browser behavior
type: feedback
---

No checkboxes in list views. The row is the selection target.
- Click = select that row (clears others)
- Shift+click = range select between last click and this one
- Cmd/Ctrl+click = toggle individual row in/out of selection

**Why:** Bill: checkboxes are tiny targets; the row is a better object. This matches standard browser/OS behavior (Finder, Explorer, email clients).

**How to apply:** Every list/table view in the WC ecosystem — DataBrowser, Statement Sorter, any future list UI. Documented at readmes/topics/ui/list-selection-standard.md. Reference impl: DataGrid.tsx handleRowClick, Statement Sorter handleRowClick.

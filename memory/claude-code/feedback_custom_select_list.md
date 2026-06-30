---
name: Custom select list is the standard — no native selects
description: The keyboard-navigable div list (type to filter begins-with, arrow up/down to highlight, Enter to select, click to select, auto-scroll) is the standard select pattern for wc3. No native HTML selects.
type: feedback
---

The custom filterable select list built for the DataBrowser model picker is the standard pattern for ALL select lists in wc3:
- Text input with begins-with filtering
- Div list below with highlighted row
- Arrow Up/Down moves highlight
- Enter selects highlighted item
- Click selects
- Escape closes
- Highlighted item auto-scrolls into view
- Current selection shown bold

**Why:** Native HTML `<select>` can't be styled, can't show highlighted rows, can't do begins-with filtering, and looks different on every OS. The custom div list gives consistent UX everywhere.

**How to apply:** Extract into a reusable `FilterSelect` component. Use it everywhere we currently use `<select>` — model picker, status selects, price level, org type, GL account lookup, campaign picker, any dropdown. The component should accept: items[], value, onChange, placeholder, filterMode ('startsWith' | 'contains').

---
name: Post or Pend — edit rule for all fields
description: Unlocked records post changes immediately; locked records create pending records needing release
type: feedback
---

**Post or Pend** — the shorthand for the universal edit rule.

- **Unlocked:** post now (change takes effect immediately)
- **Locked:** post to pending (creates pending record, needs release/approval)

**Why:** Non-inventory fields follow this pattern on every transaction. It prevents unauthorized changes to completed/invoiced/shipped records while still allowing corrections to flow through an approval path.

**How to apply:** Every field edit on every transaction detail page. The `edit_rules.locked_statuses` in the detail_layout Setting determines which statuses lock the record. When locked, edits create Pending records instead of direct writes.

**Modifier keys for field labels (detail views):**
- Click = select/focus field
- Double-click = inline edit value
- Shift+hover = tooltip
- Shift+click = deep help
- Cmd+Option+click on label = open field's Setting record (admin edits the select list / field config)

**Established:** 2026-08-01 by Bill James

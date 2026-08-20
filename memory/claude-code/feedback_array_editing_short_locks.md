---
name: Users edit arrays, not database records — lock only on save
description: All editing happens in-memory arrays; DB records lock only during the save loop; applies to lines, customers, all models
type: feedback
---

Users work with arrays in memory, never with locked database records. The database is for persistence, not editing.

**Why:** Database locks while a user is thinking block other users and waste resources. FK resolution during editing causes round-trips and errors (like the item_fk ValueError). The WC2 pattern worked: edit an array, send it back, server handles persistence.

**How to apply:**
- React holds working copies as arrays/objects in state
- No DB round-trips during editing — validate on Save only
- On Save: server loops through the array, creates/updates records, fires downstream consequences (pending, source adjustments), releases locks
- Lock window = the save loop only — milliseconds, not minutes
- Applies to ALL models: lines, customers, proposals, orders, everything
- Conversion creates header + copies data into array for React — no line records until Save

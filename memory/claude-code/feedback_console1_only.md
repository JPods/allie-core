---
name: Console 1 is the console — stop duplicating to c2
description: Console 1 (dialogs/console.html) is the primary UI; easier to teach; stop maintaining c2 in parallel
type: feedback
---

Console 1 (dialogs/console.html) is the console. Bill chose it — easier to teach, has all features, familiar layout.

**Why:** Duplicating every feature into c2 (ui/dialogs/console.html) doubles the work and they drift out of sync. c2 is incomplete and missing many c1 features.

**How to apply:** New features go in c1 only. Don't add to c2. c2 stays as-is but is not actively maintained. If c2 layout ideas are good (splitter, cleaner panels), port them into c1.

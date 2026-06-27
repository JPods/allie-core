---
name: Simple passwords are fine in dev
description: Bill uses pass1111/1111pass for all agent accounts during single-machine development; don't flag or suggest changes until production cutover
type: feedback
---

All agent passwords in dev are simple (`pass1111`, `1111pass`). This is intentional — single-machine development, no exposure.

**Why:** Bill explicitly stated this is acceptable for dev. Don't waste time on password complexity until production cutover.

**How to apply:** Don't suggest stronger passwords during dev work. The production-cutover.md checklist covers password changes before going live.

---
name: Alice sync — rsync now, Bundle at launch
description: Mac→Andi via rsync always; Andi→Mac via rsync now, switches to WC3 Bundle model at launch to dogfood the product
type: project
---

Two-phase sync architecture for Alice learning between Mac and Andi (IT15):

**Phase 1 (now):** rsync both directions via `allie-andi-sync.sh`
- Mac → Andi: knowledge, scripts, readmes (already built)
- Andi → Mac: Alice learnings (needs pull mode added)

**Phase 2 (go-live):** hybrid
- Mac → Andi: rsync (Bill controls timing, no waiting)
- Andi → Mac: WC3 Bundle model (Connection + Bundle sync). Alice on Andi is the first real customer of the sync product. If it's flaky, she knows first.

**Why:** Bill doesn't want to wait for Andi to update (rsync is instant push). But Andi→Mac should use the product to test it. Dogfooding the Bundle model validates it before offering to customers.

**How to apply:** When building Alice's learning pipeline on Andi, write learnings as .md files that the Bundle model can serialize. Don't build a format that only works with rsync.

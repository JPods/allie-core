---
name: Revert and ship beats elegant and broken
description: When a working simple approach builds correctly and the elegant replacement breaks, revert and ship; don't hold working code hostage
type: feedback
---

When the working simple approach builds correctly and the elegant replacement breaks, revert and ship. The proper fix is documented (TFTS, ouch list) for later — don't hold working code hostage to a better architecture.

**Why:** Session 2026-06-23 — terrain raycast worked with bounding-box skip. "Proper fix" (raycast into terrain Entities directly) hit two SketchUp API limitations: Entities has no raytest, Point3d.z requires Float not Symbol. Three attempts, three failures, Bill waiting. Reverted, Build worked immediately.

**How to apply:** Before replacing working code with a cleaner approach, verify the new approach actually works in SketchUp's Ruby (not standard Ruby). Test the API call exists. If the replacement fails, revert immediately — don't iterate on a broken replacement while the working version sits in git.

---
name: Layout marketplace concept
description: Users submit DataBrowser layouts for credit/cash bonuses; Alice manages submissions, tracks adoption, rewards contributors
type: project
---

Users who build useful DataBrowser layouts can submit them to WebClerk HQ for credit or cash bonuses. Once users have their 1-5 preferred views set up, they rarely change — so the valuable work is finding the right field combinations for each model/role.

**Why:** Same bottom-up pattern as Small-Stings in reverse. Value created by users, rewarded by the platform.

**How to apply:** Alice owns the submission/adoption/reward flow. Track which submitted layouts get adopted by other users. Most-adopted layouts reveal which fields actually matter per model — feeds back into defaults. Build when Alice has her own LLM and the DataBrowser is in production use.

**Transport:** Layouts submitted via sync (Connection + Bundle model, readmes/21-sync-integration.md). Layout = Setting record with purpose=workbench_fields. Bundle it, sync to HQ, Alice reviews and promotes. No separate upload mechanism.

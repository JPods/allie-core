---
name: Alpha and best_guess layouts are protected — cannot be overwritten by Save
description: The 'alpha' and 'best_guess' named layouts are system layouts. Save Layout must not overwrite them. Only WCHQ sync or seed commands can update them. Users create their own named layouts alongside.
type: feedback
---

'alpha' and 'best_guess' are protected layout names. The Save Layout function must reject these names or create a copy with a different name. Only seed_databrowser --force or WCHQ sync can update them.

**Why:** These are Alice's baselines for comparison. If users overwrite them, Alice loses her reference point for learning what fields users actually prefer.

**How to apply:** FieldOrderDialog Save handler must check if name is 'alpha' or 'best_guess' and refuse. Show a message: "This is a system layout. Save with a different name."

**Only Alice changes best_guess:** When Alice updates best_guess based on user behavior, she must add agent learning notes explaining WHY the change was made — which user layouts differed, what pattern she observed, what fields moved up or down in priority. Notes go in the view's metadata.

**Layout dropdown order:** User-created layouts first (alphabetical), system layouts (alpha, best_guess) always at the bottom, labeled "(system)". Delete button hidden for system layouts.

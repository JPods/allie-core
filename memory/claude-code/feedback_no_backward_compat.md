---
name: No backward compatibility — one path only
description: Bill's explicit rule — no aliases, no fallbacks, no legacy shims. We are the only users. Delete and update callers.
type: feedback
---

No backward compatibility. One path only. Bill said: "We are the only users. We do not want backward compatible. We want 1 path."

**Why:** Backward-compat shims are a second source of truth. They create two paths to the same result, which means two paths that can diverge. Every alias, fallback, and "kept for backward compatibility" comment is a place where the wrong path can be called. The shim looks free but costs debugging time when someone calls the alias instead of the canonical function.

**How to apply:**
- Never create aliases "for backward compatibility" — update the callers instead
- Never create fallback paths — if the canonical path is the right one, make it the only one
- When consolidating (registries, utilities, computations), delete the old versions entirely
- If you find `_LazyDict`, `backward compat`, `legacy fallback`, or similar patterns — delete the shim, update the callers
- The cost of breaking a caller and fixing it immediately is lower than the cost of maintaining two paths indefinitely

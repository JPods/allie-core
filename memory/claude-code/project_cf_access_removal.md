---
name: CF Access removed — sites public
description: Cloudflare Access applications deleted for meshmobility.com and webclerk.com; sites now public; auth handled at app level
type: project
---

CF Access applications deleted 2026-07-22 for both meshmobility.com and webclerk.com.

**Before:** Both sites 302 redirected to CF Access login page. Nobody could see anything without email OTP.

**After:**
- meshmobility.com — fully public. Landing, /app, /library, /citytool all accessible.
- webclerk.com — landing page public at /. Staff sign in at /login. /admin/ and /wcapi/ require auth.

**Auth model (Desktop Hosting pattern):**
- Public: browse, view, read — no login needed
- Authenticated: edit, save, clone — requires sign-in
- meshmobility.com uses `auth.js` + `auth.py` with CF email header for authenticated users
- webclerk.com uses Django session auth at /login

**Why:** CF Access "Allow everyone" still forces login. "Bypass" or deleting the application is required for truly public access. The app-level auth handles view-vs-edit gating.

**How to apply:** Never put CF Access back on public-facing pages. If access control is needed, do it at the application level (auth.js/auth.py for MM, Django auth for WC3). CF Access is only appropriate for admin-only services.

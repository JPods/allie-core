---
name: WC3 access control — app-level auth + role-based views
description: CF Access removed 2026-07-22; auth at app level; is_staff gates admin; vendor/mfr see own products via Setting
type: project
---

**Access tiers for webclerk.com (updated 2026-07-22):**
- Landing page `/` → public (Nginx serves static HTML)
- `/login` → React login page (Django session auth)
- `/admin/` → Django admin (requires is_staff)
- `/wcapi/` → API (requires auth token)
- All other React routes → require login via React app

**CF Access removed:** Applications deleted from Cloudflare Zero Trust 2026-07-22. Auth now entirely at app level. Cloudflare tunnel still provides HTTPS + proxying but no login wall.

**Auth flow (current):**
- webclerk.com: Django session auth at /login → is_staff gates admin
- meshmobility.com: auth.js checks CF email header (if present) → Guest or Authenticated → edit/save gated by Auth.requireAuth()

**Role mapping (future):**
- staff → full DataBrowser access
- reps → customer-facing views, orders, contacts
- vendors → their products, inventory levels, pricing
- manufacturers → their products, suggested retail, inventory limits

**Why:** CF Access "Allow everyone" still forces login. App-level auth gives view-public/edit-authenticated — the Desktop Hosting pattern.

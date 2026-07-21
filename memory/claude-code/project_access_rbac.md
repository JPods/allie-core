---
name: WC3 access control — CF Access + role-based views
description: Cloudflare Access for auth; is_staff gates admin; vendor/manufacturer see their published products via Setting+metadata
type: project
---

**Access tiers for webclerk.com:**
- Landing page / storefront → open (no login)
- All other routes → requires `is_staff=True`
- Future vendor/manufacturer access: see their own published products

**Vendor/manufacturer data visibility (design, not yet active):**
- item.manufacturer and item.vendor fields determine which vendor/manufacturer sees what
- Visibility rules defined in the Setting record for the manufacturer model
- Can be overridden per-manufacturer in that manufacturer's record metadata
- Default data points to show: suggested retail prices, inventory, min/max inventory limits

**Role mapping (future):**
- staff → full DataBrowser access
- reps → customer-facing views, orders, contacts
- vendors → their products, inventory levels, pricing
- manufacturers → their products, suggested retail, inventory limits

**Auth flow:**
- Cloudflare Access email OTP → verified email in CF header
- App reads header → creates/finds WC3 Contact
- Contact.is_staff gates admin access
- Vendor/manufacturer access controlled by field_access Setting pattern (already built)

**Why:** Test with real users first. Don't build vendor/manufacturer views until staff access is proven and users request it.

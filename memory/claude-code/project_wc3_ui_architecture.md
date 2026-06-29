---
name: WC3 UI architecture — themes, templates, communications
description: Multiple React templates for different business types; theme library system; org-contact many-to-many relationships; communications as source of truth
type: project
---

**Multi-org identity:** A contact can relate to ALL org types simultaneously. A customer can also be a vendor and a rep. OrgBase.contact FK is one-to-one per org, but Contact has FKs to customer, vendor, manufacturer, employee, rep — all nullable. Communications (email, phone, address, domain) link through Contact, not directly to org.

**React template libraries:** Different businesses need different looks. A law firm, a restaurant, a hardware store, a chimney service — each needs different page layouts, color schemes, and field emphasis. The approach:
- Theme tokens (colors, fonts, spacing) as JSON config
- Layout templates (which components, what order, what emphasis)
- Multiple templates per page type (e.g., 3 different InvoiceDetail layouts)
- Template library where users can browse, preview, and adopt
- Eventually submit custom templates for bonus credit (via sync, same as layouts)

**Communications source of truth:** Communication records (Email, Phone, Address, Domain) via FK to Contact are the truth. Contact.emails and OrgBase.emails JSON aspects are caches. Current problem: caches go stale with no auto-sync. Fix: post_save hooks on Communication models rebuild Contact + OrgBase aspects.

**How to apply:** Build a theme/template system with JSON-driven configuration. Start with 2-3 business templates (professional services, retail, field service). Template selection stored in Settings. Components read theme tokens for styling. Library of templates grows via user submissions.

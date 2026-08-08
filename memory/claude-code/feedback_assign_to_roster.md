---
name: assigned_to is a project roster, not just internal team
description: Project assigned_to includes vendors, manufacturers, customers — anyone with a stake; role determines field access; first entry is Responsible Person
type: feedback
---

assigned_to on actions is a project roster — not limited to internal team. Vendors, manufacturers, customers, reps can all be assigned to a project and see its data scoped by their role.

**Why:** Bill said contacts from vendors, manufacturers, customers can be part of a project with access to that project's data. The project is the collaboration boundary, not the org chart.

**How to apply:** When building assigned_to select lists or project team UIs, don't filter to internal contacts only. The project's `prefs.assigned_to[]` entries carry `{id, name, role, org}` — role maps to field_access RBAC (vendor sees vendor.view, customer sees customer.view). First entry is the Responsible Person by convention. Three-tier fallback: project → setting → crew seed.

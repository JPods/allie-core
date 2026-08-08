---
name: Label IS the select — WC3 norm for expert UIs
description: For fields with options, the label itself becomes the select/dropdown; colored per standard; experts look at labels; non-standard answers allowed
type: feedback
---

For fields with select options, the label IS the select. Not a label above a separate dropdown — the label text is the interaction point.

**Why:** The colored label IS a broken trail. Users know how to follow it — they see color, they know there's a choice. A field-as-selector hides the path. A label-as-selector marks it. This is onboarding built into every form — no documentation needed, the trail is visible. This is an expert UI, not retail — if users want to enter a non-standard answer, they have a reason.

**How to apply:** In DynamicDetail and any form renderer, if a field has choices, the label IS the select. Always — users expect it in WC3. Edit mode renders the label as a colored select (no border, font-mono). Display mode shows the current value as colored label text. The select is a trail, not a fence — if a user types something not on the list, the system accepts it. They are sovereign. They have a reason. No blocking, no warnings, no "are you sure." This applies to status, priority, difficulty, percent_complete, kanban_column, assigned_to, and any future field with choices.

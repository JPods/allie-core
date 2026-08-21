---
name: Two kinds of JSONField — display vs structural
description: JSONFields are either i18n display objects ({"en":"text"}) or structural envelopes (config, metadata, refs) — field_behaviors treats both as type='json', causing display fields to render as JSON trees
type: feedback
---

JSONFields in Django serve two fundamentally different purposes:
1. **Display objects** — `{"en": "text"}` language objects (action, description, assigned_to). These are text fields that happen to use JSON for multi-language.
2. **Structural envelopes** — config, metadata, refs, prefs. These are real JSON trees with nested structure.

`field_behaviors.py` marks ALL JSONFields as `type: 'json'`. This causes display objects to render as JSON tree widgets instead of text fields.

**Why this matters:** `behavior.type` is an assertion that short-circuits auto-detection in `renderField`. The current fix (override `type='json'` when `isSimpleObj` is true) works but is a runtime guess. The Pydantic schema should carry this distinction explicitly — it knows which JSONFields are i18n display vs structural.

**How to apply:**
- When building field behaviors into Pydantic schemas, mark i18n display fields as `type: 'i18n'` or `type: 'text'`, not `type: 'json'`
- Until then, the `isSimpleObj` override in `renderField` (fields/index.tsx) handles it at runtime
- Watch for this pattern in any new model with JSONFields that store simple key-value objects

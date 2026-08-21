---
name: i18n field extraction — user language or [0]
description: JSON language objects like {"en":"text"} should extract by user's language pref first, [0] as fallback; current impl uses [0] only
type: project
---

Fields like `action`, `description`, `assigned_to` store `{"en": "text"}` language objects. The detail view and list view need to extract the display value.

**Why:** Multi-language support. The key is the language code. Users should see their language, not raw JSON.

**How to apply:**
- Extract by user's language preference first (from contact record or browser locale)
- Fall back to `[0]` (first value) if user's language not present
- Current implementation (2026-08-20) uses `[0]` only — works but not language-aware
- On edit, write back preserving the key: `onChange({...value, [key]: newText})`
- SelectField handles object values: serializes for comparison, parses back on change
- This applies to all models with language-object fields, not just Action

---
name: No inline styles — use CSS
description: All styling via CSS classes/variables, never inline style={{}} blocks; applies to all React projects
type: feedback
---

All styles must be managed by CSS classes and CSS custom properties (variables), not inline `style={{}}` blocks.

**Why:** Inline styles bypass theming, can't be overridden by CSS specificity, create duplication, and make components harder to maintain. The `.db-*` CSS variable system already exists — use it.

**How to apply:** When writing or refactoring React components, never add `style={{}}`. Use CSS classes from fields.css or create new `.db-*` classes. When encountering existing inline styles during any edit, convert them to CSS classes.

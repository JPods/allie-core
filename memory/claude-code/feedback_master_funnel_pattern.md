---
name: Master funnel pattern — few patterns with differences, inheritance handles the rest
description: Always funnel many behaviors through one master function; individual formatters/renderers are internal; users get one entry point
type: feedback
---

Many patterns are really just a few patterns with differences. Inheritance takes care of most.

**Why:** Bill said this after building formatField() — a single dispatcher that calls formatDt, formatPhone, formatAddress, etc. The scattered ad-hoc calls (67 files doing their own date formatting) were all the same behavior with minor differences. One master function eliminated them all. This applies everywhere: formatting, rendering, validation, CSS.

**How to apply:**
- When you see the same behavior scattered across files with small variations, build a master funnel function
- `formatField(value, type)` for display formatting — dates, phone, currency, percent, address, all one call
- `renderField(value, type, config)` for widget rendering — same principle for input components
- CSS: `.db-*` variables are the theme funnel — everything flows through them, individual components don't hardcode colors
- Settings: one base record per behavior pattern (dd_card:base), not per-model copies
- The individual formatters still exist — they're internal. Users never need to know about them
- Inheritance = dashboard Setting overrides base card Setting overrides model defaults
- If you're about to create a second function that does almost the same thing as an existing one, extend the existing one with a parameter instead

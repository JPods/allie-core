---
name: Print architecture — SVG + CSS + JSON separation
description: SVG owns design (fonts, layout, positions). CSS is our standard plumbing. JSON is runtime config (line counts, toggles). We are not a print design tool.
type: feedback
---

WC3 merges data into templates. Anyone can create anything that can be defined by JSON and give it to us to merge data into. That is a rule. Eyes are radically more critical of printed output than screen — we cannot win the print design game.

**Three-layer separation:**
- **SVG** = the template. Fonts, positions, styling — all in the SVG. Designer owns this completely.
- **CSS** = our standard print plumbing. Page breaks, color-adjust, hide non-print. We offer it, they use it.
- **JSON** = runtime values they can change. Line count page 1, line count following pages, page X of Y, domain, margins. Configuration, not design.

**The SVG workflow (order matters):**
1. User selects fields they want on a document FROM INSIDE WebClerk
2. WC3 generates an SVG with those fields, each element has an ID we assign
3. User exports SVG to their design tool (Affinity, Figma, Illustrator)
4. User moves objects around, sets fonts, styles it — design is theirs
5. User hands the SVG back to WC3
6. WC3 populates it with data

**Line items — the line panel pattern:**
- Users create line panel templates (one row of fields, styled as a `<g>` group)
- Line panels can be copy/pasted into other documents — reusable
- User specifies line count on page 1 and following pages (in JSON config)
- User specifies headers and footers
- WC3 clones the `<g>` group, offsets by fixed increment, fills data

**Fonts are in the SVG, not our JSON.** Don't add font_family or font_size to PrintLayout. The designer sets fonts in their tool. We populate data. That's it.

**How to apply:** Never build print design features inside WC3. The JSON has only runtime config values. Standard header/footer offerings (page X of Y, domain) are toggleable in JSON — user chooses. Alice becomes the expert in form design coaching.

---
name: Affinity Designer for SVGs
description: Bill uses Affinity Designer for SVG flowcharts — Mac set to open SVGs in Affinity. Graphviz .dot for drafts, Affinity for polished versions.
type: feedback
---

Bill uses Affinity Designer for creating and editing SVG flowcharts. His Mac is configured to open .svg files in Affinity Designer by default.

**Why:** Graphviz output is functional but visually rough. Affinity gives full design control — colors, layout, typography, custom arrows. The wc3-statement-sorter.enriched.svg was hand-designed in Affinity and looks significantly better than Graphviz output.

**How to apply:** 
- Generate .dot files for quick drafts and enrichment (URL/tooltip injection)
- Don't assume Graphviz SVG output is the final product
- When Bill says he'll design something in Affinity, don't try to improve the Graphviz output instead
- The codemap enrichment pipeline can work with both: .dot → enriched .dot → SVG (Graphviz path) or hand-designed SVG (Affinity path)
- Don't open SVG files expecting a text editor — they open in Affinity on Bill's machine

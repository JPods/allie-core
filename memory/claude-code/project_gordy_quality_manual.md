---
name: Gordy quality manual digitization
description: ISO 9001 quality manual (Gordy Israelson, West Point 1972, nuclear industry) being digitized into WC3 Action model
type: project
---

Gordon Israelson (West Point 1972, decades in nuclear industry) wrote the JPods Quality Program Manual (2014). ISO 9001 for transit safety. 20 QM sections.

**Why:** Nuclear-grade quality discipline for every WC3 installation. Gordy is thoughtful but not a programmer — we digitize his disciplines.

**How to apply:**
- All quality records are Action records with metadata.quality_type (ncr/car/deviation/dcr/request)
- Single model, one dashboard ("Get It Done Today"), one Alice
- .tsx pages at `React2025/src/apps/support/models/quality/`
- Flowchart + digitization map at `Downloads/JPods Quality Program - 2014/`
- WC2 lesson: controlling actions by model fields sucked — use metadata JSON instead
- Action #404 tracks the full digitization (8 remaining sections to implement)
- Bill may add a .config JSON field to Action for form-specific data containers
- Quality manual source: `/Users/williamjames/Downloads/JPods Quality Program - 2014/`

---
name: WC3 reporting focus — campaigns and margin velocity
description: Track campaign ROI (source + cost per order), inventory by margin velocity (margin × turnover ÷ carry cost), not just counts
type: feedback
---

**Campaigns:** Every order tracks its source — where did this order come from and what did it cost to acquire? The `source` JSON on transactions already has campaign_id, campaign_name, catalog_id. Reports must connect campaign spend to orders generated to measure acquisition cost.

**Inventory — margin velocity:** Don't just count units or track cost. The real metric is: what is the margin, how fast is it turning, relative to the cost to carry it?

Formula: `margin_velocity = (margin_per_unit × annual_turns) / carry_cost_per_unit`

A $5 margin item that turns 50x/year with $2 carry cost = 125. A $50 margin item that turns 2x/year with $20 carry cost = 5. The cheap fast-mover is 25x more productive.

**How to apply:** Inventory reports must show velocity, not just quantity. Campaign reports must show ROI, not just counts. These are operations metrics that drive purchasing and marketing decisions — this is WebClerk's domain, not accounting's.

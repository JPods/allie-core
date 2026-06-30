---
name: WC2→WC3 gap analysis from flow charts
description: 15 missing flows identified from wc2 flow charts; action records GAP-01 through GAP-15 posted to Alice; time capture via external API not built-in
type: project
---

Reviewed wc2 flow charts (20 pages). 15 gaps identified, action records #367-381 in Alice's pending queue.

**Critical operational gaps:** Order Production workflow (GAP-01), Backorder Management (GAP-02), Serial Lifecycle (GAP-03), Inventory Stacks FIFO/LIFO (GAP-04), Forecast→Auto PO (GAP-05).

**Sales/CRM gaps:** Sales Pipeline/Leads (GAP-07), Territory Management (GAP-09), Campaign/Ad Source (GAP-10), Call Reports (GAP-14), Commissions (GAP-11).

**Support gaps:** Service/Support with RMA and Pareto (GAP-08), Requisition Hub (GAP-06).

**Infrastructure gaps:** Report Multi-Channel Routing (GAP-12), Item Period Sales (GAP-15).

**Design decision:** Time capture (GAP-13) via external API integration (Toggl/Harvest/Clockify), not built-in. WO Steps reference external time entries via Connection sync.

**How to apply:** Build in priority order. Order Production and Inventory Stacks are the core — without them, wc3 only handles simple buy-and-resell. Flow charts at /Volumes/Allie/allie/allie/inbox/domains/jpods.com/public_html/software/WebClerkComExFlowCharts.pdf

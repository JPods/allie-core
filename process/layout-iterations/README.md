# Layout Iterations Log

Track each layout version with JSON, screenshot, and rationale.
One source of truth with iteration library — per CLAUDE.md.

---

## order-v1-two-col-summary (2026-08-01)

**Files:** `order-v1-two-col-summary.json`, `order-v1-two-col-summary.png`

**Layout:**
- Header: 3 columns (Customer | Ship To | Order) with dot-notation fields
- Line card: sell-side, footer buttons L/S/XR/M/D, no sidebar, no action column
- Summary tab: 2 columns — Order Totals (left) | Customer (right)
- Tabs: Summary, Margins, Contacts, QA, Actions, Documents, Notes, Related

**Summary tab left column:**
Lines, Sell Amount, Discount, Sell Total, Taxable, Tax, Shipping, Other, **Total**, Cost, Freight, Commissions, Cost Total, **Margin (%)**, Payments, Received, **Balance**

**Summary tab right column:**
Company, Price Level, Terms, Credit (Limit/Available/Balance Due/Current), Sales History (MTD/YTD/Lifetime), Payment (Avg Days/Last Payment)

**Why this version:**
- Two-column keeps order totals and customer financials visible simultaneously
- Professional users scan left-to-right: "how much is the order" → "can this customer pay"
- Cost/margin below total — the salesperson sees sell price first, cost second
- Customer credit section answers "should I extend credit" without switching tabs

**Previous iterations:**
- Single column (rejected): too narrow, customer data pushed below fold
- Three-column summary (not tried): would split order totals, making scanning harder

**Discussion:**
- Bill: "Keep this Summary layout but go back to the last 2 column version" — confirming side-by-side is the right pattern
- Bill: "Payments should be Margins" — tab renamed; the Margins tab shows the FinancialsPanel (ledger/payment records), Summary shows the snapshot

---

## order-v2-three-col-summary (2026-08-01)

**Files:** `order-v2-three-col-summary.json`, `order-v2-three-col-summary.png`

**Layout change:** Summary tab expanded from 2 columns to 3 columns.

**Three columns answer three questions:**
1. **This document** — Order Totals (sell, cost, margin, balance)
2. **This customer** — Credit, sales history, payment behavior
3. **The flow of goods and money** — Invoices/payments list with Total and Unapplied at top

**Third column: Payments & Invoices**
- Total and Unapplied at the top (the two numbers that matter)
- List of related invoices: ida, amount, unapplied
- Double-click opens invoice in new window
- Red text on unapplied > 0, green when fully applied

**Why this version:**
- Bill: "Answers: This document, This customer, The flow of goods and money"
- The three columns map to the three questions a professional asks when looking at an order
- No tab switching needed — the complete financial picture is one glance
- The invoice list is evidence, not just numbers — the user can drill into any document
- Unapplied amount is the action signal: "who owes what"

**What was kept from v1:** Order Totals and Customer columns unchanged. Third column added.

---
name: No blocking validation — users provide discipline, not software
description: Never block user workflow for missing fields (customer, contact, etc). Alice observes and advises; software does not enforce. Commercial software serves the user's rhythm.
type: feedback
---

Never stop the flow of work because a field is missing. Users may have a reason we don't understand — saving a transaction to come back later, working in a different order, using template documents.

**Why:** "We are building commercial software where users need to provide the discipline, not the software." Users are sovereign. The software is an agent with limited permissions, not a gatekeeper. Blocking validation assumes the software knows better than the user — it doesn't.

**How to apply:**
- Remove all blocking validation for missing customer/contact/vendor on transactions
- Alice watches for incomplete records and alerts at sign-in or health check ("You have 3 invoices without an assigned customer")
- Observe and advise, never block
- The only validation that blocks: amount must be positive (mathematical requirement, not a business rule)
- This applies to all transaction types: orders, invoices, payments, purchases, proposals

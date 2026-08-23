---
name: R25 multi-app form architecture
description: Forms live in their domain app (transactions/purchase/pages/), not in generic folders; Alice report records point to .tsx print options
type: feedback
---

WebClerk/frontend is a multi-app platform, not a single-focus React app. Forms belong in their domain app path.

**Why:** A PurchaseOrder is a transactions concern, not a quality concern. The same data may have multiple print/display options (standard PO, vendor PDF, receiving checklist). Putting forms in a generic `quality/forms/` bucket breaks domain ownership.

**How to apply:**
- Forms go in `src/apps/{domain}/models/{model}/pages/` — e.g. `transactions/models/purchase/pages/PurchaseOrderPrint.tsx`
- Alice has report records (WC3 Document model) pointing to each .tsx print option
- Multiple print options for the same data = multiple .tsx files in the same pages/ directory
- Quality forms (NCR, CAR, DCR, DW) stay in `quality/forms/` because quality IS their domain
- RequestForSupport is cross-domain — lives in quality but used everywhere
- The index.ts can re-export from domain locations for convenience, but the source of truth is the domain app

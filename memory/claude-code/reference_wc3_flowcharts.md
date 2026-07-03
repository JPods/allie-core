---
name: WC3 flow charts — 12 diagrams
description: 12 Graphviz DOT flow charts at readmes/flowcharts/ covering master flow, inventory, payment, serials, project, QA, action, contact, signin, customer-centered sales
type: reference
---

All at `~/Allie/readmes/flowcharts/` and `webClerk3/readmes/flowcharts/`. Editable DOT source + rendered PDF. Regenerate: `dot -Tpdf <name>.dot -o <name>.pdf`.

| Chart | What |
|-------|------|
| wc3-master-flow | Full commerce cycle Contact→GL |
| wc3-order-to-invoice | Customer→verify→Order→Production→Invoice with inventory effects |
| wc3-inventory-buckets | Quantity flow: on_hand, on_so, on_po, on_wo → available |
| wc3-payment-gl | Invoice→Ledger→Aging→Payment→Journals→GL with erosion |
| wc3-big4-transactions | Proposals/Orders/Purchases/Invoices line quantities and pending |
| wc3-serial-tracking | Serial lifecycle: PO receive→Serial→ship→custodian→SerialLog |
| wc3-project | Project connects transactions; Linkage connects data |
| wc3-qa-entity | QAQuestion→QA answers via Linkage |
| wc3-action | Universal task — Who/What/Why/When + display modes |
| wc3-contact | Central identity → references any record |
| wc3-signin-register | Login/Register→Contact→role assignment |
| wc3-customer-centered-sales | Customer's cloud of options perspective |

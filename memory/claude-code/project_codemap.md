---
name: CodeMap (codemap.guru)
description: Live architecture tool — .dot flowcharts where every node links to the code that implements it; three layers sharing one mapping file
type: project
---

CodeMap — codemap.guru. Domain to be purchased.

Three layers, one source of truth (a JSON mapping file):
1. **Enrichment script** — reads .dot + mapping, adds URL/tooltip attributes, renders clickable SVG
2. **VS Code webview panel** — click a node, side panel shows function signatures, JSON schemas, test files
3. **Architecture API** — manage action `get_architecture_node(node_name)` so Alice can walk the graph

**Why:** Diagrams drift from code. CodeMap keeps them connected. Every node links to the actual implementation. When code changes, regenerate. Alice uses it to answer "what happens when I create an invoice?"

**How to apply:** Start with WC3's 15 flowcharts in readmes/flowcharts/wc3-*.dot. Priority: inventory-buckets, flight-sim-inventory, big4-transactions. Prompt at today/architecture-tool-prompt.md.

Known gap found during initial review: order_to_purchase.py doesn't create +on_po pending records.

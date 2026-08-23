---
name: JsonSchemaTree reference tool
description: Shift-click model name in DataBrowser for JSON envelope tree; /json-schema for printable reference
type: reference
---

JsonSchemaTree component at `WebClerk/frontend/src/components/widgets/JsonSchemaTree.tsx`.

- **Shift-click** model name button in DataBrowser → inline popup with collapsible tree
- Click any leaf node → copies dot-path to clipboard (e.g., `totals.total`)
- Every model includes CoreModel fields, BaseModel fields, model-specific fields, and JSON envelopes
- `_core`, `_base`, `_txn` prefixed groups are structural — children copy as direct field names (not `_core.id`, just `id`)
- `/json-schema` route → printable reference page for all models (Print button at top)
- Schemas are static TypeScript — must be manually updated if Python model defaults change
- `ENVELOPE_SCHEMAS` exported for use in other components

Panel opens at 70% width with scroll. Print Reference link in popup header opens `/json-schema` in new tab.

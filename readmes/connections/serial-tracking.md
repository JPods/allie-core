# Serial Tracking — config.actions[] and serial_trends Document

**Created:** 2026-08-09
**Models:** `apps/products/models/serial.py` (Serial), `apps/docs/models/document.py` (Document)
**WC2 lineage:** ItemSerials + ItemSerialActions tables

---

## The Architectural Shift

**Before:** SerialLog was a separate table with FK to Serial. Actions lived outside the serial record. Required JOINs to reconstruct history. History didn't travel with the serial when synced or exported.

**After:** Actions live in `serial.config.actions[]` as an embedded array of objects. Each serial record is self-contained — its complete lifecycle history travels with it. SerialLog remains as a read-only archive for existing data.

---

## config.actions[] Schema

Each action in the array is a simple event object:

```json
{
  "action": "Received on purchase order",
  "dt": 1723190400000,
  "status_before": null,
  "status_after": "received",
  "doc_type": "purchase",
  "doc_id": 100,
  "cost": 4.80,
  "price": null,
  "discount": null,
  "notes": "",
  "by": "alice"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| action | string | yes | Full sentence from Setting.serial.config.serial_actions[].name |
| dt | integer | yes | Unix timestamp (epoch ms) — UTC always (Axiom 14) |
| status_before | string | yes | Status before this action (null for first action) |
| status_after | string | yes | Status after this action |
| doc_type | string | no | Document type: purchase, order, invoice, work_order, or empty |
| doc_id | integer | no | Document ID that triggered this action |
| cost | float | no | Cost at time of action (if captures_cost) |
| price | float | no | Price at time of action (if captures_price) |
| discount | float | no | Discount at time of action |
| notes | string | no | Freeform notes (required for some actions) |
| by | string | no | Who/what performed the action |

### User-Defined Actions

Beyond the 13 standard lifecycle actions, users can add their own action types for:

- **Inspections** — visual check, dimensional check, functional test
- **Defects** — scratch, dent, misalignment, electrical fault
- **Repairs** — part replaced, firmware updated, recalibrated
- **Attributes** — color verified, weight measured, tolerance checked
- **Location** — moved to bin A3, shipped to site B, returned to warehouse
- **Certifications** — UL certified, ISO inspected, safety tagged

These are submitted through the R25 serial action interface and appended to config.actions[].

---

## Full config Schema (Updated)

```json
{
  "customer_id": 55,
  "vendor_id": 42,
  "invoice_id": 200,
  "order_id": 150,
  "purchase_id": 100,
  "sales_line_ref": 301,
  "purchase_line_ref": 201,
  "cost": 4.80,
  "price": 12.99,
  "discount": 0.50,
  "dt_received": "2026-08-05T10:30:00Z",
  "dt_shipped": "2026-08-06T14:00:00Z",
  "days_on_plan": 1,
  "floor_plan": {
    "is_active": false,
    "dt_expires": null,
    "plan_line": null
  },
  "actions": [
    {
      "action": "Received on purchase order",
      "dt": 1723190400000,
      "status_before": null,
      "status_after": "received",
      "doc_type": "purchase",
      "doc_id": 100,
      "cost": 4.80,
      "notes": "",
      "by": "warehouse"
    },
    {
      "action": "Visual inspection passed",
      "dt": 1723276800000,
      "status_before": "received",
      "status_after": "available",
      "notes": "No visible defects",
      "by": "qa_team"
    },
    {
      "action": "Issued in invoice",
      "dt": 1723363200000,
      "status_before": "available",
      "status_after": "issued",
      "doc_type": "invoice",
      "doc_id": 200,
      "price": 12.99,
      "cost": 4.80,
      "by": "alice"
    }
  ]
}
```

---

## serial_trends Document

Every serialized Item automatically gets a Document record:

```python
Document(
    purpose='serial_trends',
    source='Item',
    source_id=item.id,
    sequence=0,        # increment if data outgrows one record
    status='active',
    data={...}         # aggregated trend data
)
```

### What serial_trends Aggregates

The trend consolidation service queries all serials for an item and produces:

```json
{
  "item_id": 55,
  "item_ida": "WDG-001",
  "dt_consolidated": 1723363200000,
  "serial_count": 47,
  "status_distribution": {
    "available": 12,
    "issued": 28,
    "returned": 3,
    "damaged": 2,
    "scrapped": 1,
    "warranty": 1
  },
  "defects": {
    "total": 8,
    "by_type": {
      "scratch": 3,
      "misalignment": 2,
      "electrical_fault": 2,
      "dent": 1
    },
    "defect_rate": 0.17,
    "trend": "stable"
  },
  "warranty": {
    "active": 15,
    "expiring_30d": 3,
    "claims_total": 4,
    "claim_rate": 0.085,
    "avg_days_to_claim": 45
  },
  "inspections": {
    "total": 52,
    "pass_rate": 0.92,
    "last_30d": 8
  },
  "lifecycle": {
    "avg_days_on_plan": 12,
    "avg_days_to_issue": 5,
    "return_rate": 0.064,
    "scrap_rate": 0.021
  },
  "cost": {
    "avg_unit_cost": 4.80,
    "avg_unit_price": 12.99,
    "avg_margin": 8.19,
    "margin_percent": 0.63
  },
  "recent_actions": [
    {"action": "Marked as damaged", "serial_ida": "SN-0042", "dt": 1723363200000, "notes": "Dropped during handling"}
  ]
}
```

### Sequence Overflow

If an item has thousands of serials and the trend data exceeds comfortable JSON size:

```python
Document.objects.filter(purpose='serial_trends', source_id=item_id).order_by('sequence')
# sequence 0: summary + defects + warranty + lifecycle + cost
# sequence 1: full action history (all serials)
# sequence 2: ...
```

### When It Updates

- **On serial action** — when any serial for this item gets a new config.actions[] entry, the trend document is queued for refresh (async via Celery, not blocking)
- **Nightly batch** — full recalculation for all serialized items
- **On demand** — service function callable from R25 or API

---

## Alice's Role

- Monitors defect rates — flags items with defect_rate > threshold
- Watches warranty claim patterns — clusters by vendor, model, time period
- Tracks return velocity — sudden increase in returns for an item triggers alert
- Identifies inspection gaps — serials that haven't been inspected within policy window
- Creates Action records when patterns emerge (Alice flags, humans fix)

---

## R25 Interface — Serial Action Submission

Location: `src/apps/products/models/serial/pages/SerialActionPanel.tsx`

### What It Does

A panel (accessible from the serial detail view) for submitting new actions to `config.actions[]`.

### UI Elements

1. **Action selector** — dropdown of available actions from Setting.serial.config.serial_actions[] plus any user-defined actions
2. **Document reference** — optional link to order/invoice/purchase/work_order (auto-populated if action requires it)
3. **Notes** — text area (required for some action types per action definition)
4. **Cost/Price** — shown only when action.captures_cost or action.captures_price
5. **Submit** — appends to config.actions[], updates serial status, saves

### Behavior

- Action list comes from Setting record `ida='serial'` → `config.serial_actions[]`
- Selecting an action shows/hides fields based on the action definition (requires_document, notes_required, captures_cost, captures_price)
- Submit calls `PATCH /api/serial/{id}/` with updated config containing the new action appended
- Status auto-updates based on action's `status_result`
- After save, trend document refresh is queued

### User-Defined Actions

Users can add custom action types through the Setting record. Each custom action defines:
- Name (full sentence)
- Status result (or empty = no status change)
- Whether document/notes/cost/price are required
- Whether reversible

Custom actions appear in the same dropdown alongside the 13 standard lifecycle actions.

---

## Key Files

| What | Where |
|------|-------|
| Serial model | `apps/products/models/serial.py` |
| Serial Pydantic schemas | `common/schemas/serial.py` |
| Serial services | `apps/products/services/serial_services.py` |
| Serial API views | `apps/products/views/serial_views.py` |
| Serial operations readme | `apps/products/readmes/serial_operations.md` |
| Trend consolidation service | `apps/products/services/serial_trends.py` (to build) |
| R25 action panel | `src/apps/products/models/serial/pages/SerialActionPanel.tsx` (to build) |
| Setting seed (13 actions) | `common/schemas/serial.py` → DEFAULT_SERIAL_ACTIONS |
| Flowchart | `readmes/flowcharts/wc3-serial-actions.dot` |

---

## Migration Path

1. **Add `actions` key to `default_serial_config()`** — empty list
2. **Update lifecycle methods** — append to `config['actions']` instead of creating SerialLog
3. **Keep SerialLog model** — read-only archive, no new writes
4. **Backfill** — optional migration to copy SerialLog entries into config.actions[] for existing serials
5. **Build trend service** — `consolidate_serial_trends(item_id)` → creates/updates Document
6. **Build R25 panel** — SerialActionPanel.tsx
7. **Wire auto-creation** — when Item gets `is_serialized=True`, auto-create Document(purpose=serial_trends)

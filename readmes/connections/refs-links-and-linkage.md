# refs.links and LinkageEntry — Connecting Records Without Managing Individual FKs

**Created:** 2026-08-09
**Models:** `common/models.py` (RefsMixin), `apps/docs/models/linkage_entry.py` (LinkageEntry)

---

## The Problem

A transaction flows from Proposal → Order → Invoice. Along the way it accumulates related records — QA reports, product specs, installation videos, certifications, customer photos, whatever the business needs. These related records must:

1. **Travel with the transaction** through each stage without re-attaching
2. **Work regardless of FK relationships** — a video doesn't have a foreign key to an invoice line
3. **Not require schema changes** when a new type of related content appears
4. **Be queryable** — find all records related to this group

Two systems solve this together.

---

## System 1: refs.links — The Cache Layer

Every record in WC3 inherits `refs` (a JSONField via RefsMixin on BaseModel). Inside refs:

```json
{
  "keywords": ["acme", "widget", "rush"],
  "tags": ["priority", "west-coast"],
  "links": {
    "contact": [{"id": 42, "display_name": "Jane Doe", "email": "jane@acme.com"}],
    "customer": [{"id": 7, "display_name": "Acme Corp", "address_full": "123 Main St"}],
    "document": [{"id": 201, "name": "spec-sheet.pdf", "type": "specification"}],
    "item": [{"id": 55, "name": "Widget A", "ida": "WDG-001"}],
    "linkage": [3001]
  },
  "parents": [],
  "depends_on": {},
  "categories": [],
  "related_ids": []
}
```

### Rules

| Rule | Why |
|------|-----|
| **FK is source of truth** | `customer_id = 7` is authoritative. `refs.links.customer` is a cache for display. |
| **refs.links is denormalized** | Contains snapshot fields (name, email, address) so the UI doesn't need extra API calls. |
| **refs.keywords powers search** | PostgreSQL GIN index. Add keywords from linked records for cross-record search. |
| **Buckets are typed** | `refs.links.contact`, `refs.links.document`, `refs.links.item` — each bucket holds entries of that model type. |
| **Denormalization is async** | Celery tasks run `denormalize_org_links()` after save — never blocks the transaction. |

### What Gets Denormalized

Controlled by `DENORM_REGISTRY` in `common/denorm_registry.py`:

| Bucket | Fields snapshot |
|--------|----------------|
| customer | ida, display_name, email, phone, address_full, attention, status |
| vendor | ida, display_name, email, phone, address_full, attention, status |
| manufacturer | ida, display_name, email, phone, address_full, attention, status |
| contact | ida, display_name, email, phone |
| document | ida, name, type |
| item | ida, name |

New buckets and fields added to the registry — no schema migration needed.

---

## System 2: LinkageEntry — The Grouping Hub

When records need to be related across models **without FK relationships**, LinkageEntry creates a group.

```
LinkageEntry table:
┌──────────┬────────────┬───────────┬────────┬──────────┐
│ group_id │ model_name │ record_id │ role   │ sequence │
├──────────┼────────────┼───────────┼────────┼──────────┤
│ 3001     │ order      │ 450       │ source │ 0        │
│ 3001     │ document   │ 201       │ spec   │ 1        │
│ 3001     │ document   │ 202       │ qa     │ 2        │
│ 3001     │ document   │ 203       │ video  │ 3        │
│ 3001     │ item       │ 55        │ item   │ 4        │
│ 3001     │ document   │ 210       │ cert   │ 5        │
└──────────┴────────────┴───────────┴────────┴──────────┘
```

### How It Works

1. **Create a group** — `LinkageEntry.create_group([{model_name, record_id, role}, ...])`
2. **Add to group** — `entry.add_to_group("document", 204)`
3. **Query group** — `LinkageEntry.get_group_entries(3001)` → all entries
4. **Find a record's group** — `LinkageEntry.get_record_group("order", 450)` → group_id 3001
5. **Summary** — `LinkageEntry.group_summary(3001)` → `{"order": [450], "document": [201, 202, 203, 210], "item": [55]}`

### Constraints

| Constraint | Enforcement |
|-----------|-------------|
| A record can only belong to ONE group | Unique constraint on (model_name, record_id) |
| Group members are ordered | `sequence` field |
| Roles are freeform | CharField — spec, qa, video, cert, photo, whatever the business needs |
| Notes per entry | `note` TextField for context |

---

## The Travel-With Pattern

When a Proposal converts to an Order, then to an Invoice:

### Header Level
- FK references (customer_id, vendor_id, etc.) are **copied** to the new transaction
- `denormalize_org_links()` **regenerates** refs.links from the new record's FKs
- The header gets fresh snapshots — not stale copies

### Line Level
- refs is **deep-copied** from source line to target line
- `refs.source.converted_from_line_id` tracks lineage
- **Linkage references travel** — if `refs.links.linkage = [3001]`, the new line points to the same LinkageEntry group
- All grouped records (QA, specs, videos, certs) are now accessible from the new line without re-attaching anything

### What This Means

```
Proposal Line #12
  refs.links.linkage = [3001]  ← points to group
  refs.links.document = [{id: 201, name: "spec-sheet.pdf"}, ...]
    │
    │ convert to Order
    ▼
Order Line #87
  refs.links.linkage = [3001]  ← same group, copied automatically
  refs.links.document = [{id: 201, name: "spec-sheet.pdf"}, ...]
  refs.source.converted_from_line_id = 12
    │
    │ convert to Invoice
    ▼
Invoice Line #143
  refs.links.linkage = [3001]  ← still the same group
  refs.links.document = [{id: 201, name: "spec-sheet.pdf"}, ...]
  refs.source.converted_from_line_id = 87
```

Add a new QA report to group 3001 at any stage — it's visible from every transaction line that references that group. No re-attachment. No per-stage FK management.

---

## refs.links vs LinkageEntry — When to Use Which

| Scenario | Use |
|----------|-----|
| Record has a FK (customer_id, vendor_id) | FK is authority. refs.links caches the snapshot. |
| Record needs display fields from a related record | refs.links denormalization (DENORM_REGISTRY) |
| Records across different models need to be grouped | LinkageEntry group |
| Related content must travel through transaction stages | LinkageEntry group + refs.links.linkage pointer |
| Need to search across related records | refs.keywords (GIN indexed) |
| New type of related content appears | Add to LinkageEntry group (no schema change) |
| Need comments aggregated across related records | LinkageEntry hub — `/tx/linkages/<id>/comments/` |

---

## Alice's Role

- Monitors refs.links integrity — flags when denormalized snapshots drift from FK authority
- Watches for orphaned LinkageEntry groups (no active transaction references them)
- Tracks which document types travel most frequently with transactions (pattern recognition)
- Flags linkage groups that grow unusually large (potential misuse of grouping)

---

## Key Files

| What | Where |
|------|-------|
| RefsMixin | `common/models.py` (line ~743) |
| default_refs() | `common/models.py` |
| DENORM_REGISTRY | `common/denorm_registry.py` |
| denormalize_links() | RefsMixin method |
| LinkageEntry model | `apps/docs/models/linkage_entry.py` |
| denormalize_org_links() | `apps/transactions/services/denormalize_org_links.py` |
| Line deep-copy (conversion) | `apps/transactions/services/conversion.py` (line ~210) |
| Linkage comments endpoint | `apps/transactions/views/linkage_views.py` |
| refs pattern readme | `readmes/topics/architecture/refs-pattern.md` |
| refs denorm playbook | `readmes/topics/architecture/refs-denormalization-playbook.md` |
| Flowchart | `readmes/flowcharts/wc3-refs-linkage.dot` |
